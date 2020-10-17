param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigFile = "config.csv",

    [Parameter(Mandatory=$false, HelpMessage="How many seconds to wait before starting the next parallel lab creation")]
    [int] $SecondsBetweenLoop =  5

)

$ErrorActionPreference = "Stop"
$startTime = Get-Date

# Common setup for scripts
. "./Utils.ps1"                                          # Import all our utilities
Import-AzDtlModule                                       # Import the DTL Library

"./Remove-Lab.ps1" | Invoke-RSForEachLab -ConfigFile $ConfigFile -SecondsBetweenLoop $SecondsBetweenLoop -SecTimeout (2 * 60 * 60) -CustomRole $null -ModulesToImport $AzDtlModulePath

Remove-AzDtlModule                                       # Remove the DTL Library

$totalScriptDuration = ((Get-Date) - $startTime)
Write-Host ("`nTotal Script Duration was " + [math]::Round($totalScriptDuration.TotalMinutes,2) + " minutes") -ForegroundColor Green
