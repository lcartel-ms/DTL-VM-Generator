# Create DevTest Labs from a storage of custom images

The main script takes as input a csv file for creating multiple DevTest Labs from an Azure Blob storage containing VHDs. The script creates the labs, add the VHDs as custom images and creates one claimable VM for each custom image.

Additionally you can set owners and users for such labs together with additional data like shutdown time, region and such.

The script is [New-CustomLabs.ps1](./New-CustomLabs.ps1) and a demo csv file is [here](demoConfig.csv).

The repo also contains scripts which might have value on their own to build slightly different solutions and are, therefore, lightly described below. Refer to the code for full description of arguments.

(.\New-CustomLab.ps1) 



