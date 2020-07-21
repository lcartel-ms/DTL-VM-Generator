param
(
    [ValidateNotNullOrEmpty()]
    [Parameter(ParameterSetName='Storage', Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageAccountName,

    [ValidateNotNullOrEmpty()]
    [Parameter(ParameterSetName='Storage', Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageContainerName,

    [ValidateNotNullOrEmpty()]
    [Parameter(ParameterSetName='Storage', Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageAccountKey,

    [ValidateNotNullOrEmpty()]
    [Parameter(ParameterSetName='sharedImageGallery', Mandatory=$true, HelpMessage="The name of the SharedImageGallery that contains the image definitions & image versions for the labs")]
    [string] $SharedImageGalleryName
)

$ErrorActionPreference = 'Stop'

. "./Utils.ps1"

if ($PSCmdlet.ParameterSetName -eq "Storage") {

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
        Add-Member -InputObject $imageObj -MemberType NoteProperty -Name sourceVhdUri -Value "$($SourceStorageContext.BlobEndPoint)$StorageContainerName/$($imageObj.vhdFileName)"
        $sourceImageInfos += $imageObj
    }

    $sourceImageInfos
}
else {
    # Get the Shared Image Gallery
    $gallery = Get-AzGallery -Name $SharedImageGalleryName

# ------------ ALTERNATE IMPLEMENTATION - slower but works for multiple image versions
#    # Get all the image definitions
#    $imageDefinitions = Get-AzGalleryImageDefinition -ResourceGroupName $gallery.ResourceGroupName `
#                                                     -GalleryName $gallery.Name
#    # Get the latest image version from each of the image definitions
#    $images = $imageDefinitions `
#              | ForEach-Object {
#                    Get-AzGalleryImageVersion -ResourceGroupName $gallery.ResourceGroupName `
#                                              -GalleryName $gallery.Name `
#                                              -GalleryImageDefinitionName $_.Name `
#                     | Sort-Object -Property Name -Descending | Select -first 1
#                }
# --------------------------------------------------------------------

    # Get all the image versions for this gallery
    # ASSUMPTION:  we are assuming the image definitions have only 1 image version - we need to change this code if the image definitions can have more than one version
    $images = Get-AzResource -ResourceGroupName $gallery.ResourceGroupName -ResourceType "Microsoft.Compute/galleries/images/versions" `
                | Where-Object {$_.Name.StartsWith($gallery.Name) }

    Write-Host "Compiling settings from $(($images | Measure-Object).Count) image definitions"

    $sourceImageInfos = @()

    $images | ForEach-Object {
        $sourceImageInfos += New-Object PSCustomObject -Property $_.Tags
    }

    $sourceImageInfos
    
}