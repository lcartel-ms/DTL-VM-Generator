
# This is included at the top of each script
# You would be tempted to include generic useful actions here
# i.e. setting ErrorPreference or checking that you are in the right folder
# but those won't be executed if you are executing the script from the wrong folder
# Instead setting $ActionPreference = "Stop" at the start of each script
# and the script won't start if it executed from wrong folder as it can't import this file.

Set-StrictMode -Version Latest

# Import a patched up version of this module because the standard release
# doesn't propagate Write-host messages to console
# see https://github.com/proxb/PoshRSJob/pull/158/commits/b64ad9f5fbe6fa85f860311f81ec0d6392d5fc01
if (Get-Module | Where-Object {$_.Name -eq "PoshRSJob"}) {
} else {
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  Import-Module "$PSScriptRoot\PoshRSJob\PoshRSJob.psm1"
}

# DTL Module dependency
$AzDtlModuleName = "Az.DevTestLabs2.psm1"
$AzDtlModuleSource = "https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/DevTestLabs/Modules/Library/Az.DevTestLabs2.psm1"

# To be passed as 'ModulesToImport' param when starting a RSJob
$global:AzDtlModulePath = Join-Path -Path (Resolve-Path ./) -ChildPath $AzDtlModuleName

function Import-RemoteModule {
  param(
    [ValidateNotNullOrEmpty()]
    [string] $Source,
    [ValidateNotNullOrEmpty()]
    [string] $ModuleName
  )

  $modulePath = Join-Path -Path (Resolve-Path ./) -ChildPath $ModuleName

  # WORKAROUND: Use a checked-in version of the library temporarily
  if (Test-Path -Path $modulePath) {
    # if the file exists, delete it - just in case there's a newer version, we always download the latest
    # Remove-Item -Path $modulePath
  }

  # $WebClient = New-Object System.Net.WebClient
  # $WebClient.DownloadFile($Source, $modulePath)

  Import-Module $modulePath -Force
}

function Import-AzDtlModule {
   Import-RemoteModule -Source $AzDtlModuleSource -ModuleName $AzDtlModuleName
}

function Remove-AzDtlModule {
   # WORKAROUND:  Delete the azure context that we saved to disk
   if (Test-Path (Join-Path $env:TEMP "AzContext.json")) {
     Remove-Item (Join-Path $env:TEMP "AzContext.json") -Force
   }

   Remove-Module -Name "Az.DevTesTLabs2" -ErrorAction SilentlyContinue
}

