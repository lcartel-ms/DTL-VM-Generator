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
$runningVms = Get-AzDtlVm -Lab $existingLab -Status "Running"

# Scope to a smaller set if needed
if ($VmSettings) {
    $runningVms = $runningVms | Where-Object { $_.Name -in ($VmSettings | Select -ExpandProperty imageName) }
}

if (-not $runningVms) {
  Write-Output "'$DevTestLabName' doesn't contain any running VMs"
  return
}

Write-Output "Stopping VMs in $DevTestLabName in RG $ResourceGroupName ..."
Write-Output "This might take a while ..."

$jobs = @()
$runningVms | ForEach-Object {

  $sb = {
    # Workaround for https://github.com/Azure/azure-powershell/issues/9448
    $Mutex = New-Object -TypeName System.Threading.Mutex -ArgumentList $false, "Global\AzDtlLibrary"
    $Mutex.WaitOne() | Out-Null
    $rg = Get-AzResourceGroup | Out-Null
    $Mutex.ReleaseMutex() | Out-Null

    Stop-AzDtlVm -Vm $Using:_
  }
  $jobs += Start-RSJob -ScriptBlock $sb -Name $_.Name -ModulesToImport $AzDtlModulePath

  Start-Sleep -Seconds 2
}

Wait-RSJobWithProgress -secTimeout (2 * 60 * 60) -jobs $jobs

