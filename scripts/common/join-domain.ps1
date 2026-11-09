# Server/client toevoegen aan domein
param(
    [Parameter(Mandatory)]
    [string]$Node
)

# Importeren van functies (Get-LabConfig en Get-DomainAdminCredential)
$ErrorActionPreference = 'Stop' # Stoppen bij fout
. "$PSScriptRoot\config.ps1"
. "$PSScriptRoot\as-domain-admin.ps1"

$cfg     = Get-LabConfig
$zone    = $cfg.Domain.Name
$primary = $cfg.Nodes[$cfg.Dns.PrimaryNode].IP

Write-Host "[X] Domein join $Node -> $zone"

$computer = Get-CimInstance Win32_ComputerSystem
if ($computer.PartOfDomain -and $computer.Domain -eq $zone) {
    Write-Host "Al deel van $zone, niks te doen"
    return
}

# Join vinden via DNS (error check indien server 1 niet aan staat)
# https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/7fcdce70-5205-44d6-9c3a-260e616a2f04
for ($i = 1; -not (Resolve-DnsName "_ldap._tcp.dc._msdcs.$zone" -Type SRV -Server $primary -ErrorAction SilentlyContinue); $i++) {
    if ($i -gt 30) { throw "Domein $zone niet $primary na 5 minuten" }
    Write-Host "Wachten voor $zone via DNS server $primary..."
    Start-Sleep -Seconds 10
    # Na 5 minuten faalt hij
}

# Joining heeft domain credentials nodig: the local vagrant gebruiker heeft geen toegang in AD.
Write-Host "Joining $env:COMPUTERNAME aan $zone"
Add-Computer -DomainName $zone -Credential (Get-DomainAdminCredential -Config $cfg) -Force

# Klaar
Write-Host "[V] Domein Joined"