param
(
  [Parameter(Mandatory=$true, HelpMessage="Name of lab to remove")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to remove")]
  [string] $ResourceGroupName,

  [Parameter(valueFromRemainingArguments=$true)]
  [String[]]
  $rest = @()
)

$ErrorActionPreference = "Stop"

Write-Host "Removing lab $DevTestLabName in $ResourceGroupName"
Remove-AzureRmResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.DevTestLab/labs" -ResourceName $DevTestLabName -Force | Out-Null
Write-Output "$DevTestLabName removed."