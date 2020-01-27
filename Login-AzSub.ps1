param
(
    [Parameter(Mandatory=$true, HelpMessage="Subscription to log into")]
    [string] $SubscriptionId
)

Clear-AzContext -Scope CurrentUser -Force
Connect-AzAccount
Set-AzContext -SubscriptionId $SubscriptionId
Enable-AzContextAutosave -Scope CurrentUser