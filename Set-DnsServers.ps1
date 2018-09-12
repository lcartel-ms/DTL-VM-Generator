param
(
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group to create the lab in")]
    [string] $ResourceGroupName
)

# Clear the errors up front-  helps when running the script multiple times
$error.Clear()

Write-Output "Starting DNS setting ..."

$ErrorActionPreference = 'Continue'

$scriptFolder = Split-Path $Script:MyInvocation.MyCommand.Path

# Check we're in the right directory by checking the existence of the settings file
if (-not (Test-Path (Join-Path $scriptFolder "foo.xml"))) {
  Write-Error "Unable to find the New-Vm.ps1 template...  unable to proceed."
  return
}

# Import settings
$VMDescriptors = Import-Clixml -Path .\foo.xml

if(-not ($VMDescriptors.count -gt 0)) {
  Write-Error "VMDescriptors can't be null or empty"
}

# Get all VMs in lab expanding properties to get to compute VM
$vms = Get-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -ResourceGroupName $ResourceGroupName -ExpandProperties -Name "$DevTestLabName/"

# Needs to run first through all the vms to get the private ip for the dns servers
$nicsHash = @{}

$VMDescriptors | ForEach-Object {
  $vmName = $_.imageName
  $dnsServer = $_.dnsServer

  # Find the VM
  $vm = $vms | Where-Object {$_.Name -eq $vmName}
  if(-not $vm) {
    Write-Error "Can't find VM named $vmName in lab $DevTestLabName in RG $ResourceGroupName"
  }

  # DANGER: this is implementation specific. Might change if DTL Changes how it stores compute info.
  $computeVm = Get-AzureRmResource -ResourceId $vm.Properties.computeId
  $computeGroup = $computeVm.ResourceGroupName
  $name = $computeVm.Name

  $nic = Get-AzureRmNetworkInterface -Name $vmName -ResourceGroupName $computeGroup
  if(-not $nic) {
    Write-Error "Can't find the NIC named $vmName in the compute group $computeGroup"
  }
  Write-Output "Found the NIC for $vmName ..."

  $ip = $nic.IpConfigurations | ForEach-Object {$_.PrivateIpAddress}

  $nicsHash.add($vmName, @{'nic' = $nic; 'dnsServer' = $dnsServer;'ip' = $ip})
}

if($nicsHash.count -eq 0) {
  Write-Error "Found no NICS??"
}

# Act on each NIC depending if it's a dns server or not
$nicsHash.Keys | ForEach-Object {
  $value = $nicsHash[$_]
  $isDns = -not $value.dnsServer
  $nic = $value.nic

  if($isDns) {
    $nic.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
    Write-Output "$_`t-> static allocation"
  } else {
    $dnsName = $value.dnsServer
    $dnsIp = $nicsHash[$dnsName].ip
    $nic.DnsSettings.DnsServers.Add($dnsIp)
    $nic | Set-AzureRmNetworkInterface | Out-Null
    Write-Output "$_`t-> $dnsName`t$dnsIp"
  }
}