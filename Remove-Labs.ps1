param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [string] $ConfigFile = "config.csv",

    [Parameter(Mandatory=$false, HelpMessage="How many minutes to wait before starting the next parallel lab deletion")]
    [int] $MinutesToNextLabDeletion =  2

)

# Clear the errors up front-  helps when running the script multiple times
$error.Clear()

$scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
$executable = Join-Path $scriptFolder "Remove-Lab.ps1"

# Check we're in the right directory
if (-not (Test-Path $executable)) {
  Write-Error "Unable to find Remove-Lab.ps1...  unable to proceed."
  return
}

$config = Import-Csv $ConfigFile

$jobs = @()

ForEach ($lab in $config) {
  Write-Output "Starting job to delete a lab named $($lab.DevTestLabName)"
  $jobs += Start-Job -Name $lab.DevTestLabName -FilePath $executable -ArgumentList $lab.DevTestLabName, $lab.ResourceGroupName
}

$jobCount = $jobs.Count
Write-Output "Waiting for $jobCount Lab deletion jobs to complete"
foreach ($job in $jobs){
    $jobOutput = Receive-Job $job -Wait
    Write-Output $jobOutput
}
Remove-Job -Job $jobs