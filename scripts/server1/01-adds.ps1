# Server 1 - Stap 1: AD services installeren indien nodig
# Probleem: Vagrant verliest connectie en wilt dit niet terug verbinden.
# Oplossing: Vagrant draait een scheduled task om na promotie script uit te voeren
# https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/?view=windowsserver2025-ps
# -> Hiervoor functie Promote
$ErrorActionPreference = 'Stop' # Stoppen bij fout

param(
    [switch]$Promote
)

# Configuratiebestand inladen
. "$PSScriptRoot\..\common\config.ps1"
$cfg    = Get-LabConfig
$domain = $cfg.Domain

$localDir = 'C:\ws2'
$taskName = 'WS2-ADDS-Promotion'

# -> FASE 2
# Draaien van geplande taak indien Promote werd meegegeven als parameter
if ($Promote) {
    
    # Geef vagrant even om WinRM af te sluiten
    Start-Sleep -Seconds 30

    # Wachtwoord instellen
    $safeModePassword = ConvertTo-SecureString $domain.SafeModePassword -AsPlainText -Force

    # Installatie ADDS
    Install-ADDSForest `
        -DomainName $domain.Name `
        -DomainNetbiosName $domain.NetBiosName `
        -ForestMode $domain.ForestMode `
        -DomainMode $domain.DomainMode `
        -InstallDns `
        -SafeModeAdministratorPassword $safeModePassword `
        -NoRebootOnCompletion `
        -Force |
        Select-Object Status, Message | Format-List
    
    Restart-Computer -Force
    return # return zodat 
}

# -> FASE 1
# Effectief gedraaide script door vagrant
Write-Host "[X] AD DS: forest $($domain.Name)"

# Checken of domeincontroller (idempotentie)
# https://www.reddit.com/r/PowerShell/comments/rnbf06/detect_if_server_is_a_domain_controller/
if ((Get-CimInstance Win32_ComputerSystem).DomainRole -ge 4) {
    Write-Host 'Al een domeincontrollr!'

    # Idempotentie om taak te verwijderen indien al bestaat
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    return
}

# Installeren AD indien nodig
if (-not (Get-WindowsFeature AD-Domain-Services).Installed) {
    Write-Host 'Installeren van de AD DS role'
    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools | Out-Null
}

# Lokale administrator een wachtwoord geven (anders mislukt promotie 'Prerequisite Failures')
Write-Host 'Setting local Administrator password'
$adminPassword = ConvertTo-SecureString $domain.AdministratorPassword -AsPlainText -Force
Set-LocalUser -Name Administrator -Password $adminPassword
net user Administrator /passwordreq:yes | Out-Null

# Probleem met vagrant -> shared folder verdwijnt dus kopiëren van folder
Write-Host "Copying scripts to $localDir"
New-Item -ItemType Directory -Force $localDir | Out-Null

# .vagrant eruit laten
Get-ChildItem C:\vagrant -Exclude .vagrant | Copy-Item -Destination $localDir -Recurse -Force

# Geplande taak aanmaken -> Opsplitsen in nodige delen van Register commando

# 1. Wat er uitgevoerd moet worden
$action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$localDir\server1\01-adds.ps1`" -Promote"

# 2. Wie het moet uitvoeren (SYSTEM -> Hoogste)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

# 3. Limiet voor uitvoering in 1 uur + BELANGRIJK: FIX voor op batterij uitvoeren
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1)

# REGISTREREN van taak en uitvoeren
Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

# Klaar
Write-Host '[V] Promotie wordt in de achtergrond gedraait, server zal opnieuw opstarten na gedaan'