param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [string] $ConfigFile = "config.csv",

    [Parameter(Mandatory=$false, HelpMessage="Custom Role to use")]
    [string] $CustomRole = "No VM Creation User"

)

$ErrorActionPreference = "Stop"

. "./Utils.ps1"

$config = Import-Csv $ConfigFile


ForEach ($lab in $config) {

    $LabOwners = $lab.LabOwners
    $LabUsers = $lab.LabUsers

    # Split if multiple emails
    if($LabOwners) {
        $ownAr = $LabOwners.Split(",").Trim()
    } else {
        $ownAr = @()
    }
    if($LabUsers) {
        $userAr = $LabUsers.Split(",").Trim()
    } else {
        $userAr = @()
    }

    Set-LabAccessControl -DevTestLabName $lab.DevTestLabName -ResourceGroupName $lab.ResourceGroupName -customRole $customRole -ownAr $ownAr -userAr $userAr -ErrorAction Continue
    Write-Host "Access control set for $DevTestLabName"
}
Write-Output "Access control set correctly"