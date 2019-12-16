param
(
    [Parameter(Mandatory=$true, HelpMessage="Subscription to log into")]
    [string] $SubscriptionId
)

Clear-AzureRmContext -Scope CurrentUser -Force
Connect-AzureRmAccount
Set-AzureRmContext -SubscriptionId $SubscriptionId
Enable-AzureRmContextAutosave -Scope CurrentUser