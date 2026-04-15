param(
  [string]$FunctionName = "NativeForms-SubmitForm",
  [string]$Region = "eu-north-1",
  [string]$Profile = "nativeforms-codex",
  [string]$CaptchaSecretKey = ""
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

if (Test-Path $zipPath) {
  Remove-Item -Force $zipPath
}

Compress-Archive -Path (Join-Path $tempRoot "index.mjs") -DestinationPath $zipPath -Force

aws lambda update-function-code `
  --function-name $FunctionName `
  --zip-file ("fileb://" + $zipPath) `
  --region $Region `
  --profile $Profile

if ([string]::IsNullOrWhiteSpace($CaptchaSecretKey)) {
  Write-Host "Lambda code updated. CAPTCHA secret was not changed."
  exit 0
}

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

$variables["CAPTCHA_SECRET_KEY"] = $CaptchaSecretKey

$environmentJson = @{
  Variables = $variables
} | ConvertTo-Json -Compress

aws lambda update-function-configuration `
  --function-name $FunctionName `
  --environment $environmentJson `
  --region $Region `
  --profile $Profile

Write-Host "Lambda code updated and CAPTCHA_SECRET_KEY was applied."
