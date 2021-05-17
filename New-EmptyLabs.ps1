param
(
    [Parameter(Mandatory=$false, HelpMessage="Configuration File, see example in directory")]
    [ValidateNotNullOrEmpty()]
    [string] $ConfigFile = "config.csv",
    
    [Parameter(Mandatory=$false, HelpMessage="How many seconds to wait before starting the next parallel lab creation")]
    [int] $SecondsBetweenLoop =  60,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$false, HelpMessage="Custom Role to add users to")]
    [string] $CustomRole =  "No VM Creation User"
)

$ErrorActionPreference = "Stop"

# Common setup for scripts
. "./Utils.ps1"                                          # Import all our utilities
$config = Import-ConfigFile -ConfigFile $ConfigFile      # Import all the lab settings from the config file

$config | ForEach-Object {
    
    # Create any/all the resource groups
    # The SilentlyContinue bit is to suppress the error that otherwise this generates.
    $existingRg = Get-AzResourceGroup -Name $_.ResourceGroupName -Location $_.LabRegion -ErrorAction SilentlyContinue

    if(-not $existingRg) {
      Write-Host "Creating Resource Group '$($_.ResourceGroupName)' ..." -ForegroundColor Green
      New-AzResourceGroup -Name $_.ResourceGroupName -Location $_.LabRegion | Out-Null
    }

    # If specified create any/all the resource groups where VMs should be created
    # The SilentlyContinue bit is to suppress the error that otherwise this generates.

    if ($_.VmCreationResourceGroupName) {
        
        $existingVmCreationRg = Get-AzResourceGroup -Name $_.VmCreationResourceGroupName -Location $_.LabRegion -ErrorAction SilentlyContinue

        if(-not $existingVmCreationRg) {
          Write-Host "Creating Resource Group '$($_.ResourceGroupName)' ..." -ForegroundColor Green
          New-AzResourceGroup -Name $_.VmCreationResourceGroupName -Location $_.LabRegion | Out-Null
        }
    }
}
$configCount = ($config | Measure-Object).Count

Write-Host "---------------------------------" -ForegroundColor Green
Write-Host "Creating $configCount labs..." -ForegroundColor Green

$LabCreateSB = {
param($labConfig, $customRole)

    # Make sure we stop for errors
    $ErrorActionPreference = "Stop"

    Write-Output "Creating Lab $($labConfig.DevTestLabName) in Resource group $($labConfig.ResourceGroupName)"
    $lab = $labConfig | New-AzDtlLab -VmCreationSubnetPrefix "10.0.0.0/21" -VmCreationResourceGroupName $labConfig.VmCreationResourceGroupName

    Write-Output "   Updating shutdown policy for lab $($labConfig.DevTestLabName)"
    $lab = $labConfig | Set-AzDtlLabShutdown

    Write-Output "   Connecting Shared Image Gallery to lab $($labConfig.DevTestLabName)"
    $SharedImageGallery = Get-AzGallery -Name $labConfig.SharedImageGalleryName
    if (-not $SharedImageGallery) {
        Throw "Unable to update lab '$($labConfig.DevTestLabName)', '$($labConfig.SharedImageGalleryName)' shared image gallery does not exist."
    }
    $sharedImageGallery = $labConfig | Get-AzDtlLab | Set-AzDtlLabSharedImageGallery -Name $labConfig.SharedImageGalleryName -ResourceId $SharedImageGallery.Id

    Write-Output "   Updating IP policy to $($labConfig.IpConfig) for lab $($labConfig.DevTestLabName)"
    $result = Set-AzDtlLabIpPolicy -Lab $labConfig -IpConfig $labConfig.IpConfig

    #Write-Output "   Adding owners & users for lab $($labConfig.DevTestLabName)"
    #$result = Set-LabAccessControl $labConfig.DevTestLabName $labConfig.ResourceGroupName $CustomRole $labConfig.LabOwners $labConfig.LabUsers

    Write-Output "Completed creating lab $($labConfig.DevTestLabName) in Resource group $($labConfig.ResourceGroupName)"
}

$labCreateJobs = @()
$config | ForEach-Object {
    # $labCreateJobs += Start-RSJob -Name "$($_.DevTestLabName)-JobId$(Get-Random)" -ScriptBlock $LabCreateSB -ArgumentList $_, $CustomRole -ModulesToImport $AzDtlModulePath -FunctionFilesToImport (Resolve-Path ".\Utils.ps1").Path
    $labCreateJobs += Start-RSJob -Name "$($_.DevTestLabName)-JobId$(Get-Random)" -ScriptBlock $LabCreateSB -ArgumentList $_, $CustomRole -ModulesToImport $AzDtlModulePath
    Start-Sleep -Seconds $SecondsBetweenLoop
}

# We wait additional hour for every 10 jobs, starting at 4 hours
$timeout = 4 + [int] ($configCount / 10)
Wait-RSJobWithProgress -secTimeout ($timeout*60*60) -jobs $labCreateJobs

$configBastion = [Array] ($config | Where-Object { $_.BastionEnabled })
if (($configBastion | Measure-Object).Count -gt 0) {
    # Deploy the Azure Bastion hosts to the labs
    Write-Host "---------------------------------" -ForegroundColor Green
    Write-Host "Deploying $(($configBastion | Measure-Object).Count) Bastion hosts to the labs..." -ForegroundColor Green
    # Currently use Leave strategy for existing Bastions
    "./Deploy-Bastion.ps1" | Invoke-RSForEachLab -ConfigFile $ConfigFile -SecondsBetweenLoop $SecondsBetweenLoop -SecTimeout (8 * 60 * 60) -CustomRole $null -ModulesToImport $AzDtlModulePath
}

Write-Host "Completed creating labs!" -ForegroundColor Green
