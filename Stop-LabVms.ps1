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

Write-Host "Stopping VMs in $DevTestLabName in RG $ResourceGroupName ..."
Write-Host "This might take a while ..."

$existingLab = Get-AzDtlLab -Name $DevTestLabName -ResourceGroupName $ResourceGroupName

if (-not $existingLab) {
    throw "'$DevTestLabName' doesn't exist"
}

# Get only the running VMs
$runningVms = Get-AzDtlVm -Lab $existingLab -Status "Running"

# Scope to a smaller set if needed
if ($VmSettings) {
    $runningVms = $runningVms | Where-Object { $_.Name -in ($VmSettings | Select -ExpandProperty imageName) }
}

if (-not $runningVms) {
  Write-Host "'$DevTestLabName' doesn't contain any running VMs"
  return
}

Write-Output "Stopping VMs in $DevTestLabName in RG $ResourceGroupName ..."
Write-Output "This might take a while ..."

$jobs = @()
$runningVms | ForEach-Object {
  $sb = {
    Stop-AzDtlVm -Vm $Using:_
  }
  $jobs += Start-RSJob -ScriptBlock $sb -Name $_.Name -ModulesToImport $AzDtlModulePath

  Start-Sleep -Seconds 2
}

# Putting a 4 hour timeout for stopping VMs.  I think we get delays if the VM isn't ready (waiting for vm agent status) which seems to cause timeouts
Wait-RSJobWithProgress -secTimeout (4 * 60 * 60) -jobs $jobs

