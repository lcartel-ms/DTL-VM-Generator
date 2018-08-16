param
(
    [Parameter(Mandatory=$false, HelpMessage="How many command ago to time (default 1 for last command")]
    [int] $howLongAgo = 1

)
$cmd = (Get-History)[-$howLongAgo]
Write-Output $cmd.CommandLine
$cmd.EndExecutionTime - $cmd.StartExecutionTime