param
(
    [Parameter(Mandatory=$true, HelpMessage="Subscription to log into")]
    [string] $SubscriptionId
)

Clear-AzContext -Scope CurrentUser -Force
Add-AzAccount
Select-AzSubscription -Subscription $SubscriptionId
Enable-AzContextAutosave -Scope CurrentUser
