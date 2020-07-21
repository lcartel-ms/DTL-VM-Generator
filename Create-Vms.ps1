param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigFile = "config.csv",

    [Parameter(Mandatory=$false, HelpMessage="How many minutes to wait before starting the next parallel lab creation")]
    [int] $SecondsBetweenLoop =  10,

    [Parameter(HelpMessage="String containing comma delimitated list of patterns. The script will (re)create just the VMs matching one of the patterns. The empty string (default) recreates all labs as well.")]
    [string] $ImagePattern = "",

    [ValidateSet("Delete","Leave","Error")]
    [Parameter(Mandatory=$true, HelpMessage="What to do if a VM with the same name exist in the lab (Delete, Leave, Error)")]
    [string] $IfExist,

    [Parameter(Mandatory=$false, HelpMessage="Once the VMs are created, apply Windows Updates?")]
    [bool] $ApplyWindowsUpdates = $false
)

$ErrorActionPreference = "Stop"

# Common setup for scripts
. "./Utils.ps1"                                          # Import all our utilities
Import-AzDtlModule                                       # Import the DTL Library

Write-Host "---------------------------------" -ForegroundColor Green
Write-Host "Creating VMs..." -ForegroundColor Green

"./Create-Vm.ps1" | Invoke-RSForEachLab -ConfigFile $ConfigFile -SecondsBetweenLoop $SecondsBetweenLoop -CustomRole $null -ImagePattern $ImagePattern -IfExist $IfExist -ModulesToImport $AzDtlModulePath

if ($ApplyWindowsUpdates) {
    ./Apply-WindowsUpdateArtifactToVMs.ps1 -ConfigFile $ConfigFile -ImagePattern $ImagePattern -shutdownVMs $true
}

Write-Host "Completed creating VMs!" -ForegroundColor Green

Remove-AzDtlModule                                       # Remove the DTL Library
