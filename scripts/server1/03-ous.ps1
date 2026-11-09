# Server 1 - Stap 3: OUs en gebruikers installeren

# Invoegen configuratie functie
. "$PSScriptRoot\..\common\config.ps1"

# Configuratie importeren
$cfg = Get-LabConfig
$ous = Import-PowerShellDataFile -Path "$PSScriptRoot\..\ous.psd1"

$zone = $cfg.Domain.Name

# Zet DC om in: WS26-JDV.hogent -> DC=WS26-JDV,DC=hogent
$domainDn = 'DC=' + ($zone.Split('.') -join ',DC=')    

# Start
Write-Host "[X] OUs en gebruikers instellen voor $zone"

# Wachten tot AD services klaar zijn (probleem)
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_try_catch_finally?view=powershell-7.6
function Test-AdReady { try { [bool](Get-ADDomain) } catch { $false } }
for ($i = 1; -not (Test-AdReady); $i++) {
    if ($i -gt 30) { throw 'AD Web Services not available after 5 minutes' }
    Write-Host 'Waiting for AD Web Services...'
    Start-Sleep -Seconds 10
    # 30 * 10 = 5 minuten
}

# OUs idempotent toevoegen (zoeken via Get-ADOrganizationalUnit)
foreach ($ou in $ous.OUs) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$($ou.Name)'" -SearchBase $domainDn -SearchScope OneLevel)) {
        Write-Host "Creating OU $($ou.Name)"

        # Toevoegen van OU
        New-ADOrganizationalUnit -Name $ou.Name -Path $domainDn
    }
}

