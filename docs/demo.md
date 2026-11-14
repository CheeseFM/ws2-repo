1. Voor de test (server2)
Het record bestaat nog niet. 
vagrant powershell server2 -c "Resolve-DnsName demo.WS26-JDV.hogent -Server 127.0.0.1 -DnsOnly"
vagrant powershell server2 -c "(Get-DnsServerResourceRecord -ZoneName WS26-JDV.hogent -RRType SOA).RecordData.SerialNumber"

2. Record toevoegen (server1)
vagrant powershell server1 -c "Add-DnsServerResourceRecordA -ZoneName WS26-JDV.hogent -Name demo -IPv4Address 192.168.26.99"
vagrant powershell server1 -c "(Get-DnsServerResourceRecord -ZoneName WS26-JDV.hogent -RRType SOA).RecordData.SerialNumber"

3. Na de test (server2, enkele seconden later)
vagrant powershell server2 -c "Resolve-DnsName demo.WS26-JDV.hogent -Server 127.0.0.1 -DnsOnly"
vagrant powershell server2 -c "(Get-DnsServerResourceRecord -ZoneName WS26-JDV.hogent -RRType SOA).RecordData.SerialNumber"
vagrant powershell server2 -c "Get-WinEvent -LogName 'DNS Server' -MaxEvents 3 | Format-List TimeCreated, Id, Message"

---
CA
1. GPO
vagrant powershell server1 -c 'Get-GPO -Name "Trust WS26-JDV Root CA"

2. Tonen client vertrouwen
vagrant powershell client -c 'Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -like "*WS26-JDV-Root-CA*"'

3. Web enrollment
vagrant powershell server3 -c "Get-Service CertSvc; certutil -ping"

---
Toon Firewall

1. Gewoon wat er actief is
vagrant powershell server1 -c 'Get-NetFirewallProfile | Format-Table Name, Enabled, DefaultInboundAction, DefaultOutboundAction'
vagrant powershell server2 -c 'Get-NetFirewallProfile | Format-Table Name, Enabled, DefaultInboundAction, DefaultOutboundAction'
vagrant powershell server3 -c 'Get-NetFirewallProfile | Format-Table Name, Enabled, DefaultInboundAction, DefaultOutboundAction'

2. Voorbeelden - Toegelaten
vagrant powershell client -c 'Test-NetConnection 192.168.26.20 -Port 53 | Select ComputerName, RemotePort, TcpTestSucceeded'
vagrant powershell client -c 'Test-NetConnection 192.168.26.30 -Port 80 | Select ComputerName, RemotePort, TcpTestSucceeded'

2. Voorbeelden -> Blocked
vagrant powershell client -c 'Test-NetConnection 192.168.26.20 -Port 3389 | Select ComputerName, RemotePort, TcpTestSucceeded'
vagrant powershell client -c 'Test-NetConnection 192.168.26.30 -Port 445 | Select ComputerName, RemotePort, TcpTestSucceeded'