# README Portfolio
---
> **Naam**: Jelle De Vreeze - **Klasgroep**: `3B1` - **Domein**: `WS26-JDV.hogent`

## Opstarten
---
> Vereisten: `Virtualbox Versie 7.2.X`, `Vagrant 2.4.9`, `PowerShell 7.6.6`

Het is mogelijk dat andere versies werken, zolang vagrant de versie van virtualbox ondersteunt zou er geen probleem mogen zijn.

### Stappenplan
Het is echter niet de bedoeling dat men gewoon `vagrant up` draait - door domain promotion faalt WinRM op een bepaald punt.
1. Powershell op je host is wel een must *(voor Linux gebruikers: https://learn.microsoft.com/en-us/powershell/scripting/install/linux-overview?view=powershell-7.6 - herstart hierna)* 
2. Open je terminal
3. Ga in de scripts folder `cd scripts` vanuit de zip

```
./deploy.ps1
```
- Op Linux moet je mogelijk `chmod +x ./deploy.ps1`

>[!warning] Mogelijke problemen
>De boxes zijn niet langer beschikbaar - neem contact op met lector Windows Server 2


### Opbouw deploy script

| Stap | Script                                                        | Actie                                                                                                                                                                                                                                                                                                                                                                   | VM                   |
| ---- | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- |
| 1    | `vagrant up server1 --provision`                              | `base.ps1` stelt de adapters, het vaste IP, DNS en de hostname in en herstart. Daarna installeert `01-adds.ps1` de AD DS-rol, geeft de lokale Administrator een wachtwoord, kopieert de scripts naar `C:\ws2` en start een scheduled task voor de promotie.                                                                                                             | `server1`            |
| 1b   | _(scheduled task, los van Vagrant)_                           | `01-adds.ps1 -Promote` maakt de forest aan met `Install-ADDSForest` en herstart de server.                                                                                                                                                                                                                                                                              | `server1`            |
| 2    | `vagrant up client --provision-with rsat`                     | Draait als achtergrondjob: `01-rsat.ps1` installeert alleen de nodige RSAT-tools via Windows Update. Dat duurt ongeveer 40 minuten.                                                                                                                                                                                                                                     | `client`             |
| 3    | `vagrant winrm server1 ...` _(lus)_                           | Controleert elke 30 seconden of de NTDS-service draait, dus of de promotie en de herstart klaar zijn.                                                                                                                                                                                                                                                                   | `server1`            |
| 4    | `vagrant provision server1 --provision-with adds,dns,ous,iis` | `01-adds.ps1` ruimt de scheduled task op. `02-dns.ps1` maakt de reverse zone, de A-, PTR-, NS- en CNAME-records en de zone transfers aan en verwijdert de NAT-records. `03-ous.ps1` maakt de OU's en gebruikers aan. `04-iis.ps1` zet de intranetsite op poort 80.                                                                                                      | `server1`            |
| 5    | `vagrant up server2 --provision`                              | `base.ps1` doet de basisconfiguratie en herstart. `join-domain.ps1` voegt de server toe aan het domein en herstart. `01-dns-secondary.ps1` maakt de secundaire zones aan met server1 als master. `firewall.ps1` stelt de firewall in.                                                                                                                                   | `server2`            |
| 6    | `vagrant up server3 --provision`                              | `base.ps1` doet de basisconfiguratie en herstart. `join-domain.ps1` voegt de server toe aan het domein en herstart. `01-ca.ps1` installeert de Enterprise Root CA en Web Enrollment (`/CertSrv` over HTTP). `02-dhcp.ps1` installeert DHCP, autoriseert de server op de DC en maakt de scope, de exclusion range en de opties aan. `firewall.ps1` stelt de firewall in. | `server3`            |
| 7    | `vagrant provision server1 --provision-with ca-gpo,firewall`  | `05-ca-trust-gpo.ps1` zet het root-certificaat van de CA via een GPO (gelinkt aan het domein) in Trusted Root Certification Authorities van alle toestellen. `firewall.ps1` stelt de firewall van server1 in. *(`06-iis-https.ps1` is voor deel 2 en staat nog uit.)*                                                                                                   | `server1`            |
| 7b   | `vagrant winrm server2/server3 ...`                           | `gpupdate /target:computer /force` zodat server2 en server3 de CA GPO meteen ophalen. Ze zaten al in het domein voordat de GPO bestond en vernieuwen hun policy anders maar om de ~90 minuten.                                                                                                                                                                          | `server2`, `server3` |
| 8    | _(Wait-Job)_                                                  | Wacht tot de RSAT-job van stap 2 klaar is en stopt als die mislukt is (zie `.vagrant\client-rsat.log`).                                                                                                                                                                                                                                                                 | `client`             |
| 9    | `vagrant provision client --provision-with base,join`         | `base.ps1` zet de host-only adapter op DHCP, schakelt DNS-registratie uit en herstart. `join-domain.ps1` voegt de client toe aan het domein en herstart.                                                                                                                                                                                                                | `client`             |

### Wat doen de scipts
*provisioning scripts*
- **client** -> `01-rsat.ps1`: Installeert de RSAT tools *(wordt aangeropen in de achtergrond)*
- **common** ->
	- `base.ps1`: Basisconfiguratie die bij elke server wordt overlopen *(adapters bepalen, hernoemen, geven van een IP hostname instellen)*
	- `config.ps1`: Gedeelde functie voor `config.psd1` in te laden
	- `firewall.ps1`: Gedeelde script om firewall instellingen uit config te halen en die in te stellen
	- `join-domain.ps1`: Gedeelde functie om domein te joinen
	- `as-domain-admin.ps1` -> zie [Problemen tegengekomen](#Problemen%20tegengekomen)
- **server1** ->
	- `01-adds.ps1`: Active Directory Domain Services afhalen en instellen, daarna herstarten.
	- `02-dns.ps1`: DNS configureren
	- `03-ous.ps1`: Op basis van `ous.psd1` gebruikers en organisation units erin steken
	- `04-iis.ps1`: Webserver installeren en starten
	- `05-ca-trust-gpo.ps1`: Vertrouwen van de CA
- **server2** -> `01-dns-secondary.ps1`: DNS installeren + zone transfer
- **server3** -> 
	- `01-ca.ps1`: CA installeren en configureren via WebAdministration module
	- `02-dhcp.ps1`: DHCP installeren en configureren

*andere scripts*
- `deploy.ps1` -> elke stap voor provisionen automatisch uitvoeren *(zie [Problemen tegengekomen](#Problemen%20tegengekomen))* 
- `Vagrantfile` -> context file voor vagrant, aangevuld met provision steps
#### Centrale configuratie
1. `config.psd1`: *(Powershell Data File)* met daarin alle globale variabelen - Waaronder dus ook *bv. het domein, de hostnames van de server, wie DNS is, dhcp scope, ...*
2. `ous.psd1`: Alle nodige OUs en gebruikers die worden aangemaakt

### Overzicht gebruikers
*OUs*

|OU|
|---|
|IT|
|Lectoren|
|Studenten|

*Gebruikers in Domein*

| SamAccountName  | Voornaam | Achternaam | OU        | Domain Admin | Wachtwoord  |
| --------------- | -------- | ---------- | --------- | ------------ | ----------- |
| jelle.devreeze  | Jelle    | De Vreeze  | IT        | Ja           | `Admin123!` |
| jeroen.janssens | Jeroen   | Janssens   | IT        | Ja           | `Admin123!` |
| sanne.maes      | Sanne    | Maes       | Lectoren  | Nee          | `User123!`  |
| ben.scout       | Ben      | Scout      | Studenten | Nee          | `User123!`  |

### Firewall
Op alle servers staat de firewall aan voor elk profiel *(Domain, Private, Public)*: **inkomend blokkeren, uitgaand toelaten**. Enkel wat hieronder staat mag binnen, alle andere inkomende allow-regels *(Remote Desktop, File and Printer Sharing, WinRM-Packer van de box, ...)* worden uitgezet door [firewall](scripts/common/firewall.ps1). Waar mogelijk worden de ingebouwde regelgroepen van Windows gebruikt, de lijst zelf staat in [config](scripts/config.psd1). De client houdt zijn standaard firewall.

| Server    | Toegelaten inkomend                | Poort(en)                          | Waarom                                                         |
| --------- | ---------------------------------- | ---------------------------------- | -------------------------------------------------------------- |
| Alle      | Windows Remote Management          | 5985                               | Vagrant + remote PowerShell, anders verliest vagrant verbinding |
| Alle      | Core Networking                    | DHCP client, ICMPv6, ...           | IP via DHCP op de NAT adapter + IPv6 basis                      |
| Alle      | OpenSSH Server                     | 22                                 | `vagrant ssh`                                                  |
| Alle      | `WS2-Ping-In` *(eigen regel)*      | ICMPv4 echo request                | Ping om verbinding te testen                                   |
| `server1` | Active Directory Domain Services   | LDAP 389, GC 3268, RPC, SMB 445, … | Domein: joinen, aanmelden, SYSVOL/GPO's ophalen                 |
| `server1` | Active Directory Web Services      | 9389                               | AD PowerShell + RSAT op de client                              |
| `server1` | Kerberos Key Distribution Center   | 88                                 | Authenticatie in het domein                                    |
| `server1` | DNS Service                        | 53 + RPC                           | Primaire DNS, zone transfer naar server2 + DNS Manager          |
| `server1` | World Wide Web Services (HTTP)     | 80                                 | Intranet site                                                  |
| `server2` | DNS Service                        | 53 + RPC                           | Secundaire DNS, notify van server1 + DNS Manager                |
| `server3` | DHCP Server                        | 67/68                              | Leases uitdelen aan de client                                  |
| `server3` | DHCP Server Management             | RPC                                | DHCP console op de client                                      |
| `server3` | Certification Authority            | DCOM/RPC                           | Certificaten aanvragen + CA console                            |
| `server3` | World Wide Web Services (HTTP)     | 80                                 | Web Enrollment (`/CertSrv`)                                    |

*Uitzondering*: De groepen `Certification Authority` en `DHCP Server` openen ook SMB (445), de consoles werken ook zonder -> deze regels blijven uit via `DisabledRules`.

### DHCP
Scope `192.168.26.100 - .200` op `server3` met exclusion `192.168.26.151 - .200` *(client krijgt dus een IP tussen `.100` en `.150`)*. Lease duur is 8 dagen *(standaard van Windows)*.

*Opties*

| Optie                  | Waarde                           | Waarom                                                                         |
| ---------------------- | -------------------------------- | ------------------------------------------------------------------------------ |
| `006` DNS Servers      | `192.168.26.10`, `192.168.26.20` | Primaire + secundaire DNS, de client moet het domein vinden om te kunnen joinen |
| `015` DNS Domain Name  | `WS26-JDV.hogent`                | Korte namen *(bv. `intranet`)* worden aangevuld tot het domein                  |
| `003` Router           | *bewust weggelaten*              | Host-only netwerk heeft geen uplink, internet gaat via de NAT adapter          |

DHCP registreert ook zelf geen DNS-records voor de client (`DynamicUpdates Never`), samen met de instelling op de client zelf.

## Status project
---
*Af*
- Uitrol via [deploy](scripts/deploy.ps1) *(volledige test van nul: `TODO`)*: AD, primaire + secundaire DNS, OUs + gebruikers, IIS, CA + Web Enrollment, DHCP, RSAT tools, client in domein
- CA vertrouwd door alle toestellen via de GPO `Trust WS26-JDV Root CA`
- Firewall op server1, server2 en server3

*Niet af*
- HTTPS voor de intranet site (deel 2): [06-iis-https](scripts/server1/06-iis-https.ps1) is geschreven, maar nog niet getest/ingeschakeld

### Problemen tegengekomen

#### 1. Reboots vagrant, promotie en reboots
**De verbinding valt weg bij DC-promotie** ->
- Probleem: `Install-ADDSForest` herstart de server en maakt van lokale accounts domein accounts. WinRM valt weg en daardoor stop vagrant met de rest van de provisioning.
- Oplossing: We gebruiken `vagrant up` niet langer, het kan niet werken via WinRM en starten een skelet van [deploy](scripts/deploy.ps1) op.

**Shared folder verdwijnt**
- Probleem: Omdat de verbinding met WinRM wegvalt bestaat er geen shared folder meer. 
- Oplossing: de scripts eerst kopiëren naar C:\ws2, zonder .vagrant.

**Volgorde servers initialisatie**
- Probleem: De VMs hangen van elkaar af: server2/3 joinen het domein van server1, de client heeft DHCP van server3 nodig en de CA GPO heeft de CA op server3 nodig. Met één `vagrant up` loopt dit fout.
- Oplossing: [deploy](scripts/deploy.ps1) legt de volgorde vast. In de [Vagrantfile](scripts/Vagrantfile) hebben de provisioners een naam (en soms `run: "never"`), zodat elke stap ook los uitgevoerd kan worden *(bv. `vagrant provision server1 --provision-with dns`)*.

**`vagrant winrm` blijft hangen tijdens promotie**
- Probleem: Om te weten of de promotie klaar is moet je de server iets vragen, maar tijdens de herstart blijft `vagrant winrm` gewoon hangen.
- Oplossing: Elke 30 seconden in een aparte job `(Get-Service NTDS).Status` opvragen, met een timeout van 45 seconden. Draait NTDS? Dan gaat deploy verder.

**Timeout bij client**
- Probleem: De Windows 11 client start trager op dan de servers, vagrant geeft dan een timeout.
- Oplossing: `config.vm.boot_timeout = 1800` in de [Vagrantfile](scripts/Vagrantfile).

#### 2. Scheduled tasks blijven op "Queued"
- Probleem: VirtualBox VMs denken dat ze op batterij draaien, Windows start de task dan niet.
- Oplossing: `-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries` meegeven bij de task *(zie [01-adds](scripts/server1/01-adds.ps1) en [as-domain-admin](scripts/common/as-domain-admin.ps1))*.

#### 3. Promotie faalt met "Prerequisite Failures"
- Probleem: De lokale Administrator van de box heeft geen wachtwoord, dat mag niet bij een nieuwe forest.
- Oplossing: Wachtwoord instellen met `Set-LocalUser` + `net user Administrator /passwordreq:yes` vóór de promotie.

#### 4. Netwerkadapters
**Welke adapter is welke?**
- Probleem: De namen van de adapters zijn niet betrouwbaar.
- Oplossing: De NAT adapter is die met een `10.0.2.x` adres, de andere is host-only. Daarna werken we met `ifIndex` i.p.v. de naam *(werkt enkel met precies twee adapters)*.

**Internet en DNS via de verkeerde adapter**
- Probleem: Een default route op de host-only adapter zorgt ervoor dat internet niet meer via NAT gaat. DNS vragen gingen dan weer via NAT naar de DNS van VirtualBox.
- Oplossing: Default route op host-only verwijderen en de metric aanpassen: host-only `10`, NAT `50`.

#### 5. NAT IP's in DNS
- Probleem: Na de promotie registreert de DC ook zijn NAT IP, in de zone zelf én in `_msdcs` *(bv. `gc._msdcs`)*.
- Oplossing: Drie dingen nodig in [base](scripts/common/base.ps1) en [02-dns](scripts/server1/02-dns.ps1):
	- `RegisterThisConnectionsAddress $false` op de NAT adapter
	- DNS server enkel laten luisteren op het host-only IP, anders registreert hij het NAT IP opnieuw
	- Records die al bestaan met een NAT IP verwijderen in beide zones

#### 6. Diensten die nog niet klaar zijn
Na een reboot of herstart van een service is die nog niet direct bruikbaar, dus overal een wachtlus:
- **DNS fout 9607** *(zone locked)*: AD zone laadt nog na de promotie/herstart DNS -> `Wait-DnsZone` + 30 seconden wachten.
- **WIN32 21** *(ERROR_NOT_READY)* op server2: DNS service reageert nog niet na `Restart-Service DNS` -> retry tot 60 seconden.
- **AD Web Services** nog niet beschikbaar: AD cmdlets falen direct na de reboot -> `Test-AdReady` tot 5 minuten wachten.
- **Domein join te vroeg**: wachten tot het SRV record `_ldap._tcp.dc._msdcs` antwoordt, maximum 5 minuten.

#### 7. Rechten: vagrant is een lokale gebruiker
- Probleem: Vagrant voert alles uit als de lokale `vagrant` gebruiker, die heeft geen rechten in AD.
- Oplossing:
	- Cmdlets mét `-Credential` *(bv. `Add-Computer`, `Install-AdcsCertificationAuthority`)* -> domain admin meegeven via `Get-DomainAdminCredential`.
	- Cmdlets zónder `-Credential` *(bv. `New-GPO`)* -> `Invoke-Command` naar de machine zelf botst op het **double hop** probleem. [as-domain-admin](scripts/common/as-domain-admin.ps1) maakt daarom een tijdelijke scheduled task als domain admin, die krijgt een volledige login. Output en exit code komen via een log terug in vagrant.
	- DHCP autoriseren in AD -> `Invoke-Command` rechtstreeks naar de DC *(variabelen via `$using:`)*. De DhcpServer module staat niet op de DC, dus eerst `RSAT-DHCP` installeren.

#### 8. DHCP
- Probleem: Server Manager blijft melden dat de configuratie na installatie niet af is + de DHCPServer service bestaat pas na de rol.
- Oplossing: Eerst de rol installeren, dan `netsh dhcp add securitygroups` en de registerwaarde `ConfigurationState = 2` zetten.

#### 9. CA en GPO
**CertSrv**
- Probleem: `/CertSrv` werkte niet over HTTP.
- Oplossing: `sslFlags` op `None` zetten via `Set-WebConfigurationProperty`.

**Certificaat in GPO**
- Probleem: Een GPO verwacht het certificaat als `Blob` in Windows' eigen formaat.
- Eerste poging: certificaat lokaal importeren en de Blob uit het register kopiëren. Dat faalde zodra het certificaat al in de *Enterprise* root store stond (een Enterprise CA publiceert zich in AD, sommige toestellen halen hem zo al binnen): Windows schrijft dan niets weg en de Blob bestaat niet. Daardoor vertrouwde server2 de CA niet.
- Oplossing: de Blob is een *serialized certificate*, die .NET rechtstreeks maakt met `$cert.Export('SerializedCert')`, zonder import of register.

**GPO komt pas na ±90 minuten aan**
- Probleem: server2 en server3 zitten al in het domein voordat de GPO bestaat, en vernieuwen hun computer policy maar om de ~90 minuten. Direct na de uitrol vertrouwden ze de CA dus nog niet.
- Oplossing: stap 7b in [deploy](scripts/deploy.ps1) doet `gpupdate /target:computer /force` op beide servers. De client joint pas daarna en krijgt de GPO bij zijn herstart.

#### 10. Firewall
- Probleem: Zodra de firewall aangaat moet WinRM open blijven, anders verliest vagrant de verbinding. Sommige regelgroepen bestaan ook pas na hun rol.
- Oplossing: Firewall is de laatste stap per server, eerst worden de toegelaten groepen aangezet en pas daarna al de rest uit *(ook extra regels van de box zoals WinRM-Packer, RDP, File Sharing)*. De groepen van CA en DHCP openen ook SMB (445), die worden via `DisabledRules` in [config](scripts/config.psd1) terug uitgezet.

#### 11. RSAT duurt lang
- Probleem: RSAT komt binnen via Windows Update en duurt ±40 minuten.
- Oplossing: RSAT heeft het domein niet nodig, dus dit is de eerste stap van de client en draait in de achtergrond terwijl de servers bezig zijn.

#### 12. Kleinere PowerShell problemen
- `param()` moet het eerste statement zijn, dus `$ErrorActionPreference` komt erna.
- `Get-DnsServerZone` gooit een terminerende fout, ook met `-ErrorAction SilentlyContinue` -> try/catch.
- Een `.psd1` kan geen TimeSpan bevatten -> `LeaseDuration` casten naar `[TimeSpan]`.


## Conclusie
---
**Wat heb je geleerd uit dit deel van het project?**
- Een omgeving volledig automatiseren is iets helemaal anders dan ze manueel opzetten: elke reboot, elke service die nog aan het opstarten is en elk rechtenprobleem moet je in het script zelf opvangen.
- Scripts idempotent schrijven *(eerst kijken of iets al bestaat)*, zodat je een stap opnieuw kan draaien zonder van nul te beginnen.
- Hoe AD, DNS, DHCP en een CA van elkaar afhangen, en waarom de volgorde van uitrollen zo belangrijk is.
- Werken met PowerShell remoting en de beperkingen ervan *(double hop, lokale vs. domein gebruiker)*.

**Wat zou je in de toekomst anders doen?**
- Vroeger beginnen met de volledige uitrol van nul testen, niet enkel losse stappen.
- Van in het begin met snapshots werken (`vagrant snapshot save/restore`) zodat een fout niet telkens een volledige nieuwe uitrol kost.
- De firewall van in het begin mee opbouwen i.p.v. als laatste stap.

**Aan welke zaken heb je (te) veel tijd verloren?**
- De DC promotie: WinRM die wegvalt en vagrant dat niet meer terug verbindt *(-> scheduled task + [deploy](scripts/deploy.ps1))*.
- Timing problemen: diensten die na een reboot nog niet klaar zijn, met telkens een andere foutcode.
- Wachten: RSAT alleen duurt ±40 minuten, een volledige uitrol ±`TODO` minuten.