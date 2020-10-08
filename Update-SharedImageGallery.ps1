param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigFile = "config.csv"    
)

$ErrorActionPreference = "Stop"

# Common setup for scripts
. "./Utils.ps1"                                          # Import all our utilities
Import-AzDtlModule                                       # Import the DTL Library
$config = Import-ConfigFile -ConfigFile $ConfigFile      # Import all the lab settings from the config file

$configCount = ($config | Measure-Object).Count

# Add in Shared Image Gallery to the labs
Write-Host "---------------------------------" -ForegroundColor Green
Write-Host "Connecting Shared Image Gallery to  $configCount labs ..." -ForegroundColor Green
$config | ForEach-Object {
    $SharedImageGallery = Get-AzGallery -Name $_.SharedImageGalleryName
    if (-not $SharedImageGallery) {
        Throw "Unable to update lab '$($_.Name)', '$($_.SharedImageGalleryName)' shared image gallery does not exist."
    }
    $lab = $_ | Get-AzDtlLab
    # Check if the lab already has a gallery, if so, remove it
    $labGallery = $lab | Get-AzDtlLabSharedImageGallery
    if ($labGallery) {
        $labGallery | Remove-AzDtlLabSharedImageGallery
    }
     $lab | Set-AzDtlLabSharedImageGallery -Name $_.SharedImageGalleryName -ResourceId $SharedImageGallery.Id
}

Remove-AzDtlModule                                       # Remove the DTL Library
