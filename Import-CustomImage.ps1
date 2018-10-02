param
(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest targetLab")]
    [string] $DevTestLabName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest targetLab")]
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

    [Parameter(Mandatory=$false, HelpMessage="The VM Configuration objects (by default it downloads them)")]
    $VmSettings = ""
)

$ErrorActionPreference = 'Stop'

. "./Utils.ps1"

if(-not $VmSettings) {
  $VmSettings = & "./Import-VmSetting" -StorageAccountName $StorageAccountName -StorageContainerName $StorageContainerName -StorageAccountKey $StorageAccountKey
}

$lab = Get-AzureRmResource -Name $DevTestLabName -ResourceGroupName $ResourceGroupName

if ($lab -eq $null) {
    throw "'$DevTestLabName' Lab doesn't exist, can't copy images to it"
}

$scriptFolder = $PWD

if(-not $scriptFolder) {
  throw "'$DevTestLabName' CopyImages: Script folder is null"
}

# ------------------------------------------------------------------
# Get the storage account for the lab (temp holding spot for VHDs)
# ------------------------------------------------------------------
$labRgName= $ResourceGroupName
$sourceLab = Get-AzureRmResource -ResourceName $lab.Name -ResourceGroupName $labRgName -ResourceType 'Microsoft.DevTestLab/labs'
$DestStorageAccountResourceId = $sourceLab.Properties.artifactsStorageAccount
$DestStorageAcctName = $DestStorageAccountResourceId.Substring($DestStorageAccountResourceId.LastIndexOf('/') + 1)
$storageAcct = (Get-AzureRMStorageAccountKey  -StorageAccountName $DestStorageAcctName -ResourceGroupName $labRgName)
$DestStorageAcctKey = $storageAcct.Value[0]

$DestStorageContext = New-AzureStorageContext -StorageAccountName $DestStorageAcctName -StorageAccountKey $DestStorageAcctKey

# ------------------------------------------------------------------
# Next we copy each of the images to the DevTest Lab's storage account
# ------------------------------------------------------------------
$SourceStorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey

$copyHandles = @()

foreach ($sourceImage in $VmSettings) {
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

foreach ($sourceImage in $VmSettings) {

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
        throw "Image deploy failed for custom image $($sourceImage.vhdFileName) to Lab $DevTestLabName"
    }
}

$VmSettings
