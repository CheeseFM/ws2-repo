
# Vraagt welke server er moet afgehaald worden uit config
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters?view=powershell-7.6
$ErrorActionPreference = 'Stop' # Stoppen bij fout

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
Write-Host "[!] Basis configuratie voor $Node/$($me.Hostname)"

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
if($me.IP) { # True -> Er is een IP ingesteld, bv. IP = '192.168.26.30'
    $current = Get-NetIPAddress -InterfaceIndex $hoIdx -AddressFamily IPv4
    if ($current.IPAddress -ne $me.IP) { # Nog niet juist ingesteld?
        Write-Host "IP wordt ingesteld; nl. $($me.IP)/$($cfg.Network.PrefixLength)"

        # DHCP uitzetten
        Set-NetIPInterface -InterfaceIndex $hoIdx -Dhcp Disabled 

        # Huidige IP verwijderen
        $current | Remove-NetIPAddress -Confirm:$false # Confirm weghalen via $false

        # Verwijderen van default route (anders krijg je problemen met internet die niet via NAT verloopt)
        Remove-NetRoute -InterfaceIndex $hoIdx -DestinationPrefix '0.0.0.0/0' -Confirm:$false -ErrorAction SilentlyContinue
        
        # Nieuwe IP instellen
        New-NetIPAddress -InterfaceIndex $hoIdx -IPAddress $me.IP -PrefixLength $cfg.Network.PrefixLength | Out-Null
    }

    # DNS server IPs afhalen vanuit configuratiebestand 
    $dnsServer1 = $cfg.Nodes[$cfg.Dns.PrimaryNode].IP
    $dnsServer2 = $cfg.Nodes[$cfg.Dns.SecondaryNode].IP 

    # Debug DNS
    Write-Host "DNS servers: $dnsServer1, $dnsServer2"

    # Instellen DNS
    Set-DnsClientServerAddress -InterfaceIndex $hoIdx -ServerAddresses $dnsServer1, $dnsServer2

    # Zichzelf toevoegen aan DNS (PTR en A record)
    Set-DnsClient -InterfaceIndex $hoIdx -RegisterThisConnectionsAddress $true
}
else { # False -> er is GEEN IP ingesteld, bv. 'IP = $null'
    Write-Host "IP wordt ingesteld via DHCP"

    # DHCP aanzetten + resetten DNS zodat die via DHCP afgehaald wordt
    Set-NetIPInterface -InterfaceIndex $hoIdx -Dhcp Enabled
    Set-DnsClientServerAddress -InterfaceIndex $hoIdx -ResetServerAddresses

    # Uitzetten toevoegen PTR + A van client
    Set-DnsClient -InterfaceIndex $hoIdx -RegisterThisConnectionsAddress $false

    # DHCP Lease hernieuwen, geen output
    ipconfig /renew Host-Only | Out-Null

}

# Zet NAT lagere metric voor fixen probleem met DNS servers + zet uit dat nieuwe DNS geregistreerd wordt op NAT
Set-NetIPInterface -InterfaceIndex $hoIdx  -InterfaceMetric 10
Set-NetIPInterface -InterfaceIndex $natIdx -InterfaceMetric 50
Set-DnsClient -InterfaceIndex $natIdx -RegisterThisConnectionsAddress $false

if ($env:COMPUTERNAME -ne $me.Hostname) {
    Write-Host "Naam wordt verandert: $env:COMPUTERNAME -> $($me.Hostname)"
    Rename-Computer -NewName $me.Hostname -Force
}
Write-Host '[V] Configuratie klaar'
