param
(
  [Parameter(Mandatory=$true, HelpMessage="Name of lab to stop VMs into")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to stop VMs into")]
  [string] $ResourceGroupName
)

# HACK: Get-AzureRmResource gives me a wrong error I can't get rid off. You try ...
$ErrorActionPreference = "SilentlyContinue"

Write-Host "Stopping VMs in $DevTestLabName in RG $ResourceGroupName ..."
Write-Host "This might take a while ..."

# Get all VMs in lab expanding properties to get to compute VM
$vms = Get-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -ResourceGroupName $ResourceGroupName -ExpandProperties -Name "$DevTestLabName/"

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

  $dtlName = $vm.Name

  if($isRunning) {
    $returnStatus = Invoke-AzureRmResourceAction -ResourceId $vm.ResourceId -Action "stop" -Force

    if ($returnStatus.Status -eq 'Succeeded') {
      Write-Output "Successfully stopped DTL machine: $dtlName"
    }
    else {
      throw "Failed to stop DTL machine: $dtlName"
    }
  }
}
