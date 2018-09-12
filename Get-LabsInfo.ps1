param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [string] $ConfigFile = "config.csv"
)

# Clear the errors up front-  helps when running the script multiple times
$error.Clear()

$scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
$executable = Join-Path $scriptFolder "Get-LabInfo.ps1"

# Check we're in the right directory
if (-not (Test-Path $executable)) {
  Write-Error "Unable to find Get-LabInfo.ps1...  unable to proceed."
  return
}

function SaveProfile {
  $profilePath = Join-Path $PSScriptRoot "profile.json"

  If (Test-Path $profilePath){
    Remove-Item $profilePath
  }
  Save-AzureRmContext -Path $profilePath -Force

  return $profilePath
}

$profilePath = SaveProfile

$config = Import-Csv $ConfigFile

$jobs = @()

ForEach ($lab in $config) {
  $jobs += Start-Job -Name $lab.DevTestLabName -FilePath $executable -ArgumentList $profilePath, $lab.DevTestLabName, $lab.ResourceGroupName
}

$jobCount = $jobs.Count
Write-Output "Waiting for $jobCount threads to retrieve lab infos. Might take some time ..."
Write-Output ""
Write-Output "LAB NAME : RUNNING VMS"
Write-Output "-------------------------------"
foreach ($job in $jobs){
    $jobOutput = Receive-Job $job -Wait
    Write-Output $jobOutput
}
Remove-Job -Job $jobs
Write-Output ""