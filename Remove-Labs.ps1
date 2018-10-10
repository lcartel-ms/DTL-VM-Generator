param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigFile = "configTest.csv"
)

$ErrorActionPreference = "Stop"

. "./Utils.ps1"

"./Remove-Lab.ps1" | Invoke-RSForEachLab -ConfigFile $ConfigFile -SecondsBetweenLoop 2 -SecTimeout (1 * 60 * 60)

