param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [string] $ConfigFile = "config.csv",

    [Parameter(Mandatory=$false, HelpMessage="How many Seconds to wait before starting the next parallel vm deletion")]
    [int] $SecondsToNextVmDeletion =  10,

    [Parameter(Mandatory=$false, HelpMessage="Pattern of VM to remove")]
    [string] $Pattern = "Windows - Lab",

    [ValidateSet("Note","Name")]
    [Parameter(Mandatory=$true, HelpMessage="Property of the VM to match by (Name, Note)")]
    [string] $MatchBy
)

$ErrorActionPreference = 'Stop'

. "./Utils.ps1"

$scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path
$executable = Join-Path $scriptFolder "Remove-Vm.ps1"

# Check we're in the right directory
if (-not (Test-Path $executable)) {
  Write-Error "Unable to find $executable...  unable to proceed."
  return
}

$config = Import-Csv $ConfigFile

$jobs = @()

ForEach ($lab in $config) {

  Write-Host "Starting job to delete Vms from lab $($lab.DevTestLabName)"
  $jobs += Start-Job -Name $lab.DevTestLabName -FilePath $executable -ArgumentList $lab.DevTestLabName, $lab.ResourceGroupName, $Pattern, $MatchBy
  Start-Sleep -Seconds $SecondsToNextVmDeletion
}

$jobCount = $jobs.Count
Write-Host "Waiting for $jobCount Lab Vms deletion jobs to complete"
foreach ($job in $jobs){
    $jobOutput = Receive-Job $job -Wait
    Write-Host $jobOutput
}
Remove-Job -Job $jobs