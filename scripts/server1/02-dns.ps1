# Server 1 - Stap 2: primaire DNS
# Uitvoeren na de herstart van de promotie:
#   vagrant provision server1 --provision-with dns

# Configuratiebestand inladen
. "$PSScriptRoot\..\common\config.ps1"
$cfg    = Get-LabConfig
$zone   = $cfg.Domain.Name
$rzone  = $cfg.Dns.ReverseZone
$me     = $cfg.Nodes[$cfg.Dns.PrimaryNode]
$second = $cfg.Nodes[$cfg.Dns.SecondaryNode]

Write-Host "[X] DNS: zones voor $zone"

# Wachten tot de AD-zone geladen is (anders fout 9607 bij records toevoegen)
function Wait-DnsZone {
    for ($i = 1; $i -le 30; $i++) {
        try   { Get-DnsServerZone -Name $zone -ErrorAction Stop | Out-Null; return }
        catch { Write-Host 'Wachten op zone...'; Start-Sleep -Seconds 10 }
    }
    throw "Zone $zone niet beschikbaar na 5 minuten"
}
Wait-DnsZone

# Enkel luisteren op host-only IP (anders registreert DNS het NAT-IP opnieuw)
$settings = Get-DnsServerSetting -All -WarningAction SilentlyContinue
if ("$($settings.ListeningIPAddress)" -ne $me.IP) {
    Write-Host "DNS luistert enkel op $($me.IP)"
    $settings.ListeningIPAddress = @($me.IP)
    Set-DnsServerSetting -InputObject $settings -WarningAction SilentlyContinue
    Restart-Service DNS

    # AD-zone is na herstart even 'locked' tijdens het laden (fout 9607)
    Start-Sleep -Seconds 30
    
    Wait-DnsZone
}

# Records met NAT-IP verwijderen (ook in _msdcs, bv. gc._msdcs)
foreach ($z in $zone, "_msdcs.$zone") {
    Get-DnsServerResourceRecord -ZoneName $z -RRType A |
        Where-Object { "$($_.RecordData.IPv4Address)" -like $cfg.Network.NatSubnet } |
        ForEach-Object {
            Write-Host "Verwijderen $($_.HostName) in $z"
            $_ | Remove-DnsServerResourceRecord -ZoneName $z -Force
        }
}

# Reverse lookup zone
if (-not (Get-DnsServerZone -Name $rzone -ErrorAction SilentlyContinue)) {
    Write-Host "Reverse zone $rzone aanmaken"
    Add-DnsServerPrimaryZone -NetworkId "$($cfg.Network.NetworkId)/$($cfg.Network.PrefixLength)" -ReplicationScope Domain
}

# Eén A- en één PTR-record per server (client heeft geen vast IP)
foreach ($node in $cfg.Nodes.Values | Where-Object IP) {
    if (-not (Get-DnsServerResourceRecord -ZoneName $zone -Name $node.Hostname -RRType A -ErrorAction SilentlyContinue)) {
        Write-Host "A-record $($node.Hostname) -> $($node.IP)"
        Add-DnsServerResourceRecordA -ZoneName $zone -Name $node.Hostname -IPv4Address $node.IP
    }

    $ptrName = $node.IP.Split('.')[-1]
    if (-not (Get-DnsServerResourceRecord -ZoneName $rzone -Name $ptrName -RRType Ptr -ErrorAction SilentlyContinue)) {
        Write-Host "PTR-record $($node.IP) -> $($node.Hostname).$zone"
        Add-DnsServerResourceRecordPtr -ZoneName $rzone -Name $ptrName -PtrDomainName "$($node.Hostname).$zone"
    }
}

# Beide DNS-servers als NS + zone transfers en notify naar die NS
foreach ($z in $zone, $rzone) {
    foreach ($ns in $me, $second) {
        $nsFqdn = "$($ns.Hostname).$zone."
        $exists = Get-DnsServerResourceRecord -ZoneName $z -Name '@' -RRType NS |
            Where-Object { $_.RecordData.NameServer -eq $nsFqdn }
        if (-not $exists) {
            Write-Host "NS-record $nsFqdn in $z"
            Add-DnsServerResourceRecord -ZoneName $z -Name '@' -NS -NameServer $nsFqdn
        }
    }
    Set-DnsServerPrimaryZone -Name $z -SecureSecondaries TransferToZoneNameServer -Notify Notify
}

# CNAME voor de website (intranet -> server1)
foreach ($record in $cfg.Dns.Records) {
    if (-not (Get-DnsServerResourceRecord -ZoneName $zone -Name $record.Name -RRType CName -ErrorAction SilentlyContinue)) {
        Write-Host "CNAME $($record.Name) -> $($record.Target).$zone"
        Add-DnsServerResourceRecordCName -ZoneName $zone -Name $record.Name -HostNameAlias "$($record.Target).$zone"
    }
}

Write-Host '[V] DNS klaar'
