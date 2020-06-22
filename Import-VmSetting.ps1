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
    [string] $SharedImageGalleryName,
    
    [Parameter(HelpMessage="Include secrets (usernames/passwords/SSH keys) for the VMs, these will be generated if not available in credentials.csv")]
    [switch] $IncludeSecrets

)

$ErrorActionPreference = 'Stop'

. "./Utils.ps1"

$sourceImageInfos = @()

if ($PSCmdlet.ParameterSetName -eq "Storage") {

    $SourceStorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey

    $jsonBlobs = Get-AzStorageBlob -Context $SourceStorageContext -Container $StorageContainerName -Blob '*json'
    $jsonBlobsCount = ($jsonBlobs | Measure-Object).Count
    if ($jsonBlobsCount -eq 0) {
        throw "Unable to continue, storage account doesn't contain any JSON definition files..."
    }


    Write-Host "Downloading $jsonBlobsCount json files from storage account"

    $downloadFolder = Join-Path $env:TEMP 'CustomImageDownloads'
    if(Test-Path -Path $downloadFolder)
    {
        Remove-Item $downloadFolder -Recurse | Out-Null
    }
    New-Item -Path $downloadFolder -ItemType Directory | Out-Null

    $jsonBlobs | Get-AzStorageBlobContent -Destination $downloadFolder | Out-Null
    $downloadedFileNames = Get-ChildItem -Path $downloadFolder
    foreach($file in $downloadedFileNames)
    {
        $imageObj = (Get-Content $file.FullName -Raw) | ConvertFrom-Json
        $imageObj.timestamp = [DateTime]::Parse($imageObj.timestamp)

        # If VM Setting doesn't have osstate - specify specialized to maintain backward compatability
        if (-not ("osstate" -in $imageObj.PSObject.Properties.Name)) {
            Add-Member -InputObject $imageObj -MemberType NoteProperty -Name osstate -Value "Specialized"
        }

        # If VM Setting doesn't have hypervgeneration - specify v1 to maintain backward compatability
        if (-not ("hypervgeneration" -in $imageObj.PSObject.Properties.Name)) {
            Add-Member -InputObject $imageObj -MemberType NoteProperty -Name hypervgeneration -Value "V1"
        }

        # If VM Setting doesn't have publisher - specify custom to maintain backward compatability
        if (-not ("publisher" -in $imageObj.PSObject.Properties.Name)) {
            Add-Member -InputObject $imageObj -MemberType NoteProperty -Name publisher -Value "Custom"
        }
        
        $sourceImageInfos += $imageObj
    }
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

    $images | ForEach-Object {
        $tags =  New-Object PSCustomObject -Property $_.Tags
        $sourceImageInfos += Join-Tags $tags
    }
}

# Get the secrets if requested, or generate them if they don't exist
if ($IncludeSecrets) {

    $credentials = @()
    
    # Read in the generated CSV file if it exists
    if (Test-Path "./credentials.csv") {
        $credCSV = Import-Csv -Path "./credentials.csv"
    }

    # We only look at the source image infos for Generalized os type
    $generalizedInfos = $sourceImageInfos | Where-Object {$_.osState -eq "Generalized"}

    # iterate through the $sourceImageInfos and make sure we have creds for each of them
    foreach ($info in $generalizedInfos) {

        if ((Test-Path variable:credCSV) -and ($credCSV | Where-Object {$_.imageName -eq $info.imageName})) {
            # We have a credential object for this source image info!            
            $cred = $credCSV | Where-Object {$_.imageName -eq $info.imageName}
        }
        else {
            $cred = New-Object PSObject -Property @{
                        imageName = $info.imageName
                    }
        }

        # Must have a username
        if (-not ($cred.PSObject.Properties -match "Username")) {
            Add-Member -InputObject $cred -MemberType NoteProperty -Name "Username" -Value (Get-RandomString -length 8)
        }
        elseif (-not ($cred.Username)) {
            $cred.Username = Get-RandomString -length 8
        }

        # if OS is windows, must have a password
        if ($info.osType -eq "Windows") {
            
            # Handle credential type
            if (-not ($cred.PSObject.Properties -match "CredentialType")) {
                Add-Member -InputObject $cred -MemberType NoteProperty -Name "CredentialType" -value "Password"
            }
            elseif ($cred.CredentialType -ne "Password") {
                $cred.CredentialType = "Password"
            }

            # If value doesn't exist or is blank, create a password
            if (-not ($cred.PSObject.Properties -match "CredentialValue")) {
                Add-Member -InputObject $cred -MemberType NoteProperty -Name "CredentialValue" -Value (Get-NewPassword -length 20)
            }
            elseif (-not ($cred.CredentialValue)) {
                # If password is blank, generate one
                $cred.CredentialValue = (Get-NewPassword -length 20)
            }

        }
        else {
            # For Linux, we can have either a SSH key or a password

            # If credential type doesn't exist, create a password
            if (-not ($cred.PSObject.Properties -match "CredentialType")) {
                Add-Member -InputObject $cred -MemberType NoteProperty -Name "CredentialType" -value "Password"
            }

            # Validate we have a password
            if ($cred.CredentialType -eq "Password") {
                # If value doesn't exist, create a password
                if (-not ($cred.PSObject.Properties -match "CredentialValue")) {
                    Add-Member -InputObject $cred -MemberType NoteProperty -Name "CredentialValue" -Value (Get-NewPassword -length 20)
                }
                elseif (-not ($cred.CredentialValue)) {
                    # If password is blank, generate one
                    $cred.CredentialValue = (Get-NewPassword -length 20)
                }
            }

            # Validate the SSH key
            if ($cred.CredentialType -eq "SSHKey") {
                # If value doesn't exist, throw an error
                if (-not ($cred.PSObject.Properties -match "CredentialValue")) {
                    Write-Error "$($cred.imageName) must have a credential value when credential type is 'SSHKey'"
                }
                elseif (-not ($cred.CredentialValue.startsWith("ssh-rsa "))) {
                    Write-Error "$($cred.imageName) SSH key must start with 'ssh-rsa '.  Invalid key, only RSA keys are supported for authentification"
                }
            }
        }

        # Add to an object to export later
        $credentials += $cred

        # Add all the properties to the Source Image Infos
        Add-Member -InputObject $info -MemberType NoteProperty -Name "Username" $cred.Username
        if ($cred.CredentialType -eq "SSHKey") {
            Add-Member -InputObject $info -MemberType NoteProperty -Name "SSHKey" $cred.CredentialValue
        }
        else {
            Add-Member -InputObject $info -MemberType NoteProperty -Name "Password" $cred.CredentialValue
        }

    }

    $credentials | Export-Csv -Path "./credentials.csv"
}

$sourceImageInfos
