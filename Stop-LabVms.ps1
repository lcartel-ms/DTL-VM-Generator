param
(
  [Parameter(Mandatory=$true, HelpMessage="Name of lab to stop VMs into")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to stop VMs into")]
  [string] $ResourceGroupName
)

$ErrorActionPreference = "Stop"

# Common setup for scripts
. "./Utils.ps1"                                          # Import all our utilities
Import-AzDtlModule                                       # Import the DTL Library

Write-Host "Stopping VMs in $DevTestLabName in RG $ResourceGroupName ..."
Write-Host "This might take a while ..."

# Get only the running VMs
$existingLab = Get-AzDtlLab -Name $DevTestLabName -ResourceGroupName $ResourceGroupName

if (-not $existingLab) {
    throw "'$DevTestLabName' doesn't exist"
}

$runningVms = Get-AzDtlVm -Lab $existingLab -Status "Running"

if (-not $runningVms) {
  Write-Host "'$DevTestLabName' doesn't contain any running VMs"
  return
}

$jobs = @()
$runningVms | ForEach-Object {
  $sb = [scriptblock]::create(
    @"
    Stop-AzDtlVm -Vm $_
"@)

  $jobs += Start-RSJob -ScriptBlock $sb -Name $_.Name -ModulesToImport $AzDtlModulePath

  Start-Sleep -Seconds 2
}

Wait-RSJobWithProgress -secTimeout (2 * 60 * 60) -jobs $jobs

