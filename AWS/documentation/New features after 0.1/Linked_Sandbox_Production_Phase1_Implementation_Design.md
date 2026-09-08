# Linked Sandbox/Production Forms - Phase 1 Implementation Design

**Status:** Implemented (manual Phase 1 export/import deployed)
**Scope:** Manual JSON export/import with same TwinaForms form number
**Parent docs:**
- `Linked_Sandbox_Production_Forms.md`
- `Linked_Sandbox_Production_Phase1_Manual_Import_Export_Design.md`
- `Form_Export_Import_Implementation_Plan.md`

---

## 1. Goal

Build the manual import/export foundation for Linked Sandbox/Production Forms.

Phase 1 lets an admin:

```text
Export Form 22 from sandbox as JSON.
Import that JSON in production.
Keep the TwinaForms form number: form22.
Create a new production draft version if Form 22 already exists.
Create Production Form 22 if it does not exist yet.
Review and publish manually.
```

This phase must be designed as the same portability engine that AWS snapshots will later reuse.

---

## 2. Important Existing Capability: Rollback Already Exists

Do not build a separate rollback feature in Phase 1.

The current Designer already supports local restore from a published version:

```text
Restore From This Published Version
```

Current Apex:

```text
NativeFormsDesignerController.restoreDraftFromPublished(formId, sourceVersionId)
```

Current behavior:

- Selects a published version of the same local form.
- Creates a new draft version.
- Copies version settings.
- Copies `NF_Form_Element__c` rows.
- Copies `NF_Form_Action__c` rows.
- Sets `Current_Draft_Version__c` to the restored draft.
- Does not overwrite the live published version.

Phase 1 should rely on this for same-org rollback:

```text
Production v5 is live.
Admin restores old Production v3.
TwinaForms creates Production v6 draft from v3.
Admin reviews and publishes v6.
```

Phase 1 import should follow the same safety pattern: create a new draft version, never overwrite live
production.

---

## 3. Current System Facts To Respect

### 3.1 Salesforce is design source of truth

The design records remain:

- `NF_Form__c`
- `NF_Form_Version__c`
- `NF_Form_Element__c`
- `NF_Form_Action__c`

Generated HTML and AWS registration payloads are compiled artifacts.

### 3.2 Current runtime link is environment-specific

Current AWS publish uses tenant/company slug plus form slug:

```text
published key = companySlug / formSlug
```

Therefore:

```text
Same globalFormKey across orgs.
Different publishedPublicUrl per org.
```

Phase 1 imports the form number and definition. It does not import the source org's runtime link.

### 3.3 Current AWS runtime form id is environment-specific

Current publisher can build an internal runtime form id using org id and local Salesforce form id.

Therefore:

```text
globalFormKey moves.
runtimeFormId does not move.
publishToken does not move.
publishedPublicUrl does not move.
```

---

## 4. Phase 1 Product UX

### 4.1 Export action

Add an `Export Form` action on the Designer form page.

Export flow:

1. Admin opens a form.
2. Admin clicks `Export Form`.
3. LWC calls Apex `exportForm(formId, versionId)`.
4. Browser downloads JSON.

Recommended file name:

```text
TwinaForms_form22_2026-08-03.json
```

Export success copy:

```text
Form 22 was exported.
Import this file in another org to create Form 22 or add a new version to Form 22.
```

### 4.2 Import action

Add a primary `Import Form` action on Designer Home / Forms list.

Reason: the target org may not yet have the form.

Optional secondary entry:

```text
Designer form page -> Actions -> Import Form
```

Import flow:

1. Admin clicks `Import Form`.
2. Admin selects JSON file.
3. LWC reads file text.
4. LWC calls Apex `inspectImport(packageJson)`.
5. UI shows preview and compatibility report.
6. Admin confirms.
7. LWC calls Apex `importForm(packageJson, options)`.
8. UI opens imported form/new draft version.

---

## 5. Import UX Decision Rules

### 5.1 File must include form number

Required:

```json
{
  "globalFormKey": "form22"
}
```

If missing, block:

