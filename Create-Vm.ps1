param
(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group")]
    [string] $ResourceGroupName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageAccountName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageContainerName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageAccountKey,

    [parameter(Mandatory=$true, HelpMessage="Public=separate IP Address, Shared=load balancers optimizes IP Addresses, Private=No public IP address.")]
    [string] $LabIpConfig,

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

# Workaround for https://github.com/Azure/azure-powershell/issues/9448
$Mutex = New-Object -TypeName System.Threading.Mutex -ArgumentList $false, "Global\AzDtlLibrary"
$Mutex.WaitOne() | Out-Null
$rg = Get-AzResourceGroup | Out-Null
$Mutex.ReleaseMutex() | Out-Null

. "./Utils.ps1"

Write-Host "Start setting VMs in $DevTestLabName ..."

$VmSettings = & "./Import-VmSetting" -StorageAccountName $StorageAccountName -StorageContainerName $StorageContainerName -StorageAccountKey $StorageAccountKey
if(-not $vmSettings) {
  throw "VM Settings are null"
}

Write-Host "Settings imported ..."

$selected = Select-VmSettings -sourceImageInfos $VmSettings -ImagePattern $ImagePattern

Write-Host "Settings selected ... $selected"

$toCreate = ManageExistingVM $ResourceGroupName $DevTestLabName $selected $IfExist

if(-not $toCreate) {
  return "No Vms to create for $DevTestLabName with the pattern $ImagePattern and IfExist as $IfExist"
}

Write-Host "Creating ... $toCreate"

& "./Import-CustomImage.ps1" -VmSettings $toCreate -DevTestLabName $DevTestLabName -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -StorageContainerName $StorageContainerName -StorageAccountKey $StorageAccountKey
& "./Set-Vm.ps1" -VmSettings $toCreate -DevTestLabName $DevTestLabName -ResourceGroupName $ResourceGroupName -LabIpConfig $LabIpConfig -IfExist $IfExist
& "./Remove-SnapshotsForLab.ps1" -DevTestLabName $DevTestLabName -ResourceGroupName $ResourceGroupName
& "./Set-Network.ps1" -DevTestLabName $DevTestLabName -ResourceGroupName $ResourceGroupName -VmSettings $VmSettings -LabIpConfig $LabIpConfig

return "Creation seemed to have worked fine for $DevTestLabName"
