param
(
  [Parameter(Mandatory=$true, HelpMessage="Name of lab to remove")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to remove")]
  [string] $ResourceGroupName,

  [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
  [string] $NoteText = "Windows - Lab"
)

Write-Output "Removing Vms from lab $DevTestLabName in $ResourceGroupName"
$vms = Get-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -ResourceGroupName $ResourceGroupName -ExpandProperties -Name "$DevTestLabName/"

$jobs = @()

$vms | ForEach-Object {
  if($_.Properties.notes -eq $NoteText) {
    Write-Output "Deleting $($_.Name)"
    $jobs += Remove-AzureRmResource -AsJob -ResourceId $_.ResourceId -Force
    Start-Sleep -Seconds 2
  }
}

$jobCount = $jobs.Count
Write-Output "Waiting for $jobCount Lab Vms deletion jobs to complete in $DevTestLabName"
foreach ($job in $jobs){
    $jobOutput = Receive-Job $job -Wait
    Write-Output $jobOutput
}
Remove-Job -Job $jobs