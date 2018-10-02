param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [string] $ConfigFile = "config.csv",

    [Parameter(Mandatory=$false, HelpMessage="How many minutes to wait before starting the next parallel lab deletion")]
    [int] $MinutesToNextLabDeletion =  2

)


$scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
$executable = Join-Path $scriptFolder "Remove-SnapshotsForLab.ps1"

# Check we're in the right directory
if (-not (Test-Path $executable)) {
  Write-Error "Unable to find $executable ...  unable to proceed."
  return
}

$config = Import-Csv $ConfigFile

$jobs = @()

ForEach ($lab in $config) {
  Write-Host "Starting job to delete snapshot for lab $($lab.DevTestLabName)"
  $jobs += Start-Job -Name $lab.DevTestLabName -FilePath $executable -ArgumentList $lab.DevTestLabName, $lab.ResourceGroupName
  Start-Sleep -Seconds 30
}

$jobCount = $jobs.Count
Write-Host "Waiting for $jobCount snapshots deletion jobs to complete"
foreach ($job in $jobs){
    $jobOutput = Receive-Job $job -Wait
    Write-Host $jobOutput
}
Remove-Job -Job $jobs