```text
This file cannot be imported because it does not include a TwinaForms form number.
Export the form again using the latest TwinaForms version.
```

No legacy/no-number import in V1.

### 5.2 Target org already has the form number

If local `form22` exists:

```text
Import Form 22

This file is for Form 22.
A new draft version will be created for the existing Form 22 in this org.

Current live version will not be changed.
You can review and publish the new version when ready.

[Import as New Version]
```

Implementation behavior:

- Create new `NF_Form_Version__c`.
- Insert imported elements/actions under it.
- Preserve current published version.
- Do not publish automatically.

### 5.3 Target org does not have the form number

If local `form22` does not exist:

```text
Import Form 22

This file is for Form 22.
This org does not have Form 22 yet.

TwinaForms will create Form 22 in this org with a new draft version.

[Create Form 22]
```

Implementation behavior:

- Create new `NF_Form__c`.
- Set its stable form key to `form22`.
- Create first draft version.
- Insert imported elements/actions.
- Do not publish automatically.

### 5.4 Same number but suspicious metadata

If local `form22` exists but title/object/story differs, warn:

```text
A Form 22 already exists in this org, but its details differ from the imported package.

Existing: Event Registration
Import file: Volunteer Registration

Importing will create a new draft version under the existing Form 22.
Current live version will not be changed.
```

V1 should let the admin cancel, but should not silently create another form number.

---

## 6. Data Model Decisions

### 6.1 Global form key

Phase 1 needs a stable cross-org form number.

Current package fact:

```text
NF_Form__c.NF_Key__c is a unique text field and is already used as the published form slug.
```

Preferred implementation options:

1. Reuse `NF_Key__c` if it is already stable, user-facing, package-safe, and unique enough per org.
2. Add `NF_Global_Form_Key__c` if `NF_Key__c` is not stable enough or already overloaded.

Recommended Phase 1 decision:

```text
Use NF_Key__c as globalFormKey.
```

If reusing `NF_Key__c`, exporter maps:

```text
globalFormKey = NF_Form__c.NF_Key__c
```

If adding a field, importer/exporter maps:

```text
globalFormKey = NF_Form__c.NF_Global_Form_Key__c
```

### 6.2 Version export scope

Recommended V1:

```text
Export the selected/current version only.
```

Reason:

- simpler import semantics
- less risk
- enough for sandbox-to-production movement
- rollback already exists locally for published versions

Later AWS snapshots can store every published/release snapshot.

---

## 7. JSON Package Contract

Top-level schema:

```json
{
  "schemaVersion": "linked-env-portable-form-v1",
  "packageType": "twinaformsFormDefinition",
  "exportedAt": "2026-08-03T10:00:00Z",
  "sourceOrgId": "00D...",
  "sourceEnvironmentType": "sandbox",
  "sourcePackageVersion": "0.13.0.1",
  "sourcePublishedUrl": "https://forms.twinaforms.com/acme-sandbox/form22",
  "globalFormKey": "form22",
  "form": {},
  "version": {},
  "elements": [],
  "actions": [],
  "theme": {},
  "assets": [],
  "manifest": {},
  "stripped": {}
}
```

Required:

- `schemaVersion`
- `packageType`
- `exportedAt`
- `sourceOrgId`
- `globalFormKey`
- `form`
- `version`
- `elements`
- `actions`
- `manifest`

Informational only:

- `sourcePublishedUrl`
- `sourcePublishedKey`
- source Salesforce record IDs, if included at all, must be diagnostic-only and never importable

---

## 8. Serializer Design

Use allowlist serialization. Do not serialize whole sObjects.

### 8.1 Form fields

Export portable fields such as:

- form name/description
- stable form key
- project name as source-context only
- status as informational
- theme reference by name/key
- form-level settings

Do not export as importable values:

- `Id`
- `Project__c`
- `Current_Published_Version__c`
- generated/publication state

Project behavior:

```text
Projects are local workspace organization, not part of the cross-org identity.
```

When importing a new local form, the UI must ask for a target project or default to `General` using the
existing project service behavior. When importing into an existing local form, keep that form in its
current target project.

### 8.2 Version fields

