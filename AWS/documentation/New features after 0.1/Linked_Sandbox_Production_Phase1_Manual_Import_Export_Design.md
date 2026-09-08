# Linked Sandbox/Production Forms - Phase 1 Manual Import/Export Design

**Status:** Implemented (manual Salesforce export/import deployed)

**Scope:** Salesforce-only manual JSON export/import foundation
**Parent feature:** `Linked_Sandbox_Production_Forms.md`
**Core rule:** Every export package must include the stable TwinaForms form number (`globalFormKey`).

---

## 1. Purpose

Phase 1 creates the portability core for Linked Sandbox/Production Forms.

The admin can manually export a form definition to a JSON file and import that file into another org. The
file carries the TwinaForms form number, so the target org can either create the missing local counterpart
with the same number or add a new version to the existing local form with that number.

This phase has no AWS environment link, no AWS snapshots, no production OAuth broker, and no automatic
promotion. It deliberately proves the serializer, validator, importer, stable form identity, and artifact
stripping before AWS is added.

---

## 2. Product Promise For Phase 1

```text
Export Form 22 from sandbox.
Import the file in production.
If production already has Form 22, TwinaForms creates a new draft version.
If production does not have Form 22, TwinaForms creates Production Form 22.
The form number is preserved.
Nothing is published automatically.
```

This is still manual, but it already supports the most important expectation: the same form number can
exist across orgs.

Important boundary:

```text
Same form number does not mean the exact same full published link in Phase 1.
```

Current AWS publishing uses org/tenant context in the hosted link. The target org gets its own published
link only after it publishes locally.

---

## 3. Explicit Non-Goals

Phase 1 does not include:

- AWS snapshot storage
- environment linking
- `Link Production`
- OAuth-based production connection for this feature
- one-click promote/pullback
- shared sandbox/production public URL routing
- production rollback from AWS snapshots
- automatic publish after import
- import files without a form number
- backward compatibility for old export files

---

## 4. User Experience

### 4.1 Export

The Designer form page gets an `Export Form` action.

Recommended placement:

- form actions menu
- or a small secondary action near existing form management actions

Flow:

1. Admin opens a form in Designer.
2. Admin clicks `Export Form`.
3. TwinaForms builds a portable package for the selected form.
4. Browser downloads the JSON file.

Recommended file name:

```text
TwinaForms_form22_2026-08-03.json
```

Export success message:

```text
Form 22 was exported.
Import this file in another org to create Form 22 or add a new version to Form 22.
```

### 4.2 Import

The user-facing entry point is one button:

```text
Import Form
```

Recommended placement:

- Designer Home / Forms list, because the target form may not exist yet
- optional additional action on an existing form page

Flow:

1. Admin clicks `Import Form`.
2. Admin selects a JSON file.
3. TwinaForms parses and inspects the package.
4. TwinaForms checks the current org for the package `globalFormKey`.
5. TwinaForms validates referenced metadata.
6. TwinaForms shows a preview and compatibility report.
7. Admin confirms.
8. TwinaForms creates either a new local form or a new local version.

---

## 5. Import Decision Logic

The file's `globalFormKey` decides the default behavior. The admin should not choose from a long list of
modes in V1.

### 5.1 Current org already has the form number

Package:

```text
globalFormKey = form22
```

Current org:

```text
Form 22 exists
```

Preview:

```text
Import Form 22

This file is for Form 22.
A new draft version will be created for the existing Form 22 in this org.

Current live version will not be changed.
You can review and publish the new version when ready.

[Import as New Version]
```

Behavior:

- create a new `NF_Form_Version__c` under the existing `NF_Form__c`
- create imported elements/actions under the new version
- keep the current live/published version unchanged
- do not publish automatically

### 5.2 Current org does not have the form number

Package:

```text
globalFormKey = form22
```

Current org:

```text
Form 22 does not exist
```

Preview:

