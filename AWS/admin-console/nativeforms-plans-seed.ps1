$items = @(
  @{
    planCode = @{ S = "free" }
    label = @{ S = "Free" }
    description = @{ S = "Permanent low-volume entry plan." }
    isActive = @{ BOOL = $true }
    durationType = @{ S = "forever" }
    durationDays = @{ NULL = $true }
    sortOrder = @{ N = "1" }
    limits = @{
      M = @{
        maxSfUsers = @{ N = "1" }
        maxForms = @{ N = "1" }
        maxSubmissionsPerMonth = @{ N = "100" }
      }
    }
    featureFlags = @{
      M = @{
        enableProConditionLogic = @{ BOOL = $false }
        enableProRepeatGroups = @{ BOOL = $false }
        enableProPrefillAliasReferences = @{ BOOL = $false }
        enableProAdvancedSubmitModes = @{ BOOL = $false }
        enableProFormulaFields = @{ BOOL = $false }
        enableProPostSubmitAutoLink = @{ BOOL = $false }
        enableProSfSecretCodeAuth = @{ BOOL = $false }
        enableProLoadFile = @{ BOOL = $false }
      }
    }
    updatedAt = @{ S = "2026-04-13T07:45:00.000Z" }
  },
  @{
    planCode = @{ S = "trial" }
    label = @{ S = "Trial" }
    description = @{ S = "Time-limited evaluation with all Pro features." }
    isActive = @{ BOOL = $true }
    durationType = @{ S = "fixed_days" }
    durationDays = @{ N = "30" }
    sortOrder = @{ N = "2" }
    limits = @{
      M = @{
        maxSfUsers = @{ N = "1" }
        maxForms = @{ N = "5" }
        maxSubmissionsPerMonth = @{ NULL = $true }
      }
    }
    featureFlags = @{
      M = @{
        enableProConditionLogic = @{ BOOL = $true }
        enableProRepeatGroups = @{ BOOL = $true }
        enableProPrefillAliasReferences = @{ BOOL = $true }
        enableProAdvancedSubmitModes = @{ BOOL = $true }
        enableProFormulaFields = @{ BOOL = $true }
        enableProPostSubmitAutoLink = @{ BOOL = $true }
        enableProSfSecretCodeAuth = @{ BOOL = $true }
        enableProLoadFile = @{ BOOL = $true }
      }
    }
    updatedAt = @{ S = "2026-04-13T07:45:00.000Z" }
  },
  @{
    planCode = @{ S = "starter" }
    label = @{ S = "Starter" }
    description = @{ S = "Paid production plan without Pro-only features." }
    isActive = @{ BOOL = $true }
    durationType = @{ S = "forever" }
    durationDays = @{ NULL = $true }
    sortOrder = @{ N = "3" }
    limits = @{
      M = @{
        maxSfUsers = @{ N = "1" }
        maxForms = @{ N = "5" }
        maxSubmissionsPerMonth = @{ N = "1000" }
      }
    }
    featureFlags = @{
      M = @{
        enableProConditionLogic = @{ BOOL = $false }
        enableProRepeatGroups = @{ BOOL = $false }
        enableProPrefillAliasReferences = @{ BOOL = $false }
        enableProAdvancedSubmitModes = @{ BOOL = $false }
        enableProFormulaFields = @{ BOOL = $false }
        enableProPostSubmitAutoLink = @{ BOOL = $false }
        enableProSfSecretCodeAuth = @{ BOOL = $false }
        enableProLoadFile = @{ BOOL = $false }
      }
    }
    updatedAt = @{ S = "2026-04-13T07:45:00.000Z" }
  },
  @{
    planCode = @{ S = "pro" }
    label = @{ S = "Pro" }
    description = @{ S = "Full plan with no product limits." }
    isActive = @{ BOOL = $true }
    durationType = @{ S = "forever" }
    durationDays = @{ NULL = $true }
    sortOrder = @{ N = "4" }
    limits = @{
      M = @{
        maxSfUsers = @{ NULL = $true }
        maxForms = @{ NULL = $true }
        maxSubmissionsPerMonth = @{ NULL = $true }
      }
    }
    featureFlags = @{
      M = @{
        enableProConditionLogic = @{ BOOL = $true }
        enableProRepeatGroups = @{ BOOL = $true }
        enableProPrefillAliasReferences = @{ BOOL = $true }
        enableProAdvancedSubmitModes = @{ BOOL = $true }
        enableProFormulaFields = @{ BOOL = $true }
        enableProPostSubmitAutoLink = @{ BOOL = $true }
        enableProSfSecretCodeAuth = @{ BOOL = $true }
        enableProLoadFile = @{ BOOL = $true }
      }
    }
    updatedAt = @{ S = "2026-04-13T07:45:00.000Z" }
  }
)

foreach ($item in $items) {
  $tempFile = [System.IO.Path]::GetTempFileName()
  try {
    $json = $item | ConvertTo-Json -Depth 10
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tempFile, $json, $utf8NoBom)
    aws dynamodb put-item --table-name NativeFormsPlans --item file://$tempFile --region eu-north-1 --profile nativeforms-codex
  } finally {
    Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
  }
}
