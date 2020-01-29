<#
.SYNOPSIS
This script will import VHDs an JSON files into a Shared Image Gallery

.EXAMPLE
./Import-VHDsToSharedImageGallery.ps1 https://mystorageaccount.blob.core.windows.net/vhds-12-2019 
#>

#Requires -Version 3.0
#Requires -Module Az.Resources

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
    [string] $StorageAccountKey,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$false, HelpMessage="The resource group name for the Shared Image Gallery, only required if the SIG doesn't already exist")]
    [string] $SharedImageGalleryResourceGroupName = "SharedImageGallery_DevTestLabs_rg",

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$false, HelpMessage="The Name of the Shared Image Gallery where we will publish the VHDs & JSON information")]
    [string] $SharedImageGalleryName = "SharedImageGallery_DevTestLabs",

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$false, HelpMessage="The location of the Shared Image Gallery, only required if the SIG doesn't already exist")]
    [string] $SharedImageGalleryLocation = "westeurope"

)
$startTime = Get-Date

Write-Output "Start of script: $StartTime"

# ------------- DEBUGGING VALUES -------------
if ($false) {
$StorageAccountName = "epitacybersecurity"
$StorageContainerName = "vhds"
$StorageAccountKey = "z0+62+wrBO6tBg6IvGZA20VAK6JxND3QP7YtgmlNXGVE32ysJW9aXlPFZ1hHITEvBZs6pdgHogzMRHPUSfeKRA=="
$SharedImageGalleryResourceGroupName = "EPITA-CyberSecurity"
$SharedImageGalleryName = "CyberSecurityImageGallery"
$SharedImageGalleryLocation = "westeurope"
$ImagePublisher = "PeteHauge"

.\Import-VHDsToSharedImageGallery.ps1 -StorageAccountName "epitavhds" `
                                      -StorageContainerName "vhds" `
                                      -StorageAccountKey "vjl59kvYByxPgl8+euRkDiAvm1096VEsUv1PoVklMDTz4mEWpxR9P0txLbj7daFBuzd9RAqCDbrxDXrSyXwVhA=="
}
# --------------------------------------------

$ErrorActionPreference = 'Stop'

. "./Utils.ps1"

