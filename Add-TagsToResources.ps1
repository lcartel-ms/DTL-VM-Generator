param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigFile = "config.csv",

    [Parameter(Mandatory=$true, HelpMessage="Pass in any tags to be applied like this: @{'Course'='CyberSecurity';'BillingCode'='12345'}")]
    [Hashtable] $tags,

    [Parameter(Mandatory=$false, HelpMessage="Also tag the lab's resource group?")]
    [bool] $tagLabsResourceGroup = $true

)

$ErrorActionPreference = "Stop"

# Common setup for scripts
. "./Utils.ps1"                                          # Import all our utilities
Import-AzDtlModule                                       # Import the DTL Library
$config = Import-ConfigFile -ConfigFile $ConfigFile      # Import all the lab settings from the config file
$configCount = ($config | Measure-Object).Count

# Tag all the labs & associated resources
if ($tags) {
    Write-Host "---------------------------------" -ForegroundColor Green
    Write-Host "Tagging $configCount lab..." -ForegroundColor Green
    $jobs = $config | Add-AzDtlLabTags -tags $tags -tagLabsResourceGroup $tagLabsResourceGroup -Verbose 

    # If there was nothing to tag, there won't be any jobs
    if ($jobs) {
        Wait-JobWithProgress -jobs $jobs -secTimeout 3600
    }
}

Remove-AzDtlModule                                       # Remove the DTL Library
