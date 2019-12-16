param
(
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group")]
    [string] $ResourceGroupName,

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

$lab = Get-AzureRmResource -Name $DevTestLabName -ResourceGroupName $ResourceGroupName

if ($lab -eq $null) {
    throw "'$DevTestLabName' Lab doesn't exist, can't create VMs in it"
}

$templatePath = Join-Path $scriptFolder "NewVM.json"

$jobs = @()

# Needed for full image id creation
$SubscriptionID = (Get-AzureRmContext).Subscription.Id

foreach($descr in $VmSettings) {

  # Needs fully qualified image id, perhaps this could be done in the json file?
  # Also making it unique the same way as the custom image to avoid disk clash
  $baseImageName = $DevTestLabName + $descr.imageName
  $imageName = "/subscriptions/$SubscriptionID/ResourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$DevTestLabName/customImages/$baseImageName"
  $vmName = $descr.imageName

  Write-Host "Starting job to create a VM named $vmName"

  $deployName = "Deploy-$DevTestLabName-$vmName"

  $sb = {
    New-AzureRmResourceGroupDeployment -Name $Using:deployName -ResourceGroupName $Using:ResourceGroupName -TemplateFile $Using:templatePath -labName $Using:DevTestLabName -newVMName $Using:vmName -size ($Using:descr).size -storageType ($Using:descr).storageType -customImage $Using:imageName -notes ($Using:descr).description | Out-Null
  }

  $jobs += Start-RSJob -ScriptBlock $sb -Name $deployName
  Start-Sleep -Seconds 60
}

Wait-RSJobWithProgress -secTimeout (5*60*60) -jobs $jobs

Write-Output "VMs created succesfully in $DevTestLabName"