Export:

- version number/label as informational
- security mode
- rate-limit profile
- custom CSS/JS
- theme JSON
- UI settings JSON
- prefill params JSON
- PDF/settings where applicable

Do not export as importable values:

- `Id`
- `Form_Id__c`
- `Publish_Token__c`
- publish status as target status
- last published timestamps/users

### 8.3 Elements

Export:

- `Element_Id__c`
- `Element_Type__c`
- `Field_Key__c`
- `Element_Index__c`
- `Label__c`
- `Config_JSON__c`
- `Parent_Element_Id__c`
- `Order__c`

Do not export as target IDs:

- `Id`
- `Form_Version__c`

### 8.4 Actions

Export:

- `Action_Scope__c`
- `Command_Key__c`
- `Command_Type__c`
- `Object_Api_Name__c`
- `Store_Result_As__c`
- `Config_JSON__c`
- `Order__c`

Do not export as target IDs:

- `Id`
- `Form_Version__c`

---

## 9. Manifest Generation

The manifest supports pre-import validation.

It must include every Salesforce object/field reference that can break in the target org.

Scan:

- `NF_Form_Action__c.Object_Api_Name__c`
- action config field mappings
- prefill response mappings
- submit mappings
- lookup target object/search/display fields
- location submit/prefill mappings
- file upload attachment target action/object/field references
- signature attachment target references
- PDF attachment target references
- user verification field/sender settings
- post-submit auto-link settings
- button destination settings
- formula field references to field keys
- conditional visibility references
- layout-created form metadata if present
- custom JavaScript field key references if detectable, warning only

Blocking validation depends on this manifest, so missed references are the highest implementation risk.

---

## 10. Import Inspector

Recommended Apex:

```apex
@AuraEnabled
public static ImportPreview inspectImport(String packageJson)
```

Responsibilities:

1. Parse JSON.
2. Validate `schemaVersion`.
3. Validate required top-level fields.
4. Require `globalFormKey`.
5. Determine whether target org has the form number.
6. Detect duplicate local form keys.
7. Validate target metadata from manifest.
8. Validate package assets.
9. Resolve theme behavior.
10. Return target action and preview.

No DML.

Preview fields:

- `globalFormKey`
- `sourceOrgId`
- `sourceEnvironmentType`
- `sourcePublishedUrl`
- `targetAction`
- `targetFormId`
- `targetFormName`
- `blockingErrors`
- `warnings`
- `missingObjects`
- `missingFields`
- `themeAction`
- `imageAction`
- `targetProjectAction`
- `buttonTargetActions`

---

## 11. Importer

Recommended Apex:

```apex
@AuraEnabled
public static ImportResult importForm(String packageJson, ImportOptions options)
```

Importer must re-run all validation server-side. Do not trust the preview returned to the browser.

### 11.1 Import existing local form

When local form exists:

1. Lock/resolve local `NF_Form__c` by `globalFormKey`.
2. Compute next version number.
3. Create new draft `NF_Form_Version__c`.
4. Recreate assets.
5. Insert elements.
6. Insert actions.
7. Set `Current_Draft_Version__c` to new version.
8. Return new version id.

Do not update current published version.

### 11.2 Import missing local form

When local form does not exist:

1. Create `NF_Form__c` with `globalFormKey`.
2. Assign selected project or default project (`General`).
3. Create first draft version.
4. Recreate assets.
5. Insert elements.
6. Insert actions.
7. Set current draft.
8. Return new form and version id.

### 11.3 Transaction behavior

Use validation-before-DML and transactional DML. If import fails after DML starts, no partial form should
remain where possible.

If full rollback is not possible for asset creation, record clear cleanup instructions and surface a
handled error.

---

## 12. Compatibility Validation

Blocking errors:

- invalid JSON
- unsupported schema
- missing `globalFormKey`
- duplicate local forms with same key
- missing target object
- missing target field
- incompatible field type for mapped usage
- invalid command type
- invalid action object
- required image asset too large
- corrupted config JSON
- package uses a gated Pro feature unavailable in the target package/org
- button targets a TwinaForms form that cannot be resolved by target form key and no safe URL strategy exists

