# Server 2 - Stap 1: DNS
$ErrorActionPreference = 'Stop' # Stoppen bij fout

#Afhalen Get-LabConfig
. "$PSScriptRoot\..\common\config.ps1"

# Variabelen aanmaken
$cfg     = Get-LabConfig
$me      = $cfg.Nodes[$cfg.Dns.SecondaryNode]
$primary = $cfg.Nodes[$cfg.Dns.PrimaryNode].IP
$zones   = $cfg.Domain.Name, $cfg.Dns.ReverseZone

Write-Host "[X] Twee DNS (master: $primary)"

# DNS installeren indien nodig
if (-not (Get-WindowsFeature DNS).Installed) {
    Write-Host 'Installing DNS role'
    Install-WindowsFeature DNS -IncludeManagementTools | Out-Null
}

# Enkel op host-only IP luisteren
$listening = @((Get-DnsServerSetting -All -WarningAction SilentlyContinue).ListeningIPAddress)

# Kijken of server naar meer dan één luistert of een fout IP (fix voor idempotentie) 
if ($listening.Count -ne 1 -or "$($listening[0])" -ne $me.IP) {
    Write-Host "DNS server luistert enkel op $($me.IP)"

    # Afhalen alle DNS settings
    $settings = Get-DnsServerSetting -All -WarningAction SilentlyContinue
    
    # Settings aanpassen (enkel master)
    $settings.ListeningIPAddress = @($me.IP)

    # Settings terugvoegen
    Set-DnsServerSetting -InputObject $settings -WarningAction SilentlyContinue
    Restart-Service DNS
}

# Zone transfer
# https://learn.microsoft.com/en-us/powershell/module/dnsserver/add-dnsserversecondaryzone?view=windowsserver2025-ps
# https://learn.microsoft.com/en-us/powershell/module/dnsserver/start-dnsserverzonetransfer?view=windowsserver2025-ps
foreach ($z in $zones) { # Haalt zones af uit config (Domein + Reverse)
    if (-not (Get-DnsServerZone -Name $z -ErrorAction SilentlyContinue)) {
        Write-Host "Creating secondary zone $z (master $primary)"
        Add-DnsServerSecondaryZone -Name $z -ZoneFile "$z.dns" -MasterServers $primary
    }

    # Direct transferen
    Start-DnsServerZoneTransfer -Name $z -FullTransfer
}

Write-Host '[V] Tweede DNS geconfigureerd'