# Pro Features For Started

## Purpose
Define the Pro V1 design for `File Uploads` as the next Pro-only capability built on the existing plan feature flag `enableProLoadFile`.

This document is intentionally limited to:
- Pro V1 file uploads
- product framing
- UX direction
- trust and entitlement model
- implementation shape for a later build

It does not include later-scope ideas such as repeat-group uploads, richer previews, or broader storage tooling. Those move to `Pro features for later.md`.

---

## Product Rule

### Customer-facing name
Use:
- `File Uploads`
- `File Upload`
- `Upload files`

Do not use `File Load Support` in customer-facing product, UX, or admin-facing copy.

### Internal flag compatibility
Keep the existing internal feature flag key:
- `enableProLoadFile`

This key already exists in:
- AWS `NativeFormsPlans.featureFlags`
- the AWS admin console
- AWS runtime feature metadata
- current Salesforce config metadata

The internal key stays unchanged for compatibility.
Only the human-facing label changes to `File Uploads`.

---

## Entitlement Source Of Truth

### Canonical entitlement
For Pro V1 file uploads, the source of truth is:
- `NativeFormsPlans.featureFlags.enableProLoadFile`

AWS plan data remains the runtime authority.

### What this means
- the AWS admin console continues to manage the same feature flag
- AWS runtime must enforce the flag server-side
- published runtime must not trust Salesforce UI toggles by themselves
- Salesforce must not become a second commercial entitlement source

### Salesforce note
`NativeForms_Config__c.Enable_Pro_Load_File__c` may remain temporarily for:
- local diagnostics
- legacy testing UI
- temporary fallback behavior if explicitly needed

But it is not the authoritative entitlement decision for public runtime behavior.

---

## Pro V1 Scope

### Included in V1
- Pro-only `File Upload` field type in the Designer
- top-level file-upload fields only
- public published forms
- secure-edit forms
- upload on file selection
- staged upload before final submit
- final storage as Salesforce Files
- admin-selected target submit action per upload field
- customer-safe upload validation and failure messages

### Explicitly not in V1
- repeat-group file uploads
- per-row uploads inside repeat groups
- image thumbnails / image previews
- advanced admin storage and cleanup tools
- automatic target inference
- non-Salesforce final storage as the business record of truth

---

## UX Direction

### Designer
Add a new Pro-only field type:
- `File Upload`

Field settings for V1:
- label
- help text
- required
- allow multiple files
- allowed extensions
- max file size per file
- target submit action
- optional conditional visibility using existing condition behavior

If the org is not entitled:
- show locked / upgrade treatment
- do not show a broken field
- use upgrade-safe language, not technical flag wording

### Runtime
The runtime should show:
- a dropzone area
- a `Browse files` action
- visible file rules under the field
- a file list after selection
- per-file states:
  - uploading
  - ready
  - failed
- remove / retry before submit

### Error style
Customer-safe examples:
- `This file type is not allowed.`
- `This file is larger than the allowed size.`
- `We could not upload this file. Please try again.`

Technical detail should stay in admin logs rather than public runtime copy.

---

## Data Flow

### Final business record of truth
Uploaded files end as Salesforce Files.

### Upload timing
Actual file transfer happens on selection, not only on final submit.

### Flow
1. User selects a file in the published runtime.
2. Runtime requests AWS upload-init for that form and field.
3. AWS validates:
   - form publish token
   - form status
   - tenant status
   - `enableProLoadFile`
   - field rules
4. File uploads into temporary AWS staging storage.
5. Runtime stores upload references locally for submit.
6. Final submit sends upload references, not raw file bytes.
7. Submit Lambda validates those references belong to the same form, session, and field.
8. After the chosen submit action succeeds and returns a usable record id, runtime finalizes the staged file into Salesforce Files linked to that record.
9. If submit fails, staged files are not finalized to Salesforce.

### Required bucket CORS
Because Pro V1 uses browser-to-S3 presigned `PUT` uploads from `https://forms.twinaforms.com`, the `nativeformspublish` bucket must allow CORS for that origin.

Required rule for V1:
- allowed origin: `https://forms.twinaforms.com`
- allowed methods: `PUT`, `GET`, `HEAD`
- allowed headers: `*`
- exposed headers: `ETag`, `x-amz-request-id`, `x-amz-id-2`

If that bucket CORS rule is missing, upload-init can still succeed, but the browser upload step fails with a generic `Failed to fetch` message.

---

## Attachment Targeting

### V1 rule
Each file-upload field must explicitly choose a target submit action.

### Allowed targets
V1 should allow only submit actions that produce one stable record id, such as:
- create
- update
- find-and-update
- update-by-id

### Not allowed in V1
- `upsertMany`
- repeat-group row targets
- targets without a stable resulting record id

### Reason
This keeps attachment behavior predictable, customer-safe, and debuggable.

---

## Security And Trust

### Core rule
Public runtime must never receive:
- tenant bearer secrets
- Salesforce client secrets
- direct Salesforce upload credentials

### Trust boundary
As with other runtime operations:
- browser sends only user input and upload references
- AWS validates the stored server-side definition and plan entitlement
- AWS performs the privileged work

### Enforcement expectations
Server-side enforcement must cover:
- Pro entitlement via `enableProLoadFile`
- allowed extension list
- file-size limits
- multiplicity rules
- upload token expiry
- upload reference ownership by form/session/field

---

## Implementation Direction

### Salesforce side
- add a `File Upload` element type to the Designer model
- add config for:
  - `allowMultiple`
  - `allowedExtensions`
  - `maxFileSizeMb`
  - `targetSubmitActionKey`
- publish file-upload field definitions into the AWS form security/runtime definition
- keep plan truth external to Salesforce entitlement toggles

### AWS side
- add upload-init capability for published forms
- stage uploaded files temporarily in AWS
- enforce `enableProLoadFile` on upload-init and on final submit-linked file acceptance
- finalize files to Salesforce Files only after successful submit target completion

---

## Acceptance Criteria

### Plan and admin
- `enableProLoadFile` remains the internal flag key
- admin-facing product label says `File Uploads`
- Starter keeps the feature off
- Pro keeps the feature on
- runtime entitlement is enforced from AWS plan data

### UX
- Pro org can use `File Upload` in the Designer
- non-Pro org gets locked / upgrade treatment
- runtime supports upload on selection and remove/retry before submit

### Submit behavior
- created-record flow attaches files to the selected target record
- updated-record flow attaches files to the selected target record
- failed submit does not finalize staged files to Salesforce

---

## Notes
- This document is Pro V1 only.
- Later-scope items move to `AWS/documentation/Pro features for later.md`.
