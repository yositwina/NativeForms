# Linked Sandbox/Production Forms - Phase 2 Portability Design

**Status:** Slices 1-3 implemented and deployed to DevHub; feature/plan UX and QA pack remain
**Scope:** Theme/logo/asset portability, richer compatibility preview, and clearer operational errors
**Out of scope for Phase 2:** Integrity hash/checksum, signed packages, stronger form fingerprint identity
**Parent docs:**
- `Linked_Sandbox_Production_Forms.md`
- `Linked_Sandbox_Production_Phase1_Implementation_Design.md`
- `Linked_Sandbox_Production_Phase1_Manual_Import_Export_Design.md`

---

## 1. Goal

Phase 1 made forms portable by form number and Salesforce metadata:

```text
globalFormKey identifies the target form.
manifest.objects and manifest.fields validate Salesforce compatibility.
import creates a new draft version and never overwrites a published version.
```

Phase 2 should make exported forms visually and operationally portable:

```text
Themes move with the form.
Logos/images move with the form.
Import preview explains theme/asset/feature compatibility before insert.
Storage/limit failures become clear product messages.
```

Phase 2 should keep the manual JSON file workflow. It should not introduce linked AWS promotion yet.

---

## 2. Explicit Phase 2 Decisions

### 2.1 No integrity hash in Phase 2

Do not add checksum/hash/signature in this phase.

Reason:

- Current import is admin-only and already shows the target form number before import.
- The immediate customer value is theme/logo portability, not tamper detection.
- Hashing requires canonical JSON rules and support expectations that are better handled later.

Possible future phase:

```text
Phase 3: integrity.payloadHash, signed packages, tamper warnings.
```

### 2.2 No stronger form identity in Phase 2

Continue matching target forms by:

```text
globalFormKey -> NF_Form__c.NF_Key__c
```

Reason:

- The product promise is still "same form number across orgs."
- Current preview now distinguishes current form, different existing form, and new form.
- Stronger identity/fingerprints are trust hardening, not required for visual portability.

### 2.3 Theme/assets are compatibility concerns, not identity concerns

Themes and logos should help the imported form look right. They should not determine whether the target
form is the same business form.

### 2.4 Confirmed package storage decisions

Themes are stored as reusable Salesforce records:

```text
NF_Form__c.Theme__c -> NF_Theme__c
```

`NF_Form_Version__c.Theme_JSON__c` exists, but Phase 2 should treat it as a compatibility/fallback
snapshot, not as the primary reusable theme store.

Theme logos are stored in Salesforce Files:

```text
ContentVersion.FirstPublishLocationId = NF_Theme__c.Id
NF_Theme__c.Logo_Content_Document_Id__c = ContentDocumentId
NF_Theme__c.Logo_URL__c = /sfc/servlet.shepherd/version/download/{ContentVersionId}
```

Image elements are also stored in Salesforce Files:

```text
ContentVersion.FirstPublishLocationId = NF_Form_Version__c.Id
NF_Form_Element__c.Config_JSON__c.contentDocumentId
NF_Form_Element__c.Config_JSON__c.contentVersionId
NF_Form_Element__c.Config_JSON__c.imageUrl
```

Phase 2 import must use these same Salesforce storage mechanisms.

### 2.5 Confirmed import policy decisions

- Do not add new Phase 2 image size limits. Import should respect the package's existing upload/file
  validation. Current embedded logo/image uploads are limited to 69 KB by the package.
- External image URLs are not allowed. Export should not package external images, and import should not
  keep, fetch, or rewrite external image URLs.
- Unavailable Pro/package features should not block import. Import should create a draft and show warnings
  so the admin can review/fix before publish.
- Theme conflicts should be resolved by asking the admin in the preview, not by silently overwriting or
  automatically copying without confirmation.

---

## 3. Current Phase 1 Behavior

### 3.1 Export payload today

Current export includes:

