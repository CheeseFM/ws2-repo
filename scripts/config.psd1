# Bestand voor alle configuratie, ips, ... die gebruikt worden zodat ze hier kunnen aangepast woren
# PSD1-bestand -> Data file voor powershell met @{} structuur, waar we een soort hashtabel kunnen oproepen
@{
    Domain = @{
        # https://learn.microsoft.com/nl-nl/windows-server/identity/ad-ds/deploy/install-active-directory-domain-services--level-100-
        Name = 'WS26-JDV.hogent'
        NetBiosName = 'WS26-JDV'
        ForestMode = 'Win2025'
        DomainMode = 'Win2025'
        SafeModePassword = 'Vagrant123!'
        AdministratorPassword = 'Vagrant123!'
    }

    Network = @{
        # Host-only network
        NetworkId = '192.168.26.0'
        PrefixLength = 24

        # VirtualBox NAT always geeft ons 10.0.2.x;
        NatSubnet = '10.0.2.*'
    }

    # Per server het juiste IP en host naam
    Nodes = @{
        server1 = @{
            Hostname = 'ad-web-dns'
            IP = '192.168.26.10'
        }
        server2 = @{
            Hostname = 'sec-dns'
            IP = '192.168.26.20'
        }
        server3 = @{
            Hostname = 'ca-dhcp'
            IP = '192.168.26.30'
        }
        client = @{
            Hostname = 'client'
            IP = $null    # dynamic, via DHCP op server3
        }
    }

    Dns = @{
        PrimaryNode = 'server1'
        SecondaryNode = 'server2'
        ReverseZone = '26.168.192.in-addr.arpa'
        Forwarders = @()
        Records = @(
            @{ Name = 'intranet'; Type = 'CNAME'; Target = 'ad-web-dns' }
        )
    }

    Dhcp = @{
        ScopeName = 'Host-only clients'
        StartRange = '192.168.26.100'
        EndRange = '192.168.26.200'
        SubnetMask = '255.255.255.0'
        ExclusionStart = '192.168.26.151'
        ExclusionEnd = '192.168.26.200'
        LeaseDuration = '8.00:00:00'
    }

    # Server3 CA
    Ca = @{
        CommonName = 'WS26-JDV-Root-CA'
        Type = 'EnterpriseRootCa'
        ValidityYears = 5
        GpoName = 'Trust WS26-JDV Root CA'
    }

    # Webserver (IIS) op server1
    Iis = @{
        HostName = 'intranet'   # -> intranet.WS26-JDV.hogent (CNAME hierboven)
        SiteName = 'Intranet'   # naam van de site in IIS, ook gebruikt voor C:\inetpub\intranet
        Port = 80
        # HttpsPort = 443               # server1\06-iis-https.ps1
        # CertTemplate = 'WebServer'    # template op de CA voor het certificaat
    }

    # RSAT tools op de client (client\01-rsat.ps1), enkel wat nodig is
    Client = @{
        RsatTools = @(
            'Rsat.ActiveDirectory.DS-LDS.Tools'      # Users and Computers + AD PowerShell
            'Rsat.Dns.Tools'                         # DNS Manager
            'Rsat.DHCP.Tools'                        # DHCP console
            'Rsat.CertificateServices.Tools'         # Certification Authority console
            'Rsat.GroupPolicy.Management.Tools'      # Group Policy Management
        )
    }

    # Firewall per server (common\firewall.ps1)
    # Inkomend standaard geblokkeerd, uitgaand toegelaten. Enkel wat hieronder staat mag binnen,
    # alle andere inkomende allow-regels (Remote Desktop, File and Printer Sharing, ...) gaan uit.
    #   Groups        = ingebouwde Windows regelgroepen (DisplayGroup), sommige bestaan pas na de rol
    #   Rules         = eigen regels als er geen ingebouwde groep voor is
    #   DisabledRules = regels (Name) die UIT blijven, ook al staat hun groep open
    # De client houdt zijn standaard firewall (opdracht: enkel servers).
    Firewall = @{
        DefaultInbound  = 'Block'
        DefaultOutbound = 'Allow'

        # Op elke server
        Common = @{
            Groups = @(
                'Windows Remote Management'    # 5985: Vagrant + remote PowerShell
                'Core Networking'              # DHCP client op de NAT adapter, IPv6 basis
                'OpenSSH Server'               # 22: vagrant ssh
            )
            Rules = @(
                @{ Name = 'WS2-Ping-In'; Protocol = 'ICMPv4'; IcmpType = '8' }    # ping (echo request)
            )
        }

        server1 = @{
            Groups = @(
                'Active Directory Domain Services'    # LDAP, GC, RPC, SMB 445 (SYSVOL/GPO), tijd, ...
                'Active Directory Web Services'       # 9389: AD PowerShell / RSAT
                'Kerberos Key Distribution Center'    # 88: authenticatie
                'DNS Service'                         # 53 + zone transfer + RPC voor DNS Manager
                'World Wide Web Services (HTTP)'      # 80: intranet site
                # 'Secure World Wide Web Services (HTTPS)'    # 443: intranet site via https
            )
        }

        server2 = @{
            Groups = @(
                'DNS Service'                         # 53 + notify van server1 + RPC voor DNS Manager
            )
        }

        server3 = @{
            Groups = @(
                'DHCP Server'                         # 67/68: leases uitdelen
                'DHCP Server Management'              # RPC voor de DHCP console
                'Certification Authority'             # DCOM/RPC: certificaat aanvragen + CA console
                'World Wide Web Services (HTTP)'      # 80: /CertSrv
            )
            # Beide groepen openen SMB (445), maar de consoles werken ook zonder -> SMB dicht
            DisabledRules = @(
                'Microsoft-Windows-CertificateServices-CertSvc-RPC-NP-In'
                'Microsoft-Windows-DHCP-SMB-TCP-In'
            )
        }
    }

}