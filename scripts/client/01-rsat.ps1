# Client - stap 1: RSAT tools
# Enkel de tools uit config.psd1 (Client.RsatTools).
# RSAT is een Windows "capability" die via Windows Update binnenkomt: dit kan lang duren.
# Heeft enkel internet nodig (via NAT), niet het domein: daarom de eerste stap van de client.
# https://learn.microsoft.com/en-us/powershell/module/dism/add-windowscapability

$ErrorActionPreference = 'Stop' # Stoppen bij fout
. "$PSScriptRoot\..\common\config.ps1"

$cfg = Get-LabConfig

Write-Host '[X] RSAT tools installeren'

foreach ($tool in $cfg.Client.RsatTools) {
    # Volledige naam is bv. Rsat.Dns.Tools~~~~0.0.1.0, dus zoeken met *
    $capability = Get-WindowsCapability -Online -Name "$tool*"
    if (-not $capability) { throw "Capability $tool niet gevonden" }

    if ($capability.State -ne 'Installed') {
        Write-Host "Installeren $($capability.Name) ($(Get-Date -Format HH:mm))"
        Add-WindowsCapability -Online -Name $capability.Name | Out-Null
    }
}

# Overzicht (voor de demo)
Get-WindowsCapability -Online -Name 'Rsat.*' | Where-Object State -eq 'Installed' |
    Format-Table Name, State -AutoSize | Out-String | Write-Host

Write-Host '[V] RSAT tools klaar'
