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

  $pipelineArgs = $lab.PsObject.Copy()
  # Check if it's a generalized VM
  if ($descr.PSobject.Properties.name -match "OsState" -and  $descr.osState -eq "Generalized") {
    # Retrieve or generate an username
    $username = if ($descr.PSobject.Properties.name -match "username") { $descr.username } else { Get-RandomString 10 }
    $pipelineArgs | Add-Member -MemberType "NoteProperty" -Name "userName" -Value "$username" -Force

    # Retrieve or generate a password
    $passOrKey = if ($descr.PSobject.Properties.name -match "passwordOrKey") { $descr.passwordOrKey } else { Get-RandomString 25 }
    # If the VM is linux-based, check if the password is a public key
    # Note : Get-RandomString can't generate '-' nor ' ', generated passwords won't cause weird error cases
    if ($descr.osType -eq "Linux" -and $passOrKey.startsWith("ssh-rsa ") ) {
      $pipelineArgs | Add-Member -MemberType "NoteProperty" -Name "SshKey" -Value "$passOrKey"
      Write-Host "$vmName username is $username and is using an SSH key"
    }
    # For any other case : Windows or a Linux VM using a password, set the password. 
    else{
      $pipelineArgs | Add-Member -MemberType "NoteProperty" -Name "Password" -Value "$passOrKey"
      Write-Host "$vmName username and password are $username and $passOrKey"
    }

  }


  $jobs += $pipelineArgs | New-AzDtlVm -VmName $vmName `
                              -Size $descr.size `
                              -StorageType $descr.storageType `
                              -SharedImageGalleryImage "$SharedImageGalleryName/$($descr.imageName)" `
                              -Notes $descr.description `
                              -OsType $descr.osType `
                              -IpConfig $LabIpConfig `
                              -AsJob

  Start-Sleep -Seconds 60
}

Wait-JobWithProgress -secTimeout (5*60*60) -jobs $jobs

Write-Output "VMs created succesfully in $DevTestLabName"
