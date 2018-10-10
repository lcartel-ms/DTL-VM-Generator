param
(
  [Parameter(Mandatory=$true, HelpMessage="Name of lab to remove")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to remove")]
  [string] $ResourceGroupName,

  [Parameter(Mandatory=$false, HelpMessage="ImagePattern of VM to remove")]
  [string] $ImagePattern = "Windows - Lab",

  [ValidateSet("Note","Name")]
  [Parameter(Mandatory=$true, HelpMessage="Property of the VM to match by (Name, Note)")]
  [string] $MatchBy,

  [Parameter(valueFromRemainingArguments=$true)]
  [String[]]
  $rest = @()
)

$ErrorActionPreference = "Stop"

. "./Utils.ps1"

function Select-Vms {
  param ($vms)

  if($ImagePattern) {
    $patterns = $ImagePattern.Split(",").Trim()

    # Severely in need of a linq query to do this ...
    $newVms = @()
    foreach($vm in $vms) {
      foreach($cond in $patterns) {
        $toCompare = if($MatchBy -eq "Note") {$vm.Properties.notes} else {$vm.Name}
        if($toCompare -like $cond) {
          $newVms += $vm
          break
        }
      }
    }
    if(-not $newVms) {
      throw "No vm selected by the ImagePattern chosen in $DevTestLabName"
    }

    return $newVms
  }

  return $vms # No ImagePattern passed
}

Write-Host "Removing Vms from lab $DevTestLabName in $ResourceGroupName"
$vms = Get-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -ResourceGroupName $ResourceGroupName -ExpandProperties -Name "$DevTestLabName/"
$selectedVms = Select-Vms $vms

$jobs = @()

foreach($vm in $selectedVms) {

    $Resid = $vm.ResourceId
    Write-Host "Deleting $Resid"

    $sb = [scriptblock]::create(
    @"
    Remove-AzureRmResource -ResourceId $Resid -Force
"@)

    $jobs += Start-RSJob -ScriptBlock $sb -Name $vm.Name


    Start-Sleep -Seconds 2
}

Wait-RSJobWithProgress -secTimeout (2 * 60 * 60) -jobs $jobs