```text
Import Form 22

This file is for Form 22.
This org does not have Form 22 yet.

TwinaForms will create Form 22 in this org with a new draft version.

[Create Form 22]
```

Behavior:

- create a new `NF_Form__c`
- set its stable form key to `form22`
- create one draft version
- create imported elements/actions under that version
- do not publish automatically

### 5.3 Same form number but suspicious details

If the current org already has the same form number but title, object, or other identifying details differ,
warn but keep the default behavior as "new version of this form number".

Preview:

```text
A Form 22 already exists in this org, but its details differ from the imported package.

Existing: Event Registration
Import file: Volunteer Registration

Importing will create a new draft version under the existing Form 22.
Current live version will not be changed.

[Import as New Version]
[Cancel]
```

V1 should not silently create `form23` or another number to avoid the warning.

### 5.4 Missing form number

Phase 1 files must include `globalFormKey`.

If missing:

```text
This file cannot be imported because it does not include a TwinaForms form number.
Export the form again using the latest TwinaForms version.
```

No legacy/no-number path is required in V1.

---

## 6. Package JSON Shape

The package should be a self-contained JSON document with a fixed schema version.

Top-level shape:

```json
{
  "schemaVersion": "linked-env-portable-form-v1",
  "packageType": "twinaformsFormDefinition",
  "exportedAt": "2026-08-03T10:00:00Z",
  "sourceOrgId": "00D...",
  "sourceEnvironmentType": "sandbox",
  "sourcePublishedUrl": "https://forms.twinaforms.com/acme-sandbox/form22",
  "sourcePackageVersion": "0.13.0.1",
  "globalFormKey": "form22",
  "form": {},
  "theme": {},
  "versions": [],
  "elements": [],
  "actions": [],
  "assets": [],
  "manifest": {},
  "stripped": {}
}
```

Required top-level fields:

- `schemaVersion`
- `packageType`
- `exportedAt`
- `sourceOrgId`
- `globalFormKey`
- `form`
- `versions`
- `elements`
- `actions`
- `manifest`

Recommended optional fields:

- `sourceEnvironmentType`
- `sourcePublishedUrl` as informational only
- `sourcePackageVersion`
- `theme`
- `assets`
- `stripped`

### 6.1 `globalFormKey`

`globalFormKey` is required and must represent the user-facing TwinaForms form number.

Example:

```json
{
  "globalFormKey": "form22"
}
```

Import must preserve this key unless the admin cancels. It must not silently renumber.

### 6.1.1 Published link fields are informational only

The export package may include source link information for preview/support:

```json
{
  "sourcePublishedUrl": "https://forms.twinaforms.com/acme-sandbox/form22",
  "sourcePublishedKey": "acme-sandbox/form22"
}
```

These values must not be imported as target runtime values.

Phase 1 target behavior:

```text
Import creates form/version records only.
Target org publish later generates its own runtime form id, publish token, S3 key, and public URL.
```

This matters because the same `globalFormKey` can have different full URLs in sandbox and production due
to different tenant/company publishing context.

### 6.1.2 Salesforce formula/button URL guidance

If an admin uses the TwinaForms public link inside a Salesforce formula field, button, email template,
custom object field, or automation, the formula must handle sandbox and production separately.

Recommended pattern:

```text
IF(
  $Organization.IsSandbox,
  "https://forms.twinaforms.com/acme-sandbox/form22",
  "https://forms.twinaforms.com/acme/form22"
)
```

The imported form keeps the same `globalFormKey`, but each org uses its own published URL after local
publish. Do not copy the sandbox published URL into production formulas.

### 6.2 Form section

The `form` section should include portable business fields from `NF_Form__c`, not Salesforce IDs.

Example:

```json
{
  "form": {
    "globalFormKey": "form22",
    "name": "Volunteer Registration",
    "projectKey": "general",
    "language": "en",
    "direction": "ltr",
    "settingsJson": {}
  }
}
```

Do not include the source `NF_Form__c.Id` as an importable value.

### 6.3 Versions

