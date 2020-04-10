param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigFile = "config.csv",

    [Parameter(Mandatory=$false, HelpMessage="Shutdown the VMs when done?")]
    [ValidateNotNullOrEmpty()]
    [boolean] $shutdownVMs = $false

)

$ErrorActionPreference = "Stop"

. "./Utils.ps1"

Import-AzDtlModule

# Read in the config file
$config = Import-Csv $ConfigFile

# Foreach lab, get all the VMs
$config | ForEach-Object {
    Write-Host "----------------------------------------------------------" -ForegroundColor Green
    Write-Host "Applying Windows Update to all VMs in DevTestLab: $($_.DevTestLabName)" -ForegroundColor Green
    $vms = Get-AzDtlVm -Lab @{Name = $_.DevTestLabName; ResourceGroupName = $_.ResourceGroupName}
    $vms | Select-Object `
        @{label="Name";expression={$_.Name}},
        @{label="ProvisioningState";expression={$_.Properties.provisioningState}},
        @{label="PowerState";expression={$_.Properties.lastKnownPowerState}},
        @{label="ArtifactStatus";expression={$_.Properties.ArtifactDeploymentStatus.deploymentStatus}} `
     | Format-Table

     # we just wait for this without status
     $vms | Start-AzDtlVm -AsJob `
          | Receive-Job -Wait

     # Apply artifacts to all the VMs, wait with status for 20 min
     $jobs = $vms | Set-AzDtlVmArtifact -RepositoryName "Public Repo" -ArtifactName "windows-install-windows-updates" -AsJob
     Wait-JobWithProgress -jobs $jobs -secTimeout 1200

     if ($shutdownVMs) {
         # next we shutdown all the VMs
         $vms | Stop-AzDtlVm -AsJob `
              | Receive-Job -Wait
     }
}