# Bestand voor alle configuratie, ips, ... die gebruikt worden zodat ze hier kunnen aangepast woren
# PSD1-bestand -> Data file voor powershell met @{} structuur, waar we een soort hashtabel kunnen oproepen
@{
    Domain = @{
        # https://learn.microsoft.com/nl-nl/windows-server/identity/ad-ds/deploy/install-active-directory-domain-services--level-100-
        Name = 'WS26-JDV.hogent'
        NetBiosName    = 'WS26-JDV'
        ForestMode     = 'Win2025'
        DomainMode     = 'Win2025'
        SafeModePassword = 'Vagrant123!'
        AdministratorPassword = 'Vagrant123!'
    }

    Network = @{
        # Host-only network
        NetworkId    = '192.168.26.0'
        PrefixLength = 24

        # VirtualBox NAT always geeft ons 10.0.2.x;
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
            IP = $null    # dynamic, via DHCP op server3
        }
    }

    Dns = @{
        PrimaryNode   = 'server1'
        SecondaryNode = 'server2'
        ReverseZone   = '26.168.192.in-addr.arpa'
        Forwarders    = @()
        Records = @(
            @{ Name = 'intranet'; Type = 'CNAME'; Target = 'ad-web-dns' }
        )
    }

    # Webserver (IIS) op server1
    Iis = @{
        HostName = 'intranet'   # -> intranet.WS26-JDV.hogent (CNAME hierboven)
        SiteName = 'Intranet'   # naam van de site in IIS, ook gebruikt voor C:\inetpub\intranet
        Port     = 80
    }

}