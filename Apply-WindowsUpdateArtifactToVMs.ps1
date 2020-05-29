param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigFile = "config.csv",

    [Parameter(HelpMessage="String containing comma delimitated list of patterns. The script will apply updates to just the VMs matching one of the patterns.")]
    [string] $ImagePattern = "",

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
    Write-Host "Applying Windows Update to all VMs in DevTestLab: $($_.DevTestLabName) matching pattern: '$($ImagePattern)'" -ForegroundColor Green
    $vms = Get-AzDtlVm -Lab @{Name = $_.DevTestLabName; ResourceGroupName = $_.ResourceGroupName}
    
    # Trim down the list of VMs based on the image pattern passed in...
    if ($ImagePattern) {
        $vms = $vms | Where-Object {
            $name = $_.Name
            $ImagePattern.Split(",").Trim() | ForEach-Object {
                if ($name -like $_) {
                    $true
                }
            }
        }
    }

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