Warnings:

- source and target environment differ
- source published URL is informational only
- same form number exists but title differs
- theme name exists with different settings
- optional image payload missing
- custom JavaScript may reference org-specific URLs/IDs
- formulas may reference query params or fields that need review
- imported form will be placed in the selected/default target project, not the source project
- user verification sender email may need target-org review

No `Import Anyway` for blocking metadata errors in V1.

---

## 13. Asset Handling

### 13.1 Images

Export image payloads where available and under existing size limits.

Import:

- create target `ContentVersion`
- rewrite image config to target asset reference
- do not preserve source `/sfc/servlet.shepherd` URL as target runtime URL
- warn/block when payload is missing based on whether the image is required

### 13.2 Theme logo

Handle like image assets.

### 13.3 Published asset URLs

`publishedAssetUrl` and S3 URLs are runtime artifacts and must be stripped or treated as source-only
diagnostic fields.

---

## 14. Theme Handling

V1 policy:

```text
reuseByNameOrCreate
```

Rules:

- If same theme name exists, reuse it.
- If settings differ, warn.
- If missing, create a new theme.
- Do not overwrite existing theme settings.

---

## 15. Theme, Asset, And User Reference Handling

This section makes the cross-org handling explicit. These are common places where a sandbox export can
accidentally carry source-org assumptions into production.

### 15.1 Themes

Themes should move by portable theme definition, not by Salesforce record ID.

Export should include:

- stable theme key if available
- theme name
- theme visual tokens/settings
- settings hash
- logo reference metadata
- logo asset payload if available and within size limits

Import behavior:

- If the target org has the same stable theme key, reuse it when settings match.
- If the target org has the same name and same settings hash, reuse it.
- If the same-name target theme has different settings, warn the admin and let the import create an
  imported-copy theme rather than overwrite production silently.
- If the target org does not have the theme, create it.
- Do not overwrite an existing target theme's settings.
- Do not import the source org theme record ID.

Risk:

```text
Sandbox and production may both have a theme named Default, but the settings may differ.
```

V1 mitigation:

```text
Reuse by stable key or name + settings hash, warn on differences, never overwrite target theme silently.
```

Recommended same-name/different-settings copy:

```text
Default Blue (Imported)
```

### 15.2 Image and logo assets

Image elements and theme logos often reference source-org files or source AWS URLs. Those links are not
portable.

Export should include, where available:

- asset logical key
- original file name
- content type
- base64 payload or package asset payload
- source element/theme reference
- original URL as informational only

Import behavior:

- Validate payload size against TwinaForms image limits.
- Prefer creating new target-org `ContentVersion` records for imported image/logo assets.
- Rewrite image element config to target-org asset references.
- Rewrite theme logo config to target-org asset references.
- Do not preserve source `/sfc/servlet.shepherd/...` URLs as target runtime URLs.
- Do not preserve source S3/published asset URLs as target runtime URLs.

If an asset payload is unavailable:

- block if the asset is required for a faithful import
- otherwise warn that the image must be re-added in the target org

V1 should be conservative because broken logos/images make production imports feel untrustworthy.

#### 15.2.1 Checking whether an image already exists in the target org

Unlike themes, images should not be matched by source Salesforce file ID or by source URL. Those values are
org-specific.

Recommended Phase 1 behavior for repeated sandbox-to-production imports:

```text
Reuse only trusted TwinaForms-imported assets with the same content hash.
Otherwise create a new target-org ContentVersion.
```

This avoids creating a new logo on every repeated Form 22 import while still avoiding unsafe file-name or
URL matching.

Asset package shape:

Export each asset with a content hash:

```json
{
  "assetKey": "asset_logo_1",
  "fileName": "logo.png",
  "contentType": "image/png",
  "contentSha256": "abc123...",
  "base64": "..."
}
```

On import, search only TwinaForms-created target assets that store the same hash in metadata.

Reuse only if all of these match:

   - same `contentSha256`
   - same `contentType`
   - same file size
   - asset was previously created by TwinaForms import/export, not an arbitrary customer file

