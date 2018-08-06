param
(
    [Parameter(Mandatory=$true, HelpMessage="Subscription to log into")]
    [string] $SubscriptionId
)

Connect-AzureRmAccount
Set-AzureRmContext -SubscriptionId $SubscriptionId