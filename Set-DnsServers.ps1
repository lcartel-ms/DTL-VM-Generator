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

# Cache DNSs and NICs
$dnsServersHash = @{}
$nonDnsHash = @{}
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
  $computeGroup = ($vm.Properties.ComputeId -split "/")[4]
  $vmName = ($vm.Properties.ComputeId -split "/")[8]

  # DANGER: it could be implemented more safely by first getting the VM and then get the NIC for the VM, but it's one more network roundtrip ...
  # As it happens, as of today the NIC has the same name as the VM ...
  $nic = Get-AzureRmNetworkInterface -Name $vmName -ResourceGroupName $computeGroup
  if(-not $nic) {
    Write-Error "Can't find the NIC named $vmName in the compute group $computeGroup"
  }
  Write-Output "Found the NIC for $vmName ..."

  $ip = $nic.IpConfigurations | ForEach-Object {$_.PrivateIpAddress}
  if(-not $dnsServer) {
    $dnsServersHash.Add($vmName, $ip)
  } else {
    $nonDnsHash.Add($vmName, $dnsServer)
  }
  $nicsHash.add($vmName, $nic)
}

Write-Output "DNS:"
if($dnsServersHash.count -eq 0) {
  Write-Error "Found no DNS Servers??"
}
Write-Output $dnsServersHash

if($nicsHash.count -eq 0) {
  Write-Error "Found no NICS??"
}
Write-Output "Number of NICS: $($nicsHash.Count)"

# Act on each NIC depending if it's a dns server or not
$nicsHash.Keys | ForEach-Object {
  # If it is in the DNS hash, then it is a dns
  $isDns = $dnsServersHash[$_]
  $nic = $nicsHash[$_]
  if($isDns) {
    $nic.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
    Write-Output "Set NIC for $_ to static allocation because it is a dns server"
  } else {
    $dnsName = $nonDnsHash[$_]
    $dnsIp = $dnsServersHash[$dnsName]
    $nic.DnsSettings.DnsServers.Add($dnsIp)
    $nic | Set-AzureRmNetworkInterface | Out-Null
    Write-Output "Set DNS for $_ to $dnsName ($dnsIp)"
  }
}