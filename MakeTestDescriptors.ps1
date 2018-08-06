$all = @()
Get-ChildItem .\ImagesDescr\*.json | Foreach-Object {
  $all += Get-Content -Raw -Path $_ | ConvertFrom-Json
}
$all