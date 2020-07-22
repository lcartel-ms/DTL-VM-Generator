param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [string] $ConfigFile = "config.csv",

    [Parameter(Mandatory=$false, HelpMessage="How many Seconds to wait before starting the next parallel vm deletion")]
    [int] $SecondsToNextVmDeletion =  10,

    [Parameter(HelpMessage="Example: 'ID-*,CSW2-SRV' , a string containing comma delimitated list of patterns. The script will (re)create just the VMs matching one of the patterns. The empty string (default) recreates all labs as well.")]
    [string] $ImagePattern = "",

    [ValidateSet("Note","Name")]
    [Parameter(Mandatory=$true, HelpMessage="Property of the VM to match by (Name, Note)")]
    [string] $MatchBy
)

$ErrorActionPreference = "Stop"

. "./Utils.ps1"

Import-AzDtlModule

"./Remove-Vm.ps1" | Invoke-RSForEachLab -ConfigFile $ConfigFile -SecondsBetweenLoop 2  -SecTimeout (1 * 60 * 60) -ImagePattern $ImagePattern -MatchBy $MatchBy -ModulesToImport $AzDtlModulePath