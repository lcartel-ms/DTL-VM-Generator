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

# Workaround for https://github.com/Azure/azure-powershell/issues/9448
$Mutex = New-Object -TypeName System.Threading.Mutex -ArgumentList $false, "Global\AzDtlLibrary"
$Mutex.WaitOne() | Out-Null
$rg = Get-AzResourceGroup | Out-Null
$Mutex.ReleaseMutex() | Out-Null

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

$existingLab = Get-AzDtlLab -Name $DevTestLabName -ResourceGroupName $ResourceGroupName

if (-not $existingLab) {
    throw "'$DevTestLabName' Doesn't exist"
}

Write-Host "Removing Vms from lab $DevTestLabName in $ResourceGroupName"
$vms = Get-AzDtlVm -Lab $existingLab

$selectedVms = Select-Vms $vms

$jobs = @()
$selectedVms | ForEach-Object {

  $sb = {
    # Workaround for https://github.com/Azure/azure-powershell/issues/9448
    $Mutex = New-Object -TypeName System.Threading.Mutex -ArgumentList $false, "Global\AzDtlLibrary"
    $Mutex.WaitOne() | Out-Null
    $rg = Get-AzResourceGroup | Out-Null
    $Mutex.ReleaseMutex() | Out-Null

    Remove-AzDtlVm -Vm $_
  }
  $jobs += Start-RSJob -ScriptBlock $sb -Name $_.Name -ModulesToImport $AzDtlModulePath

  Start-Sleep -Seconds 2
}

Wait-RSJobWithProgress -secTimeout (2 * 60 * 60) -jobs $jobs