If no trusted matching asset is found, create a new `ContentVersion`.

Do not use these as primary matching criteria:

- source `ContentDocumentId`
- source `ContentVersionId`
- source `/sfc/servlet.shepherd/...` URL
- source S3 URL
- file name alone

Reason:

```text
Two orgs can have different files with the same name.
The same source file ID does not exist in production.
Source URLs are not valid target-org runtime links.
```

If Phase 1 cannot add a trusted asset registry quickly, fallback is to recreate assets every time. That is
safe but creates duplicate logos/images after repeated imports.

Recommended target metadata for imported assets:

```text
TwinaForms asset hash
TwinaForms source package id/hash
Imported by TwinaForms
Imported at
```

If no place exists to store this metadata on Salesforce Files cleanly, keep a small package-owned asset
registry object or package-owned metadata record keyed by `contentSha256`.

### 15.3 User, owner, and audit references

User and owner IDs are org-specific and must not move as record references.

Do not import:

- `OwnerId`
- `CreatedById`
- `LastModifiedById`
- `Last_Published_By__c`
- source user IDs in publication/audit records

Export may include user names/emails only as informational diagnostics if useful, but they must not drive
target record ownership.

Import behavior:

- New records are created by the importing admin/running user.
- Target org ownership follows normal Salesforce defaults or explicit package logic.
- Publication history is not imported.
- Source audit data is not treated as target audit data.

### 15.4 Form creator/admin expectation

The import preview should explain:

```text
Themes are matched by name or created if missing.
Images are recreated in this org when the export includes the image file.
Source owners, published links, and audit history are not copied.
```

---

## 16. Other Cross-Org References To Manage

The importer must treat object/field metadata differently from org-specific records and runtime artifacts.

### 16.1 Record IDs and runtime IDs that must not move

Strip or remap these values:

- Salesforce record IDs
- `OwnerId`
- `CreatedById`
- `LastModifiedById`
- `RecordTypeId`
- `ContentDocumentId`
- `ContentVersionId`
- default Campaign IDs
- default lookup record IDs
- submit target record IDs
- prefill `recordId` examples/defaults
- button `targetFormId`
- published form IDs
- publish tokens
- S3 keys
- published asset URLs
- AWS response JSON

### 16.2 Metadata references that can move by API name

These are portable when the target org has the same metadata:

- object API names
- field API names
- record type developer names
- lookup target object API names
- picklist API values
- submit/prefill action definitions
- conditional rules using field keys
- formula references using field keys

If a current config stores record type IDs, export should try to translate them to record type developer
names. Import should resolve the target org's record type ID by developer name only if needed locally.

### 16.3 Additional file/asset surfaces

Scan and handle:

- image elements
- theme logos
- PDF logo/header images
- rich text / Display Text images
- Merged Document embedded images, if supported
- file upload sample/default files, if such config exists later
- static resources, if future features rely on them

Binary assets move by content payload and content hash, not by source org file ID or URL.

### 16.5 Button targets between TwinaForms forms

Current Designer lets a button target another published TwinaForms form using local `targetFormId`.
Current publish rewrites that design-time target into a runtime `destinationUrl` and removes the local
target ID from the published artifact.

Cross-org import must not preserve the source `targetFormId`, because it is the sandbox form's Salesforce
record ID.

Export behavior:

- If a button has `destinationType = form` and `targetFormId`, resolve the target form's `NF_Key__c`.
- Export a portable target reference such as `targetGlobalFormKey`.
- Keep the source `destinationUrl` as diagnostic-only if useful.
- Do not treat a source published URL as the target production URL.

Import behavior:

- If the target org already has a form with `targetGlobalFormKey`, rewrite the button config to the
  target org's local `targetFormId`.
- If the target form is missing locally, warn or block based on final product decision.
- If the button has only a source `destinationUrl`, warn because it may point to the source environment.

Recommended V1 policy:

```text
Block form-to-form button targets when targetGlobalFormKey cannot be resolved in the target org.
```

Reason:

```text
A production form that navigates back to a sandbox form is a high-trust failure.
```

