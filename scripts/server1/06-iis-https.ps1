# Server1 - stap 6: HTTPS voor de intranet site
# Certificaat voor intranet.<domein> aanvragen bij de CA op server3 (template WebServer)
# en een https binding op poort 443 toevoegen. Poort 80 blijft gewoon werken.
# Geen self-signed certificaat: de root van onze CA wordt al vertrouwd via de GPO van stap 5.
# Pas uitvoeren NA de CA op server3 en de CA GPO:
#   vagrant provision server1 --provision-with iis-https

$ErrorActionPreference = 'Stop' # Stoppen bij fout

# Afhalen nodige functies
. "$PSScriptRoot\..\common\config.ps1"
. "$PSScriptRoot\..\common\as-domain-admin.ps1"

# Variabelen
$cfg  = Get-LabConfig
$iis  = $cfg.Iis
$fqdn = "$($iis.HostName).$($cfg.Domain.Name)".ToLower()

Write-Host "[X] HTTPS configureren: https://$fqdn"
Import-Module WebAdministration

# Bestaat er al een certificaat van onze CA voor deze naam?
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/about/about_certificate_provider
function Get-IntranetCert {
    Get-ChildItem Cert:\LocalMachine\My |
        Where-Object { $_.Issuer -like "CN=$($cfg.Ca.CommonName)*" -and $_.DnsNameList.Unicode -contains $fqdn } |
        Select-Object -First 1
}

$cert = Get-IntranetCert
if (-not $cert) {
    # Aanvragen als domein admin: de template aanpassen mag enkel een Enterprise Admin
    Invoke-AsDomainAdmin -Config $cfg -Parameters @{ Fqdn = $fqdn; Template = $iis.CertTemplate; Computer = $env:COMPUTERNAME } -ScriptBlock {
        Import-Module ActiveDirectory

        # De aanvraag gebeurt als het COMPUTER account (store LocalMachine), en de standaard
        # WebServer template laat enkel admins toe -> server1 zelf 'Enroll' rechten geven
        # https://learn.microsoft.com/en-us/windows/win32/adschema/r-certificate-enrollment
        # https://learn.microsoft.com/en-us/dotnet/api/system.directoryservices.activedirectoryaccessrule
        $configNc = (Get-ADRootDSE).configurationNamingContext
        $template = "AD:CN=$Template,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNc"
        $enroll   = [guid]'0e10c968-78fb-11d2-90d4-00c04f79dc55'   # GUID van het recht "Certificate-Enrollment"
        $sid      = (Get-ADComputer $Computer).SID
        $acl      = Get-Acl $template
        $acl.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule($sid, 'ExtendedRight', 'Allow', $enroll)))
        Set-Acl $template $acl
        Write-Output "Enroll recht op template $Template gegeven aan $Computer"

        # Certificaat aanvragen ('ldap:' = de CA opzoeken via AD).
        # De CA ziet het nieuwe recht soms pas na even, dus een paar keer proberen.
        # https://learn.microsoft.com/en-us/powershell/module/pki/get-certificate
        for ($i = 1; $i -le 5; $i++) {
            try {
                $req = Get-Certificate -Template $Template -Url 'ldap:' -SubjectName "CN=$Fqdn" -DnsName $Fqdn `
                    -CertStoreLocation Cert:\LocalMachine\My
                break
            }
            catch {
                if ($i -eq 5) { throw }
                Write-Output "Aanvraag mislukt, opnieuw over 20 seconden ($i/5)"
                Start-Sleep -Seconds 20
            }
        }
        Write-Output "Certificaat uitgegeven: $($req.Certificate.Thumbprint)"
    }
    $cert = Get-IntranetCert
    if (-not $cert) { throw "Geen certificaat voor $fqdn gevonden na de aanvraag" }
}
Write-Host "Certificaat: $($cert.Subject), geldig tot $($cert.NotAfter)"

# https binding toevoegen en het certificaat eraan koppelen
# SslFlags 1 = SNI: certificaat hoort bij hostnaam + poort
# https://learn.microsoft.com/en-us/powershell/module/webadministration/new-webbinding
# https://learn.microsoft.com/en-us/iis/configuration/system.applicationhost/sites/site/bindings/binding
if (-not (Get-WebBinding -Name $iis.SiteName -Protocol https)) {
    Write-Host "https binding toevoegen op poort $($iis.HttpsPort)"
    New-WebBinding -Name $iis.SiteName -Protocol https -Port $iis.HttpsPort -HostHeader $fqdn -SslFlags 1
    (Get-WebBinding -Name $iis.SiteName -Protocol https).AddSslCertificate($cert.Thumbprint, 'My')
}

# Testen: lukt enkel als het certificaat vertrouwd wordt en de naam klopt
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest
$response = Invoke-WebRequest -Uri "https://$fqdn" -UseBasicParsing
if ($response.Content -notmatch 'Hello World') { throw "https://$fqdn geeft de Hello World pagina niet" }
Write-Host "https://$fqdn werkt (HTTP $($response.StatusCode))"

Write-Host '[V] HTTPS klaar'
