$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$sourceFile = Join-Path $workspaceRoot "AWS\NativeFormsBackend.mjs"
$bootstrapV2HmacFile = Join-Path $workspaceRoot "AWS\bootstrap-v2-hmac.mjs"
$bootstrapV2SalesforceFile = Join-Path $workspaceRoot "AWS\bootstrap-v2-salesforce.mjs"
$tempRoot = Join-Path $workspaceRoot ".codex_tmp\NativeFormsBackendDeploy"
$zipPath = Join-Path $workspaceRoot ".codex_tmp\NativeFormsBackend.zip"

if (Test-Path $tempRoot) {
  Remove-Item -Recurse -Force $tempRoot
}

New-Item -ItemType Directory -Path $tempRoot | Out-Null
Copy-Item $sourceFile (Join-Path $tempRoot "index.mjs")
Copy-Item $bootstrapV2HmacFile (Join-Path $tempRoot "bootstrap-v2-hmac.mjs")
Copy-Item $bootstrapV2SalesforceFile (Join-Path $tempRoot "bootstrap-v2-salesforce.mjs")

if (Test-Path $zipPath) {
  Remove-Item -Force $zipPath
}

Compress-Archive -Path (Join-Path $tempRoot "*") -DestinationPath $zipPath -Force

aws lambda update-function-code `
  --function-name NativeFormsBackend `
  --zip-file ("fileb://" + $zipPath) `
  --region eu-north-1 `
  --profile nativeforms-codex

aws lambda wait function-updated `
  --function-name NativeFormsBackend `
  --region eu-north-1 `
  --profile nativeforms-codex

aws lambda update-function-configuration `
  --function-name NativeFormsBackend `
  --timeout 15 `
  --region eu-north-1 `
  --profile nativeforms-codex
