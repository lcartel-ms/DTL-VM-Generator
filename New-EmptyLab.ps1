param
(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group")]
    [string] $ResourceGroupName,

    [ValidateNotNullOrEmpty()]
    [Parameter(HelpMessage="The Region for the DevTest Lab")]
    [string] $ShutDownTime = "1900",

    [ValidateNotNullOrEmpty()]
    [Parameter(HelpMessage="The Region for the DevTest Lab")]
    [string] $TimeZoneId = "W. Europe Standard Time",

    [ValidateNotNullOrEmpty()]
    [Parameter(HelpMessage="The Region for the DevTest Lab")]
    [string] $LabRegion = "westeurope",

    [Parameter(HelpMessage="The list of users (emails) that we need to add as lab owners")]
    [string[]] $LabOwners = @(),

    [Parameter(HelpMessage="The list of users (emails) that we need to add as lab users")]
    [string[]] $LabUsers = @(),

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$false, HelpMessage="Custom Role to add users to")]
    [string] $CustomRole =  "No VM Creation User",

    [Parameter(valueFromRemainingArguments=$true)]
    [String[]]
    $rest = @()
)

$ErrorActionPreference = "Stop"

. "./Utils.ps1"

if ($DevTestLabName.Length -gt 50) {
    throw "'$DevTestLabName' is too long, must be 50 characters or less"
}

if ($DevTestLabName.Length -gt 40) {
    $deploymentName = "Create_new_lab_" + $DevTestLabName.Substring(0, 40)
}
else {
    $deploymentName = "Create_new_lab_" + $DevTestLabName
}

$existingLab = Get-AzureRmResource -Name $DevTestLabName  -ResourceGroupName $ResourceGroupName

if ($existingLab -ne $null) {
    throw "'$DevTestLabName' Lab already exists, can't create this one!  Unable to proceed."
}
else {
    Write-Host "Creating lab '$DevTestLabName'"

    # The SilentlyContinue bit is to suppress the error that otherwise this generates.
    $existingRg = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $LabRegion -ErrorAction SilentlyContinue

    if(-not $existingRg) {
      Write-Host "Creating Resource Group '$ResourceGroupName' ..."
      New-AzureRmResourceGroup -Name $ResourceGroupName -Location $LabRegion | Out-Null
    }

    Write-Host "Starting deployment of lab ..."
    New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName -TemplateFile (Join-Path $pwd.Path "New-DevTestLab.json") -devTestLabName $DevTestLabName -region $LabRegion -shutdowntime $ShutDownTime -timezoneid $TimeZoneId | out-null

    # You can easily run out of deployments. The drawback is that it doesn't remember failures, but doesn't seem to be needed to access logs.
    Write-Host "Deleting deployments ..."
    Remove-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $deploymentName  -ErrorAction SilentlyContinue | Out-Null

    Set-LabAccessControl $DevTestLabName $ResourceGroupName $CustomRole $LabOwners $LabUsers

    Write-Host "Completed Creating the '$DevTestLabName' lab"
}

