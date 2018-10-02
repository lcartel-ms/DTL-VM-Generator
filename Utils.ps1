
# This is included at the top of each script
# You would be tempted to include generic useful actions here
# i.e. setting ErrorPreference or checking that you are in the right folder
# but those won't be executed if you are executing the script from the wrong folder
# Instead setting $ActionPreference = "Stop" at the start of each script
# and the script won't start if it executed from wrong folder as it can't import this file.

Set-StrictMode -Version Latest

function Set-LabAccessControl {
  param(
    $DevTestLabName,
    $ResourceGroupName,
    $customRole,
    [string[]] $ownAr,
    [string[]] $userAr
  )
  Write-Host "Setting access control in lab $DevTestLabName in RG $ResourceGroupName for custom role $customRole to $userAr and owners to $ownAr"

  foreach ($owneremail in $ownAr) {
    New-AzureRmRoleAssignment -SignInName $owneremail -RoleDefinitionName 'Owner' -ResourceGroupName $ResourceGroupName -ResourceName $DevTestLabName -ResourceType 'Microsoft.DevTestLab/labs' | Out-Null
    Write-Host "$owneremail added as Owner"
  }

  foreach ($useremail in $userAr) {
    New-AzureRmRoleAssignment -SignInName $useremail -RoleDefinitionName $customRole -ResourceGroupName $ResourceGroupName -ResourceName $DevTestLabName -ResourceType 'Microsoft.DevTestLab/labs' | Out-Null
    Write-Host "$useremail added as $customRole"
  }
}
function Invoke-ForEachLab {
  param
  (
    [parameter(ValueFromPipeline)]
    [string] $script,
    [string] $ConfigFile = "config.csv",
    [int] $SecondsBetweenLoops =  10,
    [string] $customRole
  )

  $config = Import-Csv $ConfigFile

  $jobs = @()

  $config | ForEach-Object {
    $lab = $_
    Write-Host "Starting operating on $($lab.DevTestLabName) ..."

    # We are getting a string from the csv file, so we need to split it
    if($lab.LabOwners) {
        $ownAr = $lab.LabOwners.Split(",").Trim()
    } else {
        $ownAr = @($lab.LabOwners)
    }
    if($lab.LabUsers) {
        $userAr = $lab.LabUsers.Split(",").Trim()
    } else {
        $userAr = @($lab.LabUsers)
    }

    # It is necessary to go through a string to 'embed' the path there, otherwise the init script gets evaluated in a different scope. Couldn't get $using to work, which would be more correct.
    $initScript = [scriptblock]::create("Set-Location $PSScriptRoot")
    $jobs += Start-Job -Name $lab.DevTestLabName -InitializationScript $initScript -FilePath $script -ArgumentList $lab.DevTestLabName, $lab.ResourceGroupName, $lab.StorageAccountName, $lab.StorageContainerName, $lab.StorageAccountKey, $lab.ShutDownTime, $lab.TimezoneId, $lab.LabRegion, $ownAr, $userAr, $customRole
    Start-Sleep -Seconds $SecondsBetweenLoop
  }

  Write-Host "Waiting for results at most 5 hours..."
  $jobs | Wait-Job -Timeout (5 * 60 * 60) | ForEach-Object {
    $_ | Receive-Job -ErrorAction SilentlyContinue
    if($_.State -eq 'Failed') {
      Write-Host "$($_.Name) Failed!" -ForegroundColor Red -BackgroundColor Black
      # TODO: need to find a way to get correct stack trace
      Write-Error ($_.ChildJobs[0].JobStateInfo.Reason.Message) -ErrorAction Continue
    } else {
      Write-Host "$($_.Name) Succeded!"
    }
  }
  $jobs | Remove-Job
}