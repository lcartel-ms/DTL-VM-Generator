param
(
  [Parameter(Mandatory=$true, HelpMessage="Name of lab to remove snapshots from")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to remove")]
  [string] $ResourceGroupName
)

Write-Output "Removing snapshots for lab $DevTestLabName in $ResourceGroupName"

$snapshots = Get-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs/customImages' -ResourceName $DevTestLabName -ResourceGroupName $ResourceGroupName -ApiVersion '2016-05-15'

if(-not $snapshots) {
  Write-Error "No snapshots to remove in $DevTestLabName"
  exit
}

$jobs = @()

$snapshots | ForEach-Object {
  $jobs += Remove-AzureRmResource -AsJob -ResourceId $_.ResourceId -Force -ApiVersion '2016-05-15'
}

$jobCount = $jobs.Count
Write-Output "Waiting for $jobCount snapshots deletion jobs to complete for $DevTestLabName"
foreach ($job in $jobs){
    $jobOutput = Receive-Job $job -Wait
    Write-Output $jobOutput
}
Remove-Job -Job $jobs
