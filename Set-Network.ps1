param
(
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group to create the lab in")]
    [string] $ResourceGroupName,

    [Parameter(Mandatory=$false, HelpMessage="The VMs we're adjusting the network settings")]
    $VMsToConfigure = "",

    [Parameter(Mandatory=$false, HelpMessage="The VM Configuration objects (by default it downloads them)")]
    $VmSettings = "",

    [parameter(Mandatory=$false, HelpMessage="Public=separate IP Address, Shared=load balancers optimizes IP Addresses, Private=No public IP address.")]
    [string] $LabIpConfig = "Public"

)

$ErrorActionPreference = 'Stop'

. "./Utils.ps1"

if(-not $VmSettings) {
  $VmSettings = & "./Import-VmSetting" -StorageAccountName $StorageAccountName -StorageContainerName $StorageContainerName -StorageAccountKey $StorageAccountKey
}

if(-not $VmSettings) {
  throw "VmSettings can't be null or empty"
}

if (-not $VMsToConfigure) {
  # If $VMsToConfigure is empty, we assume we're updating all VMs
  $VMsToConfigure = $VmSettings
}

$VMsToConfigureNames = $VMsToConfigure | Select -ExpandProperty imagename

$scriptFolder = $PWD

Write-Host "Starting DNS setting ..."

if(-not $scriptFolder) {
  throw "Script folder is null"
}

# Get all VMs in lab expanding properties to get to compute VM
$vms = Get-AzResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -ResourceGroupName $ResourceGroupName -ExpandProperties -Name "$DevTestLabName/"

# Needs to run first through all the vms to get the private ip for the dns servers
$nicsHash = @{}
# Also track, for the Shared config, the VM size & largest IP
$nicsHashBySize = @{}

$VmSettings | ForEach-Object {
  $vmName = $_.imageName
  $dnsServer = $_.dnsServer

  # Find the VM
  $vm = $vms | Where-Object {$_.Name -eq $vmName}

  # We only proceed if we've found the VM
  if($vm) {
      # DANGER: this is implementation specific. Might change if DTL Changes how it stores compute info.
      $computeVm = Get-AzResource -ResourceId $vm.Properties.computeId
      $computeGroup = $computeVm.ResourceGroupName

      $nic = Get-AzNetworkInterface -Name $vmName -ResourceGroupName $computeGroup
      if(-not $nic) {
        throw "Can't find the NIC named $vmName in the compute group $computeGroup"
      }
      Write-Host "Found the NIC for $vmName ..."

      # Clear any existing DNS settings, in case this is the 2nd+ time through this script
      # since we reset them all anyway, for all the VMs in the lab
      if (($nic.DnsSettings.DnsServers | Measure-Object).Count -gt 0) {
        $nic.DnsSettings.DnsServers.Clear()
      }

      $ip = $nic.IpConfigurations | ForEach-Object {$_.PrivateIpAddress}

      # Add the network details for all the VMs into the list
      $nicsHash.add($vmName, @{'nic' = $nic; 'dnsServer' = $dnsServer;'ip' = $ip})

      # Handle Shared IPs based on VM Size since that's how DTL groups them into availability sets
      if ($LabIpConfig -eq "Shared") {
          if ($nicsHashBySize.Keys | Where-Object {$vm.Properties.size -eq $_}) {
            $nicsHashBySize[$vm.Properties.size].Add(@{'nic' = $nic; 'dnsServer' = $dnsServer;'ip' = $ip})
          }
          else {
            $list = New-Object System.Collections.ArrayList
            $list.Add(@{'nic' = $nic; 'dnsServer' = $dnsServer;'ip' = $ip})
            $nicsHashBySize.Add($vm.Properties.size, $list)
          }
      }
  }

} | Out-Null

if(($nicsHash | Measure-Object).count -eq 0) {
  throw "Found no NICS??"
}

# Act on each NIC depending if it's a dns server or not
$nicsHash.Keys | Where-Object {$VMsToConfigureNames -contains $_} | ForEach-Object {
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
    
    Write-Host "$_`t-> $dnsName`t$dnsIp"
  }

  if ($LabIpConfig -ne "Shared") {
      # Add the general DNS server to enable windows update - 168.63.129.16
      $nic.DnsSettings.DnsServers.Add("168.63.129.16")
  }

  $nic | Set-AzNetworkInterface | Out-Null

} | Out-Null

# At the end, if we are using Shared IPs we need to find
# Each VM with the highest private IP address within each group
# of sizes and add the DNS server for Windows Update only once
if ($LabIpConfig -eq "Shared") {
    foreach ($groupName in $nicsHashBySize.Keys) {
      
      Write-Host "Adding 168.63.129.16 to availability set: $groupName"

      # Get the net card with the highest IP
      $nic = ($nicsHashBySize[$groupName] | Sort-Object -Property @{Expression={[int] ($_.ip.Split('.') | Select -Last 1)}; Descending=$true} | Select -First 1).nic

      # Add the general DNS server to enable windows update - 168.63.129.16
      $nic.DnsSettings.DnsServers.Add("168.63.129.16")

      $nic | Set-AzNetworkInterface | Out-Null

    }
}

Write-Output "Network setted correctly for $DevTestLabName"