- `schemaVersion`
- `packageType`
- `globalFormKey`
- `form`
- `version`
- `elements`
- `actions`
- `manifest.objects`
- `manifest.fields`
- `theme` currently empty
- `assets` currently empty
- `stripped` summary

### 3.2 Import target selection today

If local form with same key exists:

```text
Create a new Draft version for that existing form.
```

If local form with same key does not exist:

```text
Create a new form and first Draft version.
```

### 3.3 Current gaps

- Theme is not portable.
- Logo/image assets are not portable.
- Image/file URLs inside configs are not rewritten to target-org assets.
- Missing theme/assets do not have actionable preview rows.
- Storage errors can surface as raw Salesforce messages.
- Feature/plan compatibility is not yet shown.

---

## 4. Phase 2 Export Contract

Phase 2 should evolve the payload without breaking Phase 1 imports.

### 4.1 Schema version

Recommended:

```json
{
  "schemaVersion": "linked-env-portable-form-v2"
}
```

The importer should continue to support v1 for older files.

Import behavior:

- v1: supported, no portable theme/assets.
- v2: supported, validates theme/assets/features.
- unknown version: blocked.

### 4.2 Theme block

Add a portable theme block.

Example:

```json
"theme": {
  "portableThemeKey": "theme-form35-2026-08-04",
  "sourceThemeId": "a07...",
  "name": "Blue Volunteer Theme",
  "tokens": {
    "primaryColor": "#1B96FF",
    "buttonColor": "#1B96FF",
    "backgroundColor": "#FFFFFF",
    "fontFamily": "Inter"
  },
  "versionThemeJson": "{...}"
}
```

Rules:

- `sourceThemeId` is informational only and must not be used as a target lookup.
- `portableThemeKey` is the cross-org match key if available.
- `tokens` are the portable source of truth.
- `versionThemeJson` is allowed as a compatibility bridge if existing runtime uses JSON settings.

### 4.3 Asset block

Add portable assets for logos/images used by the form.

Example:

```json
"assets": [
  {
    "assetKey": "logo-main",
    "usage": "logo",
    "fileName": "logo.png",
    "contentType": "image/png",
    "sourceUrl": null,
    "base64": "iVBORw0KGgo...",
    "sizeBytes": 18422
  }
]
```

Rules:

- `assetKey` must be stable inside the export.
- `base64` is included only for supported image sizes.
- `sourceUrl` is informational and should not be imported as a target runtime URL.
- Import uploads assets to the target org or target TwinaForms asset store, then rewrites configs.

### 4.4 Manifest v2

Extend manifest:

```json
"manifest": {
  "objects": ["Contact", "Account"],
  "fields": ["Contact.LastName", "Account.Name"],
  "themes": ["theme-form35-2026-08-04"],
  "assets": ["logo-main"],
  "features": ["prefill", "submit", "userVerification", "lookup"],
  "limits": {
    "elementCount": 35,
    "actionCount": 2,
    "assetCount": 1,
    "assetBytes": 18422
  }
}
```

Purpose:

- Show required Salesforce metadata.
- Show required TwinaForms features.
- Estimate data/file storage impact before import.
- Decide which theme/assets will be reused, created, skipped, or blocked.

---

## 5. Theme Import Design

### 5.1 Preview logic

Import preview should calculate:

```text
themeAction = reuseExisting | createTheme | createThemeCopy | useDefault | deferred | blocked
```

Recommended Phase 2 behavior:

| Situation | Preview behavior | Import behavior |
| --- | --- | --- |
| File has no theme | Info: default/current theme will be used | Keep default/imported version theme blank |
| Target has same `portableThemeKey` | Success: reuse existing theme | Link imported version to target theme |
| Target has no matching theme | Info: create imported theme | Create theme and link imported version |
| Same key but materially different tokens | Warning: theme conflict | Default to create copy |
| Theme data malformed | Warning or block, depending severity | Use default or block if required |

### 5.2 Theme storage target

Confirmed:

```text
Create/reuse a TwinaForms NF_Theme__c record in Salesforce and link it through NF_Form__c.Theme__c.
```

