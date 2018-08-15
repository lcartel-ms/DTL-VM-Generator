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

$scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
$executable = Join-Path $scriptFolder "CreateCyberLab.ps1"

# Check we're in the right directory
if (-not (Test-Path $executable)) {
  Write-Error "Unable to find CreateCyberLab.ps1...  unable to proceed."
  return
}

# Create Unique string for error files
$dateString = get-date -f "-yyyy_MM_dd-HH_mm_ss"
Write-Output "Error logs for this run are in logs/ and contain the string $datestring"

$config = Import-Csv $ConfigFile

$errorFolder = Join-Path $scriptFolder "logs\"

$procs = @()

$count = 1
Write-Output "Starting processes to create labs in $WindowsStyle windows ..."
ForEach ($lab in $config) {
  $errorFile = $lab.DevTestLabName + $dateString + ".err.txt"
  $errorFilePath = Join-Path $errorFolder $errorFile

  $argList = "-File ""$executable"" -DevTestLabName $($lab.DevTestLabName) -ResourceGroupName $($lab.ResourceGroupName) -StorageAccountName $($lab.StorageAccountName) -StorageContainerName $($lab.StorageContainerName) -StorageAccountKey ""$($lab.StorageAccountKey)"" -ShutDownTime $($lab.ShutDownTime) -TimeZoneId ""$($lab.TimeZoneId)"" -LabRegion ""$($lab.LabRegion)"" -LabOwners $($lab.LabOwners) -LabUsers $($lab.LabUsers)"

  Write-Output "$count : Creating lab $($lab.DevTestLabName)"
  Write-Output "$argList"
  $procs += Start-Process "powershell.exe" -PassThru -WindowStyle $WindowsStyle -RedirectStandardError $errorFilePath -ArgumentList $argList -WorkingDirectory $scriptFolder
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
