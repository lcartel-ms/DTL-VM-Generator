param
(
  [Parameter(Mandatory=$true, HelpMessage="Name of lab to stop VMs into")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to stop VMs into")]
  [string] $ResourceGroupName
)

# HACK: Get-AzureRmResource gives me a wrong error I can't get rid off. You try ...
$ErrorActionPreference = "SilentlyContinue"

Write-Output "Stopping VMs in $DevTestLabName in RG $ResourceGroupName ..."
Write-Output "This might take a while ..."

# Get all VMs in lab expanding properties to get to compute VM
$vms = Get-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -ResourceGroupName $ResourceGroupName -ExpandProperties -Name "$DevTestLabName/"
$runningVms = @()

foreach ($vm in $vms) {
  $computeGroup = ($vm.Properties.ComputeId -split "/")[4]
  $name = ($vm.Properties.ComputeId -split "/")[8]
  $compVM = Get-AzureRmVM -ResourceGroupName $computeGroup -name $name -Status
  $status = $compVM.Statuses.Code[1]

  $dtlName = $vm.Name

  if($status -eq "PowerState/running") {
    $returnStatus = Invoke-AzureRmResourceAction -ResourceId $vm.ResourceId -Action "stop" -Force

    if ($returnStatus.Status -eq 'Succeeded') {
      Write-Output "Successfully stopped DTL machine: $dtlName"
    }
    else {
      Write-Error "Failed to stop DTL machine: $dtlName"
    }
  }
}
