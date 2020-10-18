param
(
  [Parameter(Mandatory=$true, HelpMessage="Name of lab to remove")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to remove")]
  [string] $ResourceGroupName,

  [Parameter(HelpMessage="Example: 'ID-*,CSW2-SRV' , a string containing comma delimitated list of patterns. The script will (re)create just the VMs matching one of the patterns. The empty string (default) recreates all labs as well.")]
  [string] $ImagePattern = "",

  [Parameter(valueFromRemainingArguments=$true)]
  [String[]]
  $rest = @()
)

$ErrorActionPreference = "Stop"

. "./Utils.ps1"

$existingLab = Get-AzDtlLab -Name $DevTestLabName -ResourceGroupName $ResourceGroupName

if (-not $existingLab) {
    throw "'$DevTestLabName' Doesn't exist"
}

Write-Host "Removing Vms from lab $DevTestLabName in $ResourceGroupName"
$vms = Get-AzDtlVm -Lab $existingLab

$selectedVms = Select-Vms -vms $vms -ImagePattern $ImagePattern

$jobs = @()
$selectedVms | ForEach-Object {

  $sb = {
    Remove-AzDtlVm -Vm $_
  }
  $jobs += Start-RSJob -ScriptBlock $sb -Name $_.Name -ModulesToImport $AzDtlModulePath

  Start-Sleep -Seconds 2
}

Wait-RSJobWithProgress -secTimeout (2 * 60 * 60) -jobs $jobs
