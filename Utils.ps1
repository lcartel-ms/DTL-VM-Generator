
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

  foreach ($owneremail in $ownAr) {
    New-AzureRmRoleAssignment -SignInName $owneremail -RoleDefinitionName 'Owner' -ResourceGroupName $ResourceGroupName -ResourceName $DevTestLabName -ResourceType 'Microsoft.DevTestLab/labs' | Out-Null
    Write-Host "$owneremail added as Owner"
  }

  foreach ($useremail in $userAr) {
    New-AzureRmRoleAssignment -SignInName $useremail -RoleDefinitionName $customRole -ResourceGroupName $ResourceGroupName -ResourceName $DevTestLabName -ResourceType 'Microsoft.DevTestLab/labs' | Out-Null
    Write-Host "$useremail added as $customRole"
  }
}

function Show-JobProgress {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory,ValueFromPipeline)]
      [ValidateNotNullOrEmpty()]
      [System.Management.Automation.Job[]]
      $Job
      ,
      [Parameter()]
      [ValidateNotNullOrEmpty()]
      [scriptblock]
      $FilterScript
  )

  Process {
      $Job.ChildJobs | ForEach-Object {
          if (-not $_.Progress) {
              return
          }

          $LastProgress = $_.Progress
          if ($FilterScript) {
              $LastProgress = $LastProgress | Where-Object -FilterScript $FilterScript
          }

          $LastProgress | Group-Object -Property Activity,StatusDescription | ForEach-Object {
              $_.Group | Select-Object -Last 1

          } | ForEach-Object {
              $ProgressParams = @{}
              if ($_.Activity          -and $_.Activity          -ne $null) { $ProgressParams.Add('Activity',         $_.Activity) }
              if ($_.StatusDescription -and $_.StatusDescription -ne $null) { $ProgressParams.Add('Status',           $_.StatusDescription) }
              if ($_.CurrentOperation  -and $_.CurrentOperation  -ne $null) { $ProgressParams.Add('CurrentOperation', $_.CurrentOperation) }
              if ($_.ActivityId        -and $_.ActivityId        -gt -1)    { $ProgressParams.Add('Id',               $_.ActivityId) }
              if ($_.ParentActivityId  -and $_.ParentActivityId  -gt -1)    { $ProgressParams.Add('ParentId',         $_.ParentActivityId) }
              if ($_.PercentComplete   -and $_.PercentComplete   -gt -1)    { $ProgressParams.Add('PercentComplete',  $_.PercentComplete) }
              if ($_.SecondsRemaining  -and $_.SecondsRemaining  -gt -1)    { $ProgressParams.Add('SecondsRemaining', $_.SecondsRemaining) }

              Write-Progress @ProgressParams
          }
      }
  }
}

function Invoke-ForEachLab {
  param
  (
    [parameter(ValueFromPipeline)]
    [string] $script,
    [string] $ConfigFile = "config.csv",
    [int] $SecondsBetweenLoops =  10,
    [string] $customRole = "No VM Creation User",
    [string] $ImagePattern = "",
    [string] $IfExist
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
        $ownAr = @()
    }
    if($lab.LabUsers) {
        $userAr = $lab.LabUsers.Split(",").Trim()
    } else {
        $userAr = @()
    }

    # It is necessary to go through a string to 'embed' the path there, otherwise the init script gets evaluated in a different scope. Couldn't get $using to work, which would be more correct.
    $initScript = [scriptblock]::create("Set-Location ""$PWD""")
    $jobs += Start-Job -Name $lab.DevTestLabName -InitializationScript $initScript -FilePath $script -ArgumentList $lab.DevTestLabName, $lab.ResourceGroupName, $lab.StorageAccountName, $lab.StorageContainerName, $lab.StorageAccountKey, $lab.ShutDownTime, $lab.TimezoneId, $lab.LabRegion, $ownAr, $userAr, $customRole, $ImagePattern, $IfExist
    Start-Sleep -Seconds $SecondsBetweenLoop
  }

  Write-Host "Waiting for results at most 5 hours..."

  $runningJobs = $jobs | Where-Object { $_.state -eq "Running" }
  while($runningJobs) {
    $jobs | ForEach-Object {
      $_ | Wait-Job -Timeout 4
      $_ | Show-JobProgress
    }
    $runningJobs = $jobs | Where-Object { $_.state -eq "Running" }
  }

  $jobs | Wait-Job -Timeout (5 * 60 * 60) | ForEach-Object {
    if($_.State -eq 'Failed') {
      Write-Host "$($_.Name) Failed!" -ForegroundColor Red -BackgroundColor Black
      # TODO: need to find a way to get correct stack trace
    } else {
      Write-Host "$($_.Name) Succeded!"
    }
    $_ | Receive-Job -ErrorAction Continue
  }
  $jobs | Remove-Job
}

function Select-VmSettings {
  param (
    $sourceImageInfos,

    [Parameter(HelpMessage="String containing comma delimitated list of patterns. The script will (re)create just the VMs matching one of the patterns. The empty string (default) recreates all labs as well.")]
    [string] $ImagePattern = ""
  )

  if($ImagePattern) {
    $imgAr = $ImagePattern.Split(",").Trim()

    # Severely in need of a linq query to do this ...
    $newSources = @()
    foreach($source in $sourceImageInfos) {
      foreach($cond in $imgAr) {
        if($source.imageName -like $cond) {
          $newSources += $source
          break
        }
      }
    }

    if(-not $newSources) {
      throw "No source images selected by the image pattern chosen"
    }

    return $newSources
  }

  return $sourceImageInfos
}

function ManageExistingVM {
  param($DevTestLabName, $VmSettings, $IfExist)

  $newSettings = @()

  $VmSettings | ForEach-Object {
    $vmName = $_.imageName
    $existingVms = Get-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -Name "*$DevTestLabName*" | Where-Object { $_.Name -eq "$DevTestLabName/$vmName"}

    if($existingVms) {
      Write-Host "Found an existing VM $vmName"
      if($IfExist -eq "Delete") {
        Write-Host "Deleting VM $vmName"
        $vmToDelete = $existingVms[0]
        Remove-AzureRmResource -ResourceId $vmToDelete.ResourceId -Force | Out-Null
        $newSettings += $_
      } elseif ($IfExist -eq "Leave") {
        Write-Host "Leaving VM $vmName be, not moving forward ..."
      } elseif ($IfExist -eq "Error") {
        throw "Found VM $vmName . Error because passed the 'Error' parameter"
      } else {
        throw "Shouldn't get here in New-Vm. Parameter passed is $IfExist"
      }
    } else { # It is not an existing VM, we should continue creating it
      Write-Host "$vmName doesn't exist in $DevTestLabName"
      $newSettings += $_
    }
  }
  return $newSettings
}