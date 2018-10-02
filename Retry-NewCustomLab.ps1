param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [string] $ConfigFile = "config.csv",

    [Parameter(Mandatory=$true, HelpMessage="Window style for the spawn off processes")]
    [string] $LabName,

    [Parameter(Mandatory=$false, HelpMessage="Window style for the spawn off processes")]
    [string] $WindowsStyle =  "Minimized"
)

# Clear the errors up front-  helps when running the script multiple times
$error.Clear()

$scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
$removeScript = Join-Path $scriptFolder "Remove-Lab.ps1"
$executable = Join-Path $scriptFolder "New-CustomLab.ps1"

# Check we're in the right directory
if (-not (Test-Path $removeScript)) {
  Write-Error "Unable to find $removeScript ...  unable to proceed."
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

ForEach ($lab in $config) {

  if($lab.DevTestLabName -eq $LabName) {
    & $removeScript -DtlLabName $LabName -ResourceGroupName $lab.ResourceGroupName

    $argList = "-File ""$executable"" -DateString ""$dateString"" -DevTestLabName $($lab.DevTestLabName) -ResourceGroupName $($lab.ResourceGroupName) -StorageAccountName $($lab.StorageAccountName) -StorageContainerName $($lab.StorageContainerName) -StorageAccountKey ""$($lab.StorageAccountKey)"" -ShutDownTime $($lab.ShutDownTime) -TimeZoneId ""$($lab.TimeZoneId)"" -LabRegion ""$($lab.LabRegion)"" -LabOwners ""$($lab.LabOwners)"" -LabUsers ""$($lab.LabUsers)"""

    Write-Host "Started process to create lab $($lab.DevTestLabName)"
    $procs += Start-Process "powershell.exe" -PassThru -WindowStyle $WindowsStyle -ArgumentList $argList -WorkingDirectory $scriptFolder
  }
}

Write-Host "Waiting for all processes to end"
$procs | Wait-Process -Timeout (60 * 60 * 8)

# Check if there were errors by looking for the presence of error files
if (Test-Path $errorFolder) {
  $files = @(Get-ChildItem $errorFolder -Filter "*$dateString*.err.txt" -File)
} else {
  $files = @()
}

if($files.Count -eq 0) {
  Write-Host "All process terminated. No error"
} else {
  Write-Error "Some errors where found. Opening log files with errors."
  $files | Foreach-Object {
    Start-Process $_.Fullname
  }
}
