# Bestand voor alle configuratie, ips, ... die gebruikt worden zodat ze hier kunnen aangepast woren
# PSD1-bestand -> Data file voor powershell met @{} structuur, waar we een soort hashtabel kunnen oproepen
@{
    Domain = @{
        # https://learn.microsoft.com/nl-nl/windows-server/identity/ad-ds/deploy/install-active-directory-domain-services--level-100-
        Name = 'WS26-JDV.hogent'
        NetBiosName    = 'WS26-JDV'
        ForestMode     = 'Win2025'
        DomainMode     = 'Win2025'
    }

    Network = @{
        # Host-only network. VirtualBox DHCP on this network must be disabled.
        NetworkId    = '192.168.26.0'
        PrefixLength = 24
        # No default gateway on the host-only adapter: internet goes via NAT.

        # VirtualBox NAT always hands out 10.0.2.x; used to tell the adapters apart.
        NatSubnet    = '10.0.2.*'
    }

    # Per server het juiste IP en host naam
    Nodes = @{
        server1 = @{
            Hostname = 'ad-web-dns'
            IP       = '192.168.26.10'
        }
        server2 = @{
            Hostname = 'sec-dns'
            IP       = '192.168.26.20'
        }
        server3 = @{
            Hostname = 'ca-dhcp'
            IP       = '192.168.26.30'
        }
        client = @{
            Hostname = 'client'
            IP       = $null    # dynamic, via DHCP on server3
        }
    }

}