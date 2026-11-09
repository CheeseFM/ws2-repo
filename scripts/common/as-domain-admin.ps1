# Hulpfuncties voor stappen die domein administrator rechten nodig hebben.
$ErrorActionPreference = 'Stop' # Stoppen bij fout

# Credential van de domein administrator (uit config.psd1).
# Voor cmdlets met een -Credential parameter, zoals Add-Computer.
function Get-DomainAdminCredential {
    param([Parameter(Mandatory)] $Config)
    $password = ConvertTo-SecureString $Config.Domain.AdministratorPassword -AsPlainText -Force
    New-Object PSCredential("$($Config.Domain.NetBiosName)\Administrator", $password)
}

# Script als domein administrator uitvoeren via een loopback sessie.
# -EnableNetworkAccess geeft de sessie een interactief token, zodat ze verder mag naar de DC
# (geen double hop probleem, dus geen CredSSP nodig).
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/invoke-command
function Invoke-AsDomainAdmin {
    param(
        [Parameter(Mandatory)] $Config,
        [Parameter(Mandatory)] [scriptblock]$ScriptBlock
    )
    Invoke-Command -ComputerName localhost -EnableNetworkAccess `
        -Credential (Get-DomainAdminCredential -Config $Config) -ScriptBlock $ScriptBlock
}
