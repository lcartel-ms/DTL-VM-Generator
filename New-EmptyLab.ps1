param
(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group")]
    [string] $ResourceGroupName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the Shared Image Gallery to add to the lab")]
    [string] $SharedImageGalleryName,

    [ValidateNotNullOrEmpty()]
    [Parameter(HelpMessage="The time (relative to timeZoneId) at which the Lab VMs will be automatically shutdown (E.g. 17:30, 20:00, 09:00)")]
    [string] $ShutDownTime = "1900",

    [ValidateNotNullOrEmpty()]
    [Parameter(HelpMessage="The Windows time zone id associated with labVmShutDownTime (E.g. UTC, Pacific Standard Time, Central Europe Standard Time)")]
    [string] $TimeZoneId = "W. Europe Standard Time",

    [ValidateNotNullOrEmpty()]
    [Parameter(HelpMessage="The Region for the DevTest Lab")]
    [string] $LabRegion = "westeurope",

    [Parameter(HelpMessage="The list of users (emails) that we need to add as lab owners")]
    [string[]] $LabOwners = @(),

    [Parameter(HelpMessage="The list of users (emails) that we need to add as lab users")]
    [string[]] $LabUsers = @(),

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$false, HelpMessage="Custom Role to add users to")]
    [string] $CustomRole =  "No VM Creation User",

    [Parameter(valueFromRemainingArguments=$true)]
    [String[]]
    $rest = @()
)

$ErrorActionPreference = "Stop"

. "./Utils.ps1"

if ($DevTestLabName.Length -gt 50) {
    throw "'$DevTestLabName' is too long, must be 50 characters or less"
}

$existingLab = Get-AzResource -Name $DevTestLabName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

if ($null -ne $existingLab) {
    throw "'$DevTestLabName' Lab already exists, can't create this one!  Unable to proceed."
}
else {

    $SharedImageGallery = Get-AzGallery -Name $SharedImageGalleryName
    if (-not $SharedImageGallery) {
        Throw "Unable to create lab, '$SharedImageGalleryName' shared image gallery does not exist."
    }

    Write-Host "Creating lab '$DevTestLabName'"

    # The SilentlyContinue bit is to suppress the error that otherwise this generates.
    $existingRg = Get-AzResourceGroup -Name $ResourceGroupName -Location $LabRegion -ErrorAction SilentlyContinue

    if(-not $existingRg) {
      Write-Host "Creating Resource Group '$ResourceGroupName' ..."
      New-AzResourceGroup -Name $ResourceGroupName -Location $LabRegion | Out-Null
    }

    Write-Host "Starting creation of lab $DevTestLabName ..."

    # Use new DTL Library here
    New-AzDtlLab -Name $DevTestLabName -ResourceGroupName $ResourceGroupName `
        | Set-AzDtlLabShutdown -ShutdownTime $ShutDownTime -TimeZoneId $TimeZoneId `
        | Set-AzDtlLabSharedImageGallery -Name "SharedImageGallery" -ResourceId $SharedImageGallery.Id
    
    Set-LabAccessControl $DevTestLabName $ResourceGroupName $CustomRole $LabOwners $LabUsers

    Write-Output "Completed Creating the '$DevTestLabName' lab"
}

