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

$config | ForEach-Object {
    
    # Confirm all the names are a good length
    if ($_.DevTestLabName.Length -gt 50) {
        throw "'$($_.DevTestLabName)' is too long, must be 50 characters or less"
    }

    # Create any/all the resource groups
    # The SilentlyContinue bit is to suppress the error that otherwise this generates.
    $existingRg = Get-AzResourceGroup -Name $_.ResourceGroupName -Location $_.LabRegion -ErrorAction SilentlyContinue

    if(-not $existingRg) {
      Write-Host "Creating Resource Group '$($_.ResourceGroupName)' ..." -ForegroundColor Green
      New-AzResourceGroup -Name $_.ResourceGroupName -Location $_.LabRegion | Out-Null
    }
}

# Use new DTL Library here to create new labs
Write-Host "---------------------------------" -ForegroundColor Green
Write-Host "Creating $($config.Count) labs..." -ForegroundColor Green
Wait-JobWithProgress -jobs ($config | New-AzDtlLab -AsJob) -secTimeout 1200

# Update the shutdown policy on the labs
Write-Host "---------------------------------" -ForegroundColor Green
Write-Host "Updating $($config.Count) labs with correct shutdown policy..." -ForegroundColor Green
Wait-JobWithProgress -jobs ($config | Set-AzDtlLabShutdown -AsJob) -secTimeout 300

# Add appropriate owner/user permissions for the labs
Write-Host "---------------------------------" -ForegroundColor Green
Write-Host "Adding owners & users for $($config.Count) labs..." -ForegroundColor Green
$config | ForEach-Object {
    Set-LabAccessControl $_.DevTestLabName $_.ResourceGroupName $CustomRole $_.LabOwners $_.LabUsers
}

Write-Host "Completed creating labs!" -ForegroundColor Green

Remove-AzDtlModule                                       # Remove the DTL Library
