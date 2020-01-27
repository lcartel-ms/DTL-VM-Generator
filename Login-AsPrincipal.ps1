param
(
    [Parameter(Mandatory=$true, HelpMessage="Subscription to create service principal into")]
    [string] $PrincipalKey,

    [Parameter(Mandatory=$true, HelpMessage="Name of app")]
    [string] $PrincipalAppId,

    [Parameter(Mandatory=$true, HelpMessage="Name of app")]
    [string] $TenantId

)

$secpasswd = ConvertTo-SecureString $PrincipalKey -AsPlainText -Force
$pscreds = New-Object System.Management.Automation.PSCredential ($PrincipalAppId, $secpasswd)

# Log into Azure with the service principal
Login-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $pscreds
