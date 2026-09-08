# TwinaForms Form Export / Import JSON Plan

**Status:** Implemented (Phase 1 deployed)

## Summary

Implement Phase 1 only: portable JSON export/import for TwinaForms form definitions.

V1 lets an admin export one form from Designer and import it into another org. Import can either create a new form or add a new draft version to an existing form matched by the portable form key. No AWS broker, no org linking, no one-click Move, and no backward compatibility for older export formats.

Chosen defaults:

- Import supports `New Form` and `Add Draft Version To Existing Form`.
- Missing target metadata blocks import and creates no records.
- Themes are reused by name; created only if missing.
- Images are exported as file payloads where available and recreated as new `ContentVersion` records in the target org.
- Published/runtime artifacts are always stripped and regenerated only when the target form is published.

## Key Changes

### Apex Export / Import API

Add a new Apex controller, recommended name:

`NativeFormsFormPortabilityController`

Expose these methods to LWC:

- `exportForm(Id formId)`  
  Returns a JSON string or DTO containing a complete portable form package.
- `inspectImport(String packageJson)`  
  Parses the uploaded package, validates format, checks target metadata, finds matching theme/form candidates, and returns an import preview report. Performs no DML.
- `importForm(String packageJson, ImportOptions options)`  
  Re-runs validation, blocks on errors, then creates records.

`ImportOptions`:

- `mode`: `newForm` or `newVersion`
- `targetFormId`: required only for `newVersion`
- `projectId`: optional target project for new form
- `themePolicy`: fixed to `reuseByNameOrCreate` for v1
- `imagePolicy`: fixed to `recreateContentVersions` for v1

### Export Package Shape

Export a single JSON package with:

- `schemaVersion`: fixed v1 value, no backward compatibility required
- `exportedAt`, `sourceOrgId`, `sourcePackageVersion`
- `form`: portable fields from `NF_Form__c`
- `theme`: exported `NF_Theme__c` fields needed to recreate appearance
- `versions`: form versions, including UI settings and custom JS
- `elements`: all `NF_Form_Element__c` records for exported versions
- `actions`: all `NF_Form_Action__c` records for exported versions
- `assets`: embedded image payloads for image elements and theme logo where available
- `manifest`: referenced Salesforce objects, fields, record types, layouts, and action mappings

Strip from export/import:

- Salesforce record Ids
- `Publish_Token__c`
- `Current_Published_Version__c`
- publication records
- generated HTML refs
- published form ids
- AWS response JSON
- `publishedAssetUrl`
- source-org `/sfc/servlet.shepherd/...` URLs unless accompanied by exported asset data

### Import Behavior

For `newForm`:

- Create or reuse target theme.
- Create `NF_Form__c` with source `NF_Key__c` preserved when it is unused.
- If the target already has the same `NF_Key__c`, the import preview must require an explicit choice: update the existing form, or create a separate form with a new local key.
- New local keys come from the durable `NF_Admin__c` form-key sequence and are never reused after deletion.
- Preserved numeric keys advance the local sequence when necessary.
- Create one draft version from the selected exported version.
- Insert copied elements/actions with new Salesforce Ids while preserving logical keys: `Element_Id__c`, `Field_Key__c`, `Parent_Element_Id__c`, `Command_Key__c`, aliases, and config JSON.

For `newVersion`:

- Require `targetFormId`.
- Preserve the target form record.
- Create a new inactive/draft version on the target form.
- Insert elements/actions under that new version.
- Do not overwrite published or current draft versions silently.
- Set current draft version only if that matches existing product behavior for new drafts; otherwise leave the imported version available for admin review.

### Validation And Compatibility Report

`inspectImport` and `importForm` must validate:

- Package JSON is valid and v1.
- Required package sections exist.
- Referenced Salesforce objects exist in target org.
- Referenced fields exist on those objects.
- Field types are compatible enough for mapped field usage.
- Action command object names are valid.
- Element field mappings in config JSON point to existing target fields.
- Imported image payloads are within existing image size limits.
- Theme name conflicts are reported.

Block import on missing required metadata. The report should clearly list:

- errors that block import
- warnings that do not block import
- theme action: reused or created
- image action: recreated or missing
- target action: new form or new version

## Designer UI

Add Export / Import actions in `nativeFormsDesigner`.

Export:

- Add an `Export Form` action near existing form actions.
- Calls `exportForm(selectedFormId)`.
- Downloads a `.json` file named like `TwinaForms_<formKey>_<date>.json`.

Import:

- Add an `Import Form` action.
- Admin uploads JSON.
- LWC calls `inspectImport`.
- Show a modal with package summary, compatibility report, target mode choice, optional target form picker, optional project picker, and final Import button.
- Import button disabled while blocking errors exist.
- After import success, refresh Designer workspace and select the imported form/version.

Keep UI text plain:

- `Import creates a draft form version. Publish from this org to create new public runtime artifacts.`
- `Missing Salesforce metadata must be fixed before import.`

## Tests

Apex tests:

- Export includes form, selected versions, elements, actions, theme, manifest, and image references.
- Export excludes publish token, publication records, generated HTML refs, published form id, AWS response JSON, and source org Salesforce Ids.
- Import as new form creates form, draft version, elements, actions, and assigns/reuses theme.
- Import as new version creates a new draft version on an existing target form without overwriting current published version.
- Missing object blocks import with no DML.
- Missing field blocks import with no DML.
- Existing theme name reuses target theme and does not duplicate.
- Missing theme creates a new theme.
- Image payload creates new `ContentVersion` and rewrites image config to target-org URL.
- Invalid JSON and wrong schema version return clean handled errors.
- Config JSON references are scanned for object/field mappings used by prefill, submit, lookup, layout-created forms, file upload target action, signature target action, formulas, and conditional visibility.

Manual smoke tests:

- Export a simple Contact form and import into same org as a new form.
- Export from sandbox and import into production-style org with same metadata.
- Remove one target field and confirm import is blocked before any records are created.
- Import a form with an image and confirm image displays in Designer and published output after republish.
- Import a form with a theme name that already exists and confirm no duplicate theme is created.
- Import as new version and confirm live/published version is untouched.

## Assumptions

- No backward compatibility with old export files.
- No submissions, logs, publication records, or runtime AWS state move.
- No Phase 2 org linking, OAuth environment link, AWS broker, or audit trail in this implementation.
- `NF_Key__c` is the portable identity for matching existing forms unless implementation discovers it is not stable enough; if unstable, add a dedicated immutable exported GUID field before implementing `newVersion`.
- Theme reuse by name is acceptable for v1 even when settings differ; preview warns but does not overwrite target theme.
- Image duplication is acceptable because uploaded images are form content, not shared configuration.
- Import creates draft/inactive content only; admins must review and publish in the target org.
