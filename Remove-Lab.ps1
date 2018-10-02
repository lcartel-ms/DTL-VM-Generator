param
(
  [Parameter(Mandatory=$true, HelpMessage="Name of lab to remove")]
  [string] $DtlLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to remove")]
  [string] $ResourceGroupName
)

Write-Host "Removing lab $DtlLabName in $ResourceGroupName"
Remove-AzureRmResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.DevTestLab/labs" -ResourceName $DtlLabName -Force