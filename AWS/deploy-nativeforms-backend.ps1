$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$sourceFile = Join-Path $workspaceRoot "AWS\NativeFormsBackend.mjs"
$tempRoot = Join-Path $workspaceRoot ".codex_tmp\NativeFormsBackendDeploy"
$zipPath = Join-Path $workspaceRoot ".codex_tmp\NativeFormsBackend.zip"

if (Test-Path $tempRoot) {
  Remove-Item -Recurse -Force $tempRoot
}

New-Item -ItemType Directory -Path $tempRoot | Out-Null
Copy-Item $sourceFile (Join-Path $tempRoot "index.mjs")

if (Test-Path $zipPath) {
  Remove-Item -Force $zipPath
}

Compress-Archive -Path (Join-Path $tempRoot "index.mjs") -DestinationPath $zipPath -Force

aws lambda update-function-code `
  --function-name NativeFormsBackend `
  --zip-file ("fileb://" + $zipPath) `
  --region eu-north-1 `
  --profile codex-nativeforms
