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

    [parameter(Mandatory=$false, HelpMessage="Whether or not the bastion support is enabled in the config - we skip if we get false here")]
    [bool] $LabBastionEnabled = $false,

    [ValidateSet("Delete","Leave","Error")]
    [Parameter(Mandatory=$false, HelpMessage="What to do if a VM with the same name exist in the lab (Delete, Leave, Error)")]
    [string] $IfExist = "Leave",

    [Parameter(valueFromRemainingArguments=$true)]
    [String[]]
    $rest = @()
)

if ($LabBastionEnabled) {
    $ErrorActionPreference = "Stop"

    # Common setup for scripts
    . "./Utils.ps1"                                          # Import all our utilities
    Import-AzDtlModule   

    #TODO WRITE-VERBOSE 

    Write-Host "Deploying a new Bastion for the Lab $DevTestLabName..."

    $lab = Get-AzDtlLab -ResourceGroupName $ResourceGroupName -Name $DevTestLabName

    # Get the underlying VNets
    Write-Verbose "Retrieving details of the Lab VNet"
    $virtualNetworks = $lab | Get-AzDtlLabVirtualNetworks -ExpandedNetwork

    # Check if there is already a Bastion for this Lab. If so, proceed depending on the $IfExist strategy
    $existingBastion = $Lab | Get-AzDtlBastion -ErrorAction SilentlyContinue
    if ($existingBastion) {
      if($IfExist -eq "Delete") {
        $Lab | Remove-AzDtlBastion | Out-Null
      }
      elseif ($IfExist -eq "Error") {
        throw "Found Bastion $($existingBastion.Name) in $DevTestLabName. Error because passed the 'Error' parameter"
      }
      elseif ($IfExist -eq "Leave") {
        # NOP
      }
    }

    # Try to get an address range with lenght >= 27 (smallest supported by Bastion)
    Write-Verbose "Trying to get an unallocated address range of size >= /27"
    $bastionAddressSpace = Get-VirtualNetworkUnallocatedSpace -VirtualNetwork $virtualNetworks -Length 27
    if (-not $bastionAddressSpace) {
      Write-Verbose "No unallocated address range to deploy a Bastion subnet of length 27"

      # Logic to halve an existing subnet
      Write-Verbose "Trying to halve an existing subnet..."
      $vnetUnassignedSpace = Get-VirtualNetworkUnassignedSpace -VirtualNetwork $virtualNetworks -Length 27
      if (-not $vnetUnassignedSpace) {
        Write-Warning "No available address space or subnet to deploy a Bastion host"
        throw "No address space or subnet to deploy a Bastion host. To proceed, please expand the Virtual Network address range."
      }
  
      $resizingVirtualNetworkSubnet = $vnetUnassignedSpace.VirtualNetworkSubnet
      $assignedAddressSpace = $vnetUnassignedSpace.AssignedSubnetSpace
      $unassignedAddressSpace = $vnetUnassignedSpace.UnassignedSubnetSpace

      # Shrink the VirtualNetwork subnet to the assigned range only
      # This is supported only
      # It does not matter which kind of subnet (e.g. 'UsedInVmCreation','UsedInPublicIpAddress')
      Write-Verbose "Resizing subnet $($resizingVirtualNetworkSubnet.AddressPrefix) to $assignedAddressSpace"
      $virtualNetworks.Subnets | ForEach-Object {
        if ($_.Id -eq $resizingVirtualNetworkSubnet.Id) {
          $_.AddressPrefix = $assignedAddressSpace
        }
      }
      try {
        $virtualNetworks = Set-AzureRmVirtualNetwork -VirtualNetwork $virtualNetworks
      }
      catch [Microsoft.Azure.Commands.Network.Common.NetworkCloudException] {
        if ($_.Exception.InnerException.Body.Code -eq "InUseSubnetCannotBeUpdated") {

          Write-Warning "Assigned address space: $assignedAddressSpace"
          Write-Warning "Unassigned address space: $unassignedAddressSpace"

          throw "Subnet is in use. You must either move the resources to another subnet, or delete them from the subnet first."
        }
      }

      Write-Verbose "Subnet successfully resized to $assignedAddressSpace"
    }

    # Resize the address space to the minimum /27, in case we found a larger one at the previous step.
    # TODO check limitations of having a /27 Bastion subnet. Is it 1 address per VM?
    $bastionAddressSpace = $bastionAddressSpace.Split("/")[0] + "/27"

    Write-Verbose "Found an available address range at $bastionAddressSpace"

    # Get the corresponding DTL VNet
    $labVirtualNetworks = $lab | Convert-AzDtlVirtualNetwork -VirtualNetworkId $virtualNetworks.Id

    # Deploy the Bastion to the specific VNet address range
    Write-Verbose "Deploying the Bastion at $bastionAddressSpace"
    $bastion = $lab | New-AzDtlBastion -LabVirtualNetworkId $labVirtualNetworks.Id -BastionSubnetAddressPrefix $bastionAddressSpace

    Write-Host "Azure Bastion $($bastion.Name) successfully deployed"
}