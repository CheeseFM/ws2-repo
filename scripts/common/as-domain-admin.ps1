# Hulpfuncties voor stappen die domein administrator rechten nodig hebben.


# Credential van de domein administrator (uit config.psd1).
# Voor cmdlets met een -Credential parameter, zoals Add-Computer.
function Get-DomainAdminCredential {
    param([Parameter(Mandatory)] $Config)
    $password = ConvertTo-SecureString $Config.Domain.AdministratorPassword -AsPlainText -Force
    New-Object PSCredential("$($Config.Domain.NetBiosName)\Administrator", $password)
}

# Script als domein administrator uitvoeren via CredSSP.
# https://learn.microsoft.com/en-us/powershell/module/microsoft.wsman.management/enable-wsmancredssp?view=powershell-7.6
function Invoke-AsDomainAdmin {
    param(
        [Parameter(Mandatory)] $Config,
        [Parameter(Mandatory)] [scriptblock]$ScriptBlock
    )
    # CredSSP aanzetten: deze machine mag credentials doorgeven aan zichzelf
    Enable-WSManCredSSP -Role Server -Force | Out-Null
    Enable-WSManCredSSP -Role Client -DelegateComputer $env:COMPUTERNAME -Force | Out-Null

    Invoke-Command -ComputerName $env:COMPUTERNAME -Authentication Credssp `
        -Credential (Get-DomainAdminCredential -Config $Config) -ScriptBlock $ScriptBlock
}
