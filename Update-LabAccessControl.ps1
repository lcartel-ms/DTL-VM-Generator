param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigFile = "config.csv",
    
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$false, HelpMessage="Custom Role to add users to")]
    [string] $CustomRole =  "No VM Creation User"
)

$ErrorActionPreference = "Stop"

# Common setup for scripts
. "./Utils.ps1"                                          # Import all our utilities
Import-AzDtlModule                                       # Import the DTL Library
$config = Import-ConfigFile -ConfigFile $ConfigFile      # Import all the lab settings from the config file
$configCount = ($config | Measure-Object).Count

# Add/Update appropriate owner/user permissions for the labs
Write-Host "---------------------------------" -ForegroundColor Green
Write-Host "Adding owners & users for $configCount labs..." -ForegroundColor Green
$config | ForEach-Object {
    Set-LabAccessControl $_.DevTestLabName $_.ResourceGroupName $CustomRole $_.LabOwners $_.LabUsers
}

Write-Host "Completed updating users & owners for the labs!" -ForegroundColor Green

Remove-AzDtlModule                                       # Remove the DTL Library
