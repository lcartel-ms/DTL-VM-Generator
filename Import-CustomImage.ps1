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

$lab = Get-AzDtlLab -Name $DevTestLabName -ResourceGroupName $ResourceGroupName

if ($null -eq $lab) {
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
$sourceLab = Get-AzResource -ResourceName $lab.Name -ResourceGroupName $labRgName -ResourceType 'Microsoft.DevTestLab/labs'
$DestStorageAccountResourceId = $sourceLab.Properties.artifactsStorageAccount
$DestStorageAcctName = $DestStorageAccountResourceId.Substring($DestStorageAccountResourceId.LastIndexOf('/') + 1)
$storageAcct = (Get-AzStorageAccountKey -StorageAccountName $DestStorageAcctName -ResourceGroupName $labRgName)
$DestStorageAcctKey = $storageAcct.Value[0]

$DestStorageContext = New-AzStorageContext -StorageAccountName $DestStorageAcctName -StorageAccountKey $DestStorageAcctKey

# ------------------------------------------------------------------
# Next we copy each of the images to the DevTest Lab's storage account
# ------------------------------------------------------------------
$SourceStorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey

$copyHandles = @()

foreach ($sourceImage in $VmSettings) {
    $srcURI = $SourceStorageContext.BlobEndPoint + "$StorageContainerName/" + $sourceImage.vhdFileName
    # Create it if it doesn't exist...
    New-AzStorageContainer -Context $DestStorageContext -Name 'uploads' -ErrorAction Ignore
    # Initiate all the file copies
    $copyHandles += Start-AzStorageBlobCopy -srcUri $srcURI -SrcContext $SourceStorageContext -DestContainer 'uploads' -DestBlob $sourceImage.vhdFileName -DestContext $DestStorageContext -Force
    Write-Host ("Started copying " + $sourceImage.vhdFileName + " to " + $DestStorageAcctName + " at " + (Get-Date -format "h:mm:ss tt"))
}

$copyStatus = $copyHandles | Get-AzStorageBlobCopyState

while ($null -ne ($copyStatus | Where-Object {$_.Status -eq "Pending"})) {
    $copyStatus | Where-Object {$_.Status -eq "Pending"} | ForEach-Object {
        [int]$perComplete = ($_.BytesCopied/$_.TotalBytes)*100
        Write-Host ("    Copying " + $($_.Source.Segments[$_.Source.Segments.Count - 1]) + " to " + $DestStorageAcctName + " - $perComplete% complete" )
    }
    Start-Sleep -Seconds 60
    $copyStatus = $copyHandles | Get-AzStorageBlobCopyState
}

# Copies are complete by this point, but we need to check for errors
$copyStatus | Where-Object {$_.Status -ne "Success"} | ForEach-Object {
    throw "    Error copying image $($_.Source.Segments[$_.Source.Segments.Count - 1]), $($_.StatusDescription)"
}

$copyStatus | Where-Object {$_.Status -eq "Success"} | ForEach-Object {
    Write-Host "    Completed copying image $($_.Source.Segments[$_.Source.Segments.Count - 1]) to $DestStorageAcctName - 100% complete"
}

# ------------------------------------------------------------------
# Once copies are done, we need to create 'custom images' that use the VHDs
# ------------------------------------------------------------------

foreach ($sourceImage in $VmSettings) {

    $vhdUri = $DestStorageContext.BlobEndPoint + "uploads/" + $sourceImage.vhdFileName

    # Making it unique otherwise the generated Managed Disk created in the RG ends up having the same name
    $uniqueImageName = $DevTestLabName + $sourceImage.imageName    

    Import-AzDtlCustomImageFromUri -Lab $lab -Uri $vhdUri -ImageOsType $sourceImage.osType -ImageName $uniqueImageName -ImageDescription $sourceImage.description
}

Write-Output "Copied all images to $DevTestLabName"