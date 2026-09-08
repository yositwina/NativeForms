# TwinaForms Import QA JSONs

Source file: `C:\Users\Yosi\Downloads\TwinaForms_form35_2026-08-04.json`

Use these files from **Form Designer -> Actions -> Import Form**. Each file changes one compatibility condition where possible.

| File | Purpose | Expected behavior |
| --- | --- | --- |
| `00-baseline-form35-valid.json` | Original valid export copy | Preview targets existing `form35`. Import creates a new Draft version if data storage is available. |
| `01-different-existing-form-number-form29.json` | Same payload but `globalFormKey = form29` | Preview targets existing `form29`, not the currently open form unless you are on form29. Should show different-form warning when opened from another form. |
| `02-different-new-form-number-form9999.json` | Same payload but new form number | Preview says it will create a new form. Import creates form9999 if storage and form limits allow. |
| `03-invalid-form-key-format.json` | Bad form number format with spaces | Current Phase 1 backend may not block this before insert. Use this to identify whether we need stricter `globalFormKey` validation. |
| `04-missing-target-field.json` | Adds `Contact.QA_Missing_Field__c` to manifest | Preview should block with missing target field. |
| `05-missing-target-object.json` | Adds `QA_Missing_Object__c` to manifest | Preview should block with missing target object. |
| `06-missing-object-and-field.json` | Adds missing object and field | Preview should block with both object/field metadata issues. |
| `07-incompatible-schema-version.json` | Unsupported `schemaVersion` | Preview should fail with unsupported schema message. |
| `08-invalid-package-type.json` | Invalid `packageType` | Preview should fail with not-a-TwinaForms-definition message. |
| `09-source-salesforce-url-warning.json` | Adds Salesforce file URL | Preview should show source Salesforce URL warning. |
| `10-runtime-url-warning.json` | Adds TwinaForms runtime URL | Preview should show runtime URL informational warning. |
| `11-missing-theme-reference-phase1.json` | Adds fake theme reference | Phase 1 currently defers theme handling; this should not block import unless we later add theme validation. |

Note: DevHub currently has `DataStorageMB` remaining `0`, so imports that create records can fail with `storage limit exceeded` until data storage is freed.