### 16.6 Package feature gates and plan safety

The current Salesforce package gates several designer/publish features through `NativeFormsFeatureFlags`.
Import validation must check these gates before creating records.

Examples:

- Records List / repeat groups
- File Upload
- Electronic Signature
- Submission PDF
- Merged Document
- Survey fields
- Location fields
- Formula fields
- Post-submit auto-link
- Salesforce user verification
- Custom JavaScript
- Button elements
- Advanced submit modes

If the imported package uses a feature disabled in the target org/package, V1 should block before DML.

### 16.7 User verification and org email settings

`UI_Settings_JSON__c` can include user verification settings such as `userVerificationSenderEmail`.

Portable:

- enabled/disabled setting
- match field key/API-name intent
- text labels/messages
- expiry and retry settings

Needs target-org validation or warning:

- sender email address
- match field existence/type
- any email identity assumption

Recommended V1 policy:

```text
Warn when a sender email is present and differs from the target default sender email.
Block only if publish/runtime requires a target-verified sender and validation can prove it is missing.
```

### 16.8 Post-submit URLs and Salesforce formula guidance

`UI_Settings_JSON__c` and button configs may contain post-submit URLs, URL templates, or formulas.

Import should scan these for:

- source TwinaForms published URLs
- source Salesforce instance URLs
- hardcoded sandbox/prod slugs
- Salesforce ID-looking query parameter values

These are warnings unless they become actual write targets or form-to-form navigation targets that cannot
be safely resolved.

The import preview should connect this warning to the documented Salesforce formula pattern:

```text
Use $Organization.IsSandbox when a Salesforce formula/button/template must choose between sandbox and
production TwinaForms links.
```

### 16.4 Hidden ID scanner

The highest risk is org-specific IDs hidden inside `Config_JSON__c`, `UI_Settings_JSON__c`, theme JSON,
custom JavaScript, rich text HTML, or button URLs.

Add a portability scanner that reports:

- Salesforce 15-character or 18-character ID-looking values
- source-org `/sfc/servlet.shepherd/...` URLs
- source Salesforce instance URLs
- source published TwinaForms URLs
- S3/published asset URLs
- hardcoded record IDs inside query parameters

Blocking findings:

- mapped object/field missing
- record type referenced only by source ID and no developer-name mapping exists
- required file/image payload missing
- action target uses a source record ID as an actual write target

Warning findings:

- custom JavaScript contains a source org URL
- rich text contains a source org file URL
- hidden field default contains a possible Salesforce ID
- button URL contains a sandbox published link
- formula/config contains an ID-like literal that cannot be classified

The preview should show these findings before import. Do not bury them in debug logs.

---

## 17. Published Link Guidance In UI

Import/export UI must explain:

```text
The form number is preserved.
The source published link is not copied.
This org will generate its own link when you publish.
```

If the admin uses TwinaForms links in Salesforce formulas/buttons/templates, show the recommended pattern:

```text
IF(
  $Organization.IsSandbox,
  "https://forms.twinaforms.com/acme-sandbox/form22",
  "https://forms.twinaforms.com/acme/form22"
)
```

This should appear in:

- export success help
- import preview help
- import success help
- future `Copy Salesforce Formula` action

---

## 18. LWC Design

Likely changes:

- `nativeFormsDesigner.html`
- `nativeFormsDesigner.js`
- `nativeFormsDesigner.css`

New UI state:

- selected import file name
- package JSON text
- import preview
- import errors
- import warnings
- importing/exporting flags

New handlers:

- `handleExportForm`
- `handleImportFormClick`
- `handleImportFileSelected`
- `handleInspectImport`
- `handleConfirmImport`

Client-side parsing can provide quick file validation, but Apex remains authoritative.

---

## 19. Apex Classes

Recommended new classes:

```text
NativeFormsFormPortabilityController
NativeFormsFormPortabilityControllerTest
```

Optional helper classes if the controller becomes too large:

```text
NativeFormsFormPackageSerializer
NativeFormsFormPackageImporter
NativeFormsFormPackageValidator
```

