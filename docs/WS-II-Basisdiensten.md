📅 Aangemaakt: 01-10-2026

> https://developer.hashicorp.com/vagrant/docs

>[!quote] 
>In dit deel automatiseer je de installatie en configuratie van een aantal basisdiensten. Voor dit deel dien je de scripts in, een korte deployment guide en een demo-video die het uitrollen van de omgeving illustreert en de nodige functionaliteiten illustreert.

# Doel opdracht
---
Om deze omgeving zo veel mogelijk te automatiseren. In een ideaal scenario kan je de volledige omgeving uitrollen met één vagrant up commando.
## VM verdeling

| VM                       | [[#IP verdeling & DHCP\|IP]] | OS                       | Rollen                                                      |
| ------------------------ | ---------------------------- | ------------------------ | ----------------------------------------------------------- |
| `ad-web-dns` *(server1)* | `192.168.26.10`              | Windows Server 2025 Core | [[#Active Directory]], [[#DNS\|Primary DNS]], [[#DNS\|IIS]] |
| `sec_dns` *(server2)*    | `192.168.26.20`              | Windows Server 2025 Core | [[#DNS\|Secundary DNS]]                                     |
| `ca-dhcp` *(server 3)*   | `192.168.26.30`              | Windows Server 2025 Core | [[#Certificate Authority\|CA]], [[#DHCP]]                   |
| `client`                 | `192.168.26.100 - 200`       | Windows 11 Enterprise    | [[#Management tools\|RSAT tools]]                           |

### Netwerk
Bij elke VM:
- Eén interface verbonden met `VirtualBox (default) NAT` *(voor toegang tot het Internet)*  
- Eén interface verbonden met een `Host-Only network` *(voor interne communicatie, geen Internettoegang)*

>[!warning] Je mag de versie + box type niet veranderen!

Hieronder de vereisten per applicatie *(ook gelinkt in [[#VM verdeling]])*
## IP verdeling & DHCP

> [!warning] Hiervoor maak je geen gebruik van de ingebouwde DHCP-server van VirtualBox  
> Deze moet uitgeschakeld zijn! Maar gebruik je de DHCP-rol van Windows Server.  

Voor het host-only netwerk gebruik je IP-adressen uit de range `192.168.26.0/24`.  
1. De 3 servers krijgen een vast IP-adres via PowerShell *(dus niet via vagrant, de IP-adressen in de VagrantFile zijn een placeholder).*
2. De client krijgt dynamisch een IP-adres via DHCP  
### DHCP
De DHCP server op `server3` heeft een actieve scope van `192.168.26.100` tot en met `192.168.26.200` , waarbij IP-adressen `192.168.26.151` tot en met `192.168.26.200` voorlopig nog niet gebruikt worden.  

### Firewall
Bekijk binnenkomende verkeer bij elke VM en beslis welke poorten door de firewall gelaten wordt.

>[!warning] Het is de bedoeling dat je écht een lijst opstelt en die correct toepast op de VMs, anders krijg je minpunten

*Tijdelijk oplossing*
```Powershell
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
```

## Active Directory
Alle toestellen (3 servers en de client) behoren tot één Active Directory domein met  
volgende eigenschappen
- **Naam domein**: `WS26- $initialen .hogent` *(vervang $initialen door jouw initialen, bv. WS26-JD.hogent voor John Doe).*  
- **Forest functional level**: Windows Server 2025  
- **Domain functional level**: Windows Server 2025

Voorzie een OU-structuur met daarin minstens **3 OUs** en minstens **4 gebruikers**
- Minstens 2 gebruikers hebben de rol van `Domain Admin`  
- Minstens 2 gebruikers zijn enkel `Domain User zonder administrator-rechten`

### DNS
Binnen DNS is er zowel een forward als reverse lookup zone, en alle 3 de servers hebben exact één A-record en één PTR-record in DNS. 
- Hiervoor ==gebruik je het IP-adres van het host-only netwerk== (er mogen dus geen records zijn in DNS met het IP-adres van de VirtualBox NAT interface). 
- Zorg er ook voor dat de ==client zichzelf niet automatisch registreert in DNS==. 
- ==Hetzelfde geldt voor de NAT interface van alle servers==. Vergeet niet dat  er twee DNS-servers zijn, dit moet ook zo zichtbaar zijn in de DNS zones
- Zorg ervoor dat de ==zone transfers correct werken==, dus alle wijzigingen binnen zones op de primaire DNS-server moeten automatisch overgenomen worden door de secundaire DNS-server

## Certificate Authority
Voorzie op server3 een Certification Authority voor jouw domein. Deze CA is automatisch vertrouwd door alle toestellen (de servers én de client) binnen het Active Directory domein.
- Zorg er voor dat de Web Enrollment Role Service (te bereiken via http://$FQDN/CertSrv) correct werkt *(vervang FQDN door de Fully Qualified Domain Name van server3).*

## Webserver
Op server1 voer je een basisinstallatie uit van IIS, waarop je een lokale webpagina host. De  
website is bereikbaar via http://intranet.`$jouw-domein *(vervang `$jouw-domein` door de naam*  
*van jouw domein)*. -> Voorzie voor deze website de nodige record(s) in DNS.
- Voor dit deel is een eenvoudige statische HTML-pagina met Hello World in een webapplicatie die luistert op poort `80` voldoende. *(In deel 2 zal je deze webserver verder uitbreiden)*

## Management tools
Installeer de nodige Management (RSAT) Tools op de `Windows 11 client`. 
- ==Installeer enkel de tools die je echt nodig hebt voor de demo (zie verder).==

# Concrete TODO's
---
Hierbij hoort ook telkens het documenteren van deze stappen (screenshots + problemen noteren, handig voor readme/reflectie).

## Planning
| Deadline        | Wat                                                    |
| --------------- | ------------------------------------------------------ |
| **01/10**       | Vagrant boxes lokaal backuppen                         |
| 11/10           | Finale versie opdrachtdocument checken op wijzigingen  |
| midden okt      | Demo-checklist op leerpad ophalen en verwerken         |
| 18/10           | Server1 werkt (AD, DNS, IIS)                           |
| 25/10           | Server2 + Server3 werken (sec. DNS, CA, DHCP)          |
| 01/11           | Client + firewall + zoveel mogelijk automatisatie      |
| **08/11**       | Scripts af, volledige uitrol van nul getest            |
| 09/11 - 14/11   | Readme, video, zip                                     |
| **15/11 15:00** | Indienen op Orion (niet last minute uploaden!)         |

## Basisconfiguratie
- [x] VirtualBox 7.2.x en Vagrant installeren
- [x] **Boxes lokaal backuppen** (versies zijn vastgepind, niet wijzigen!)
	- [x] Windows Server 2025 Core box downloaden (versie 2607.0.0)
	- [x] Windows 11 Enterprise box downloaden (versie 2607.1.0)
	- [x] Beide boxes exporteren naar een `.box` bestand en veilig bewaren
- [x] Basis Vagrantfile van Orion downloaden
- [x] Git-repo aanmaken voor scripts (versiebeheer + backup)
- [x] VirtualBox DHCP-server op het host-only netwerk **uitschakelen**
- [x] Mappenstructuur `scripts/` opzetten:
	- [x] Vagrantfile
	- [x] Centraal configbestand (domeinnaam, IP's, wachtwoorden op één plek)
	- [x] Apart bestand voor OU's en gebruikers (eenvoudig aanpasbaar)
	- [x] Map met gedeelde functies (IP instellen, hostname, firewall)
	- [x] Map per VM (server1, server2, server3, client)
- [x] Vagrantfile uitbreiden met provisioners per VM
	- [x] Reboots opvangen (opsplitsen in meerdere provisioning-stappen)
	- [x] Volgorde VMs vastleggen: server1, server2, server3, client
- [x] Mogelijk systeem voorzien om scripts **los** te kunnen uitvoeren, zodat je niet telkens van nul moet starten
	- *Benoemde provisioners (`vagrant provision server1 --provision-with dns`) + alle scripts idempotent + snapshots (`vagrant snapshot save/restore`).*

## Gemeenschappelijk (elke server)
- [x] Hostname instellen
- [x] Host-only adapter identificeren op basis van IP/MAC, niet op naam
- [x] Vast IP instellen, **zonder default gateway** op host-only (anders conflict met NAT)
- [x] DNS-servers van host-only adapter instellen
- [x] NAT-adapter niet laten registreren in DNS

## Server1 - [[#Active Directory]], [[#DNS|Primary DNS]], [[#Webserver|IIS]]
- [x] Vast IP `192.168.26.10`, DNS naar zichzelf
- [x] AD DS rol installeren
- [x] Nieuwe forest aanmaken (`WS26-<initialen>.hogent`, forest + domain level Windows Server 2025) en rebooten
- [ ] **DNS na promotie**
	- [x] DNS-server enkel laten luisteren op host-only IP
	- [x] Controleren dat er geen records met het NAT-IP bestaan, anders verwijderen
	- [x] Reverse lookup zone aanmaken voor `192.168.26.0/24`
	- [x] Exact één A- en één PTR-record per server
	- [x] NS-record voor server2 in forward én reverse zone
	- [ ] Zone transfers + notify naar server2 toestaan (voor beide zones)
	- [ ] Forwarder voor internetnamen instellen (testen of nodig)*
- [x] **OU's en gebruikers**
	- [x] Minstens 3 OU's
	- [x] Minstens 2 gebruikers in Domain Admins
	- [x] Minstens 2 gewone Domain Users
	- [ ] Wachtwoorden noteren voor readme
- [x] **IIS**
	- [x] Webserver-rol installeren
	- [x] Statische Hello World-pagina op poort 80
	- [x] DNS-record voor `intranet` aanmaken
- [ ] **GPO voor CA-vertrouwen** (pas na installatie CA op server3)
	- [ ] Root-certificaat via GPO verspreiden naar Trusted Root Certification Authorities

## Server2 - [[#DNS|Secundary DNS]]
- [x] Vast IP `192.168.26.20`, DNS naar server1
- [x] Toevoegen aan domein en rebooten (**geen** domeincontroller!)
- [x] DNS-rol installeren
- [x] Secondary zones aanmaken voor forward en reverse zone, met server1 als master
- [ ] Testen: record op server1 toevoegen en controleren of het op server2 verschijnt

## Server3 - [[#Certificate Authority|CA]], [[#DHCP]]
- [x] Vast IP `192.168.26.30`, DNS naar server1 en server2
- [x] Toevoegen aan domein en rebooten
- [x] **CA** (uitvoeren als domain admin)
	- [x] CA-rol en Web Enrollment installeren
	- [x] Enterprise Root CA configureren
	- [x] Web Enrollment configureren
	- [ ] Testen of `http://<FQDN server3>/CertSrv` werkt
- [x] **DHCP**
	- [x] DHCP-rol installeren en autoriseren in AD*
	- [x] Security groups aanmaken en Server Manager-melding wegwerken
	- [x] Scope `192.168.26.100 - .200` aanmaken
	- [x] Exclusion range `192.168.26.151 - .200`
	- [ ] Opties bewust kiezen en motiveren in readme:
		- [ ] DNS-servers (server1 en server2)
		- [ ] DNS-domeinnaam
		- [ ] Router-optie bewust weglaten (host-only heeft geen uplink)
	- [x] DHCP geen DNS-records laten registreren voor clients

## Client - [[#Management tools|RSAT tools]]
- [x] Host-only adapter op DHCP, controleren dat IP in `.100 - .150` valt
- [x] DNS-registratie uitschakelen op beide adapters*
- [x] Toevoegen aan domein en rebooten
- [x] Enkel de nodige RSAT tools installeren:*
	- [x] Active Directory
	- [x] DNS
	- [x] DHCP
	- [x] Certificate Services
	- [x] Group Policy Management
- [ ] Controleren dat het CA-certificaat vertrouwd wordt

## Firewall
- [ ] Default policy op alle servers: inkomend blokkeren, uitgaand toelaten, firewall aan
- [ ] WinRM openlaten, anders verliest Vagrant de verbinding
- [ ] Lijst opstellen en motiveren in readme:

| Server  | Toegelaten inkomend (regelgroepen)                                                                                               |
| ------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Alle    | Windows Remote Management, Core Networking (DHCP-client op NAT, IPv6), OpenSSH Server, ping (eigen regel)                        |
| server1 | Active Directory Domain Services (LDAP, GC, RPC, SMB 445 voor SYSVOL, W32Time), AD Web Services, Kerberos KDC, DNS Service, HTTP |
| server2 | DNS Service (53 + RPC voor beheer)                                                                                               |
| server3 | DHCP Server, DHCP Server Management (RPC console), Certification Authority (DCOM/RPC), HTTP (CertSrv)                            |

- [ ] Waar mogelijk ingebouwde regelgroepen gebruiken
- [ ] Testen dat alles werkt met firewall aan*

## Testen
- [ ] Volledige uitrol van nul zonder manuele fixes
- [ ] Duur van volledige uitrol noteren (handig voor video)
- [ ] Commando voor tijdelijk DNS-record (CNAME) voorbereiden voor de demo
	- *Server1: `Add-DnsServerResourceRecordCName -ZoneName WS26-JDV.hogent -Name demotest -HostNameAlias ad-web-dns.WS26-JDV.hogent.` → server2: `Get-DnsServerResourceRecord -ZoneName WS26-JDV.hogent -Name demotest`*

## Finalisatie
- [ ] **readme.pdf** (max. 8 pagina's, naam + klasgroep vermelden, enkel PDF)
	- [ ] Deel 1 - Deployment guide ("dummyproof")
		- [ ] Vereisten (VirtualBox-versie, Vagrant, RAM)
		- [ ] Installatie boxes en uitschakelen host-only DHCP
		- [ ] Mappenstructuur en waar initialen/domeinnaam aanpassen
		- [ ] Alle stappen in volgorde, inclusief manuele stappen
		- [ ] **Overzicht gebruikers en wachtwoorden**
	- [ ] Deel 2 - Status: wat is af, wat niet, problemen en oplossingen
	- [ ] Deel 3 - Conclusie: wat geleerd, wat anders, waaraan te veel tijd verloren
- [ ] **Demo video** (Panopto, max. **10 min**, webcam + micro verplicht)
	- [ ] Ongeveer 6 min uitrol: door elk script scrollen en uitleggen, manuele stappen tonen, pauzeren tijdens wachten
	- [ ] Ongeveer 4 min demo:
		- [ ] OU's en gebruikers vanaf client
		- [ ] Forward/reverse zones op beide DNS-servers, NS-records, A/PTR per server
		- [ ] Tijdelijk record op server1 verschijnt op server2
		- [ ] Client krijgt IP via DHCP, scope/exclusion/opties tonen
		- [ ] CA-certificaat vertrouwd op client en CertSrv werkt
		- [ ] Intranetsite in browser van client
		- [ ] Firewallregels
	- [ ] Aanvullen met officiële checklist (midden oktober)
	- [ ] Video delen met beide lectoren
- [ ] `demo.txt` met enkel de Panopto-link
- [ ] **Zip** `WS2-2627-EP1-NaamVoornaam.zip` (max. 5 MB)
	- [ ] Bevat `readme.pdf`, `demo.txt` en `scripts/`
	- [ ] Geen `.vagrant/`, ISO's of installers
- [ ] ==Terug toevoegen aan normale vault==
