# Server 1 - Stap 4: IIs
$ErrorActionPreference = 'Stop' # Stoppen bij fout

# LabConfig
. "$PSScriptRoot\..\common\config.ps1"

# Configuratie
$cfg  = Get-LabConfig
$iis  = $cfg.Iis

# To lower voor directory
$fqdn = "$($iis.HostName).$($cfg.Domain.Name)".ToLower()
$root = "C:\inetpub\$($iis.SiteName.ToLower())" # root van IIS

# Start
Write-Host "[X] Configureren webserver:  http://$fqdn"


# Rol installeren indien nodig
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/where-object?view=powershell-7.6
$features = 'Web-Server', 'Web-Scripting-Tools' # Array met features (voor gemak)
$missing  = $features | Where-Object { -not (Get-WindowsFeature $_).Installed } # Filter (wow)
if ($missing) {
    Write-Host "Installing $($missing -join ', ')"
    Install-WindowsFeature $missing | Out-Null
}

# GUI niet mogelijk, module nodig
# https://learn.microsoft.com/en-us/powershell/module/webadministration/?view=windowsserver2025-ps
Import-Module WebAdministration

# Aanmaken HTML
New-Item -ItemType Directory -Force $root | Out-Null
$html = @"
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Intranet $($cfg.Domain.Name)</title></head>
<body>
  <h1>Hello World</h1>
  <p>Intranet van $($cfg.Domain.Name), door $env:COMPUTERNAME.</p>
</body>
</html>
"@
Set-Content -Path "$root\index.html" -Value $html -Encoding UTF8

# Site aanzetten/-maken
if (-not (Get-Website -Name $iis.SiteName)) {
    Write-Host "Creating site $($iis.SiteName) on port $($iis.Port) for $fqdn"
    New-Website -Name $iis.SiteName -PhysicalPath $root -Port $iis.Port -HostHeader $fqdn | Out-Null
}
if ((Get-Website -Name $iis.SiteName).State -ne 'Started') {
    Start-Website -Name $iis.SiteName
}

# Klaar
Write-Host '[V] IIS klaar'