function Set-LabAccessControl {
  param(
    $DevTestLabName,
    $ResourceGroupName,
    $customRole,
    [string[]] $ownAr,
    [string[]] $userAr
  )

  foreach ($owneremail in $ownAr) {
    New-AzRoleAssignment -SignInName $owneremail -RoleDefinitionName 'Owner' -ResourceGroupName $ResourceGroupName -ResourceName $DevTestLabName -ResourceType 'Microsoft.DevTestLab/labs' | Out-Null
    Write-Host "$owneremail added as Owner in Lab '$DevTestLabName'"
  }

  foreach ($useremail in $userAr) {
    New-AzRoleAssignment -SignInName $useremail -RoleDefinitionName $customRole -ResourceGroupName $ResourceGroupName -ResourceName $DevTestLabName -ResourceType 'Microsoft.DevTestLab/labs' | Out-Null
    Write-Host "$useremail added as $customRole in Lab '$DevTestLabName'"
  }
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
      throw "No source images selected by the image pattern chosen: $ImagePattern"
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
    $existingVms = Get-AzResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -Name "*$DevTestLabName*" | Where-Object { $_.Name -eq "$DevTestLabName/$vmName"}

    if($existingVms) {
      Write-Host "Found an existing VM $vmName in $DevTestLabName"
      if($IfExist -eq "Delete") {
        Write-Host "Deleting VM $vmName in $DevTestLabName"
        $vmToDelete = $existingVms[0]
        Remove-AzResource -ResourceId $vmToDelete.ResourceId -Force | Out-Null
        $newSettings += $_
      } elseif ($IfExist -eq "Leave") {
        Write-Host "Leaving VM $vmName  in $DevTestLabName be, not moving forward ..."
      } elseif ($IfExist -eq "Error") {
        throw "Found VM $vmName in $DevTestLabName. Error because passed the 'Error' parameter"
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

function Wait-JobWithProgress {
  param(
    [ValidateNotNullOrEmpty()]
    $jobs,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    $secTimeout
    )

  Write-Host "Waiting for results at most $secTimeout seconds, or $( [math]::Round($secTimeout / 60,1)) minutes, or $( [math]::Round($secTimeout / 60 / 60,1)) hours ..."

  if(-not $jobs) {
    Write-Host "No jobs to wait for"
    return
  }

  # Control how often we show output and print out time passed info
  # Change here to make it go faster or slower
  $RetryIntervalSec = 7
  $MaxPrintInterval = 7
  $PrintInterval = 1

  $timer = [Diagnostics.Stopwatch]::StartNew()

  $runningJobs = $jobs | Where-Object { $_ -and ($_.State -eq "Running") }
  while(($runningJobs) -and ($timer.Elapsed.TotalSeconds -lt $secTimeout)) {

    $output = $runningJobs | Receive-Job -Keep -ErrorAction Continue
    # Only output something if we have something to show
    if ($output -and $output.ToString().Trim()) {
      $output | Out-String | Write-Host
    }

    $runningJobs | Wait-Job -Timeout $RetryIntervalSec

    if($PrintInterval -ge $MaxPrintInterval) {
      $totalSecs = [math]::Round($timer.Elapsed.TotalSeconds,0)
      Write-Host "Passed: $totalSecs seconds, or $( [math]::Round($totalSecs / 60,1)) minutes, or $( [math]::Round($totalSecs / 60 / 60,1)) hours ..." -ForegroundColor Yellow
      $PrintInterval = 1
    } else {
      $PrintInterval += 1
    }

    $runningJobs = $jobs | Where-Object { $_ -and ($_.State -eq "Running") }
  }

  $timer.Stop()
  $lasted = $timer.Elapsed.TotalSeconds

  Write-Host ""
  Write-Host "JOBS STATUS"
  Write-Host "-------------------"
  $jobs | Format-Table                            # Show overall status of all jobs
  Write-Host ""
  Write-Host "JOBS OUTPUT"
  Write-Host "-------------------"
  
  $output = $jobs | Receive-Job -ErrorAction Continue

  # If the output has resource types, format it like a table, otherwise just write it out
  if ($output -and (Get-Member -InputObject $output[0] -Name ResourceType -MemberType Properties)) {
    $output | Select-Object Name, `
                            ResourceGroupName, `
                            ResourceType, `
                            @{Name="ProvisioningState";Expression={$_.Properties.provisioningState}}`
            | Out-String | Write-Host
  }
  else {
    $output | Out-String | Write-Host
  }

  $jobs | Remove-job -Force                       # -Force removes also the ones still running ...

  if ($lasted -gt $secTimeout) {
    throw "Jobs did not complete before timeout period. It lasted $lasted secs."
  } else {
    Write-Host "Jobs completed before timeout period. It lasted $lasted secs."
  }
}

function Import-ConfigFile {
  param
  (
    [parameter(ValueFromPipeline)]
    [string] $ConfigFile = "config.csv"
  )

  $config = Import-Csv $ConfigFile

  $config | ForEach-Object {
    $lab = $_

    # Also add "Name" since that's used by the DTL Library for DevTestLabName
    Add-Member -InputObject $lab -MemberType NoteProperty -Name "Name" -Value $lab.DevTestLabName

    # We are getting a string from the csv file, so we need to split it
    if($lab.LabOwners) {
        $lab.LabOwners = $lab.LabOwners.Split(",").Trim()
    } else {
        $lab.LabOwners = @()
    }
    if($lab.LabUsers) {
        $lab.LabUsers = $lab.LabUsers.Split(",").Trim()
    } else {
        $lab.LabUsers = @()
    }

    $lab
  }
}
function Show-JobProgress {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory,ValueFromPipeline)]
      [ValidateNotNullOrEmpty()]
      [System.Management.Automation.Job[]]
      $Job
  )

  Process {
      $Job.ChildJobs | ForEach-Object {
          if (-not $_.Progress) {
              return
          }

          $_.Progress |Select-Object -Last 1 | ForEach-Object {
              $ProgressParams = @{}
              if ($_.Activity          -and $null -ne $_.Activity) { $ProgressParams.Add('Activity',         $_.Activity) }
              if ($_.StatusDescription -and $null -ne $_.StatusDescription) { $ProgressParams.Add('Status',           $_.StatusDescription) }
              if ($_.CurrentOperation  -and $null -ne $_.CurrentOperation) { $ProgressParams.Add('CurrentOperation', $_.CurrentOperation) }
              if ($_.ActivityId        -and $_.ActivityId        -gt -1)    { $ProgressParams.Add('Id',               $_.ActivityId) }
              if ($_.ParentActivityId  -and $_.ParentActivityId  -gt -1)    { $ProgressParams.Add('ParentId',         $_.ParentActivityId) }
              if ($_.PercentComplete   -and $_.PercentComplete   -gt -1)    { $ProgressParams.Add('PercentComplete',  $_.PercentComplete) }
              if ($_.SecondsRemaining  -and $_.SecondsRemaining  -gt -1)    { $ProgressParams.Add('SecondsRemaining', $_.SecondsRemaining) }

              Write-Progress @ProgressParams
          }
      }
  }
}

