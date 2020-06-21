param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigFile = "config.csv",
    
    [Parameter(Mandatory=$false, HelpMessage="How many seconds to wait before starting the next parallel lab creation")]
    [int] $SecondsBetweenLoop =  10,

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
    
    # Create any/all the resource groups
    # The SilentlyContinue bit is to suppress the error that otherwise this generates.
    $existingRg = Get-AzResourceGroup -Name $_.ResourceGroupName -Location $_.LabRegion -ErrorAction SilentlyContinue

    if(-not $existingRg) {
      Write-Host "Creating Resource Group '$($_.ResourceGroupName)' ..." -ForegroundColor Green
      New-AzResourceGroup -Name $_.ResourceGroupName -Location $_.LabRegion | Out-Null
    }
}
$configCount = ($config | Measure-Object).Count

# Use new DTL Library here to create new labs
Write-Host "---------------------------------" -ForegroundColor Green
Write-Host "Creating $configCount labs..." -ForegroundColor Green
$labCreateJobs = $config | ForEach-Object {
                                $_ | New-AzDtlLab -VmCreationSubnetPrefix "10.0.0.0/21" -AsJob
                                Start-Sleep -Seconds $SecondsBetweenLoop
                           }
Wait-JobWithProgress -jobs $labCreateJobs -secTimeout 1200

$configBastion = [Array] ($config | Where-Object { $_.BastionEnabled })
if (($configBastion | Measure-Object).Count -gt 0) {
    # Deploy the Azure Bastion hosts to the labs
    Write-Host "---------------------------------" -ForegroundColor Green
    Write-Host "Deploying $($configBastion.Count) Bastion hosts to the labs..." -ForegroundColor Green
    # Currently use Leave strategy for existing Bastions
    "./Deploy-Bastion.ps1" | Invoke-RSForEachLab -ConfigFile $ConfigFile -SecondsBetweenLoop $SecondsBetweenLoop -SecTimeout (8 * 60 * 60) -CustomRole $null -ModulesToImport $AzDtlModulePath
}

# Update the shutdown policy on the labs
Write-Host "---------------------------------" -ForegroundColor Green
Write-Host "Updating $configCount labs with correct shutdown policy..." -ForegroundColor Green
Wait-JobWithProgress -jobs ($config | Set-AzDtlLabShutdown -AsJob) -secTimeout 300

# Update the IP Policy on the labs
Write-Host "---------------------------------" -ForegroundColor Green
Write-Host "Updating $configCount labs with IP Policy ..." -ForegroundColor Green
$config | ForEach-Object {
    Set-AzDtlLabIpPolicy -Lab $_ -IpConfig $_.IpConfig
}

# Add appropriate owner/user permissions for the labs
Write-Host "---------------------------------" -ForegroundColor Green
Write-Host "Adding owners & users for $configCount labs..." -ForegroundColor Green
$config | ForEach-Object {
    Set-LabAccessControl $_.DevTestLabName $_.ResourceGroupName $CustomRole $_.LabOwners $_.LabUsers
}

Write-Host "Completed creating labs!" -ForegroundColor Green

Remove-AzDtlModule                                       # Remove the DTL Library
