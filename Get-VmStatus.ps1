param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigFile = "config.csv"
)

$ErrorActionPreference = "Stop"

. "./Utils.ps1"

Import-AzDtlModule

# Read in the config file
$config = Import-Csv $ConfigFile

# Foreach lab, get all the VMs
$config | ForEach-Object {
    Write-Host "----------------------------------------------" -ForegroundColor Green
    Write-Host "DevTestLab: $($_.DevTestLabName)" -ForegroundColor Green
    $vms = Get-AzDtlVm -Lab @{Name = $_.DevTestLabName; ResourceGroupName = $_.ResourceGroupName}
    $vms | Select-Object `
        @{label="Name";expression={$_.Name}},
        @{label="ProvisioningState";expression={$_.Properties.provisioningState}},
        @{label="PowerState";expression={$_.Properties.lastKnownPowerState}},
        @{label="ArtifactStatus";expression={$_.Properties.ArtifactDeploymentStatus.deploymentStatus}} `
     | Format-Table
}