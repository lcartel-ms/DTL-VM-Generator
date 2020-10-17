param
(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the new DevTest Lab")]
    [string] $DevTestLabName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The Name of the resource group")]
    [string] $ResourceGroupName,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true, HelpMessage="The storage key for the storage account where custom images are stored")]
    [bool] $LabBastionEnabled,

    [Parameter(valueFromRemainingArguments=$true)]
    [String[]]
    $rest = @()
)

$ErrorActionPreference = "Stop"

# Common setup for scripts
. "./Utils.ps1"                                          # Import all our utilities
Import-AzDtlModule                                       # Import the DTL Library

Write-Host "Starting to remove lab '$DevTestLabName'..." -ForegroundColor Green
$lab = Get-AzDtlLab -Name $DevTestLabName -ResourceGroupName $ResourceGroupName

if ($lab) {

    if ($LabBastionEnabled) {
        Write-Host "Removing Bastion host from the lab '$DevTestLabName' ..."
        $result = $lab | Remove-AzDtlBastion   
        Write-Host "Completed removing Bastion hosts from '$DevTestLabName'"
    }

    Write-Host "Removing the lab '$DevTestLabName' in RG '$ResourceGroupName' .. "
    $result = $lab | Remove-AzDtlLab

    Write-Host "Completed removing lab '$DevTestLabName' .." -ForegroundColor Green

}
else {
    Write-Host "Cannot find lab '$DevTestLabName' in RG '$ResourceGroupName', cannot remove.." -ForegroundColor Yellow
}
