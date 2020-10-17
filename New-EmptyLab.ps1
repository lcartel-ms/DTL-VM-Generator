param
(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group")]
    [string] $ResourceGroupName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $ShutDownTime,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $TimezoneId,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $LabRegion,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string[]] $LabOwners,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string[]] $LabUsers,

    [parameter(Mandatory=$true, HelpMessage="Public=separate IP Address, Shared=load balancers optimizes IP Addresses, Private=No public IP address.")]
    [string] $LabIpConfig,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [bool] $LabBastionEnabled,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $CustomRole,

    [Parameter(valueFromRemainingArguments=$true)]
    [String[]]
    $rest = @()
)

$ErrorActionPreference = "Stop"

# Common setup for scripts
. "./Utils.ps1"                                          # Import all our utilities
Import-AzDtlModule                                       # Import the DTL Library

Write-Host "Starting to create lab '$DevTestLabName'..." -ForegroundColor Green

# Create any/all the resource groups
# The SilentlyContinue bit is to suppress the error that otherwise this generates.
$existingRg = Get-AzResourceGroup -Name $ResourceGroupName -Location $LabRegion -ErrorAction SilentlyContinue

if(-not $existingRg) {
    Write-Host "Creating Resource Group '$ResourceGroupName' ..."
    New-AzResourceGroup -Name $ResourceGroupName -Location $LabRegion | Out-Null
}

# Use new DTL Library here to create new lab
Write-Host "Creating DevTest Lab '$DevTestLabName' ..."
$lab = New-AzDtlLab -Name $DevTestLabName -ResourceGroupName $ResourceGroupName -VmCreationSubnetPrefix "10.0.0.0/21"

if ($lab) {
    Write-Output "Lab '$DevTestLabName' in Resource Group '$ResourceGroupName' created successfully"
    $lab | Write-Output
}

# Update the IP Policy on the lab
Write-Host "Update the IP Policy on '$DevTestLabName'..."
$policy = Set-AzDtlLabIpPolicy -Lab $lab -IpConfig $LabIpConfig

if ($policy) {
    Write-Output "Succesfully updated IP Policy.."
}

if ($LabBastionEnabled) {
    # Deploy the Azure Bastion hosts to the labs
    Write-Host "Deploying bastion hosts to '$DevTestLabName'..."

    # Currently use Leave strategy for existing Bastions
    & "./Deploy-Bastion.ps1" -DevTestLabName $DevTestLabName -ResourceGroupName $ResourceGroupName -LabIpConfig $LabIpConfig -LabBastionEnabled $true -IfExist Leave
}

# Update the shutdown policy on the labs
Write-Host "Updating '$DevTestLabName' with correct shutdown policy..."
$shutdown = Set-AzDtlLabShutdown -Lab $lab -ShutdownTime $ShutDownTime -TimeZoneId $TimezoneId -ScheduleStatus Enabled

# Add appropriate owner/user permissions for the labs
Write-Host "Adding owners & users to '$DevTestLabName'..."
Set-LabAccessControl $DevTestLabName $ResourceGroupName $CustomRole $LabOwners $LabUsers

Write-Host "Lab '$DevTestLabName' in Resource Group '$ResourceGroupName' created and configured successfully" -ForegroundColor Green
