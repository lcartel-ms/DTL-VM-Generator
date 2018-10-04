
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

function Wait-JobWithProgress {
  param(
    [ValidateNotNullOrEmpty()]
    $jobs,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    $secTimeout
    )

  Write-Host "Waiting for results at most $secTimeout seconds, or $( [math]::Round($secTimeout / 60,1)) minutes, or $( [math]::Round($secTimeout / 60 / 60,1)) hours ..."

  $RetryIntervalSec = 5
  $timer = [Diagnostics.Stopwatch]::StartNew()

  $runningJobs = $jobs | Where-Object { $_.State -eq "Running" }
  while(($runningJobs) -and ($timer.Elapsed.TotalSeconds -lt $secTimeout)) {

    $runningJobs | Receive-job -Keep -ErrorAction Continue                # Show partial results
    $runningJobs | Wait-Job -Timeout $RetryIntervalSec | Show-JobProgress # Show progress bar

    $totalSecs = [math]::Round($timer.Elapsed.TotalSeconds,0)
    Write-Host "Passed: $totalSecs seconds, or $( [math]::Round($totalSecs / 60,1)) minutes, or $( [math]::Round($totalSecs / 60 / 60,1)) hours ..." -ForegroundColor Yellow

    $runningJobs = $jobs | Where-Object { $_.State -eq "Running" }
  }
  $timer.Stop()
  Write-Host ""
  Write-Host "JOBS STATUS"
  Write-Host "-------------------"
  $jobs                                           # Show overall status of all jobs
  Write-Host ""
  Write-Host "JOBS OUTPUT"
  Write-Host "-------------------"
  $jobs | Receive-Job -ErrorAction Continue       # Show output for all jobs

  $jobs | Remove-job -Force                       # -Force removes also the ones still running ...

  if ($timer.Elapsed.TotalSeconds -gt $secTimeout) {
    throw 'Jobs did not complete before timeout period.'
  } else {
    Write-Host 'Jobs completed before timeout period'
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
    [string] $IfExist = "Leave",
    [int] $SecTimeout = 5 * 60 * 60
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

    # The scripts that operate over a single lab need to have an uniform number of parameters so that they can be invoked by Invoke-ForeachLab.
    # The argumentList of star-job just allows passing arguments positionally, so it can't be used if the scripts have arguments in different positions.
    # To workaround that, a string gets generated that embed the script as text and passes the parameters by name instead
    # Also, a valueFromRemainingArguments=$true parameter needs to be added to the single lab script
    # So we achieve the goal of reusing the Invoke-Foreach function for everything, while still keeping the single lab scripts clean for the caller
    # The price we pay for the above is the crazy code below, which is likely quite bug prone ...
    $formatOwners = $ownAr | ForEach-Object { "'$_'"}
    $ownStr = $formatOwners -join ","
    $formatUsers = $userAr | ForEach-Object { "'$_'"}
    $userStr = $formatUsers -join ","

    $initScript = [scriptblock]::create("Set-Location ""$PWD""")
    $params = "@{
      DevTestLabName='$($lab.DevTestLabName)';
      ResourceGroupName='$($lab.ResourceGroupName)';
      StorageAccountName='$($lab.StorageAccountName)';
      StorageContainerName='$($lab.StorageContainerName)';
      StorageAccountKey='$($lab.StorageAccountKey)';
      ShutDownTime='$($lab.ShutDownTime)';
      TimezoneId='$($lab.TimezoneId)';
      LabRegion='$($lab.LabRegion)';
      LabOwners= @($ownStr);
      LabUsers= @($userStr);
      CustomRole='$($customRole)';
      ImagePattern='$($ImagePattern)';
      IfExist='$($IfExist)'
    }"

    $sb = [scriptblock]::create(
    @"
    `$params=$params
    .{$(get-content $script -Raw)} @params
"@)

    $jobs += Start-Job -Name $lab.DevTestLabName -InitializationScript $initScript -ScriptBlock $sb
    Start-Sleep -Seconds $SecondsBetweenLoops
  }

  Wait-JobWithProgress -secTimeout $secTimeout -jobs $jobs
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