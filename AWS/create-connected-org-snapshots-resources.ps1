param(
  [string]$Region = "eu-north-1",
  [string]$Profile = "nativeforms-codex",
  [string]$SnapshotBucket = "nativeforms-portable-snapshots-355617663345-eu-north-1",
  [string]$ConnectedOrgGroupTable = "NativeFormsConnectedOrgGroups",
  [string]$PortableSnapshotTable = "NativeFormsPortableSnapshots",
  [string]$BackendRoleName = "NativeFormsBackend-role-pqo9wb23"
)

$ErrorActionPreference = "Stop"

function Invoke-Aws {
  param([scriptblock]$Command)
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "AWS command failed with exit code $LASTEXITCODE."
  }
}

function Test-DynamoTableExists {
  param([string]$TableName)
  try {
    aws dynamodb describe-table --table-name $TableName --region $Region --profile $Profile *> $null
    return $LASTEXITCODE -eq 0
  } catch {
    return $false
  }
}

function Test-S3BucketExists {
  param([string]$BucketName)
  try {
    aws s3api head-bucket --bucket $BucketName --profile $Profile *> $null
    return $LASTEXITCODE -eq 0
  } catch {
    return $false
  }
}

if (-not (Test-DynamoTableExists -TableName $ConnectedOrgGroupTable)) {
  Invoke-Aws { aws dynamodb create-table `
    --table-name $ConnectedOrgGroupTable `
    --attribute-definitions AttributeName=pk,AttributeType=S AttributeName=sk,AttributeType=S AttributeName=gsi1pk,AttributeType=S AttributeName=gsi1sk,AttributeType=S `
    --key-schema AttributeName=pk,KeyType=HASH AttributeName=sk,KeyType=RANGE `
    --global-secondary-indexes "IndexName=GSI1,KeySchema=[{AttributeName=gsi1pk,KeyType=HASH},{AttributeName=gsi1sk,KeyType=RANGE}],Projection={ProjectionType=ALL}" `
    --billing-mode PAY_PER_REQUEST `
    --region $Region `
    --profile $Profile }

  Invoke-Aws { aws dynamodb wait table-exists --table-name $ConnectedOrgGroupTable --region $Region --profile $Profile }
}

if (-not (Test-DynamoTableExists -TableName $PortableSnapshotTable)) {
  Invoke-Aws { aws dynamodb create-table `
    --table-name $PortableSnapshotTable `
    --attribute-definitions AttributeName=pk,AttributeType=S AttributeName=sk,AttributeType=S `
    --key-schema AttributeName=pk,KeyType=HASH AttributeName=sk,KeyType=RANGE `
    --billing-mode PAY_PER_REQUEST `
    --region $Region `
    --profile $Profile }

  Invoke-Aws { aws dynamodb wait table-exists --table-name $PortableSnapshotTable --region $Region --profile $Profile }
}

if (-not (Test-S3BucketExists -BucketName $SnapshotBucket)) {
  Invoke-Aws { aws s3api create-bucket `
    --bucket $SnapshotBucket `
    --create-bucket-configuration LocationConstraint=$Region `
    --region $Region `
    --profile $Profile }
}

Invoke-Aws { aws s3api put-public-access-block `
  --bucket $SnapshotBucket `
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true `
  --profile $Profile }

$encryptionPath = Join-Path ([System.IO.Path]::GetTempPath()) "nativeforms-portable-snapshot-bucket-encryption.json"
'{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' | Set-Content -Path $encryptionPath -Encoding Ascii
Invoke-Aws { aws s3api put-bucket-encryption `
  --bucket $SnapshotBucket `
  --server-side-encryption-configuration ("file://" + $encryptionPath) `
  --profile $Profile }

Invoke-Aws { aws s3api put-bucket-versioning `
  --bucket $SnapshotBucket `
  --versioning-configuration Status=Enabled `
  --profile $Profile }

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$policyPath = Join-Path $workspaceRoot "AWS\infrastructure\connected-org-snapshots-backend-role-policy.json"
Invoke-Aws { aws iam put-role-policy `
  --role-name $BackendRoleName `
  --policy-name NativeFormsConnectedOrgSnapshotsAccess `
  --policy-document ("file://" + $policyPath) `
  --profile $Profile }

Write-Output "Connected org snapshot AWS resources are ready."
