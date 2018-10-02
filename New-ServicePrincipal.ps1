param
(
    [Parameter(Mandatory=$true, HelpMessage="Subscription to create service principal into")]
    [string] $SubscriptionId,
    [Parameter(Mandatory=$true, HelpMessage="Name of app")]
    [string] $ApplicationDisplayName

)
Import-Module AzureRM.Resources

# Generate password lifted from this location: https://blogs.technet.microsoft.com/heyscriptingguy/2015/11/05/generate-random-letters-with-powershell/
Function Get-NewPassword() {
    Param(
        [int]$length=60
    )

    return (-join ((48..57) + (65..90) + (97..122) | Get-Random -Count $length | % {[char]$_}))
}

$sub = Get-AzureRmSubscription -SubscriptionId $SubscriptionId

$ServicePrincipalPasswordPlainText = Get-NewPassword
$ServicePrincipalPassword = ConvertTo-SecureString -String $ServicePrincipalPasswordPlainText -AsPlainText -Force

# Create the service principal!
$ServicePrincipal = New-AzureRMADServicePrincipal -DisplayName $ApplicationDisplayName -Password $ServicePrincipalPassword

Write-Host "--------------------------------------------------"
Write-Host "Service Principle Information"
Write-Host "Connection Name: $ApplicationDisplayName"
Write-Host "Subscription Id: $($sub.Id)"
Write-Host "Subscription Name: $($sub.Name)"
Write-Host "Service Principle Client Id: $($ServicePrincipal.ApplicationId)"
Write-Host "Service Principle Key: $ServicePrincipalPasswordPlainText"
Write-Host "Tenant Id: $($sub.TenantId)"
Write-Host "Object Id: $($ServicePrincipal.Id)"
Write-Host "--------------------------------------------------"

Start-Sleep -Seconds 30

New-AzureRmRoleAssignment -ObjectId $ServicePrincipal.Id -Scope "/subscriptions/$($sub.Id)" -RoleDefinitionName "Contributor"

