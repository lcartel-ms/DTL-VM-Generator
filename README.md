# Scripts to Automatically create Labs and Virtual Machines 
We are working on v2 of the scripts for automatically generating DevTest Labs in Azure and populating those labs automatically with virtual machines.

# Description of Scripts
There are a few different PowerShell scripts to run for the overall solution
* **Import-VHDsToSharedImageGallery.ps1** : This script will import VHDs an JSON files into a Shared Image Gallery
* **New-EmptyLabs.ps1**:  This script will create the labs as a first step before populating the Virtual Machines.  It's based on the metadata in the Shared Image Gallery that was imported with the previous script.
* **Create-VMs.ps1**:  Create all the virtual machines in the labs, metadata is stored in Shared Image Gallery
* **Remove-VMs.ps1**:  Remove all the virtual machines in the labs once we're done with them
* **Remove-Labs.ps1**:  Remove all the labs once they are no longer needed

