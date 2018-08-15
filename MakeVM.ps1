param
(
    [Parameter(Mandatory=$true, HelpMessage="The full path of the profile file")]
    [string] $ProfilePath,

    [Parameter(Mandatory=$true, HelpMessage="The full path of the template file")]
    [string] $TemplateFilePath,

    [Parameter(Mandatory=$true, HelpMessage="The name of the lab")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The name of the lab")]
    [string] $ResourceGroupName,

    [Parameter(Mandatory=$true, HelpMessage="The name of the VM to create")]
    [string] $vmName,

    [Parameter(Mandatory=$true, HelpMessage="Size of VM")]
    [string] $vmSize,

    [Parameter(Mandatory=$true, HelpMessage="Storage type")]
    [string] $storageType,

    [Parameter(Mandatory=$true, HelpMessage="Custom image to use")]
    [string] $customImage,

    [Parameter(Mandatory=$true, HelpMessage="Notes on the VM")]
    [string] $notes
)

Import-AzureRmContext -Path $ProfilePath

Write-Output "Starting Deploy for $vmName"

# If the VM already exists then we fail out.
$existingVms = Get-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -Name "*$DevTestLabName*" | Where-Object { $_.Name -eq "$DevTestLabName/$vmName"}
if($existingVms.Count -ne 0){
    Write-Error "VM creation failed because there is an existing VM named $vmName in Lab $DevTestLabName"
    return ""
}
else {
    $deployName = "Deploy-$DevTestLabName-$vmName"

    $vmDeployResult = New-AzureRmResourceGroupDeployment -Name $deployName -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFilePath -labName $DevTestLabName -newVMName $vmName -size $vmSize -storageType $storageType -customImage $customImage -notes $notes

    if(-not ($vmDeployResult.ProvisioningState -eq "Succeeded")) {
        Write-Error "##[error]Deploying VM failed:  $vmName from $TemplateFilePath"
    }
    Remove-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $deployName  -ErrorAction SilentlyContinue | Out-Null

    return $vmName
}