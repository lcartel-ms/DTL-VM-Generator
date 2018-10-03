param
(
  [Parameter(Mandatory=$true, HelpMessage="Name of lab to remove")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to remove")]
  [string] $ResourceGroupName,

  [Parameter(Mandatory=$false, HelpMessage="Pattern of VM to remove")]
  [string] $Pattern = "Windows - Lab",

  [ValidateSet("Note","Name")]
  [Parameter(Mandatory=$true, HelpMessage="Property of the VM to match by (Name, Note)")]
  [string] $MatchBy
)

$ErrorActionPreference = 'Stop'

function Select-Vms {
  param ($vms)

  if($Pattern) {
    $patterns = $Pattern.Split(",").Trim()

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
      throw "No vm selected by the pattern chosen"
    }

    return $newVms
  }

  return $vms # No pattern passed
}

Write-Host "Removing Vms from lab $DevTestLabName in $ResourceGroupName"
$vms = Get-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -ResourceGroupName $ResourceGroupName -ExpandProperties -Name "$DevTestLabName/"
$selectedVms = Select-Vms $vms

$jobs = @()

$selectedVms | ForEach-Object {
    $jobs += Remove-AzureRmResource -AsJob -ResourceId $_.ResourceId -Force
    Start-Sleep -Seconds 2
}

$jobCount = $jobs.Count
Write-Host "Waiting for $jobCount Lab Vms deletion jobs to complete in $DevTestLabName"
foreach ($job in $jobs){
    $jobOutput = Receive-Job $job -Wait
    Write-Host $jobOutput
}
Remove-Job -Job $jobs