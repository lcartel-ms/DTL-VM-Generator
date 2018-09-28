param
(
    [Parameter(Mandatory=$false, HelpMessage="Unique string representing the date")]
    [string] $DateString = (get-date -f "-yyyy_MM_dd-HH_mm_ss"),

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

    [Parameter(Mandatory=$true, HelpMessage="Name of VM to add")]
    [string] $VmName,

    [Parameter(Mandatory=$false, HelpMessage="Creates a transcript of the execution in the logs folder")]
    [switch] $Transcript
)

Import-Module AzureRM.Profile

if($Transcript) {
  $DebugPreference = "Continue"
}

$error.Clear()

$scriptFolder = $PSScriptRoot
if(-not $scriptFolder) {
  Write-Error "Script folder is null"
  exit
}

$outputFolder = Join-Path $scriptFolder "logs\"

$outputFile = $DevTestLabName + $DateString + ".txt"
$outputFilePath = Join-Path $outputFolder $outputFile

if($Transcript) {
  Start-Transcript -Path $outputFilePath -NoClobber -IncludeInvocationHeader
}



if($error.Count -ne 0) {
  Resolve-AzureRmError
  $errorFile = $DevTestLabName + $DateString + ".err.txt"
  $outputFilePath = Join-Path $outputFolder $errorFile
  $error | Out-File $outputFilePath
  Resolve-AzureRmError | Out-File $outputFilePath -Append
}

if($Transcript) {
  Stop-Transcript
}