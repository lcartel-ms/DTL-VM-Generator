param
(
    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageAccountName,

    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageContainerName,

    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageAccountKey
)

# Clear the errors up front-  helps when running the script multiple times
$error.Clear()
$ErrorActionPreference = 'Continue'


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

$sourceImageInfos | Export-Clixml -Path .\foo.xml # Passed thorugh as subsequent scripts needs info to create VMs, better way?
