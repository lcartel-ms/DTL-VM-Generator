param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigFile = "configTest.csv"
)

$ErrorActionPreference = "Stop"

# Common setup for scripts
. "./Utils.ps1"                                          # Import all our utilities
Import-AzDtlModule                                       # Import the DTL Library
$labConfig = Import-ConfigFile -ConfigFile $ConfigFile   # Import all the lab settings from the config file
$labConfigCount = ($labConfig | Measure-Object).Count

$bastionLabConfig = [Array] ($labConfig | Where-Object { $_.BastionEnabled })
$bastionLabConfigCount = ($bastionLabConfig | Measure-Object).Count

if ($bastionLabConfigCount -gt 0) {
    Write-Host "---------------------------------" -ForegroundColor Green
    Write-Host "Removing Bastion hosts from the following $bastionLabConfigCount labs..." -ForegroundColor Green
    $labConfig | Select-Object DevTestLabName, ResourceGroupName | Format-Table | Out-String | Write-Host
    
    $bastionRemoveJobs = $bastionLabConfig | Get-AzDtlLab | Remove-AzDtlBastion -AsJob
    Wait-JobWithProgress -jobs $bastionRemoveJobs -secTimeout 1200

    Write-Host "Completed removing Bastion hosts from Labs!" -ForegroundColor Green
}

if ($labConfigCount -gt 0) {
    Write-Host "---------------------------------" -ForegroundColor Green
    Write-Host "Removing the following $labConfigCount labs from Azure..." -ForegroundColor Green
    $labConfig | Select-Object DevTestLabName, ResourceGroupName | Format-Table | Out-String | Write-Host

    $labRemoveJobs = $labConfig | Get-AzDtlLab | Remove-AzDtlLab -AsJob
    Wait-JobWithProgress -jobs $labRemoveJobs -secTimeout 1200

    Write-Host "Completed removing labs!" -ForegroundColor Green
}

Remove-AzDtlModule                                       # Remove the DTL Library
