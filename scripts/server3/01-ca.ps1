# Server 3 - Stap 1: CA

$ErrorActionPreference = 'Stop' # Stoppen bij fout
. "$PSScriptRoot\..\common\config.ps1"
. "$PSScriptRoot\..\common\as-domain-admin.ps1"

# Variabelen en configuratie
$cfg  = Get-LabConfig
$ca   = $cfg.Ca
$cred = Get-DomainAdminCredential -Config $cfg

# CertServ variabelen
$filter = 'system.webServer/security/access'
$path   = 'IIS:\Sites\Default Web Site\CertSrv'

Write-Host "[X] CA configureren $($ca.CommonName)"

# Features installeren zoals bij IIS (server1)
$features = 'ADCS-Cert-Authority', 'ADCS-Web-Enrollment'
$missing  = $features | Where-Object { -not (Get-WindowsFeature $_).Installed }
if ($missing) {
    Write-Host "Installing $($missing -join ', ')"
    Install-WindowsFeature $missing -IncludeManagementTools | Out-Null
}

# Certificaat aanmaken
$caConfig = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration' -ErrorAction SilentlyContinue
if (-not $caConfig.Active) {
    Write-Host "Configuratie van $($ca.Type) $($ca.CommonName) ($($ca.ValidityYears) jaar)"
    Install-AdcsCertificationAuthority `
        -CAType $ca.Type `
        -CACommonName $ca.CommonName `
        -KeyLength 2048 `
        -HashAlgorithmName SHA256 `
        -ValidityPeriod Years `
        -ValidityPeriodUnits $ca.ValidityYears `
        -Credential $cred `
        -Force | Out-Null
}
else {
    Write-Host "CA already configured: $($caConfig.Active)"
}

# Configureren CertSrv
# https://www.youtube.com/watch?v=HArtt4IQoUU&vl=en&t=405
# https://learn.microsoft.com/en-us/powershell/module/adcsdeployment/install-adcscertificationauthority?view=windowsserver2025-ps
Import-Module WebAdministration
if (-not (Get-WebApplication -Site 'Default Web Site' -Name 'CertSrv')) { # Indien CertServ niet bestaat maak het aan
    Write-Host 'Web Enrollment configureren (/CertSrv)'
    Install-AdcsWebEnrollment -Force | Out-Null
}

if ((Get-WebConfigurationProperty -PSPath $path -Filter $filter -Name sslFlags) -ne 'None') {
    Write-Host 'HTTP toelaten voor /CertSrv'
    Set-WebConfigurationProperty -PSPath 'IIS:\' -Location 'Default Web Site/CertSrv' -Filter $filter -Name sslFlags -Value 'None'
}

Write-Host '[V] CA Klaar'