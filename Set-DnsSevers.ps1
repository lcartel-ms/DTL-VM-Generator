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

Write-Output "Looking for the DNS Servers ..."
$dnsServersHash = @{}
foreach($descr in $VMDescriptors) {
  $vmName = $descr.imageName
  $dnsServer = $descr.dnsServer

  # It is a DNS Server because no dns server has been specified for it
  if(-not $dnsServer) {
    Write-Output "Processing DNS $vmName ..."

    # Find the VM
    $vm = $vms | Where-Object {$_.Name -eq $vmName}
    if(-not $vm) {
      Write-Error "Can't find VM named $vmName in lab $DevTestLabName in RG $ResourceGroupName"
    }

    # DANGER: this is implementation specific. Might change if DTL Changes how it stores compute info.
    $computeGroup = ($vm.Properties.ComputeId -split "/")[4]
    $vmName = ($vm.Properties.ComputeId -split "/")[8]

    # DANGER: it could be implemented more safely by first getting the VM and then get the NIC for the VM, but it's one more network roundtrip ...
    # As it happens, as of today the NIC has the same name as the VM ...
    $nic = Get-AzureRmNetworkInterface -Name $vmName -ResourceGroupName $computeGroup
    if(-not $nic) {
      Write-Error "Can't find the NIC named $vmName in the compute group $computeGroup"
    }
    Write-Output "Found the NIC ..."

    $nic.IpConfigurations | ForEach-Object {$_.PrivateIpAddress} | ForEach-Object {$dnsServersHash.Add($vmName, $_)}
  }
}

if($dnsServersHash.count -eq 0) {
  Write-Error "Found no DNS Servers??"
}
Write-Output $dnsServersHash

Write-Output "Assigning DNS Servers to VMs ..."
foreach($descr in $VMDescriptors) {

  $vmName = $descr.imageName
  $dnsServer = $descr.dnsServer

  Write-Output "Processing $vmName ..."
  # Find the VM
  $vm = $vms | Where-Object {$_.Name -eq $vmName}
  if(-not $vm) {
    Write-Error "Can't find VM named $vmName in lab $DevTestLabName in RG $ResourceGroupName"
  }

  # DANGER: this is implementation specific. Might change if DTL Changes how it stores compute info.
  $computeGroup = ($vm.Properties.ComputeId -split "/")[4]
  $vmName = ($vm.Properties.ComputeId -split "/")[8]

  # DANGER: it could be implemented more safely by first getting the VM and then get the NIC for the VM, but it's one more network roundtrip ...
  # As it happens, as of today the NIC has the same name as the VM ...
  $nic = Get-AzureRmNetworkInterface -Name $vmName -ResourceGroupName $computeGroup
  if(-not $nic) {
    Write-Error "Can't find the NIC named $vmName in the compute group $computeGroup"
  }
  Write-Output "Found the NIC ..."

  if($dnsServer) { # It is not a DNS Server, assign it to the right $dnsServer
    $ip = $dnsServersHash[$dnsServer]
    if(-not $ip) {
      Write-Error "Not found IP for DNS Server $dnsServer."
    }
    $nic.DnsSettings.DnsServers.Add($ip)
    $nic | Set-AzureRmNetworkInterface | Out-Null
    Write-Output "Set DNS for $vmName to $ip"
  } else { # It is a DNS Server, move it to static allocation method
    $nic.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
    Write-Output "Set NIC for $vmName to static allocation because it is a dns server"
  }
}
