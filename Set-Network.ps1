param
(
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group to create the lab in")]
    [string] $ResourceGroupName,

    [Parameter(Mandatory=$false, HelpMessage="The VM Configuration objects (by default it downloads them)")]
    $VmSettings = ""
)

$ErrorActionPreference = 'Stop'

. "./Utils.ps1"

if(-not $VmSettings) {
  $VmSettings = & "./Import-VmSetting" -StorageAccountName $StorageAccountName -StorageContainerName $StorageContainerName -StorageAccountKey $StorageAccountKey
}

if(-not $VmSettings) {
  throw "VmSettings can't be null or empty"
}

$scriptFolder = $PWD

Write-Host "Starting DNS setting ..."

if(-not $scriptFolder) {
  throw "Script folder is null"
}

# Get all VMs in lab expanding properties to get to compute VM
$vms = Get-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -ResourceGroupName $ResourceGroupName -ExpandProperties -Name "$DevTestLabName/"

# Needs to run first through all the vms to get the private ip for the dns servers
$nicsHash = @{}

$VmSettings | ForEach-Object {
  $vmName = $_.imageName
  $dnsServer = $_.dnsServer

  # Find the VM
  $vm = $vms | Where-Object {$_.Name -eq $vmName}
  if(-not $vm) {
    throw "Can't find VM named $vmName in lab $DevTestLabName in RG $ResourceGroupName"
  }

  # DANGER: this is implementation specific. Might change if DTL Changes how it stores compute info.
  $computeVm = Get-AzureRmResource -ResourceId $vm.Properties.computeId
  $computeGroup = $computeVm.ResourceGroupName

  $nic = Get-AzureRmNetworkInterface -Name $vmName -ResourceGroupName $computeGroup
  if(-not $nic) {
    throw "Can't find the NIC named $vmName in the compute group $computeGroup"
  }
  Write-Host "Found the NIC for $vmName ..."

  $ip = $nic.IpConfigurations | ForEach-Object {$_.PrivateIpAddress}

  $nicsHash.add($vmName, @{'nic' = $nic; 'dnsServer' = $dnsServer;'ip' = $ip})
} | Out-Null

if($nicsHash.count -eq 0) {
  throw "Found no NICS??"
}

# Act on each NIC depending if it's a dns server or not
$nicsHash.Keys | ForEach-Object {
  $value = $nicsHash[$_]
  $isDns = -not $value.dnsServer
  $nic = $value.nic

  if($isDns) {
    $nic.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
    Write-Host "$_`t-> static allocation"
  } else {
    $dnsName = $value.dnsServer
    $thisServer = $nicsHash[$dnsName]
    if(-not $thisServer) {
      throw "The DNS server '$dnsName' is not in the lab, hence cannot be set as DNS server for '$_'"
    }
    $dnsIp = $thisServer.ip
    $nic.DnsSettings.DnsServers.Add($dnsIp)
    $nic | Set-AzureRmNetworkInterface | Out-Null
    Write-Host "$_`t-> $dnsName`t$dnsIp"
  }
} | Out-Null

Write-Output "Network setted correctly for $DevTestLabName"