Phase 1 can export the selected/current draft version by default. Exporting all versions is useful later,
but not necessary for V1 if it increases risk.

Recommended V1 default:

```text
Export the currently selected form version.
```

Version entries should include:

- logical version key or source version label
- status as informational only
- form settings
- UI settings
- custom CSS/JS if supported by current product scope
- PDF/settings if supported by current product scope

Import always creates a new draft/inactive version in the target org.

### 6.4 Elements

Elements should preserve logical identity and layout relationships:

- `Element_Id__c`
- `Parent_Element_Id__c`
- `Field_Key__c`
- element type
- label/text
- order/index
- column/parent placement
- `Config_JSON__c`

Do not preserve Salesforce record IDs.

### 6.5 Actions

Actions should preserve portable command definitions:

- prefill/submit scope
- command type
- object API name
- field mappings by Salesforce field API name
- aliases
- response mapping
- condition/run-if config
- command keys

Do not preserve Salesforce action record IDs.

### 6.6 Assets

Image assets and theme logo assets should be included as payloads where practical and within existing size
limits.

For each asset:

- logical asset key
- file name
- content type
- base64 payload or package attachment reference
- source element/theme reference
- original source URL as informational only

Import should recreate target-org `ContentVersion` records and rewrite element/theme config to target-org
asset references.

### 6.7 Manifest

The manifest is used for compatibility validation and later AWS snapshots.

It should include:

- referenced Salesforce objects
- referenced Salesforce fields by object
- referenced record types where relevant
- referenced page layouts where relevant
- lookup target objects and display/search fields
- submit writable fields
- prefill readable fields
- file upload target actions
- signature/PDF attachment targets
- formula field references
- conditional visibility field references

Example:

```json
{
  "manifest": {
    "objects": ["Contact", "CampaignMember"],
    "fields": {
      "Contact": ["FirstName", "LastName", "Email", "Work_Email__c"],
      "CampaignMember": ["CampaignId", "ContactId", "Status"]
    }
  }
}
```

### 6.8 Stripped artifacts record

Include a small `stripped` section for diagnostics and support.

Example:

```json
{
  "stripped": {
    "salesforceRecordIds": true,
    "publishTokens": true,
    "publicationRecords": true,
    "generatedHtmlRefs": true,
    "awsResponseJson": true,
    "submissions": true
  }
}
```

---

## 7. Data That Must Not Move

Export/import moves form definition only.

Never move:

- Salesforce record IDs as target IDs
- submitted Salesforce data
- TwinaForms submission logs
- `Publish_Token__c`
- `Current_Published_Version__c`
- `NF_Form_Publication__c`
- generated HTML references
- published form IDs from AWS/S3
- source published URL as a target URL
- source S3 key as a target S3 key
- AWS response JSON
- Salesforce OAuth refresh tokens
- tenant secrets
- Bootstrap V2 HMAC secrets
- production/sandbox runtime state

All runtime artifacts regenerate only when the target org publishes.

Identity rule:

```text
globalFormKey moves.
runtimeFormId does not move.
publishedPublicUrl does not move.
publishToken does not move.
```

---

## 8. Apex Design

Recommended controller:

```text
NativeFormsFormPortabilityController
```

Recommended methods:

```apex
@AuraEnabled
public static String exportForm(Id formId, Id versionId)

@AuraEnabled
public static ImportPreview inspectImport(String packageJson)

@AuraEnabled
public static ImportResult importForm(String packageJson, ImportOptions options)
```

### 8.1 `exportForm`

Inputs:

- `formId`
- optional `versionId`

Behavior:

1. Load the form and selected/current version using user-mode access where appropriate.
2. Load version elements/actions/theme/assets needed for the package.
3. Build a portable DTO.
4. Build the manifest.
5. Strip org/runtime artifacts.
6. Serialize JSON.

Errors should be handled and customer-safe.

### 8.2 `inspectImport`

Inputs:

- uploaded package JSON

Behavior:

