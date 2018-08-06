param
(
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group")]
    [string] $ResourceGroupName
)

function SaveProfile {
  $profilePath = Join-Path $PSScriptRoot "profile.json"

  Save-AzureRmContext -Path $profilePath
}

function GetProfilePath {
  $scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
  Join-Path $scriptFolder "profile.json"
}

# Clear the errors up front-  helps when running the script multiple times
$error.Clear()

$ErrorActionPreference = 'Continue'

$VMDescriptors = Import-Clixml -Path .\foo.xml

if(-not ($VMDescriptors.count -gt 0)) {
  Write-Error "VMDescriptors can't be null or empty"
}

$lab = Get-AzureRmResource -Name $DevTestLabName -ResourceGroupName $ResourceGroupName

if ($lab -eq $null) {
    Write-Error "'$DevTestLabName' Lab doesn't exist, can't create VMs in it"
}

$scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
$makeVmScriptLocation = Join-Path $scriptFolder "MakeVM.ps1"

$templatePath = Join-Path $scriptFolder "NewVM.json"

$jobs = @()

SaveProfile
$profilePath = GetProfilePath

# Needed for full image id creation
$SubscriptionID = (Get-AzureRmContext).Subscription.Id

foreach($descr in $VMDescriptors) {

  # Needs fully qualified image id, perhaps this could be done in the json file?
  # Also making it unique the same way as the custom image to avoid disk clash
  $baseImageName = $DevTestLabName + $descr.imageName
  $imageName = "/subscriptions/$SubscriptionID/ResourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$DevTestLabName/customImages/$baseImageName"

  $vmName = $baseImageName
  Write-Output "Starting job to create a VM named $vmName"
  $jobs += Start-Job -Name $file.Name -FilePath $makeVmScriptLocation -ArgumentList $profilePath, $templatePath, $DevTestLabName, $vmName, $descr.size, $descr.storageType, $imageName, $descr.description
}

$jobCount = $jobs.Count
Write-Output "Waiting for $jobCount VM creation jobs to complete"
foreach ($job in $jobs){
    $jobOutput = Receive-Job $job -Wait
    Write-Output $jobOutput
}
Remove-Job -Job $jobs
