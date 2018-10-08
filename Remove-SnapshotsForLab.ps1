param
(
  [Parameter(Mandatory=$true, HelpMessage="Name of lab to remove snapshots from")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to remove")]
  [string] $ResourceGroupName,

  [Parameter(valueFromRemainingArguments=$true)]
  [String[]]
  $rest = @()
)

$ErrorActionPreference = "Stop"

. "./Utils.ps1"

Write-Host "Removing snapshots for lab $DevTestLabName in $ResourceGroupName"

$snapshots = Get-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs/customImages' -ResourceName $DevTestLabName -ResourceGroupName $ResourceGroupName -ApiVersion '2016-05-15'

if(-not $snapshots) {
  Write-Host "No snapshots to remove in $DevTestLabName"
  exit
}

$jobs = @()

$snapshots | ForEach-Object {
  $jobs += Remove-AzureRmResource -AsJob -ResourceId $_.ResourceId -Force -ApiVersion '2016-05-15'
}

Wait-JobWithProgress -secTimeout (1 * 60 * 60) -jobs $jobs