1. Parse JSON.
2. Validate schema and required fields.
3. Require `globalFormKey`.
4. Determine whether the current org already has that form key.
5. Validate destination metadata from the manifest.
6. Validate image payload sizes.
7. Resolve theme action.
8. Return preview only; no DML.

Return should include:

- package summary
- target action: `createForm` or `createVersion`
- blocking errors
- warnings
- missing metadata list
- theme action
- image action

### 8.3 `importForm`

Inputs:

- package JSON
- import options returned/confirmed from preview

Behavior:

1. Re-run the same validations as `inspectImport`.
2. If blocking errors exist, create no records.
3. Start DML only after validation passes.
4. Create/reuse target form based on `globalFormKey`.
5. Create new draft version.
6. Recreate assets.
7. Insert elements/actions under the new version.
8. Return the new form/version IDs.

`importForm` must not trust client-side preview state. It must re-validate server-side.

---

## 9. Import Options

Keep options minimal in V1.

Recommended shape:

```json
{
  "confirmedGlobalFormKey": "form22",
  "targetAction": "createForm",
  "targetFormId": null,
  "projectId": null,
  "themePolicy": "reuseByNameOrCreate",
  "imagePolicy": "recreateContentVersions"
}
```

Allowed `targetAction` values:

- `createForm`
- `createVersion`

The user does not manually choose these in the normal flow. TwinaForms derives them from whether
`globalFormKey` already exists in the current org.

---

## 10. Compatibility Validation

Blocking validation should happen before any import DML.

Blocking errors:

- invalid JSON
- unsupported schema version
- missing `globalFormKey`
- missing required package sections
- referenced object missing in target org
- referenced field missing in target org
- incompatible field type for mapped usage
- invalid submit command object
- invalid prefill command object
- required lookup target object/field missing
- required image payload too large
- malformed config that cannot be safely imported

Warnings:

- target org already has the same form number but title/details differ
- theme with same name exists and will be reused
- theme will be created
- image will be recreated
- source environment is sandbox/production but target environment is unknown
- optional display-only metadata mismatch that does not affect runtime execution

V1 should not offer `Import Anyway` for blocking metadata errors.

---

## 11. Theme Handling

V1 policy:

```text
reuseByNameOrCreate
```

Rules:

- If a theme with the same name exists, reuse it and warn if settings differ.
- If no theme exists, create a new target theme.
- Do not overwrite an existing target theme.
- Imported form/version should reference the target org theme record.

---

## 12. Image Handling

V1 policy:

```text
recreateContentVersions
```

Rules:

- Export embedded image payloads where available.
- Validate payload size against current TwinaForms image limits.
- Import creates new `ContentVersion` records in the target org.
- Rewrite image config from source URLs/IDs to target org asset references.
- If an image payload is missing but the image is optional, warn.
- If a required image payload is missing, block or import with a clear broken-image warning depending on
  product decision; safer V1 default is block for required visual assets.

---

## 13. Form Number Collision Rules

The form number is protected.

Rules:

- If `form22` does not exist locally, create `form22`.
- If `form22` exists locally, create a new version under local `form22`.
- Never silently import as `form23`.
- Never silently attach to a different existing form number.
- If local `form22` appears unrelated, warn and let the admin cancel.
- If duplicate local `globalFormKey` records exist, block and ask admin/support to repair data.

---

## 14. Designer UI Details

### 14.1 Import entry point

Recommended primary placement:

```text
Designer Home / Forms List -> Import Form
```

Reason: the target form may not exist in the org yet.

Optional secondary placement:

```text
Designer Form Page -> Actions -> Import Form
```

If started from an existing form page, still inspect the file's `globalFormKey`; do not assume the current
form is the target when the key differs.

### 14.2 Import modal states

States:

1. Select file
2. Inspecting
3. Preview ready
4. Compatibility errors
5. Importing
6. Import complete

Preview should show:

