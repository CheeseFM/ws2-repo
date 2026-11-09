# Hulpfuncties voor stappen die domein administrator rechten nodig hebben.
# Vagrant werkt als de LOKALE vagrant gebruiker, die geen rechten heeft in AD.
$ErrorActionPreference = 'Stop' # Stoppen bij fout

# Credential van de domein administrator (uit config.psd1).
# Voor cmdlets met een -Credential parameter, zoals Add-Computer.
function Get-DomainAdminCredential {
    param([Parameter(Mandatory)] $Config)
    $password = ConvertTo-SecureString $Config.Domain.AdministratorPassword -AsPlainText -Force
    New-Object PSCredential("$($Config.Domain.NetBiosName)\Administrator", $password)
}

# Scriptblock uitvoeren als domein administrator via een tijdelijke scheduled task.
# Nodig voor cmdlets zonder -Credential (bv. New-GPO): Invoke-Command naar de machine
# zelf botst op het double hop probleem, een scheduled task krijgt een volledige login.
# -Parameters worden variabelen met dezelfde naam in de scriptblock (enkel tekst).
#   Invoke-AsDomainAdmin -Config $cfg -Parameters @{ Naam = 'x' } -ScriptBlock { ... $Naam ... }
# https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/register-scheduledtask
function Invoke-AsDomainAdmin {
    param(
        [Parameter(Mandatory)] $Config,
        [Parameter(Mandatory)] [scriptblock]$ScriptBlock,
        [hashtable]$Parameters = @{}
    )

    $taskName = 'WS2-DomainAdmin'
    $dir      = 'C:\ws2'
    $script   = "$dir\task.ps1"
    $log      = "$dir\task.log"
    $user     = "$($Config.Domain.NetBiosName)\Administrator"
    New-Item -ItemType Directory -Force $dir | Out-Null
    Remove-Item $log -ErrorAction SilentlyContinue

    # Script voor de task wegschrijven: eerst de parameters als variabelen, dan de scriptblock
    $lines = @('$ErrorActionPreference = ''Stop''')
    foreach ($p in $Parameters.GetEnumerator()) {
        $lines += "`$$($p.Key) = '$($p.Value)'"
    }
    # try/catch: zo komt een fout ook in de log en geeft de task exit code 1
    $lines += 'try {'
    $lines += $ScriptBlock.ToString()
    $lines += '    exit 0'
    $lines += '} catch { $_ | Out-String; exit 1 }'
    $lines | Set-Content -Path $script -Encoding UTF8

    # Task aanmaken die het script uitvoert en alle output in de log zet
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"& '$script' *>&1 | Out-File '$log'; exit `$LASTEXITCODE`""
    # VirtualBox VMs denken dat ze op batterij draaien: zonder dit blijft de task op "Queued" staan
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $taskName -Action $action -Settings $settings -RunLevel Highest `
        -User $user -Password $Config.Domain.AdministratorPassword -Force | Out-Null

    try {
        # Starten en wachten tot de task klaar is
        Start-ScheduledTask -TaskName $taskName
        do { Start-Sleep -Seconds 2 } while ((Get-ScheduledTask -TaskName $taskName).State -in 'Running', 'Queued')

        # Output tonen in Vagrant + controleren of het gelukt is
        if (Test-Path $log) { Get-Content $log | Write-Host }
        $result = (Get-ScheduledTaskInfo -TaskName $taskName).LastTaskResult
        if ($result -ne 0) { throw "Task als $user mislukt (exit code $result)" }
    }
    finally {
        # Opruimen, ook als er iets misliep (het script bevat geen wachtwoord, maar toch netjes)
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Remove-Item $script -ErrorAction SilentlyContinue
    }
}
