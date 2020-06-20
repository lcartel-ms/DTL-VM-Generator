param
(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group")]
    [string] $ResourceGroupName,

    [parameter(Mandatory=$false, HelpMessage="Public=separate IP Address, Shared=load balancers optimizes IP Addresses, Private=No public IP address.")]
    [string] $LabIpConfig = "Public",

    [ValidateSet("Delete","Leave","Error")]
    [Parameter(Mandatory=$false, HelpMessage="What to do if a VM with the same name exist in the lab (Delete, Leave, Error)")]
    [string] $IfExist = "Leave"
)

$ErrorActionPreference = "Stop"

# Workaround for https://github.com/Azure/azure-powershell/issues/9448
$Mutex = New-Object -TypeName System.Threading.Mutex -ArgumentList $false, "Global\AzDtlLibrary"
$Mutex.WaitOne() | Out-Null
$rg = Get-AzResourceGroup | Out-Null
$Mutex.ReleaseMutex() | Out-Null

. "./Utils.ps1"

Write-Host "Trying to deploy a new Bastion for the Lab $DevTestLabName"

$lab = Get-AzDtlLab -ResourceGroupName $ResourceGroupName -Name $DevTestLabName

# Get the underlying VNets
Write-Host "Retrieving details of the Lab VNet"
$virtualNetworks = $lab | Get-AzDtlLabVirtualNetworks -ExpandedNetwork

# TODO Check if there is already a Subnet named AzureBastionSubnet. If so, fail depending on the strategy $IfExist

# Try to get an address range with lenght >= 27 (smallest supported by Bastion)
Write-Host "Trying to get an unallocated address range of size >= /27"
$bastionAddressSpace = Get-VirtualNetworkUnallocatedSpace -VirtualNetwork $virtualNetworks -Length 27
if (-not $bastionAddressSpace) {
  Write-Host "No unallocated address range to deploy a Bastion subnet of length 27"

  # Logic to halve an existing subnet
  # TODO should we ask permission to the user?
  Write-Host "Trying to halve an existing subnet..."
  $vnetUnassignedSpace = Get-VirtualNetworkUnassignedSpace -VirtualNetwork $virtualNetworks -Length 27
  if (-not $vnetUnassignedSpace) {
    Write-Error "No available address space or subnet to deploy a Bastion host"
    throw "No address space or subnet to deploy a Bastion host. To proceed, please expand the Virtual Network address range."
  }

  $resizingVirtualNetworkSubnet = $vnetUnassignedSpace.VirtualNetworkSubnet
  $assignedAddressSpace = $vnetUnassignedSpace.AssignedSubnetSpace
  $bastionAddressSpace = $vnetUnassignedSpace.UnassignedSubnetSpace

  # Shrink the VirtualNetwork subnet to the assigned range only
  # It does not matter which kind of subnet (e.g. 'UsedInVmCreation','UsedInPublicIpAddress')
  Write-Host "Resizing subnet $($resizingVirtualNetworkSubnet.AddressPrefix) to $assignedAddressSpace"
  $virtualNetworks.Subnets | ForEach-Object {
    if ($_.Id -eq $resizingVirtualNetworkSubnet.Id) {
      $_.AddressPrefix = $assignedAddressSpace
    }
  }
  $virtualNetworks = Set-AzureRmVirtualNetwork -VirtualNetwork $virtualNetworks

  Write-Host "Subnet successfully resized to $assignedAddressSpace"
}

# Resize the address space to the minimum /27, in case we found a larger one at the previous step.
# TODO check limitations of having a /27 Bastion subnet. Is it 1 address per VM?
$bastionAddressSpace = $bastionAddressSpace.Split("/")[0] + "/27"

Write-Host "Found an available address range at $bastionAddressSpace"

# Get the corresponding DTL VNet
$labVirtualNetworks = $lab | Convert-AzDtlVirtualNetwork -VirtualNetworkId $virtualNetworks.Id

# Deploy the Bastion to the specific VNet address range
Write-Host "Deploying the Bastion at $bastionAddressSpace"
$lab | New-AzDtlBastion -LabVirtualNetworkId $labVirtualNetworks.Id -BastionSubnetAddressPrefix $bastionAddressSpace

Write-Host "Azure Bastion successfully deployed"