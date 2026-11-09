# Firewall voor een server, volgens Firewall in config.psd1
# Inkomend standaard geblokkeerd, enkel wat de server nodig heeft mag binnen.
# Als LAATSTE stap per server uitvoeren: sommige regelgroepen bestaan pas na de rol.
#   C:\vagrant\common\firewall.ps1 -Node server1

param(
    [Parameter(Mandatory)]
    [ValidateSet('server1', 'server2', 'server3')]
    [string]$Node
)

$ErrorActionPreference = 'Stop' # Stoppen bij fout

# Afhalen nodige functies
. "$PSScriptRoot\config.ps1"

# Variabelen: gemeenschappelijk + specifiek voor deze server
$cfg    = Get-LabConfig
$fw     = $cfg.Firewall
$groups = @($fw.Common.Groups) + @($fw[$Node].Groups)
$rules  = @($fw.Common.Rules) + @($fw[$Node].Rules) | Where-Object { $_ }
$off    = @($fw[$Node].DisabledRules) | Where-Object { $_ }

Write-Host "[X] Firewall configureren voor $Node"

# Default policy: firewall aan, inkomend blok, uitgaand toelaten
# https://learn.microsoft.com/en-us/powershell/module/netsecurity/set-netfirewallprofile
Set-NetFirewallProfile -Profile Domain, Private, Public -Enabled True `
    -DefaultInboundAction $fw.DefaultInbound -DefaultOutboundAction $fw.DefaultOutbound

# Toegelaten groepen EERST aanzetten: WinRM moet open blijven, anders verliest Vagrant de verbinding
foreach ($group in $groups) {
    if (-not (Get-NetFirewallRule -DisplayGroup $group -ErrorAction SilentlyContinue)) {
        throw "Firewall groep '$group' bestaat niet (rol nog niet geinstalleerd?)"
    }
    Enable-NetFirewallRule -DisplayGroup $group
}

# Uitzonderingen binnen een toegelaten groep terug uitzetten
foreach ($name in $off) {
    Write-Host "Uitzetten: $name"
    Disable-NetFirewallRule -Name $name
}

# Eigen regels aanmaken indien nodig
foreach ($rule in $rules) {
    if (-not (Get-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue)) {
        Write-Host "Aanmaken regel $($rule.Name)"
        New-NetFirewallRule -Name $rule.Name -DisplayName $rule.Name -Direction Inbound -Action Allow `
            -Protocol $rule.Protocol -IcmpType $rule.IcmpType -Profile Any | Out-Null
    }
    Enable-NetFirewallRule -Name $rule.Name
}

# Al de rest inkomend uitzetten (Remote Desktop, File and Printer Sharing, WinRM-Packer van de box, ...)
$ruleNames = @($rules | ForEach-Object { $_.Name })
$extra = Get-NetFirewallRule -Direction Inbound -Enabled True -Action Allow |
    Where-Object { $_.DisplayGroup -notin $groups -and $_.Name -notin $ruleNames }
if ($extra) {
    Write-Host "Uitzetten: $(($extra.DisplayName | Sort-Object -Unique) -join ', ')"
    $extra | Disable-NetFirewallRule
}

# Resultaat tonen (handig voor de demo)
Get-NetFirewallRule -Direction Inbound -Enabled True -Action Allow |
    Group-Object { if ($_.DisplayGroup) { $_.DisplayGroup } else { $_.DisplayName } } |
    Sort-Object Name | Format-Table @{ n = 'Toegelaten inkomend'; e = { $_.Name } }, Count -AutoSize |
    Out-String | Write-Host

Write-Host '[V] Firewall klaar'
