param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigFile = "configTest.csv"
)

$ErrorActionPreference = "Stop"

# Common setup for scripts
. "./Utils.ps1"                                          # Import all our utilities
$labConfig = Import-ConfigFile -ConfigFile $ConfigFile   # Import all the lab settings from the config file
$configCount = ($labConfig | Measure-Object).Count

$labDeleteSB = {
param($labConfig)

    if ($labConfig.BastionEnabled) {
        Write-Output "Removing Bastion hosts from the lab '$($labConfig.DevTestLabName)' in Resource group '$($labConfig.ResourceGroupName)'"
        $labConfig | Get-AzDtlLab | Remove-AzDtlBastion
        Write-Output "Completed removing Bastion host"
    }

    Write-Output "Removing lab '$($labConfig.DevTestLabName)' in Resource group '$($labConfig.ResourceGroupName)' ..."
    $labConfig | Get-AzDtlLab | Remove-AzDtlLab
    Write-Output "Completed removing lab '$($labConfig.DevTestLabName)' in Resource group '$($labConfig.ResourceGroupName)'"

}

Write-Host "---------------------------------" -ForegroundColor Green
Write-Host "Removing $configCount labs..." -ForegroundColor Green

$labDeleteJobs = @()
$labConfig | ForEach-Object {
    $labDeleteJobs += Start-RSJob -Name "$($_.DevTestLabName)-JobId$(Get-Random)" -ScriptBlock $labDeleteSB -ArgumentList $_ -ModulesToImport $AzDtlModulePath
}

# We wait additional hour for every 10 jobs, starting at 4 hours
$timeout = 4 + [int] ($configCount / 10)
Wait-RSJobWithProgress -secTimeout ($timeout*60*60) -jobs $labDeleteJobs

Write-Host "Completed removing $configCount labs!" -ForegroundColor Green
