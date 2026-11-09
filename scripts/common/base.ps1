
# Vraagt welke server er moet afgehaald worden uit config
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters?view=powershell-7.6
param(
    [Parameter(Mandatory)]
    [string]$Node
)

# Laadt bestand in line in script zodat ze beschikbaar is in sessie
# https://medium.com/@abshuemail/dot-sourcing-in-powershell-e12046ad6e10
. "$PSScriptRoot\config.ps1"

# Variabelen voor configuratie
$cfg = Get-LabConfig
$me  = $cfg.Nodes[$Node]

# Start script
Write-Host "[!] Basis configuratie voor $Node/$me.Hostname"

# Identificeren van nat adapter en host-only
$natIndex = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object IPAddress -like $cfg.Network.NatSubnet).InterfaceIndex

# Teruggeven welke adapters geconnecteerd is
$adapters = Get-NetAdapter -Physical | Where-Object Status -eq 'Up'

# NAT is adapter die met 10.2.X.X geconfigureerd is - werkt enkel bij twee adapter, waarvan 1 NAT en 1 Host-Only
$nat      = $adapters | Where-Object ifIndex -eq $natIndex
$hostOnly = $adapters | Where-Object ifIndex -ne $natIndex

## Optioneel: Hernoem adapters
if ($nat.Name -ne 'NAT') { Rename-NetAdapter -Name $nat.Name -NewName 'NAT' }
if ($hostOnly.Name -ne 'Host-Only') { Rename-NetAdapter -Name $hostOnly.Name -NewName 'Host-Only' }

# Afhalen ID voor later te gebruiken (na testen is dit betrouwbaarder)
$natIdx = $nat.ifIndex
$hoIdx  = $hostOnly.ifIndex

# Debug
Write-Host "NAT adapter: index $natIdx, host-only adapter: index $hoIdx"

# Checken of er een IP is meegegeven in config via IF
if($me.IP) { # True -> Er is een IP ingesteld, bv. 'IP       = '192.168.26.30'
    $current = Get-NetIPAddress -InterfaceIndex $hoIdx -AddressFamily IPv4
    if ($current.IPAddress -ne $me.IP) { # Nog niet juist ingesteld?
        Write-Host "IP wordt ingesteld; nl. $($me.IP)/$($cfg.Network.PrefixLength)"
        Set-NetIPInterface -InterfaceIndex $hoIdx -Dhcp Disabled # DHCP uitzetten
        $current | Remove-NetIPAddress -Confirm:$false
        Remove-NetRoute -InterfaceIndex $hoIdx -DestinationPrefix '0.0.0.0/0' -Confirm:$false -ErrorAction SilentlyContinue
    }
}