param
(
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group")]
    [string] $ResourceGroupName,

    [Parameter(HelpMessage="The Region for the DevTest Lab")]
    [string] $ShutDownTime = "1900",

    [Parameter(HelpMessage="The Region for the DevTest Lab")]
    [string] $TimeZoneId = "W. Europe Standard Time",

    [Parameter(HelpMessage="The Region for the DevTest Lab")]
    [string] $LabRegion = "westeurope",

    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageAccountName,

    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageContainerName,

    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageAccountKey,

    [Parameter(HelpMessage="The list of users (emails) that we need to add as lab owners")]
    [string[]] $LabOwners = @(),

    [Parameter(HelpMessage="The list of users (emails) that we need to add as lab users")]
    [string[]] $LabUsers = @()
)

# Clear the errors up front-  helps when running the script multiple times
$error.Clear()

& "$PSScriptRoot\New-DevTestLab.ps1" -DevTestLabName $DevTestLabName -ResourceGroupName $ResourceGroupName -ShutDownTime $ShutDownTime -TimeZoneId $TimeZoneId -LabRegion $LabRegion -LabOwners $LabOwners -LabUsers $LabUsers

& "$PSScriptRoot\CopyCustomImagesToLab.ps1" -DevTestLabName $DevTestLabName -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -StorageContainerName $StorageContainerName -StorageAccountKey $StorageAccountKey

& "$PSScriptRoot\CreateVMs.ps1" -DevTestLabName $DevTestLabName -ResourceGroupName $ResourceGroupName

