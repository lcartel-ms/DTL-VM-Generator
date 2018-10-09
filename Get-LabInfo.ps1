param
(

  [Parameter(Mandatory=$true, HelpMessage="Name of lab to query")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to query")]
  [string] $ResourceGroupName,

  [Parameter(valueFromRemainingArguments=$true)]
  [String[]]
  $rest = @()
)

$ErrorActionPreference = "Stop"

$vms = Get-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -ResourceGroupName $ResourceGroupName -ExpandProperties -Name "$DevTestLabName/"
$runningVms = @()

foreach ($vm in $vms) {
  $computeVm = Get-AzureRmResource -ResourceId $vm.Properties.computeId
  $computeGroup = $computeVm.ResourceGroupName
  $name = $computeVm.Name

  $compVM = Get-AzureRmVM -ResourceGroupName $computeGroup -name $name -Status

  $isRunning = $false
  $compVM.Statuses | ForEach-Object {
            if ($_.Code -eq 'PowerState/running') {
              $isRunning = $true
            }
      }
  if($isRunning) {
    $runningVms += $vm.Name
  }
}
if($runningVms) {
  $runString = $runningVms -join " "
} else {
  $runString = 'None'
}
Write-Host "RUNNING VMS FOR LAB $DevTestLabName : $runString"