Compatibility bridge:

```text
Keep using NF_Form_Version__c.Theme_JSON__c only where the existing runtime/designer expects a version
theme snapshot or fallback.
```

Do not import source Salesforce theme ids as target ids. Source ids are informational only.

### 5.3 Theme conflict copy

If target already has a theme with the same key but different tokens:

```text
Ask admin: Reuse existing theme, create imported copy, or cancel import.
```

Do not silently overwrite target theme records in Phase 2.

---

## 6. Logo/Image Asset Import Design

### 6.1 Supported assets

Phase 2 should support:

- Form logo
- Header/background image if currently represented in version or element config
- Image elements
- Small static images needed by the form definition

Do not support in Phase 2:

- User-uploaded submission files
- Generated PDFs
- Runtime publication files
- External images

### 6.2 Export asset discovery

Exporter should scan:

- `NF_Theme__c` logo fields through `NF_Form__c.Theme__c`
- `NF_Form_Element__c.Config_JSON__c`
- known fields such as `contentDocumentId`, `contentVersionId`, `imageUrl`, and `Logo_Content_Document_Id__c`

For each supported image:

1. Resolve source file/blob if it belongs to TwinaForms/Salesforce.
2. Store it as an `assets[]` entry.
3. Replace source-specific references in config with portable references:

```json
{
  "imageAssetKey": "image-element-3"
}
```

### 6.3 Import asset handling

Importer should:

1. Validate asset count and size using the same constraints as the existing package upload flow.
2. Create target Salesforce Files with `ContentVersion`.
3. Map `assetKey -> targetAssetReference`.
4. Rewrite imported config JSON before inserting elements/version.

Example mapping:

```text
logo-main -> /sfc/servlet.shepherd/version/download/068Target...
```

Theme logo import should create a `ContentVersion` linked to the imported/reused `NF_Theme__c`.
Image element import should create a `ContentVersion` linked to the target `NF_Form_Version__c` and rewrite
the element config keys.

### 6.4 Asset preview states

Preview should show:

| State | Meaning |
| --- | --- |
| `readyToImport` | asset is embedded and within size limits |
| `tooLarge` | asset exceeds the existing package upload limit |
| `unsupportedType` | not an allowed image type |
| `missingContent` | config references an image but export did not include content |
| `externalUrl` | image is external; import will remove/ignore it with a warning |

### 6.5 Size limits

Policy:

```text
No new Phase 2 import-specific limit.
Respect the package's existing upload limits and supported image types.
```

Current package behavior:

```text
Embedded logo/image uploads are limited to 69 KB.
Files are stored in Salesforce Files, so they count against Salesforce File Storage.
The related form, version, element, action, and theme records count against Salesforce Data Storage.
```

---

## 7. Feature/Plan Compatibility

Phase 2 preview should identify required TwinaForms capabilities from the export.

Examples:

- Prefill
- Submit
- User Verification
- File Upload
- E-signature
- Repeat Groups
- Lookup
- Button navigation
- Custom JavaScript
- Submission PDF
- Location fields

Preview behavior:

| Target support | Behavior |
| --- | --- |
| Feature enabled | success |
| Feature disabled but can be enabled | warning |
| Feature unavailable in plan/package | warning; import draft for admin review |

Confirmed Phase 2 rule:

```text
Do not block import because of unavailable Pro/package features.
Warn and create a draft so the admin can review, adjust, and decide whether to publish later.
```

Examples:

- Missing Salesforce field: block.
- Missing Pro feature for file upload: warn.
- Custom JS not enabled: warn.

---

## 8. Import Preview UX

### 8.1 Sections

Preview modal should show:

1. Target result
2. Metadata compatibility
3. Theme
4. Assets
5. Feature/plan compatibility
6. Operational limits
7. File info

### 8.2 Target result colors

Already decided:

- Green: imported file targets the currently selected form.
- Red: imported file targets a different existing form.
- Neutral bold: imported file creates a new form.

### 8.3 Theme section copy

Examples:

