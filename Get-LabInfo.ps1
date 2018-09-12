param
(
  [Parameter(Mandatory=$true, HelpMessage="The full path of the profile file")]
  [string] $ProfilePath,

  [Parameter(Mandatory=$true, HelpMessage="Name of lab to query")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to query")]
  [string] $ResourceGroupName
)

# HACK: Get-AzureRmResource gives me a wrong error I can't get rid off. You try ...
$ErrorActionPreference = "SilentlyContinue"
Import-AzureRmContext -Path $ProfilePath | Out-Null

# Get all VMs in lab expanding properties to get to compute VM
$vms = Get-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -ResourceGroupName $ResourceGroupName -ExpandProperties -Name "$DevTestLabName/"
$runningVms = @()

foreach ($vm in $vms) {
  $computeGroup = ($vm.Properties.ComputeId -split "/")[4]
  $name = ($vm.Properties.ComputeId -split "/")[8]
  $compVM = Get-AzureRmVM -ResourceGroupName $computeGroup -name $name -Status
  $status = $compVM.Statuses.Code[1]

  if($status -eq "PowerState/running") {
    $runningVms += $vm.Name
  }
}

$runString = $runningVms -join " "
Write-Output "$DevTestLabName : $runningVms"
