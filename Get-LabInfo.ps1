param
(

  [Parameter(Mandatory=$true, HelpMessage="Name of lab to query")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to query")]
  [string] $ResourceGroupName
)

# HACK: Get-AzureRmResource gives me a wrong error I can't get rid off. You try ...
$ErrorActionPreference = "SilentlyContinue"

# Get all VMs in lab expanding properties to get to compute VM
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

$runString = $runningVms -join " "
Write-Host "$DevTestLabName : $runningVms"
