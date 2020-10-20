param
(
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group")]
    [string] $ResourceGroupName,

    [parameter(Mandatory=$true, HelpMessage="Public=separate IP Address, Shared=load balancers optimizes IP Addresses, Private=No public IP address.")]
    [string] $LabIpConfig,

    [ValidateSet("Delete","Leave","Error")]
    [Parameter(Mandatory=$true, HelpMessage="What to do if a VM with the same name exist in the lab (Delete, Leave, Error)")]
    [string] $IfExist,

    [Parameter(Mandatory=$false, HelpMessage="The VM Configuration objects (by default it downloads them)")]
    $VmSettings = ""
)

$ErrorActionPreference = 'Stop'

. "./Utils.ps1"

if(-not $VmSettings) {
  $VmSettings = & "./Import-VmSetting" -StorageAccountName $StorageAccountName -StorageContainerName $StorageContainerName -StorageAccountKey $StorageAccountKey
}

if(-not $VmSettings) {
  throw "VmSettings can't be null or empty"
}

$scriptFolder = $PWD

if(-not $scriptFolder) {
  throw "Script folder is null"
}

$lab = Get-AzDtlLab -Name $DevTestLabName -ResourceGroupName $ResourceGroupName

if ($null -eq $lab) {
    throw "'$DevTestLabName' Lab doesn't exist, can't create VMs in it"
}

$jobs = @()

foreach($descr in $VmSettings) {

  $imageName = $DevTestLabName + $descr.imageName
  $vmName = $descr.imageName

  Write-Host "Starting job to create a VM named $vmName"
  $sb = {
    param($lab, $vmName, $size, $storageType, $imageName, $description, $osType, $LabIpConfig)
        New-AzDtlVm -Name $lab.Name `
                    -ResourceGroupName $lab.ResourceGroupName `
                    -VmName $vmName `
                    -Size $size `
                    -StorageType $storageType `
                    -CustomImage $imageName `
                    -Notes $description `
                    -OsType $osType `
                    -IpConfig $LabIpConfig
  }
  $jobs += Start-RSJob -Name $imageName -ScriptBlock $sb -ArgumentList $lab, $vmName, $descr.size, $descr.storageType, $imageName, $descr.description, $descr.osType, $LabIpConfig -ModulesToImport $AzDtlModulePath

  Start-Sleep -Seconds 60

}

Wait-RSJobWithProgress -secTimeout (5*60*60) -jobs $jobs

Write-Output "VMs created succesfully in $DevTestLabName"
