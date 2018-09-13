param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [string] $ConfigFile = "config.csv",

    [Parameter(Mandatory=$false, HelpMessage="Window style for the spawn off processes")]
    [string] $WindowsStyle =  "Minimized",

    [Parameter(Mandatory=$false, HelpMessage="How many minutes to wait before starting the next parallel lab creation")]
    [int] $MinutesToNextLabCreation =  2

)

# Clear the errors up front-  helps when running the script multiple times
$error.Clear()

# Is the below line going to make it check for errors in the spawn processes even when an error on this one?
# I am really unconfortable with PS error model ...
$ErrorActionPreference = 'Continue'

$scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
$executable = Join-Path $scriptFolder "New-CustomLab.ps1"

# Check we're in the right directory
if (-not (Test-Path $executable)) {
  Write-Error "Unable to find New-CustomLab.ps1...  unable to proceed."
  return
}

$config = Import-Csv $ConfigFile

# Creates error folder if it doesn't exist
$errorFolder = Join-Path $scriptFolder "logs\"
if(!(Test-Path -Path $errorFolder )){
  New-Item -ItemType directory -Path $errorFolder
}

$dateString = get-date -f "-yyyy_MM_dd-HH_mm_ss"

$procs = @()

$count = 1
Write-Output "Starting processes to create labs in $WindowsStyle windows ..."
ForEach ($lab in $config) {

  $argList = "-DateString $dateString -File ""$executable"" -DevTestLabName $($lab.DevTestLabName) -ResourceGroupName $($lab.ResourceGroupName) -StorageAccountName $($lab.StorageAccountName) -StorageContainerName $($lab.StorageContainerName) -StorageAccountKey ""$($lab.StorageAccountKey)"" -ShutDownTime $($lab.ShutDownTime) -TimeZoneId ""$($lab.TimeZoneId)"" -LabRegion ""$($lab.LabRegion)"" -LabOwners ""$($lab.LabOwners)"" -LabUsers ""$($lab.LabUsers)"""

  Write-Output "$count : Creating lab $($lab.DevTestLabName)"
  $procs += Start-Process "powershell.exe" -PassThru -WindowStyle $WindowsStyle -ArgumentList $argList -WorkingDirectory $scriptFolder
  Start-Sleep -Seconds ($MinutesToNextLabCreation * 60)
  $count += 1
}

Write-Output "Waiting for all processes to end"
$procs | Wait-Process -Timeout (60 * 60 * 8)

# Check if there were errors by looking for the presence of error files
if (Test-Path $errorFolder) {
  $files = @(Get-ChildItem $errorFolder -Filter "*$dateString*.err.txt" -File)
} else {
  $files = @()
}

if($files.Count -eq 0) {
  Write-Output "All process terminated. No error"
} else {
  Write-Error "Some errors where found. Opening log files with errors."
  $files | Foreach-Object {
    Start-Process $_.Fullname
  }
}
