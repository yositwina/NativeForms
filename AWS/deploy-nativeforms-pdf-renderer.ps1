param(
  [string]$FunctionName = "NativeForms-PdfRenderer",
  [string]$Region = "eu-north-1",
  [string]$Profile = "nativeforms-codex",
  [string]$RoleArn = "",                 # execution role; if empty on create, reuses the Submit Lambda's role
  [string]$SubmitFunctionName = "NativeForms-SubmitForm",
  [int]$MemorySize = 2048,
  [int]$Timeout = 60,
  [int]$EphemeralStorageMb = 1024,       # chromium extracts to /tmp
  [string]$Runtime = "nodejs20.x",
  [string]$CodeBucket = "nativeformspublish",  # zip uploaded here (too big for --zip-file direct upload)
  [string]$CodeKey = "lambda-deploy/NativeFormsPdfRenderer.zip"
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$rendererDir = Join-Path $workspaceRoot "AWS\pdf-renderer"
$tempRoot = Join-Path $workspaceRoot ".codex_tmp\NativeFormsPdfRendererDeploy"
$zipPath = Join-Path $workspaceRoot ".codex_tmp\NativeFormsPdfRenderer.zip"

$rendererNodeModules = Join-Path $rendererDir "node_modules"
if (!(Test-Path $rendererNodeModules)) {
  throw "AWS\pdf-renderer\node_modules not found. Run: npm install --omit=dev  (inside AWS\pdf-renderer) before deploying."
}

if (Test-Path $tempRoot) { Remove-Item -Recurse -Force $tempRoot }
New-Item -ItemType Directory -Path $tempRoot | Out-Null

foreach ($file in @("index.mjs", "htmlBuilder.mjs", "schemaTree.mjs", "chromium.mjs", "package.json")) {
  Copy-Item (Join-Path $rendererDir $file) (Join-Path $tempRoot $file)
}
Copy-Item (Join-Path $rendererDir "assets") (Join-Path $tempRoot "assets") -Recurse
Copy-Item $rendererNodeModules (Join-Path $tempRoot "node_modules") -Recurse

if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
Compress-Archive -Path (Join-Path $tempRoot "*") -DestinationPath $zipPath -Force

# Chromium makes the zip exceed the 50MB direct-upload limit, so stage it in S3.
Write-Host ("Uploading code zip to s3://{0}/{1} ..." -f $CodeBucket, $CodeKey)
aws s3 cp $zipPath ("s3://{0}/{1}" -f $CodeBucket, $CodeKey) --region $Region --profile $Profile

# Does the function already exist? (aws is a native exe; check exit code, not try/catch.
# EAP=Continue so the not-found stderr is not treated as a terminating NativeCommandError.)
$global:LASTEXITCODE = 0
$ErrorActionPreference = "Continue"
aws lambda get-function --function-name $FunctionName --region $Region --profile $Profile 2>$null | Out-Null
$exists = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = "Stop"

if ($exists) {
  aws lambda update-function-code `
    --function-name $FunctionName `
    --s3-bucket $CodeBucket `
    --s3-key $CodeKey `
    --region $Region `
    --profile $Profile
  aws lambda wait function-updated `
    --function-name $FunctionName `
    --region $Region `
    --profile $Profile
  aws lambda update-function-configuration `
    --function-name $FunctionName `
    --memory-size $MemorySize `
    --timeout $Timeout `
    --ephemeral-storage ("Size=" + $EphemeralStorageMb) `
    --region $Region `
    --profile $Profile
  Write-Host "Updated $FunctionName (ZIP) -> $zipPath"
} else {
  if ([string]::IsNullOrWhiteSpace($RoleArn)) {
    Write-Host "No -RoleArn given; reusing the Submit Lambda's execution role..."
    $submitConfig = aws lambda get-function-configuration --function-name $SubmitFunctionName --region $Region --profile $Profile | ConvertFrom-Json
    $RoleArn = $submitConfig.Role
    if ([string]::IsNullOrWhiteSpace($RoleArn)) {
      throw "Could not resolve an execution role. Pass -RoleArn explicitly."
    }
    Write-Host "Using role: $RoleArn"
  }
  aws lambda create-function `
    --function-name $FunctionName `
    --runtime $Runtime `
    --handler "index.handler" `
    --role $RoleArn `
    --code ("S3Bucket={0},S3Key={1}" -f $CodeBucket, $CodeKey) `
    --memory-size $MemorySize `
    --timeout $Timeout `
    --ephemeral-storage ("Size=" + $EphemeralStorageMb) `
    --region $Region `
    --profile $Profile
  Write-Host "Created $FunctionName (ZIP, $Runtime)"
}

Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Allow the Submit Lambda role lambda:InvokeFunction on $FunctionName."
Write-Host "  2. Point Submit at it:  ./deploy-nativeforms-submit.ps1 -PdfRendererFunctionName $FunctionName"
Write-Host "  3. Turn ON for test:    ./deploy-nativeforms-submit.ps1 -PdfRenderer chromium"
Write-Host "  4. Replace assets/fonts with a FULL Hebrew TTF before production (or set PDF_FONT_PATH)."
