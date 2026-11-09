# Haalt configuratiebestand af via functie die oproepbaar is vanuit elk script
function Get-LabConfig {
    Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot '..\config.psd1')
}