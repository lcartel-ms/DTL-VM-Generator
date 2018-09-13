param
(
    [Parameter(Mandatory=$false, HelpMessage="Unique string representing the date")]
    [string] $DateSTring = "-yyyy_MM_dd-HH_mm_ss",

    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group to create the lab in")]
    [string] $ResourceGroupName,

    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageAccountName,

    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageContainerName,

    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [string] $StorageAccountKey,

    [Parameter(HelpMessage="The shutdown time for the lab")]
    [string] $ShutDownTime = "1900",

    [Parameter(HelpMessage="The timezone to use")]
    [string] $TimeZoneId = "W. Europe Standard Time",

    [Parameter(HelpMessage="The Region for the DevTest Lab")]
    [string] $LabRegion = "westeurope",

    [Parameter(HelpMessage="The list of users (emails) that we need to add as lab owners")]
    [string[]] $LabOwners = @(),

    [Parameter(HelpMessage="The list of users (emails) that we need to add as lab users")]
    [string[]] $LabUsers = @()
)

Import-Module AzureRM.Profile

$DebugPreference = "Continue"

$error.Clear()

$scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
$outputFolder = Join-Path $scriptFolder "logs\"

$outputFile = $DevTestLabName + $DateString + ".txt"
$outputFilePath = Join-Path $outputFolder $outputFile

Start-Transcript -Path $outputFilePath -NoClobber -IncludeInvocationHeader

$newLab = Join-Path $scriptFolder "New-DevTestLab.ps1"
$copyImages = Join-Path $scriptFolder "New-CustomImagesFromStorage.ps1"
$createVMs = Join-Path $scriptFolder "New-Vms.ps1"
$setDnsServers = Join-Path $scriptFolder "Set-DnsServers.ps1"

& $newLab -DevTestLabName $DevTestLabName -ResourceGroupName $ResourceGroupName -ShutDownTime $ShutDownTime -TimeZoneId $TimeZoneId -LabRegion $LabRegion -LabOwners $LabOwners -LabUsers $LabUsers
& $copyImages -DevTestLabName $DevTestLabName -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -StorageContainerName $StorageContainerName -StorageAccountKey $StorageAccountKey
& $createVMs -DevTestLabName $DevTestLabName -ResourceGroupName $ResourceGroupName
& $setDnsServers -DevTestLabName $DevTestLabName -ResourceGroupName $ResourceGroupName

if($error.Count -ne 0) {
  Resolve-AzureRmError
  $errorFile = $DevTestLabName + $DateString + ".err.txt"
  $outputFilePath = Join-Path $outputFolder $errorFile
  $error | Out-File $outputFilePath
  Resolve-AzureRmError | Out-File $outputFilePath -Append
}

Stop-Transcript