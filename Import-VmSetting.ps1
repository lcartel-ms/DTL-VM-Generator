param
(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageAccountName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageContainerName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageAccountKey
)

$ErrorActionPreference = 'Stop'

. "./Utils.ps1"

$SourceStorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
$jsonBlobs = Get-AzStorageBlob -Context $SourceStorageContext -Container $StorageContainerName -Blob '*json'
Write-Host "Downloading $($jsonBlobs.Count) json files from storage account"

$downloadFolder = Join-Path $env:TEMP 'CustomImageDownloads'
if(Test-Path -Path $downloadFolder)
{
    Remove-Item $downloadFolder -Recurse | Out-Null
}
New-Item -Path $downloadFolder -ItemType Directory | Out-Null

$sourceImageInfos = @()

$jsonBlobs | Get-AzStorageBlobContent -Destination $downloadFolder | Out-Null
$downloadedFileNames = Get-ChildItem -Path $downloadFolder
foreach($file in $downloadedFileNames)
{
    $imageObj = (Get-Content $file.FullName -Raw) | ConvertFrom-Json
    $imageObj.timestamp = [DateTime]::Parse($imageObj.timestamp)
    $sourceImageInfos += $imageObj
}

$sourceImageInfos