function Wait-RSJobWithProgress {
  param(
    [ValidateNotNullOrEmpty()]
    $jobs,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    $secTimeout
    )

  Write-Host "Waiting for results at most $secTimeout seconds, or $( [math]::Round($secTimeout / 60,1)) minutes, or $( [math]::Round($secTimeout / 60 / 60,1)) hours ..."

  if(-not $jobs) {
    Write-Host "No jobs to wait for"
    return
  }

  $timer = [Diagnostics.Stopwatch]::StartNew()

  $jobs | Wait-RSJob -ShowProgress -Timeout $secTimeout | Out-Null

  $timer.Stop()
  $lasted = $timer.Elapsed.TotalSeconds

  Write-Host ""
  Write-Host "JOBS STATUS"
  Write-Host "-------------------"
  $jobs | Format-Table | Out-Host

  $allJobs = $jobs | Select-Object -ExpandProperty 'Name'
  $failedJobs = $jobs | Where-Object {$_.State -eq 'Failed'} | Select-Object -ExpandProperty 'Name'
  $runningJobs = $jobs | Where-Object {$_.State -eq 'Running'} | Select-Object -ExpandProperty 'Name'
  $completedJobs = $jobs | Where-Object {$_.State -eq 'Completed'} | Select-Object -ExpandProperty 'Name'

  Write-Output "OUTPUT for ($allJobs)"
  # These go to output to show errors and correct results
  $jobs | Receive-RSJob -ErrorAction Continue
  $jobs | Remove-RSjob -Force | Out-Null

  $errorString =  ""
  if($failedJobs -or $runningJobs) {
    $errorString += "Failed jobs: $failedJobs, Running jobs: $runningJobs. "
  }

  if ($lasted -gt $secTimeout) {
    $errorString += "Jobs did not complete before timeout period. It lasted for $lasted secs."
  }

  if($errorString) {
    throw "ERROR: $errorString"
  }

  Write-Output "These jobs ($completedJobs) completed before timeout period. They lasted for $lasted secs."
}

function Invoke-RSForEachLab {
  param
  (
    [parameter(ValueFromPipeline)]
    [string] $script,
    [string] $ConfigFile = "config.csv",
    [int] $SecondsBetweenLoops =  10,
    [string] $customRole = "No VM Creation User",
    [string] $ImagePattern = "",
    [string] $IfExist = "Leave",
    [int] $SecTimeout = 5 * 60 * 60,
    [string] $MatchBy = "",
    [string[]] $ModulesToImport
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
      IfExist='$($IfExist)';
      MatchBy='$($MatchBy)'
    }"

    $sb = [scriptblock]::create(
    @"
    `Set-Location `$Using:PWD
    `$params=$params
    .{$(get-content $script -Raw)} @params
"@)

    $jobs += Start-RSJob -Name $lab.DevTestLabName -ScriptBlock $sb -ModulesToImport $ModulesToImport
    Start-Sleep -Seconds $SecondsBetweenLoops
  }

  Wait-RSJobWithProgress -secTimeout $secTimeout -jobs $jobs
}