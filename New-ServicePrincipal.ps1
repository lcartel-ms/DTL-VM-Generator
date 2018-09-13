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

Write-Output "--------------------------------------------------"
Write-Output "Service Principle Information"
Write-Output "Connection Name: $ApplicationDisplayName"
Write-Output "Subscription Id: $($sub.Id)"
Write-Output "Subscription Name: $($sub.Name)"
Write-Output "Service Principle Client Id: $($ServicePrincipal.ApplicationId)"
Write-Output "Service Principle Key: $ServicePrincipalPasswordPlainText"
Write-Output "Tenant Id: $($sub.TenantId)"
Write-Output "Object Id: $($ServicePrincipal.Id)"
Write-Output "--------------------------------------------------"

Start-Sleep -Seconds 30

New-AzureRmRoleAssignment -ObjectId $ServicePrincipal.Id -Scope "/subscriptions/$($sub.Id)" -RoleDefinitionName "Contributor"