```text
Theme
Will import theme: "Blue Volunteer Theme"
```

```text
Theme
Matching theme exists and will be reused: "Blue Volunteer Theme"
```

```text
Theme Warning
Theme with same key exists but has different colors. Choose whether to reuse the existing theme or create an imported copy.
```

### 8.4 Asset section copy

Examples:

```text
Assets
1 logo will be imported.
```

```text
Assets Warning
Header image uses an external URL and will not be imported.
```

```text
Assets Blocked
Logo is 3.4 MB, above the 500 KB limit.
```

### 8.5 Operational limits section

Before import, preview should estimate:

- data records to create
- embedded asset bytes
- current Salesforce data storage remaining if accessible
- current file storage remaining if accessible

If target org storage is full:

```text
Import cannot create the draft because Salesforce Data Storage is full.
Free data records or use another org.
```

This should replace raw Salesforce text like:

```text
storage limit exceeded
```

---

## 9. Backend Implementation Plan

### 9.1 Apex export changes

Extend `NativeFormsFormPortabilityController.exportForm`:

1. Export `schemaVersion = linked-env-portable-form-v2`.
2. Build `theme` from the selected version and theme source.
3. Discover assets from version/element configs.
4. Add asset entries to `assets[]`.
5. Replace target/source-specific asset URLs with portable asset keys in exported configs.
6. Extend `manifest`.

### 9.2 Apex inspect changes

Extend `inspectImport`:

1. Parse v1 and v2.
2. Validate objects/fields as today.
3. Inspect theme action.
4. Inspect asset action.
5. Inspect feature/plan requirements.
6. Inspect operational limits.
7. Return structured preview JSON.

Recommended preview shape:

```json
{
  "targetAction": "createVersion",
  "themePreview": {
    "action": "createTheme",
    "messages": []
  },
  "assetPreview": {
    "assetCount": 1,
    "totalBytes": 18422,
    "blockingErrors": [],
    "warnings": []
  },
  "featurePreview": {
    "blockingErrors": [],
    "warnings": []
  },
  "limitPreview": {
    "estimatedRecords": 38,
    "warnings": []
  }
}
```

### 9.3 Apex import changes

Extend `importForm`:

1. Re-run preview validation server-side.
2. Block on blocking errors.
3. Create/reuse theme, or apply the admin's selected conflict choice.
4. Create/import assets into Salesforce Files.
5. Rewrite version and element config JSON with target asset references.
6. Insert form/version/elements/actions as today.
7. Return created theme/assets info.

Important:

```text
No target published version is changed.
No source org runtime URL/token/id is imported.
```

### 9.4 DML safety

Use savepoints:

```apex
Savepoint sp = Database.setSavepoint();
try {
    create theme;
    create assets;
    create version/elements/actions;
} catch (Exception ex) {
    Database.rollback(sp);
    throw user-safe error;
}
```

This avoids partial imports when asset creation succeeds but form version creation fails.

---

## 10. Error Message Design

Replace raw lower-level errors with user-safe messages.

| Raw condition | User-safe message |
| --- | --- |
| `storage limit exceeded` | `Salesforce Data Storage is full. Import cannot create the draft until data records are deleted or storage is increased.` |
| invalid JSON | `This file is not valid JSON.` |
| unsupported schema | `This export uses an unsupported TwinaForms schema.` |
| missing field | `The target org is missing Contact.Some_Field__c.` |
| unsupported asset type | `Logo cannot be imported because SVG import is not enabled.` |
| asset too large | `Logo is larger than the import limit.` |
| external image URL | `External images are not supported. The image will not be imported.` |

---

## 11. Testing Plan

### 11.1 Unit tests

Add Apex tests for:

- v1 import still works.
- v2 export includes theme manifest.
- v2 export includes asset manifest.
- inspect reports create/reuse/copy theme decisions.
- inspect blocks oversized assets.
- import rewrites asset references.
- storage-limit exceptions are normalized where practical.

### 11.2 QA JSON files

