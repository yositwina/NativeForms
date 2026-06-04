$ErrorActionPreference = "Stop"

$tableName = "NativeFormsGeoLocations"
$region = "eu-north-1"
$profile = "nativeforms-codex"

$tableNamesJson = aws dynamodb list-tables `
  --region $region `
  --profile $profile

$tableNames = ($tableNamesJson | ConvertFrom-Json).TableNames
if ($tableNames -contains $tableName) {
  Write-Host "$tableName already exists."
  exit 0
}

aws dynamodb create-table `
  --table-name $tableName `
  --attribute-definitions `
    AttributeName=locationPartition,AttributeType=S `
    AttributeName=searchKey,AttributeType=S `
  --key-schema `
    AttributeName=locationPartition,KeyType=HASH `
    AttributeName=searchKey,KeyType=RANGE `
  --billing-mode PAY_PER_REQUEST `
  --region $region `
  --profile $profile

aws dynamodb wait table-exists `
  --table-name $tableName `
  --region $region `
  --profile $profile

Write-Host "$tableName is ready."
