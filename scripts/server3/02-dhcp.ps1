# Server3 - stap 2: DHCP

$ErrorActionPreference = 'Stop' # Stoppen bij fout

# Afhalen nodige functies
. "$PSScriptRoot\..\common\config.ps1"
. "$PSScriptRoot\..\common\as-domain-admin.ps1"

# Variabelen
$cfg = Get-LabConfig
$dhcp = $cfg.Dhcp
$me = $cfg.Nodes.server3
$fqdn = "$($me.Hostname).$($cfg.Domain.Name)"
$scopeId = $cfg.Network.NetworkId
$dns     = $cfg.Nodes[$cfg.Dns.PrimaryNode].IP, $cfg.Nodes[$cfg.Dns.SecondaryNode].IP

# Start
Write-Host "[X] DHCP wordt geconfigureerd ($($dhcp.StartRange) - $($dhcp.EndRange))"

# Security groups configureren
# https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/understand-security-groups
if (-not (Get-LocalGroup 'DHCP Administrators' -ErrorAction SilentlyContinue)) {
    Write-Host 'Creating DHCP security groups'
    netsh dhcp add securitygroups | Out-Null
    Restart-Service DHCPServer
}
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12' -Name ConfigurationState -Value 2

# Installeren van DHCP indien nodig
if (-not (Get-WindowsFeature DHCP).Installed) {
    Write-Host 'Installing DHCP role'
    Install-WindowsFeature DHCP -IncludeManagementTools | Out-Null
}

# Toevoegen DHCP aan AD kennis: uitvoeren op de DC zelf (geen double hop)
# $using nodig voor andere sessie (variabelen van dit script in de scriptblock)
$dc = "$($cfg.Nodes[$cfg.Dns.PrimaryNode].Hostname).$($cfg.Domain.Name)"
Invoke-Command -ComputerName $dc -Credential (Get-DomainAdminCredential -Config $cfg) -ScriptBlock {
    # DhcpServer module staat niet standaard op de DC
    if (-not (Get-WindowsFeature RSAT-DHCP).Installed) {
        Install-WindowsFeature RSAT-DHCP | Out-Null
    }
    Add-DhcpServerInDC -DnsName $using:fqdn -IPAddress $using:me.IP
}

# Instellen scope
if (-not (Get-DhcpServerv4Scope -ScopeId $scopeId -ErrorAction SilentlyContinue)) {
    Write-Host "Aanmaken scope $scopeId ($($dhcp.StartRange) - $($dhcp.EndRange))"
    Add-DhcpServerv4Scope -Name $dhcp.ScopeName -StartRange $dhcp.StartRange -EndRange $dhcp.EndRange -SubnetMask $dhcp.SubnetMask -LeaseDuration ([TimeSpan]$dhcp.LeaseDuration) -State Active # Cast nodig door type conflict
}

# Instellen exclusion deel van de scope
$exists = Get-DhcpServerv4ExclusionRange -ScopeId $scopeId |
    Where-Object StartRange -eq $dhcp.ExclusionStart
if (-not $exists) {
    Write-Host "Exclusion $($dhcp.ExclusionStart) - $($dhcp.ExclusionEnd)"
    Add-DhcpServerv4ExclusionRange -ScopeId $scopeId -StartRange $dhcp.ExclusionStart -EndRange $dhcp.ExclusionEnd
}

# Instellen DNS servers
Set-DhcpServerv4OptionValue -ScopeId $scopeId -DnsServer $dns -DnsDomain $cfg.Domain.Name -Force

# Client ook niet laten registreren via DNS
Set-DhcpServerv4DnsSetting -DynamicUpdates Never