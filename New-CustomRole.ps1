[CmdletBinding()]
param
(
    [ValidateNotNullOrEmpty()]
    [string] $customRoleName = "No VM Creation User",

    [ValidateNotNullOrEmpty()]
    [string] $ActionFile = ".\NoVMCreationRole.json"
)

$ErrorActionPreference = "Stop"

. "./Utils.ps1"

if(-not (Get-AzRoleDefinition -Name $customRoleName)) {
    $tmp = New-TemporaryFile
    $text = (Get-Content -Path $ActionFile -ReadCount 0) -join "`n"
    $subId = (Get-AzContext).Subscription.Id
    Write-Host "Current subId $subId"
    $text -replace '__subscription__', $subId | Set-Content -Path $tmp.FullName
    # All of the above because someone thought that taking an input file, instead of text, is a good idea
    New-AzRoleDefinition -InputFile $tmp.FullName
    Write-Host "Created $customRoleName from $($tmp.FullName)"
} else {
    Write-Error "Custom Role $customRoleName already present"
}
