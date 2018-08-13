param
(
    [Parameter(Mandatory=$true, HelpMessage="Configuration File, see example in directory")]
    [string] $ConfigFile = "config.csv",

    [Parameter(Mandatory=$false, HelpMessage="The Name of the resource group to create the lab in")]
    [string] $WindowsStyle =  "Minimized"
)

# Clear the errors up front-  helps when running the script multiple times
$error.Clear()

$scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
$executable = Join-Path $scriptFolder "CreateCyberLab.ps1"

# Check we're in the right directory
if (-not (Test-Path $executable)) {
  Write-Error "Unable to find CreateCyberLab.ps1...  unable to proceed."
  return
}

# Create Unique string for error files
$dateString = get-date -f "-yyyy_MM_dd-HH_mm_ss"

$config = Import-Csv $ConfigFile

$procs = @()

$errorFolder = Join-Path $scriptFolder "logs\"

Write-Output "Starting processes to create labs in $WindowsStyle windows ..."
ForEach ($lab in $config) {
  $errorFile = $lab.LabName + $dateString + ".err.txt"
  $errorFilePath = Join-Path $errorFolder $errorFile

  $argList = "-DevTestLabName $($lab.DevTestLabName) -ResourceGroupName $($lab.ResourceGroupName) -StorageAccountName $($lab.StorageAccountName) -StorageContainerName $($lab.StorageContainerName) -StorageAccountKey $($lab.StorageAccountKey) -ShutDownTime $($lab.ShutDownTime) -TimeZoneId $($lab.TimeZoneId) -LabRegion $($lab.LabRegion) -LabOwners $($lab.LabOwners) -LabUsers $($lab.LabUsers)"

  Write-Output "Starting $executable $argList ..."
  $procs += Start-Process -FilePath $executable -PassThru -WindowStyle $WindowsStyle -RedirectStandardError $errorFilePath -ArgumentList $argList -WorkingDirectory $scriptFolder
}

Write-Output "Waiting for all processes to end"
$procs | Wait-Process -Timeout (60 * 60 * 8)

# Check if there were errors by looking for the presence of error files
$files = @(Get-ChildItem $errorFolder -Filter "*$dateString*.err.txt" -File)

if($files.Count -eq 0) {
  Write-Output "All process terminated. No error"
} else {
  Write-Error "Some errors where found. Opening log files with errors."
  $files | Foreach-Object {
    Start-Process $_.Fullname
  }
}
