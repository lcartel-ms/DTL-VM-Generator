param
(
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group")]
    [string] $ResourceGroupName,

    [parameter(Mandatory=$true, HelpMessage="Public=separate IP Address, Shared=load balancers optimizes IP Addresses, Private=No public IP address.")]
    [string] $LabIpConfig,
    
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the Shared Image Gallery attached to the lab")]
    [string] $SharedImageGalleryName,

    [ValidateSet("Delete","Leave","Error")]
    [Parameter(Mandatory=$true, HelpMessage="What to do if a VM with the same name exist in the lab (Delete, Leave, Error)")]
    [string] $IfExist,

    [Parameter(Mandatory=$false, HelpMessage="The VM Configuration objects (by default it downloads them)")]
    $VmSettings = ""
)

$ErrorActionPreference = 'Stop'

. "./Utils.ps1"

if(-not $VmSettings) {
    $VmSettings = & "./Import-VmSetting" -SharedImageGalleryName $SharedImageGalleryName
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

  $vmName = $descr.imageName

  Write-Host "Starting job to create a VM named $vmName"

  if ($descr.PSObject.Properties -match "SSHKey") {
      # If we have a SSHKey, we know it's Linux and Generalized
      $jobs += $lab | New-AzDtlVm -VmName $vmName `
                                  -Size $descr.size `
                                  -StorageType $descr.storageType `
                                  -SharedImageGalleryImage "$SharedImageGalleryName/$($descr.imageName)" `
                                  -Notes $descr.description `
                                  -OsType $descr.osType `
                                  -IpConfig $LabIpConfig `
                                  -UserName $descr.Username `
                                  -SshKey $descr.SSHKey `
                                  -AsJob

  }
  elseif ($descr.PSObject.Properties -match "Password") {
      # If we have a password, we know it's windows or linux and generalized
      $jobs += $lab | New-AzDtlVm -VmName $vmName `
                                  -Size $descr.size `
                                  -StorageType $descr.storageType `
                                  -SharedImageGalleryImage "$SharedImageGalleryName/$($descr.imageName)" `
                                  -Notes $descr.description `
                                  -OsType $descr.osType `
                                  -IpConfig $LabIpConfig `
                                  -UserName $descr.Username `
                                  -Password $descr.Password `
                                  -AsJob
  }
  else {
      # Must be specialized custom image
      $jobs += $lab | New-AzDtlVm -VmName $vmName `
                                  -Size $descr.size `
                                  -StorageType $descr.storageType `
                                  -SharedImageGalleryImage "$SharedImageGalleryName/$($descr.imageName)" `
                                  -Notes $descr.description `
                                  -OsType $descr.osType `
                                  -IpConfig $LabIpConfig `
                                  -AsJob
  }

  Start-Sleep -Seconds 60
}

Wait-JobWithProgress -secTimeout (5*60*60) -jobs $jobs

Write-Output "VMs created succesfully in $DevTestLabName"
