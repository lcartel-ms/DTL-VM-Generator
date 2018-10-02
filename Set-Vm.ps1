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
  $jobs += New-AzureRmResourceGroupDeployment -AsJob -Name $deployName -ResourceGroupName $ResourceGroupName -TemplateFile $templatePath -labName $DevTestLabName -newVMName $vmName -size $descr.size -storageType $descr.storageType -customImage $imageName -notes $descr.description

  Start-Sleep -Seconds 60
}

Write-Host "Waiting for results at most 5 hours..."
$jobs | Wait-Job -Timeout (5 * 60 * 60) | ForEach-Object {
  if($_.State -eq 'Failed') {
    Write-Host "$($_.Name) Failed!" -ForegroundColor Red -BackgroundColor Black
    # TODO: need to find a way to get correct stack trace
  } else {
    Write-Host "$($_.Name) Succeded!"
  }
  $_ | Receive-Job -ErrorAction Continue
}
$jobs | Remove-Job

$VmSettings