Package-visible LWC calls should prefer primitive/String parameters over custom DTO input parameters to
avoid managed-package DTO binding fragility.

Good method boundary:

```apex
exportForm(Id formId, Id versionId) -> String
inspectImport(String packageJson) -> String serialized preview DTO
importForm(String packageJson, String optionsJson) -> String serialized result DTO
```

Returning JSON strings is less elegant but may be safer for managed LWC/Apex boundaries.

---

## 20. Security Review Notes

Security-sensitive rules:

- Do not include secrets in JSON.
- Do not include publish tokens.
- Do not include protected package settings.
- Do not trust imported object/field names without describe validation.
- Do not execute imported custom JavaScript during import preview.
- Use customer-safe errors.
- Use user-mode CRUD/FLS patterns for normal package data.
- Keep any system-context exception narrow and documented if needed.

This feature moves configuration between orgs, not Salesforce business data.

---

## 21. Test Plan

### 21.1 Unit tests

Required:

- export requires/read form and version
- export includes `globalFormKey`
- export includes manifest
- export strips runtime artifacts
- inspect rejects missing `globalFormKey`
- inspect rejects invalid schema
- inspect returns `createForm` when key missing locally
- inspect returns `createVersion` when key exists locally
- inspect blocks missing object
- inspect blocks missing field
- import creates new local form with same key
- import places new local form in selected/default project
- import into existing local form keeps existing target project
- import creates new draft version under existing key
- import does not alter current published version
- import handles suspicious same-key metadata warning
- import blocks duplicate local key records
- theme reuse
- theme create
- image recreate
- published URL is informational and not imported
- source owner/user IDs are not imported
- theme same-name mismatch produces warning
- missing required image payload blocks or warns per final product decision
- identical imported image/logo content reuses trusted hash-matched target asset
- filename-only image match does not reuse arbitrary target file
- hidden ID scanner reports Salesforce ID-looking literals in config JSON
- record type developer-name mapping works or blocks when unresolved
- button targetFormId exports as targetGlobalFormKey and imports as the target org's local form id
- unresolved form-to-form button target blocks or warns per final V1 policy
- Pro feature gate mismatch blocks before DML
- user verification sender email mismatch warns

### 21.2 Manual tests

Required:

1. Export sandbox Form 22.
2. Import in production org with no Form 22; verify production Form 22 is created.
3. Import again in same production org; verify new draft version is created.
4. Publish production draft; verify production gets its own URL.
5. Restore older published production version using existing restore feature; verify rollback flow still works.
6. Remove target field and verify import blocks before records are created.
7. Import image form and verify images work after publish.
8. Verify source published URL is displayed as informational only.
9. Import a form with a source theme/logo and verify target theme/logo behavior.
10. Verify created target records are owned by the importing user/default target org behavior, not source users.
11. Repeat-import a form with the same logo and verify hash-based reuse or documented duplicate behavior.
12. Import a form with a hardcoded sandbox record ID in config and verify warning/blocking behavior.

---

## 22. Implementation Order

Recommended order:

### 22.1 Pre-coding decisions

Close these before implementation starts:

1. Use `NF_Key__c` as `globalFormKey` for Phase 1.
2. Export the selected/current version only.
3. Default newly imported forms to the existing/default `General` project unless the first UI slice can cheaply offer project selection.
4. Warn for missing optional image payloads; block for required visible image/logo payloads when the import would otherwise create a broken production form.
5. Treat same-name theme setting differences as warning-only, and create an imported-copy theme rather than overwriting target theme settings.
6. Defer trusted asset hash reuse in the first coding slice if no clean storage location exists; recreate assets and document possible duplicate files for V1.
7. Block unresolved form-to-form button targets in V1.
8. Place `Export Form` on the Designer form page.
9. Place primary `Import Form` on Designer Home / Forms list, because the target org may not yet have the form.

### 22.2 First coding slice

Build the smallest package-safe Apex vertical slice first, without images/themes/UI polish:

1. Add `NativeFormsFormPortabilityController`.
2. Add methods with managed-package-safe primitive/String boundaries:
   - `exportForm(Id formId, Id versionId) -> String`
   - `inspectImport(String packageJson) -> String`
   - `importForm(String packageJson, String optionsJson) -> String`
3. Add internal DTO/helper classes only if they stay package-safe and reduce controller size.
4. Build allowlist serializer for form, selected/current version, elements, and actions.
5. Strip runtime/source-org artifacts during export: record IDs, `Form_Id__c`, publish tokens, publication state, source published URLs as importable values, Salesforce file IDs, S3 keys, and owner/audit IDs.
6. Build manifest generation for object/field references that are already easy to discover from actions, mappings, formula references, conditional references, lookup config, and button config.
7. Build schema validation and import preview with no DML.
8. Build metadata compatibility validation for missing objects/fields and unsupported schema/package types.
9. Build importer for missing local form: create `NF_Form__c` with `NF_Key__c = globalFormKey`, default/selected project, first draft version, elements, and actions.
10. Build importer for existing local form: create a new draft version and set `Current_Draft_Version__c`, without changing current published version.
11. Add a basic hidden ID/source URL scanner that reports Salesforce ID-looking values, `/sfc/servlet.shepherd` URLs, Salesforce instance URLs, source TwinaForms published URLs, S3/published asset URLs, and hardcoded ID-looking query params.
12. Add focused Apex tests for export, inspect, import-new-form, import-existing-form, published-version safety, missing metadata blocks, runtime artifact stripping, and hidden-ID warnings.

### 22.3 Second coding slice

After the first slice is stable:

1. Add theme handling: reuse exact match, create missing theme, create imported-copy theme for same-name/different-settings.
2. Add image/logo payload export and target-org `ContentVersion` recreation.
3. Decide whether to add trusted asset hash storage or keep V1 duplicate-file behavior documented.
4. Add form-to-form button target export/import by `targetGlobalFormKey`; block unresolved targets.
5. Expand tests for theme, image/logo, button targets, feature gates, user verification sender warnings, and record type developer-name mapping.

### 22.4 UI slice

After Apex behavior is covered:

1. Add Designer page `Export Form` action.
2. Add Designer Home / Forms list `Import Form` action.
3. Add import file picker, preview, warnings/errors, and confirm flow.
4. Show customer-safe published-link guidance:
   - form number is preserved
   - source published link is not copied
   - target org gets its own link after publish
5. Open the imported form/new draft version after successful import.

### 22.5 Release validation

Before calling Phase 1 done:

1. Run Apex tests.
2. Run clean-org or scratch-org smoke tests for new-form import, existing-form import, publish after import, missing-field block, source URL warning, and rollback via existing Restore From Published.
3. Verify package-visible UI and Apex boundaries do not rely on custom DTO input parameters.
4. Update `skills/project-nativeforms/architecture.md` and `skills/salesforce/packaging.md` if implementation changes any stable operating rule.

---

## 23. Phase 2 Readiness

Phase 2 AWS snapshots should reuse:

- same JSON schema
- same manifest
- same inspector
- same compatibility validator
- same importer

Phase 2 changes only the package source:

```text
Phase 1: uploaded local JSON file
Phase 2: AWS snapshot JSON
```

The target behavior stays:

```text
If form number exists locally, create new draft version.
If form number is missing locally, create local counterpart with same number.
```

---

## 24. Resolved Build Defaults

Use these defaults when coding Phase 1 unless implementation proves one is package-unsafe:

- Reuse `NF_Key__c` as `globalFormKey`.
- Export the selected/current version only.
- Default newly imported forms to the existing/default `General` project unless project selection is included in the first UI slice.
- Warn for missing optional image payloads; block for required visible image/logo payloads.
- Treat theme settings differences as warning-only and create imported-copy themes instead of overwriting target themes.
- Block unresolved form-to-form button targets in V1.
- Put `Export Form` on the Designer form page.
- Put primary `Import Form` on Designer Home / Forms list.

Deferred implementation choice:

- Trusted imported asset hash reuse may be postponed if no clean storage location exists. The safe V1 fallback is to recreate imported assets and document possible duplicate files.
