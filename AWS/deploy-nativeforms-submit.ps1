param(
  [string]$FunctionName = "NativeForms-SubmitForm",
  [string]$Region = "eu-north-1",
  [string]$Profile = "nativeforms-codex",
  [string]$CaptchaSecretKey = "",
  [string]$UploadStagingBucket = ""
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$sourceFile = Join-Path $workspaceRoot "AWS\NativeForms-SubmitForm.mjs"
$tempRoot = Join-Path $workspaceRoot ".codex_tmp\NativeFormsSubmitDeploy"
$zipPath = Join-Path $workspaceRoot ".codex_tmp\NativeFormsSubmit.zip"

if (Test-Path $tempRoot) {
  Remove-Item -Recurse -Force $tempRoot
}

New-Item -ItemType Directory -Path $tempRoot | Out-Null
Copy-Item $sourceFile (Join-Path $tempRoot "index.mjs")
Copy-Item (Join-Path $workspaceRoot "package.json") (Join-Path $tempRoot "package.json")

$assetsPath = Join-Path $workspaceRoot "AWS\assets"
if (Test-Path $assetsPath) {
  Copy-Item $assetsPath (Join-Path $tempRoot "assets") -Recurse
}

$nodeModulesPath = Join-Path $workspaceRoot "node_modules"
if (!(Test-Path $nodeModulesPath)) {
  throw "node_modules was not found. Run npm install before deploying NativeForms-SubmitForm."
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

if ([string]::IsNullOrWhiteSpace($CaptchaSecretKey) -and [string]::IsNullOrWhiteSpace($UploadStagingBucket)) {
  Write-Host "Lambda code updated. Lambda environment was not changed."
  exit 0
}

aws lambda wait function-updated `
  --function-name $FunctionName `
  --region $Region `
  --profile $Profile

$configurationJson = aws lambda get-function-configuration `
  --function-name $FunctionName `
  --region $Region `
  --profile $Profile

if ([string]::IsNullOrWhiteSpace($configurationJson)) {
  throw "Unable to read Lambda configuration for $FunctionName."
}

$configuration = $configurationJson | ConvertFrom-Json
$variables = @{}

if ($null -ne $configuration.Environment -and $null -ne $configuration.Environment.Variables) {
  $configuration.Environment.Variables.PSObject.Properties | ForEach-Object {
    $variables[$_.Name] = [string]$_.Value
  }
}

if (![string]::IsNullOrWhiteSpace($CaptchaSecretKey)) {
  $variables["CAPTCHA_SECRET_KEY"] = $CaptchaSecretKey
}
if (![string]::IsNullOrWhiteSpace($UploadStagingBucket)) {
  $variables["UPLOAD_STAGING_BUCKET"] = $UploadStagingBucket
}

$environmentJson = @{
  Variables = $variables
} | ConvertTo-Json -Compress
$environmentPath = Join-Path $tempRoot "lambda-environment.json"
$environmentJson | Set-Content -Path $environmentPath -Encoding UTF8

aws lambda update-function-configuration `
  --function-name $FunctionName `
  --environment ("file://" + $environmentPath) `
  --region $Region `
  --profile $Profile

Write-Host "Lambda code updated and requested environment settings were applied."
