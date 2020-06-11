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
# Workaround for https://github.com/Azure/azure-powershell/issues/9448
$Mutex = New-Object -TypeName System.Threading.Mutex -ArgumentList $false, "Global\AzDtlLibrary"
$Mutex.WaitOne() | Out-Null
$rg = Get-AzResourceGroup | Out-Null
$Mutex.ReleaseMutex() | Out-Null

. "./Utils.ps1"

Write-Host "Removing snapshots for lab $DevTestLabName in $ResourceGroupName"

$snapshots = Get-AzResource -ResourceType 'Microsoft.DevTestLab/labs/customImages' -ResourceName $DevTestLabName -ResourceGroupName $ResourceGroupName -ApiVersion '2016-05-15'

if(-not $snapshots) {
  return "No snapshots to remove in $DevTestLabName"
}

$jobs = @()

$snapshots | ForEach-Object {
  $sb = {

    # Workaround for https://github.com/Azure/azure-powershell/issues/9448
    $Mutex = New-Object -TypeName System.Threading.Mutex -ArgumentList $false, "Global\AzDtlLibrary"
    $Mutex.WaitOne() | Out-Null
    $rg = Get-AzResourceGroup | Out-Null
    $Mutex.ReleaseMutex() | Out-Null

    Remove-AzResource -ResourceId ($Using:_).ResourceId -Force -ApiVersion '2016-05-15' | Out-Null
  }
  $jobs += Start-RSJob -ScriptBlock $sb -Name $DevTestLabName
}

Wait-RSJobWithProgress -secTimeout (1 * 60 * 60) -jobs $jobs

Write-Output "Snapshot deleted for $DevTestLabName"