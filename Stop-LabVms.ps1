param
(
  [Parameter(Mandatory=$true, HelpMessage="Name of lab to stop VMs into")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to stop VMs into")]
  [string] $ResourceGroupName,

  [Parameter(Mandatory=$false, HelpMessage="The VM Configuration objects to operate on (by default it downloads them)")]
  $VmSettings = ""
)

$ErrorActionPreference = "Stop"

# Common setup for scripts
. "./Utils.ps1"                                          # Import all our utilities
Import-AzDtlModule                                       # Import the DTL Library

$existingLab = Get-AzDtlLab -Name $DevTestLabName -ResourceGroupName $ResourceGroupName

if (-not $existingLab) {
    throw "'$DevTestLabName' doesn't exist"
}

# Get only the running VMs
$vms = Get-AzDtlVm -Lab $existingLab

# Scope to a smaller set if needed
if ($VmSettings) {
    $vms = $vms | Where-Object { $_.Name -in ($VmSettings | Select -ExpandProperty imageName) }
}

if (-not $vms) {
  Write-Output "'$DevTestLabName' doesn't contain any VMs"
  return
}

Write-Output "Stopping VMs in $DevTestLabName in RG $ResourceGroupName ..."
Write-Output "This might take a while ..."

$jobs = @()
$vms | ForEach-Object {

  $sb = {
    Stop-AzDtlVm -Vm $_
  }
  $jobs += Start-RSJob -ScriptBlock $sb -Name $_.Name -ModulesToImport $AzDtlModulePath
}

Wait-RSJobWithProgress -secTimeout (2 * 60 * 60) -jobs $jobs

