param
(
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $ResourceGroupName,

    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageAccountName,

    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageContainerName,

    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageAccountKey,

    [Parameter(Mandatory=$false, HelpMessage="Unique string representing the date")]
    [string] $DateString = (get-date -f "-yyyy_MM_dd-HH_mm_ss"),

    [Parameter(HelpMessage="String containing comma delimitated list of patterns. The script will (re)create just the VMs matching one of the patterns. The empty string (default) recreates all labs as well.")]
    [string] $ImagePattern = ""
)

$ErrorActionPreference = 'Continue'


$lab = Get-AzureRmResource -Name $DevTestLabName -ResourceGroupName $ResourceGroupName

if ($lab -eq $null) {
    Write-Error "'$DevTestLabName' Lab doesn't exist, can't copy images to it"
    exit
}

$scriptFolder = $PSScriptRoot

if(-not $scriptFolder) {
  Write-Error "CopyImages: Script folder is null"
  exit
}

# Check we're in the right directory
if (-not (Test-Path (Join-Path $scriptFolder "CreateImageFromVHD.json"))) {
  Write-Error "Unable to find the CreateImageFromVHD.json template...  unable to proceed."
  return
}

# ------------------------------------------------------------------
# Get the storage account for the lab (temp holding spot for VHDs)
# ------------------------------------------------------------------
$labRgName= $ResourceGroupName
$sourceLab = Get-AzureRmResource -ResourceName $lab.Name -ResourceGroupName $labRgName -ResourceType 'Microsoft.DevTestLab/labs'
$DestStorageAccountResourceId = $sourceLab.Properties.artifactsStorageAccount
$DestStorageAcctName = $DestStorageAccountResourceId.Substring($DestStorageAccountResourceId.LastIndexOf('/') + 1)
$storageAcct = (Get-AzureRMStorageAccountKey  -StorageAccountName $DestStorageAcctName -ResourceGroupName $labRgName)

# Azure Powershell version 1.3.2 or below - https://msdn.microsoft.com/en-us/library/mt607145.aspx
$DestStorageAcctKey = $storageAcct.Key1
if ($DestStorageAcctKey -eq $null) {
    # Azure Powershell version 1.4 or greater:
    $DestStorageAcctKey = $storageAcct.Value[0]
}

$DestStorageContext = New-AzureStorageContext -StorageAccountName $DestStorageAcctName -StorageAccountKey $DestStorageAcctKey

# ------------------------------------------------------------------
# Enumerate the JSON files for the images to figure out what to copy
# ------------------------------------------------------------------
$SourceStorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
$jsonBlobs = Get-AzureStorageBlob -Context $SourceStorageContext -Container $StorageContainerName -Blob '*json'
Write-Host "Downloading $($jsonBlobs.Count) json files from storage account"

$downloadFolder = Join-Path $env:TEMP 'CustomImageDownloads'
if(Test-Path -Path $downloadFolder)
{
    Remove-Item $downloadFolder -Recurse | Out-Null
}
New-Item -Path $downloadFolder -ItemType Directory | Out-Null

$sourceImageInfos = @()

$jsonBlobs | Get-AzureStorageBlobContent -Destination $downloadFolder | Out-Null
$downloadedFileNames = Get-ChildItem -Path $downloadFolder
foreach($file in $downloadedFileNames)
{
    $imageObj = (gc $file.FullName -Raw) | ConvertFrom-Json
    $imageObj.timestamp = [DateTime]::Parse($imageObj.timestamp)
    $sourceImageInfos += $imageObj
}

# ------------------------------------------------------------------
# Then we filter the infos according to the vm name patterns
# ------------------------------------------------------------------

# Just filter if there is an image pattern
if($ImagePattern) {
  $imgAr = $ImagePattern.Split(",").Trim()

  # Severely in need of a linq query to do this ...
  $newSources = @()
  foreach($source in $sourceImageInfos) {
    foreach($cond in $imgAr) {
      if($source.imageName -like $cond) {
        $newSources += $source
        break
      }
    }
  }

  if(-not $newSources) {
    Write-Error "No source images selected by the image pattern chosen"
    exit
  }

  $sourceImageInfos = $newSources
}

