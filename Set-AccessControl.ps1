param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [string] $ConfigFile = "config.csv"
)

$ErrorActionPreference = 'Continue'

$error.Clear()

$config = Import-Csv $ConfigFile

$customRole = "No VM Creation User"

ForEach ($lab in $config) {
    $LabOwners = $lab.LabOwners
    $LabUsers = $lab.LabUsers

    # Split if multiple emails
    if($LabOwners) {
        $ownAr = $LabOwners.Split(",").Trim()
    } else {
        $ownAr = $LabOwners
    }
    if($LabUsers) {
        $userAr = $LabUsers.Split(",").Trim()
    } else {
        $userAr = $LabUsers
    }

    Write-Output $lab.DevTestLabName
    foreach ($owneremail in $ownAr) {
      Write-Output "$owneremail"
      New-AzureRmRoleAssignment -SignInName $owneremail -RoleDefinitionName 'Owner' -ResourceGroupName $lab.ResourceGroupName -ResourceName $lab.DevTestLabName -ResourceType 'Microsoft.DevTestLab/labs'
    }

    foreach ($useremail in $userAr) {
      Write-Output "$useremail"
      New-AzureRmRoleAssignment -SignInName $useremail -RoleDefinitionName $customRole -ResourceGroupName $lab.ResourceGroupName -ResourceName $lab.DevTestLabName -ResourceType 'Microsoft.DevTestLab/labs'
    }

}