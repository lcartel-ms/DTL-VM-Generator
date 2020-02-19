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
$config = Import-ConfigFile -ConfigFile $ConfigFile      # Import all the lab settings from the config file

Write-Host "---------------------------------" -ForegroundColor Green
Write-Host "Removing the following $($config.Count) labs from Azure..." -ForegroundColor Green

$config | Select-Object DevTestLabName, ResourceGroupName | Format-Table | Out-String | Write-Host

$jobs = $config | Get-AzDtlLab | Remove-AzDtlLab -AsJob

if ($jobs) {
    Wait-JobWithProgress -jobs $jobs -secTimeout 600
}

Write-Host "Completed removing labs!" -ForegroundColor Green

Remove-AzDtlModule                                       # Remove the DTL Library
