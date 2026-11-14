# Server1 - stap 5: GPO zodat alle toestellen de CA vertrouwen
# Root certificaat van de CA (server3) in Trusted Root Certification Authorities
# van alle servers en de client, via een GPO gelinkt aan het domein.
# Pas uitvoeren NA de CA op server3:
#   vagrant provision server1 --provision-with ca-gpo

$ErrorActionPreference = 'Stop' # Stoppen bij fout

# Afhalen nodige functies
. "$PSScriptRoot\..\common\config.ps1"
. "$PSScriptRoot\..\common\as-domain-admin.ps1"

# Variabelen
$cfg = Get-LabConfig
$ca  = $cfg.Ca

Write-Host "[X] GPO voor vertrouwen van $($ca.CommonName)"

# GPO's aanmaken mag enkel een domein admin -> Invoke-AsDomainAdmin
Invoke-AsDomainAdmin -Config $cfg -Parameters @{ GpoName = $ca.GpoName; CaName = $ca.CommonName } -ScriptBlock {
    Import-Module ActiveDirectory, GroupPolicy

    # Root certificaat uit AD halen: een Enterprise CA publiceert zich onder Public Key Services,
    # zo moeten we server3 zelf niet contacteren
    $configNc = (Get-ADRootDSE).configurationNamingContext
    $caObject = Get-ADObject -SearchBase "CN=Certification Authorities,CN=Public Key Services,CN=Services,$configNc" `
        -Filter "Name -eq '$CaName'" -Properties cACertificate
    if (-not $caObject) { throw "CA $CaName niet gevonden in AD: is de CA op server3 al geinstalleerd?" }
    $cert  = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(, [byte[]]$caObject.cACertificate[0])
    $thumb = $cert.Thumbprint
    Write-Output "Root certificaat: $($cert.Subject) ($thumb)"

    # Een GPO bewaart het certificaat als registerwaarde 'Blob' in Windows' eigen formaat
    # (een 'serialized certificate'). .NET kan dat formaat rechtstreeks maken met SerializedCert.
    # (Vroeger: lokaal importeren en de Blob uit het register kopieren -> faalt als het
    #  certificaat al in de Enterprise root store staat, want dan schrijft Windows niets weg.)
    # https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509contenttype
    $blob = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::SerializedCert)

    # GPO aanmaken indien nodig
    if (-not (Get-GPO -Name $GpoName -ErrorAction SilentlyContinue)) {
        Write-Output "Aanmaken GPO '$GpoName'"
        New-GPO -Name $GpoName | Out-Null
    }

    # GPO linken aan het domein (geldt dan voor alle toestellen)
    $domainDn = (Get-ADDomain).DistinguishedName
    if ((Get-GPInheritance -Target $domainDn).GpoLinks.DisplayName -notcontains $GpoName) {
        Write-Output "GPO linken aan $domainDn"
        New-GPLink -Name $GpoName -Target $domainDn | Out-Null
    }

    # Certificaat in de GPO zetten
    # = Computer Configuration > Windows Settings > Security Settings > Public Key Policies > Trusted Root CAs
    $key = "HKLM\SOFTWARE\Policies\Microsoft\SystemCertificates\Root\Certificates\$thumb"
    if (-not (Get-GPRegistryValue -Name $GpoName -Key $key -ValueName Blob -ErrorAction SilentlyContinue)) {
        Write-Output 'Certificaat toevoegen aan GPO'
        Set-GPRegistryValue -Name $GpoName -Key $key -ValueName Blob -Type Binary -Value $blob | Out-Null
    }

    # Controle op server1 zelf
    gpupdate /target:computer /force | Out-Null
    if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\SystemCertificates\Root\Certificates\$thumb")) {
        throw 'Certificaat niet toegepast door de GPO na gpupdate'
    }
    Write-Output "GPO toegepast op $env:COMPUTERNAME"
}

Write-Host '[V] CA GPO klaar'
