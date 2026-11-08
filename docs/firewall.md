```
$servers = 'ad-web-dns','sec-dns','ca-dhcp'
Invoke-Command -ComputerName $servers {
    Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
} | Format-Table PSComputerName, Name, Enabled, DefaultInboundAction, DefaultOutboundAction

Invoke-Command -ComputerName $servers {
    Get-NetFirewallRule -Direction Inbound -Enabled True -Action Allow |
        Group-Object DisplayGroup | Select-Object Name, Count
} | Sort-Object PSComputerName | Format-Table PSComputerName, Name, Count
```