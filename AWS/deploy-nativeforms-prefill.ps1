param(
  [string]$FunctionName = "NativeForms-PrefillForm",
  [string]$Region = "eu-north-1",
  [string]$Profile = "nativeforms-codex"
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$sourceFile = Join-Path $workspaceRoot "AWS\NativeForms-PrefillForm.mjs"
$tempRoot = Join-Path $workspaceRoot ".codex_tmp\NativeFormsPrefillDeploy"
$zipPath = Join-Path $workspaceRoot ".codex_tmp\NativeFormsPrefill.zip"

if (Test-Path $tempRoot) {
  Remove-Item -Recurse -Force $tempRoot
}

New-Item -ItemType Directory -Path $tempRoot | Out-Null
Copy-Item $sourceFile (Join-Path $tempRoot "index.mjs")
Copy-Item (Join-Path $workspaceRoot "package.json") (Join-Path $tempRoot "package.json")

$nodeModulesPath = Join-Path $workspaceRoot "node_modules"
if (!(Test-Path $nodeModulesPath)) {
  throw "node_modules was not found. Run npm install before deploying NativeForms-PrefillForm."
}
Copy-Item $nodeModulesPath (Join-Path $tempRoot "node_modules") -Recurse

if (Test-Path $zipPath) {
  Remove-Item -Force $zipPath
}

Compress-Archive -Path (Join-Path $tempRoot "*") -DestinationPath $zipPath -Force

aws lambda update-function-code `
  --function-name $FunctionName `
  --zip-file ("fileb://" + $zipPath) `
  --region $Region `
  --profile $Profile

aws lambda wait function-updated `
  --function-name $FunctionName `
  --region $Region `
  --profile $Profile

Write-Host "Lambda code updated for $FunctionName."