Extend `QA/import-jsons` with:

- theme missing/reuse/copy cases
- logo import case
- oversized asset case
- external image URL case
- missing asset content case
- Pro feature unavailable case

### 11.3 Manual QA

Manual cases:

1. Import same form with theme/logo into same org.
2. Import same form into clean org.
3. Import file with missing target field.
4. Import file with oversized logo.
5. Import while data storage is full.
6. Import from form29 page using form35 file and verify red target warning.

---

## 12. Implementation Questions Before Coding

These questions should be answered before Phase 2 implementation starts.

### 12.1 Theme model

1. Answered: use the dedicated `NF_Theme__c` object linked from `NF_Form__c.Theme__c`.
2. Answered: imported themes should be reusable Salesforce theme records.
3. Answered: if a matching theme exists with different colors, ask the admin in preview.

### 12.2 Logo/image storage

4. Answered: imported logos/images should live in Salesforce Files using the existing upload mechanisms.
5. Answered: file bytes count against Salesforce File Storage; related records count against Salesforce Data Storage.
6. Answered: add no new Phase 2 import-specific limit; respect existing package upload validation.

### 12.3 Asset URL rewriting

7. Answered for known keys: theme logos use `Logo_URL__c` and `Logo_Content_Document_Id__c`; image
   elements use `contentDocumentId`, `contentVersionId`, `imageUrl`, and may later use `publishedAssetUrl`.
8. Answered: external image URLs are not allowed and should not be kept, fetched, or imported.
9. Open: confirm supported file types from the existing upload UI/Apex before implementation.

### 12.4 Feature compatibility

10. Answered: unavailable Pro/package features should not block import.
11. Answered: warn and import draft for admin review.
12. Open: decide during UX implementation whether custom JavaScript needs an additional confirmation message.

### 12.5 UX decisions

13. Answered: the import preview should let the admin choose theme conflict behavior.
14. Recommended: show estimated storage impact before import.
15. Recommended: keep direct file-picker behavior only for now; do not reintroduce paste JSON or visible upload box.

---

## 13. Recommended Phase 2 Build Slices

### Slice 1: Preview foundations

- Done: support v1 and v2 schema parsing.
- Done: export v2 packages with reusable theme foundation, feature manifest, and limit manifest.
- Done: add structured theme/asset/feature/limit preview placeholders.
- Done: improve storage-limit error normalization and rollback failed imports with a savepoint.
- Done: focused DevHub validation passed with `NativeFormsFormPortabilityControllerTest`.

### Slice 2: Theme portability

- Done: export theme tokens from `NF_Theme__c`.
- Done: preview theme action as use default, create, reuse, or ask admin on conflict.
- Done: import/reuse/create `NF_Theme__c` and link it through `NF_Form__c.Theme__c`.
- Done: import preview shows a radio choice for theme conflicts.

### Slice 3: Logo/image portability

- Done: export supported Salesforce Files for image elements and theme logos into `assets[]`.
- Done: empty image elements stay empty and do not create assets.
- Done: source Salesforce file ids/URLs are removed from exported image configs.
- Done: import creates target-org `ContentVersion` records and rewrites image configs.
- Done: theme logo import updates `NF_Theme__c.Logo_Content_Document_Id__c` and `Logo_URL__c`.

### Slice 4: Feature/plan compatibility

- Detect feature requirements.
- Remaining: show feature compatibility warnings in the import preview UI.
- Remaining: keep warning-only behavior for unavailable Pro/package features.

### Slice 5: QA pack and release validation

- Expand `QA/import-jsons`.
- Add Apex tests.
- Run clean-org import tests.

---

## 14. Completion Definition

Phase 2 is complete when:

- A form with theme and logo exports into a v2 package.
- A clean target org can import the form and see the same theme/logo in draft.
- Missing objects/fields still block correctly.
- Theme and asset issues appear in preview before import.
- Storage-limit failures show clear TwinaForms messages.
- Published versions remain untouched.
- Phase 1 v1 files still import.
