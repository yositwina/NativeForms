param(
  [string]$UploadStagingBucket = ""
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$sourceFile = Join-Path $workspaceRoot "AWS\NativeFormsBackend.mjs"
$bootstrapV2HmacFile = Join-Path $workspaceRoot "AWS\bootstrap-v2-hmac.mjs"
$bootstrapV2SalesforceFile = Join-Path $workspaceRoot "AWS\bootstrap-v2-salesforce.mjs"
$geoLocationsPolicyFile = Join-Path $workspaceRoot "AWS\infrastructure\backend-geolocations-role-policy.json"
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

if (Test-Path $geoLocationsPolicyFile) {
  aws iam put-role-policy `
    --role-name NativeFormsBackend-role-pqo9wb23 `
    --policy-name NativeFormsGeoLocationsRead `
    --policy-document ("file://" + $geoLocationsPolicyFile) `
    --profile nativeforms-codex
}

if (![string]::IsNullOrWhiteSpace($UploadStagingBucket)) {
  aws lambda wait function-updated `
    --function-name NativeFormsBackend `
    --region eu-north-1 `
    --profile nativeforms-codex

  $configurationJson = aws lambda get-function-configuration `
    --function-name NativeFormsBackend `
    --region eu-north-1 `
    --profile nativeforms-codex

  if ([string]::IsNullOrWhiteSpace($configurationJson)) {
    throw "Unable to read Lambda configuration for NativeFormsBackend."
  }

  $configuration = $configurationJson | ConvertFrom-Json
  $variables = @{}

  if ($null -ne $configuration.Environment -and $null -ne $configuration.Environment.Variables) {
    $configuration.Environment.Variables.PSObject.Properties | ForEach-Object {
      $variables[$_.Name] = [string]$_.Value
    }
  }

  $variables["UPLOAD_STAGING_BUCKET"] = $UploadStagingBucket
  $environmentJson = @{ Variables = $variables } | ConvertTo-Json -Compress
  $environmentPath = Join-Path $tempRoot "lambda-environment.json"
  $environmentJson | Set-Content -Path $environmentPath -Encoding UTF8

  aws lambda update-function-configuration `
    --function-name NativeFormsBackend `
    --environment ("file://" + $environmentPath) `
    --region eu-north-1 `
    --profile nativeforms-codex
}
