param
(
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group")]
    [string] $ResourceGroupName,

    [Parameter(HelpMessage="The Region for the DevTest Lab")]
    [string] $ShutDownTime = "1900",

    [Parameter(HelpMessage="The Region for the DevTest Lab")]
    [string] $TimeZoneId = "W. Europe Standard Time",

    [Parameter(HelpMessage="The Region for the DevTest Lab")]
    [string] $LabRegion = "westeurope",

    [Parameter(HelpMessage="The list of users (emails) that we need to add as lab owners")]
    [string[]] $LabOwners = @(),

    [Parameter(HelpMessage="The list of users (emails) that we need to add as lab users")]
    [string[]] $LabUsers = @()

)

# Clear the errors up front-  helps when running the script multiple times
$error.Clear()

if ($DevTestLabName.Length -gt 50) {
    Write-Output "DevTest Lab name is too long, must be 50 characters or less"
    return
}

if ($DevTestLabName.Length -gt 40) {
    # if the name is longer than 40 characters, let's truncate it for the deployment name so we don't run out of characters
    $deploymentName = "Create_new_lab_" + $DevTestLabName.Substring(0, 40)
}
else {
    $deploymentName = "Create_new_lab_" + $DevTestLabName
}

# Check we're in the right directory
if (-not (Test-Path (Join-Path $PSScriptRoot "New-DevTestLab.json"))) {
    Write-Error "Unable to find the New-DevTestLab.json template...  unable to proceed."
    return
}

# lets only proceed if we don't have any errors...
if ($error.Count -eq 0) {

    # Lets check to see if the DevTest Lab name exists, if so - we should bail, don't want to mess it up
    $existingLab = Get-AzureRmResource -Name $DevTestLabName  -ResourceGroupName $ResourceGroupName

    if ($existingLab -ne $null) {
        Write-Error "'$DevTestLabName' Lab already exists, can't create this one!  Unable to proceed."
    }
    else {
        Write-Output "Creating lab '$DevTestLabName'"

        $rg = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $LabRegion -ErrorVariable $notPresent -ErrorAction SilentlyContinue

        # Create resource group if it doesn't exist
        if($notPresent) {
          $rg = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $LabRegion
        }

        # Create the DevTest Lab
        $newLab = New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName -TemplateFile (Join-Path $PSScriptRoot "New-DevTestLab.json") -devTestLabName $DevTestLabName -region $LabRegion -shutdowntime $ShutDownTime -timezoneid $TimeZoneId

        # Add all the lab owners to the lab
        foreach ($owneremail in $LabOwners) {
            # see if we can find the user in AAD - must be the display name, NOT the email
            $userPrinciple = Get-AzureRmADUser -Mail $owneremail

            if ($userPrinciple -eq $null) {
                Write-Output "unable to find '$owner' in Azure Active Directory, cannot add them as an owner automatically to this new lab '$DevTestLabName' "
            }
            else {
                # Found the user, but might have a list
                if ($userPrinciple.Count -gt 0) {
                    $spid = $userPrinciple[0].Id
                }
                else {
                    $spid = $userPrinciple.Id
                }

                New-AzureRmRoleAssignment -ObjectId $spid -RoleDefinitionName 'Owner' -ResourceGroupName $ResourceGroupName -ResourceName $DevTestLabName -ResourceType 'Microsoft.DevTestLab/labs' | Out-Null
                Write-Output "Added '$owneremail' as Lab Owner to this new lab '$DevTestLabName'"
            }
        }


        # Add all the lab users to the lab
        foreach ($useremail in $LabUsers) {
            $userPrinciple = Get-AzureRmADUser -Mail $useremail

            if ($userPrinciple.Count -eq $null) {
                Write-Output "unable to find '$user' in Azure Active Directory, cannot add them as a DevTest Lab User automatically to this new lab '$DevTestLabName' , in this sector '$Sector'"
            }
            else {
                # Found the user, but might have a list
                if ($userPrinciple.Count -gt 0) {
                    $spid = $userPrinciple[0].Id
                }
                else {
                    $spid = $userPrinciple.Id
                }

                New-AzureRmRoleAssignment -ObjectId $spid -RoleDefinitionName 'DevTest Labs User' -ResourceGroupName $ResourceGroupName -ResourceName $DevTestLabName -ResourceType 'Microsoft.DevTestLab/labs' | Out-Null
                Write-Output "Added '$useremail' as DevTest Lab user to this new lab '$DevTestLabName'"
            }
        }

        Write-Output "Completed Creating the '$DevTestLabName' lab"
    }
}

