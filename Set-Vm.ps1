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
  if ($descr.osState -eq "Generalized") {
    # Retrieve or generate an username
    $username = if ($descr.PSobject.Properties.name -match "username") { $descr.username } else { Get-RandomString 10 }
    $pipelineArgs | Add-Member -MemberType "NoteProperty" -Name "userName" -Value "$username" -Force
    
    # Retrieve or generate a password
    if ($descr.credentialType -eq "Password"){
      $password = if ($descr.PSobject.Properties.name -match "credentialValue") { $descr.credentialValue } else { Get-RandomString 25 }
      $pipelineArgs | Add-Member -MemberType "NoteProperty" -Name "Password" -Value "$password"
      $descr.credentialValue = $password 
    }
    # Using an SSH key
    else{
      $pipelineArgs | Add-Member -MemberType "NoteProperty" -Name "SshKey" -Value "$($descr.credentialValue)"
    }
    # Create or Update the CSV file
    if (Test-Path .\credentials.csv) { 
      (Import-Csv -Path .\credentials.csv) | Where-Object { $_.VMName -ne "$vmName" } | Export-Csv -NoTypeInformation -Path .\credentials.csv
    }
    $item = New-Object PSCustomObject -Property @{"VMName" = $vmName; "Username" = $username; "CredentialValue" = $descr.credentialValue }
    Export-Csv -NoTypeInformation -InputObject $item -Path .\credentials.csv
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
