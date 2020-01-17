param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigFile = "configTest.csv"
)

$ErrorActionPreference = "Stop"

. "./Utils.ps1"

Import-AzDtlModule

"./Remove-SnapshotsForLab.ps1" | Invoke-RSForEachLab -ConfigFile $ConfigFile -SecondsBetweenLoop 2 -ModulesToImport $AzDtlModulePath