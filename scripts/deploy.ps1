# Volledige omgeving uitrollen in de juiste volgorde. Uitvoeren op de HOST in de scripts map:
#   .\deploy.ps1
#
# Waarom niet gewoon vagrant up?
#   - Na de DC promotie antwoordt server1 niet tot hij herstart is (zie server1\01-adds.ps1),
#     dus dit script wacht tot AD draait en gaat dan verder met server1.
#   - De VMs hangen van elkaar af: server2/3 joinen het domein van server1,
#     de client heeft DHCP van server3 nodig en de CA GPO heeft de CA op server3 nodig.
#   - RSAT op de client (Windows Update, lang) heeft geen domein nodig,
#     dus dat draait in de achtergrond terwijl de servers bezig zijn.
#
# Opnieuw uitvoeren mag: elk script past enkel aan wat nog niet juist is.

$ErrorActionPreference = 'Stop' # Stoppen bij fout
Set-Location $PSScriptRoot
$start  = Get-Date
$rsatLog = "$PSScriptRoot\.vagrant\client-rsat.log"

# Vagrant uitvoeren en stoppen als het mislukt
function Invoke-Vagrant {
    & vagrant @args
    if ($LASTEXITCODE -ne 0) { throw "vagrant $($args -join ' ') mislukt" }
}

# Titel per stap
function Write-Step($text) {
    Write-Host ''
    Write-Host "##### $text ($(Get-Date -Format HH:mm)) #####" -ForegroundColor Cyan
}

# 1. server1: basis + DC promotie inplannen
Write-Step '1. server1: basis + AD DS'
Invoke-Vagrant up server1 --provision

# 2. client: RSAT in de achtergrond (heeft enkel internet nodig)
Write-Step "2. client: RSAT in de achtergrond (log: $rsatLog)"
$rsatJob = Start-Job {
    Set-Location $using:PSScriptRoot
    vagrant up client --provision-with rsat *> $using:rsatLog
    $LASTEXITCODE
}

# 3. Wachten tot server1 domeincontroller is (promotie + herstart)
# Tijdens de promotie kan vagrant winrm blijven hangen -> job met timeout van 45 seconden
Write-Step '3. server1: wachten op DC promotie'
do {
    Start-Sleep -Seconds 30
    $job = Start-Job {
        Set-Location $using:PSScriptRoot
        vagrant winrm server1 -s powershell -c '(Get-Service NTDS).Status' 2>$null
    }
    $status = if (Wait-Job $job -Timeout 45) { "$(Receive-Job $job)".Trim() } else { 'geen antwoord' }
    Remove-Job $job -Force
    Write-Host "  $(Get-Date -Format HH:mm:ss) AD service: $status"
} until ($status -match 'Running')

# 4. server1: rest van de stappen (adds opnieuw ruimt de geplande taak op)
Write-Step '4. server1: DNS, OUs, IIS'
Invoke-Vagrant provision server1 --provision-with 'adds,dns,ous,iis'

# 5. server2 en server3
Write-Step '5. server2: basis, join, secundaire DNS, firewall'
Invoke-Vagrant up server2 --provision

Write-Step '6. server3: basis, join, CA, DHCP, firewall'
Invoke-Vagrant up server3 --provision

# 7. server1: CA GPO (CA bestaat nu) + firewall als laatste
Write-Step '7. server1: CA GPO, firewall'
Invoke-Vagrant provision server1 --provision-with 'ca-gpo,firewall'

# 8. client: wachten op RSAT, dan domein
Write-Step '8. client: wachten op RSAT'
$exitCode = Receive-Job (Wait-Job $rsatJob) | Select-Object -Last 1
Remove-Job $rsatJob
if ($exitCode -ne 0) { throw "RSAT op de client mislukt, zie $rsatLog" }

Write-Step '9. client: basis, join'
Invoke-Vagrant provision client --provision-with 'base,join'

# Klaar
Write-Host ''
Write-Host "[V] Omgeving klaar in $([math]::Round(((Get-Date) - $start).TotalMinutes)) minuten" -ForegroundColor Green