Write-Output $sourceImageInfos

# ------------------------------------------------------------------
# Next we copy each of the images to the DevTest Lab's storage account
# ------------------------------------------------------------------
$copyHandles = @()

foreach ($sourceImage in $sourceImageInfos) {
    $srcURI = $SourceStorageContext.BlobEndPoint + "$StorageContainerName/" + $sourceImage.vhdFileName
    # Create it if it doesn't exist...
    New-AzureStorageContainer -Context $DestStorageContext -Name 'uploads' -ErrorAction Ignore
    # Initiate all the file copies
    $copyHandles += Start-AzureStorageBlobCopy -srcUri $srcURI -SrcContext $SourceStorageContext -DestContainer 'uploads' -DestBlob $sourceImage.vhdFileName -DestContext $DestStorageContext -Force
    Write-Output ("Started copying " + $sourceImage.vhdFileName + " to " + $DestStorageAcctName + " at " + (Get-Date -format "h:mm:ss tt"))
}

$copyStatus = $copyHandles | Get-AzureStorageBlobCopyState

while (($copyStatus | Where-Object {$_.Status -eq "Pending"}) -ne $null) {
    $copyStatus | Where-Object {$_.Status -eq "Pending"} | ForEach-Object {
        [int]$perComplete = ($_.BytesCopied/$_.TotalBytes)*100
        Write-Output ("    Copying " + $($_.Source.Segments[$_.Source.Segments.Count - 1]) + " to " + $DestStorageAcctName + " - $perComplete% complete" )
    }
    Start-Sleep -Seconds 60
    $copyStatus = $copyHandles | Get-AzureStorageBlobCopyState
}

# Copies are complete by this point, but we need to check for errors
$copyStatus | Where-Object {$_.Status -ne "Success"} | ForEach-Object {
    Write-Error "    Error copying image $($_.Source.Segments[$_.Source.Segments.Count - 1]), $($_.StatusDescription)"
}

$copyStatus | Where-Object {$_.Status -eq "Success"} | ForEach-Object {
    Write-Output "    Completed copying image $($_.Source.Segments[$_.Source.Segments.Count - 1]) to $DestStorageAcctName - 100% complete"
}

# ------------------------------------------------------------------
# Once copies are done, we need to create 'custom images' that use the VHDs by deploying an ARM template
# ------------------------------------------------------------------

$templatePath = Join-Path $scriptFolder "CreateImageFromVHD.json"

foreach ($sourceImage in $sourceImageInfos) {

    $vhdUri = $DestStorageContext.BlobEndPoint + "uploads/" + $sourceImage.vhdFileName

    $deployName = "Deploy-$DevTestLabName-$($sourceImage.vhdFileName)"

    # Making it unique otherwise the generated Managed Disk created in the RG ends up having the same name
    $uniqueImageName = $DevTestLabName + $sourceImage.imageName
    $deployResult = New-AzureRmResourceGroupDeployment -Name $deployName -ResourceGroupName $labRgName -TemplateFile $templatePath -existingLabName $DevTestLabName -existingVhdUri $vhdUri -imageOsType $sourceImage.osType -imageName $uniqueImageName -imageDescription $sourceImage.description

    # Delete the VHD, we don't need it after the custom image is created, since it uses managed images
    Remove-AzureStorageBlob -Context $DestStorageContext -Container 'uploads' -Blob $sourceImage.vhdFileName

    # Remove Deployment
    Remove-AzureRmResourceGroupDeployment -ResourceGroupName $labRgName -Name $deployName  -ErrorAction SilentlyContinue | Out-Null

    if($deployResult.ProvisioningState -eq "Succeeded"){
        Write-Output "Successfully deployed custom image $($sourceImage.vhdFileName) to Lab $DevTestLabName"
    }
    else {
        Write-Error "Image deploy failed for custom image $($sourceImage.vhdFileName) to Lab $DevTestLabName"
    }
}

$sourceImageInfos | Export-Clixml -Path "Images$DateString.xml" # Passed thorugh as subsequent scripts needs info to create VMs, better way?