$importVhdToSharedImageGalleryScriptBlock = {
    param
    (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true, HelpMessage="The Shared Image Gallery object")]
        [psobject] $SharedImageGallery,
    
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true, HelpMessage="All the image definitions in the Shared Image Gallery")]
        [psobject] $ImageDefinitions,
    
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true, HelpMessage="The details of the VHD to import into the Shared Image Gallery")]
        [psobject] $imageInfo
    )

    # See if we have an existing image
    $imageDef = $ImageDefinitions | Where-Object {$_.Name -eq $imageInfo.imageName}
    Write-Output "Begin import of image '$($imageInfo.imageName)'"
    if (-not $imageDef) {
        Write-Output "Creating Image Definition '$($imageInfo.imageName)'.."
        # Image definition doesn't exist, let's create one
        $imageDef = New-AzGalleryImageDefinition -GalleryName $SharedImageGallery.Name `
                                                 -ResourceGroupName $SharedImageGallery.ResourceGroupName `
                                                 -Location $SharedImageGallery.Location `
                                                 -Name $imageInfo.imageName `
                                                 -Description $imageInfo.description `
                                                 -Publisher 'Custom' `
                                                 -Offer $imageInfo.imageName `
                                                 -Sku $imageInfo.vhdFileName `
                                                 -OsState Specialized `
                                                 -OsType $imageInfo.osType
    }

    # Remove any existing image versions
    Get-AzGalleryImageVersion -ResourceGroupName  $SharedImageGallery.ResourceGroupName `
                              -GalleryName $SharedImageGallery.Name `
                              -GalleryImageDefinitionName $imageDef.Name `
                              | Remove-AzGalleryImageVersion -Force | Out-Null

    $imageConfig = New-AzImageConfig -Location $SharedImageGallery.Location
    $imageConfig = Set-AzImageOsDisk -Image $imageConfig -OsType Windows -OsState Specialized -BlobUri $imageinfo.sourceVhdUri
    Write-Output "   Importing VHD '$($imageInfo.vhdFileName)' as a Managed Image.."
    $managedimage = New-AzImage -ImageName $imageInfo.imageName -ResourceGroupName $SharedImageGallery.ResourceGroupName -Image $imageConfig

    Write-Output "   Creating a new image version for '$($imageInfo.imageName)'"

    # Convert the properties to a hashtable so we can apply as tags
    $tags = @{}
    $imageInfo.psobject.properties | Foreach { $tags[$_.Name] = $_.Value.ToString() }

    # Let's create a new image version based on the existing image definition & upload the VHD
    $imageVersion = New-AzGalleryImageVersion -GalleryImageDefinitionName $imageDef.Name `
                                              -GalleryImageVersionName '1.0.0' `
                                              -GalleryName $SharedImageGallery.Name `
                                              -ResourceGroupName  $SharedImageGallery.ResourceGroupName `
                                              -Location $SharedImageGallery.Location `
                                              -TargetRegion @(@{Name=$SharedImageGallery.Location;ReplicaCount=1})  `
                                              -Source $managedimage.Id `
                                              -Tag $tags
    
    # Delete the managed image (we don't need it anymore), just a step to get into shared image gallery
    Write-Output "   Cleaning up managed image from '$($imageInfo.vhdFileName)'"
    Remove-AzResource -ResourceId $managedimage.Id -Force | Out-Null
    Write-Output "Complete import of image '$($imageInfo.imageName)'"
}

# Check if the shared image gallery exists, if not we create it
$SharedImageGallery = Get-AzGallery | Where-Object {$_.Name -eq $SharedImageGalleryName -and $_.ResourceGroupName -eq $SharedImageGalleryResourceGroupName}

if (-not $SharedImageGallery) {
    # if the SIG doesn't exist, need to create it
    if (-not $SharedImageGalleryLocation) {
        Write-Error "Must provide SharedImageGalleryLocation parameter when the Shared Image Gallery provided does not exist.."
    }
    else {
        Write-Output "Shared Image Gallery doesn't exist, creating it..."
        # Check if the resource group exists
        $SIGrg = Get-AzResourceGroup | Where-Object {$_.ResourceGroupName -eq $SharedImageGalleryResourceGroupName }
        if (-not $SIGrg) {
            $SIGrg = New-AzResourceGroup -Name $SharedImageGalleryResourceGroupName -Location $SharedImageGalleryLocation
        }

        $SharedImageGallery = New-AzGallery -GalleryName $SharedImageGalleryName -ResourceGroupName $SharedImageGalleryResourceGroupName -Location $SharedImageGalleryLocation
    }
} else {
    Write-Output "Shared Image Gallery already exists, reusing it..."
}

# List of image definitions in the shared image gallery
$ImageDefinitions = Get-AzGalleryImageDefinition -GalleryName $SharedImageGallery.Name -ResourceGroupName $SharedImageGallery.ResourceGroupName
if (-not $ImageDefinitions) {
    # If the image definitions variable is null, we need to make it an empty list
    $ImageDefinitions = @()
}

# Get the list of JSON files in the storage account
$VmSettings = & "./Import-VmSetting" -StorageAccountName $StorageAccountName -StorageContainerName $StorageContainerName -StorageAccountKey $StorageAccountKey

$jobs = @()

# For each JSON file, we create a image (if there isn't one already), or add a new image version
foreach ($imageInfo in $VmSettings) {
    Write-Output "Starting job to import $($imageInfo.imageName) image"
    $jobs += Start-RSJob -ScriptBlock $importVhdToSharedImageGalleryScriptBlock -ArgumentList $SharedImageGallery, $ImageDefinitions, $imageInfo -Throttle 25
    Start-Sleep -Seconds 15
}

# Wait for all the jobs to complete - but send some status to the UI
$runningJobs = ($jobs | Where-Object {$_.State -eq "Running"} | Measure-Object).Count
while ($runningJobs -gt 0){
    Write-Output "Waiting for remaining $($runningJobs) jobs to complete.."
    Start-Sleep -Seconds 60

    # We can write the output of any completed jobs
    foreach ($job in Get-RsJob -State Completed) {
        Write-Output "----------------------------------------------"
        $job.Output | Write-Output
        
        Remove-RSJob -Job $job
    }

    $runningJobs = ($jobs | Where-Object {$_.State -eq "Running"} | Measure-Object).Count
}

# Write the output of any remaining jobs
foreach ($job in Get-RsJob){
    Write-Output "----------------------------------------------"
    $job.Output | Write-Output
    Remove-RSJob -Job $job
}

Write-Output "----------------------------------------------"

Write-Output "End of script: $(Get-Date)"
Write-Output "Total script duration $(((Get-Date) - $StartTime).TotalSeconds) seconds"
