param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [string] $ConfigFile = "config.csv",

    [Parameter(Mandatory=$false, HelpMessage="How many Seconds to wait before starting the next parallel vm deletion")]
    [int] $SecondsToNextVmDeletion =  10,

    [Parameter(Mandatory=$false, HelpMessage="Pattern of VM to remove")]
    [string] $Pattern = "Windows - Lab",

    [ValidateSet("Note","Name")]
    [Parameter(Mandatory=$true, HelpMessage="Property of the VM to match by (Name, Note)")]
    [string] $MatchBy
)

$ErrorActionPreference = "Stop"

. "./Utils.ps1"

"./Remove-Vm.ps1" | Invoke-RSForEachLab -ConfigFile $ConfigFile -SecondsBetweenLoop 2  -SecTimeout (1 * 60 * 60) -ImagePattern $Pattern -MatchBy $MatchBy