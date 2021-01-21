param
(
  [Parameter(Mandatory=$true, HelpMessage="Name of lab to remove role assignments for")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to stop VMs into")]
  [string] $ResourceGroupName,

  [Parameter(Mandatory=$true, HelpMessage="The VM Configuration objects to operate on")]
  $VmSettings
)

$ErrorActionPreference = "Stop"

# Common setup for scripts
. "./Utils.ps1"                                          # Import all our utilities
Import-AzDtlModule                                       # Import the DTL Library

Write-Host "Removing extra role assignments in $DevTestLabName in RG $ResourceGroupName ..."

$existingLab = Get-AzDtlLab -Name $DevTestLabName -ResourceGroupName $ResourceGroupName

if (-not $existingLab) {
    throw "'$DevTestLabName' doesn't exist"
}

$VmSettings | ForEach-Object {
    # Get the DTL VM
    $vm = Get-AzDtlVm -Lab $existingLab -Name $_.imageName
    Remove-AzRoleAssignment -Scope $vm.Id -ObjectId $vm.Properties.ownerObjectId -RoleDefinitionName "Owner"
}

Write-Host "Removed $(($VmSettings | Measure-Object).Count) role assignments for $DevTestLabName in RG $ResourceGroupName"
