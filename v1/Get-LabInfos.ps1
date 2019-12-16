param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigFile = "config.csv"
)

$ErrorActionPreference = "Stop"

. "./Utils.ps1"

"./Get-LabInfo.ps1" | Invoke-RSForEachLab -ConfigFile $ConfigFile -SecondsBetweenLoop 2 -SecTimeout (30 * 60)

