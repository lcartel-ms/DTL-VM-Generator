param
(

  [Parameter(Mandatory=$true, HelpMessage="Name of lab to query")]
  [string] $DevTestLabName,

  [Parameter(Mandatory=$true, HelpMessage="RG of lab to query")]
  [string] $ResourceGroupName,

  [Parameter(valueFromRemainingArguments=$true)]
  [String[]]
  $rest = @()
)

$ErrorActionPreference = "Stop"
# Workaround for https://github.com/Azure/azure-powershell/issues/9448
$Mutex = New-Object -TypeName System.Threading.Mutex -ArgumentList $false, "Global\DTL-VM-GENERATOR"
$Mutex.WaitOne() | Out-Null
$rg = Get-AzResourceGroup | Out-Null
$Mutex.ReleaseMutex() | Out-Null

$existingLab = Get-AzDtlLab -Name $DevTestLabName  -ResourceGroupName $ResourceGroupName

if (-not $existingLab) {
    throw "'$DevTestLabName' Doesn't exist"
}

$vms = Get-AzDtlVm -Lab $existingLab

if(-not $vms) {
  throw "No VMs in $DevTestLabName"
}

$runningVms = Get-AzDtlVm -Lab $existingLab -Status "Running" | Select-Object -ExpandProperty Name

if($runningVms) {
  $runString = $runningVms -join " "
} else {
  $runString = 'None'
}

Write-Output "RUNNING VMS FOR LAB $DevTestLabName : $runString"
