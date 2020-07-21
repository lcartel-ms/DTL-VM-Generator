# Create DevTest Labs and populate Virtual Machines from a storage of custom images (VHDs)
The main script takes as input a csv file for creating multiple DevTest Labs from an Azure Blob storage containing VHDs and [json descriptors](./ImagesDescr). The script creates the labs, add the VHDs as custom images and creates one claimable VM for each custom image.

Additionally you can set owners and users for such labs together with additional data like shutdown time, region and such. The users added to the lab have no permissions to create new VMs, so that the content of the lab is fixed.

The script creates the labs in paralllel with a new powershell job.

The script runs slowlly on my machines (~2.30hr). It is recommended to execute it from inside an Azure VM to minimize network delays. If the DevTest Labs team implements creating custom images from a storage location without copying them to the lab storage account first, then the script can be made substantially faster.

## The main scripts (in order of logical exectution)
* [New-CustomRole.ps1](./New-CustomRole.ps1) adds a custom role to the subcription which doesn't have permissions to create new VMs.
* [New-EmptyLabs.ps1](./New-EmptyLabs.ps1), reads a csv file (exemple [here](demoConfig.csv)) and creates empty DTL Labs ready to be filled with VMs later on.  NOTE:  To include guest AAD users:  you must have the [AzureAd PowerShell module](https://docs.microsoft.com/en-us/powershell/module/azuread/?view=azureadps-2.0) installed AND run the [Connect-AzureAd](https://docs.microsoft.com/en-us/powershell/module/azuread/connect-azuread?view=azureadps-2.0) commandlet before running this script.
* [Create-VMs.ps1](./Create-Vms.ps1), this is the main way to fill a lab with VMs. You can pass a series of patterns that match image names to create and specify what to do in case there are already existing VMs in the lab with the same name. It performs:
  * Gets the json descriptors for the VMs and select the ones matching the patterns
  * Copy VHDs from blob storage to DTL lab storage
  * Creates Custom Images from the VHDs
  * Creates one VM for each custom image
  * Creates the network topology described in the json descriptors
  * Deletes the custom images from the lab
* [Apply-WindowsUpdateArtifactToVMs](./Apply-WindowsUpdateArtifactToVMs), applys windows updates to the VMs in the labs.  The script will start the VMs (if needed), apply the windows update artifact to each VM and shut the VMs down (if the user specifies)
* [RemoveVms.ps1](./RemoveVms.ps1), removes all VMs in each lab matching certain patterns in the Notes field or Name field


## Ancillary scripts
The repo also contains scripts which might have value on their own to build slightly different solutions. Most of them perform a single operation, instead of a chain of operations (often in parallel). Refer to the code for full description.


## Utility scripts
* [Login-AzSub.ps1](./Login-AzSub.ps1) log into Azure with a specific subId.
* [Get-NAgoCommandTime.ps1](./Get-NAgoCommandTime.ps1) gives the execution time for the command executed N commands ago (default last command)
* [Get-VmStatus.ps1](./Get-VmStatus.ps1) Prints out the status of the VMs for the labs.  Includes the name, state and artifact status
* [Remove-Labs.ps1](./Remove-Labs.ps1) removes all the labs described in the configuration csv file.
* [Remove-Deployments.ps1](./Remove-Deployments.ps1) removes all deployments in a resource group starting N days ago