- form number
- form name
- source org id
- source environment
- source published URL, if present, labeled as informational only
- package exported date
- target action
- compatibility summary
- warnings

Suggested text:

```text
The source form number will be preserved.
The source published link will not be copied.
This org will generate its own published link when you publish the imported version.
```

### 14.3 Completion behavior

After success:

- refresh Designer workspace
- select/open the imported form
- select/open the new draft version
- show success message

Success for existing local form:

```text
Form 22 draft version was created from the import file.
Review and publish when ready.
```

Success for missing local form:

```text
Form 22 was created in this org with a new draft version.
Review and publish when ready.
```

---

## 15. Security And ISV Notes

Phase 1 is safer than AWS-linked promotion because the admin manually downloads/uploads the package, but
it still needs package-safe and security-review-safe behavior.

Rules:

- Use user-mode access patterns for normal form/theme/asset reads and writes where appropriate.
- Do not expose hidden secrets or protected package data in JSON.
- Do not include OAuth tokens, HMAC secrets, tenant secrets, or runtime publish tokens.
- Do not trust imported object/field names until validated against target metadata.
- Do not execute imported custom JavaScript during import/preview.
- Keep customer-facing errors concise and safe.
- Keep detailed technical diagnostics server-side or in admin-safe debug output.

---

## 16. Test Plan

### 16.1 Apex tests

Required tests:

- export includes `globalFormKey`
- export includes form/version/elements/actions/manifest
- export excludes Salesforce record IDs as importable IDs
- export excludes publish tokens/publication/AWS response JSON
- inspect blocks missing `globalFormKey`
- inspect blocks invalid JSON
- inspect blocks unsupported schema version
- inspect detects local form exists and returns `createVersion`
- inspect detects local form missing and returns `createForm`
- missing object blocks import with no DML
- missing field blocks import with no DML
- import creates a new form when the key is missing locally
- import creates a new version when the key exists locally
- import does not overwrite live/current published version
- theme existing by name is reused
- missing theme is created
- image payload creates target `ContentVersion`
- duplicate local `globalFormKey` blocks import

### 16.2 Manual smoke tests

Smoke tests:

1. Export sandbox Form 22 and import into an org with no Form 22; confirm Form 22 is created.
2. Export sandbox Form 22 and import into an org with existing Form 22; confirm new draft version is
   created.
3. Remove a target field and confirm import is blocked before any records are created.
4. Import a form with a theme; confirm theme reuse/create behavior.
5. Import a form with an image; confirm image appears in Designer and after publish.
6. Confirm imported form does not publish automatically.
7. Publish imported form and confirm runtime artifacts are regenerated in the target org.

---

## 17. Implementation Sequence

Recommended order:

1. Add/persist `globalFormKey` support if the current form key is not reliable enough.
2. Build export DTOs and serializer.
3. Build manifest generation.
4. Build `inspectImport` parser and schema validation.
5. Build metadata compatibility validation.
6. Build importer for missing local form -> create form.
7. Build importer for existing local form -> create version.
8. Add theme handling.
9. Add image handling.
10. Add Designer export action.
11. Add Designer import modal.
12. Add tests.
13. Run clean-org smoke tests.

---

## 18. Open Decisions

- Is current `NF_Key__c` stable enough to be `globalFormKey`, or do we add `NF_Global_Form_Key__c`?
- Does V1 export only the selected/current version, or all versions with one selected import version?
- Should missing optional display-only image payloads block import or warn?
- Which project should a newly created imported form use by default: selected project, `General`, or
  package value?
- Should source environment type be read from Salesforce `Organization.IsSandbox` during export in Phase 1,
  or left nullable until environment linking?

---

## 19. Relationship To Phase 2

Phase 2 will reuse the same package schema, inspector, validator, and importer.

The only change is package source:

```text
Phase 1: uploaded JSON file
Phase 2: AWS snapshot JSON
```

The target behavior stays the same:

```text
If form number exists locally -> create new version.
If form number is missing locally -> create local counterpart with same form number.
```
