param
(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group")]
    [string] $ResourceGroupName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the Shared Image Gallery attached to the lab")]
    [string] $SharedImageGalleryName,

    [Parameter(HelpMessage="String containing comma delimitated list of patterns. The script will (re)create just the VMs matching one of the patterns. The empty string (default) recreates all labs as well.")]
    [string] $ImagePattern = "",

    [ValidateSet("Delete","Leave","Error")]
    [Parameter(Mandatory=$true, HelpMessage="What to do if a VM with the same name exist in the lab (Delete, Leave, Error)")]
    [string] $IfExist,

    [Parameter(valueFromRemainingArguments=$true)]
    [String[]]
    $rest = @()
)

$ErrorActionPreference = "Stop"

. "./Utils.ps1"

Write-Host "Start setting VMs in $DevTestLabName ..."

$VmSettings = & "./Import-VmSetting" -SharedImageGalleryName $SharedImageGalleryName
if(-not $vmSettings) {
  throw "VM Settings are null"
}

Write-Host "Settings imported ..."

$selected = Select-VmSettings -sourceImageInfos $VmSettings -ImagePattern $ImagePattern

Write-Host "Settings selected ... $selected"

$toCreate = ManageExistingVM $DevTestLabName $selected $IfExist

if(-not $toCreate) {
  return "No Vms to create for $DevTestLabName with the pattern $ImagePattern and IfExist as $IfExist"
}

Write-Host "Creating ... $toCreate"

& "./Set-Vm.ps1" -VmSettings $toCreate -DevTestLabName $DevTestLabName -ResourceGroupName $ResourceGroupName -SharedImageGalleryName $SharedImageGalleryName -IfExist $IfExist
& "./Set-Network.ps1" -DevTestLabName $DevTestLabName -ResourceGroupName $ResourceGroupName -VmSettings $toCreate

return "Creation seemed to have worked fine for $DevTestLabName"