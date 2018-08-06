param
(

)

# Clear the errors up front-  helps when running the script multiple times
$error.Clear()

$v = Get-AzureRmResource -Name TestVM -ResourceGroupName Cyber -ResourceType "Microsoft.DevTestLab/labs"
if ($v) {
  Write-Output "Exists"
} else {
  Write-Output "It doesn't exist"
}