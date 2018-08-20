# Create DevTest Labs from a storage of custom images
The main script takes as input a csv file for creating multiple DevTest Labs from an Azure Blob storage containing VHDs and json descriptors. The script creates the labs, add the VHDs as custom images and creates one claimable VM for each custom image.

Additionally you can set owners and users for such labs together with additional data like shutdown time, region and such.

The script creates the labs in paralllel with a new powershell process for each lab in a minimized window for easy tracking. It also automatically generates log files errors and opens them up at the end of execution. 

The script runs slowlly on my machines (~2.30hr). It is recommended to execute it from inside an Azure VM to minimize network delays. If the DevTest Labs team implements creating custom images from a storage location without copying them to the lab storage account first, then the script can be made substantially faster.

The script is [New-CustomLabs.ps1](./New-CustomLabs.ps1), a demo csv file is [here](demoConfig.csv) and sample descriptors are [here](./ImagesDescr).

## Ancillary scripts
The repo also contains scripts which might have value on their own to build slightly different solutions and are, therefore, lightly documented below. Refer to the code for full description of arguments.

* [New-CustomLab.ps1](./New-CustomLab.ps1) creates a lab as above given arguments as in one line of the above csv file
* [New-DevTestLab.ps1](./New-DevTestLab.ps1) creates a generic DevTest Lab given most common parameters
* [New-CustomImagesFromStorage.ps1](./New-CustomImagesFromStorage.ps1) creates a set of custom images in a lab given a link to a blob storage containing vhds and descriptor json files. As side effects it creates a foo.xml file used in the next step of the process.
* [New-Vms.ps1](./New-Vms.ps1) Creates the vms described in a foo.xml file in parallel.

## Utility scripts
* [Login-AzSub.ps1](./Login-AzSub.ps1) log into Azure with a specific subId.
* [Get-NAgoCommandTime.ps1](./Get-NAgoCommandTime.ps1) gives the execution time for the command executed N commands ago (default last command).
* [Remove-Labs.ps1](./Remove-Labs.ps1) removes all the labs described in the configuration csv file.
* [Remove-Lab.ps1](./Remove-Lab.ps1) remove one specific lab.
* [Remove-Deployments.ps1](./Remove-Deployments.ps1) remmove all deployments in a resource group starting N days ago.
