# Linked Sandbox/Production Forms

**Status:** Partially implemented (Phase 1 portability and Phase 3 snapshot sync deployed; full promotion workflow remains open)
**Area:** Designer + Connect + form portability + environment linking + AWS snapshots + runtime routing
**Core promise:** Same form number across Salesforce sandbox and production, with one-click promotion and rollback.

---

## 1. Feature summary

TwinaForms should let an admin manage the **same form number across Salesforce sandbox and production**.

The admin develops and tests the form in the sandbox org, then promotes that same form to production with
one click. This is not a loose copy/export/import model. It is a linked environment model where both orgs
share one stable TwinaForms form identity.

The key architecture decision is that AWS stores **portable JSON release snapshots** for each linked
environment. Each Salesforce org imports/pulls snapshots into itself. AWS does not directly merge orgs or
move Salesforce records live between orgs.

The product promise:

```text
Same form number across orgs.
Develop in sandbox.
Test fully in sandbox.
Promote the same form to production in one click.
Move production back to sandbox when needed.
Keep production URL stable.
Rollback production if something goes wrong.
```

---

## 2. Admin expectation

The admin thinks in terms of one business form:

```text
Form 22 is our Volunteer Registration form.

I develop Form 22 in sandbox.
I test Form 22 in sandbox.
When ready, I promote Form 22 to production.
If production has a problem, I roll back Form 22 to the previous production version.
```

The admin should not have to think about:

- Salesforce record IDs
- copied forms
- new form numbers
- JSON files
- S3 artifacts
- publish tokens
- rebuilding Salesforce mappings manually

---

## 3. Local editing rule

The operator works only on the form that belongs to the org they are currently in.

- In the Salesforce sandbox org, edits affect only sandbox `Form 22`.
- In the Salesforce production org, edits affect only production `Form 22`.
- Promotion copies the sandbox definition into the production org's local `Form 22`.
- Pullback copies the production definition into the sandbox org's local `Form 22`.
- Old versions remain available in each org.

This is local-org editing with linked form identity and controlled sync between orgs.

Confirmed decision:

```text
The admin never edits the production form while operating from sandbox.
The admin never edits the sandbox form while operating from production.
Each org edits only its own local form records.
```

Technically, promotion and pullback should be implemented as **pulling a portable snapshot** into the
current org as a new local version, not as direct cross-org record mutation.

---

## 4. Example UX

In sandbox:

```text
Form 22
Environment: Sandbox
Sandbox version: v9
Production version: v5
Status: Sandbox has changes not in Production

[Preview Sandbox]
[Compare with Production]
[Promote to Production]
[Pull Production to Sandbox]
[Version History]
```

In production:

```text
Form 22
Environment: Production
Live version: v5
Linked sandbox version: v9
Status: Sandbox has newer changes

[Preview Production]
[Compare with Sandbox]
[Update Production from Sandbox]
[Rollback Production]
[Version History]
```

The wording should make destructive direction clear. In production, prefer `Update Production from Sandbox`
over ambiguous terms such as `Pull Sandbox`.

---

## 5. URL promise

Important correction: **same form number does not mean the exact same full published link in the current
AWS hosting model.**

Current AWS publish behavior builds the hosted key from tenant/company slug plus form slug:

```text
published key = companySlug / formSlug
```

So two linked orgs can share:

```text
globalFormKey = form22
```

while still having different full hosted links because each org has its own tenant/company publishing
context.

Example:

```text
Production: https://forms.twinaforms.com/acme/form22
Sandbox:    https://forms.twinaforms.com/acme-sandbox/form22
```

The Phase 1/Phase 2 promise is therefore:

```text
Same TwinaForms form number across orgs.
Environment-specific published links.
```

Production should keep its own stable production URL:

```text
https://forms.twinaforms.com/acme/form22?A=b
```

Sandbox/test uses its own environment-specific published URL:

```text
https://forms.twinaforms.com/acme-sandbox/form22?A=b
```

No `source=sandbox` parameter is needed for this feature because sandbox and production do not share the
same full hosted link. The link itself already reflects the org/tenant publishing context.

Design implication:

- `globalFormKey` is the cross-org business identity.
- `publishedPublicUrl` is environment-specific runtime output.
- Export/import must preserve the form number, but must not import the source org's published URL as the
  target org's URL.
- Target org publish regenerates its own published link from its own tenant/company slug and runtime
  publish context.

### 5.1 Salesforce formula/button URL guidance

If a Salesforce admin stores or generates a TwinaForms public link in a formula field, button, email
template, custom object field, or automation, the formula must be environment-aware because sandbox and
production links are different.

Recommended formula pattern:

```text
IF(
  $Organization.IsSandbox,
  "https://forms.twinaforms.com/acme-sandbox/form22",
  "https://forms.twinaforms.com/acme/form22"
)
```

Admins can append query parameters after the base URL as needed.

TwinaForms should later make this easier with `Copy Sandbox Link`, `Copy Production Link`, and possibly
`Copy Salesforce Formula` actions, but Phase 1 documentation should clearly show the
`$Organization.IsSandbox` pattern.

---

## 6. Core capabilities

- Same TwinaForms form number across sandbox and production.
- One-click sandbox-to-production promotion.
- One-click production-to-sandbox pullback.
- Compare sandbox vs production before moving.
- Validate destination org metadata before promotion or pullback.
- Create a new destination version instead of overwriting live production.
- Keep previous production versions for rollback.
- Preserve the production URL and public links.
- Keep sandbox and production data, OAuth connections, publish tokens, submissions, and runtime artifacts separate.
- Audit who promoted what, from which version, to which version, and when.

---

## 7. Architecture meaning

This feature requires three separate concepts.

### 7.1 Local Salesforce form

Each org has its own real `NF_Form__c` record.

```text
Sandbox org:
NF_Form__c record A

Production org:
NF_Form__c record B
```

They are different Salesforce records because they live in different orgs.

### 7.2 Global TwinaForms form identity

Both local records share one TwinaForms-owned identity:

```text
globalFormKey = form22
```

This is the user-facing business identity. It is what keeps the form number stable.

Salesforce record IDs are local implementation details only.

### 7.3 Environment link

AWS stores that a sandbox org and production org belong to the same linked environment group.

```text
Environment Group: customer-abc
Sandbox orgId: 00D-sandbox
Production orgId: 00D-production
```

Then AWS can understand:

```text
form22 + sandbox    -> sandbox org local form
form22 + production -> production org local form
```

AWS is not merging orgs. AWS is creating a release bridge between two independent orgs.

### 7.4 Environment-local runtime records

Production and sandbox may share the same `globalFormKey`, but they must still have separate runtime
security records.

Conceptually:

```text
globalFormKey = form22

Production runtime:
  environment = production
  orgId = productionOrgId
  publishToken = production token
  submit/prefill definitions = production definitions

Sandbox runtime:
  environment = sandbox
  orgId = sandboxOrgId
  publishToken = sandbox/test token
  submit/prefill definitions = sandbox definitions
```

This avoids the dangerous failure mode where a sandbox preview accidentally writes to production, or a
production visitor reaches sandbox mappings.

### 7.5 Form number vs runtime link

There are now three different identities to keep separate:

```text
globalFormKey
  User-facing cross-org form number, for example form22.

runtimeFormId
  AWS/Lambda security key embedded in the published HTML.
  Today this may be generated from org id + local Salesforce form id.

publishedPublicUrl
  Full hosted link generated by AWS for the current org/tenant publish context.
  Today this uses tenant/company slug + form slug.
```

Phase 1 export/import should preserve `globalFormKey`, but strip `runtimeFormId`, `publishToken`, and
`publishedPublicUrl`. Those are regenerated or resolved by the target org on publish.

---

## 8. AWS responsibility

AWS should be the authority for:

- environment links
- global form key uniqueness
- sandbox/production pairing
- promotion and pullback authorization
- promotion audit
- runtime environment resolution
- destination compatibility checks that require the destination org connection
- durable release snapshots
- short-lived transfer sessions used during promotion/pullback

AWS should store environment groups, linked form identities, portable release snapshots, and promotion audit
history.

Example environment group:

```json
{
  "environmentGroupId": "envgrp_123",
  "customerName": "Acme",
  "sandboxOrgId": "00DxxxSandbox",
  "productionOrgId": "00DxxxProduction",
  "createdBy": "admin@example.com",
  "status": "active"
}
```

Example linked form identity:

```json
{
  "globalFormKey": "form22",
  "environmentGroupId": "envgrp_123",
  "sandbox": {
    "orgId": "00DxxxSandbox",
    "localFormId": "a01Sandbox",
    "currentVersion": "v9",
    "publishedRuntimeId": "form22",
    "lastSyncedFromProductionVersion": "v5"
  },
  "production": {
    "orgId": "00DxxxProduction",
    "localFormId": "a01Production",
    "currentVersion": "v5",
    "publishedRuntimeId": "form22",
    "lastPromotedFromSandboxVersion": "v8"
  }
}
```

Example promotion audit:

```json
{
  "globalFormKey": "form22",
  "direction": "sandbox_to_production",
  "sourceOrgId": "00DxxxSandbox",
  "sourceVersion": "v9",
  "targetOrgId": "00DxxxProduction",
  "targetVersionCreated": "v6",
  "status": "completed",
  "promotedBy": "admin@example.com",
  "promotedAt": "2026-08-02T10:00:00Z"
}
```

Recommended DynamoDB/storage concepts:

- `NativeFormsEnvironmentGroups`
- `NativeFormsLinkedForms`
- `NativeFormsFormSnapshots`
- `NativeFormsFormReleaseAudits`
- optional short-lived `NativeFormsFormReleasePackages` for in-flight transfer packages

`NativeFormsFormSnapshots` is durable release history. In-flight transfer packages, if separated from
snapshots, should use TTL because they are transport state.

Example environment snapshot:

```json
{
  "snapshotId": "snap_123",
  "environmentGroupId": "envgrp_123",
  "globalFormKey": "form22",
  "environment": "sandbox",
  "sourceOrgId": "00DxxxSandbox",
  "sourceLocalFormId": "a01Sandbox",
  "sourceVersion": "v9",
  "snapshotType": "releaseCandidate",
  "packageSchemaVersion": "v1",
  "packageJsonS3Key": "snapshots/envgrp_123/form22/sandbox/v9.json",
  "packageHash": "sha256...",
  "createdBy": "admin@example.com",
  "createdAt": "2026-08-02T10:00:00Z",
  "status": "active"
}
```

Example production snapshot:

```json
{
  "snapshotId": "snap_456",
  "environmentGroupId": "envgrp_123",
  "globalFormKey": "form22",
  "environment": "production",
  "sourceOrgId": "00DxxxProduction",
  "sourceLocalFormId": "a01Production",
  "sourceVersion": "v5",
  "snapshotType": "published",
  "packageSchemaVersion": "v1",
  "packageJsonS3Key": "snapshots/envgrp_123/form22/production/v5.json",
  "publicUrl": "https://forms.twinaforms.com/acme/form22",
  "createdAt": "2026-08-02T09:00:00Z",
  "status": "active"
}
```

---

## 9. Salesforce responsibility

Salesforce remains the local design authority for:

- editing the local form
- local versions
- elements/actions/settings
- local publish action
- local rollback history

Salesforce should store enough local metadata for the Designer to show linked-environment context without
guessing:

```text
NF_Global_Form_Key__c = form22
NF_Environment_Group_Id__c = envgrp_123
NF_Environment_Type__c = sandbox / production
NF_Linked_Form_Status__c = linked / unlinked / mismatch
```

AWS remains the shared broker because one org cannot reliably see the other org directly.

Salesforce should also expose local environment actions in the Designer and Connect pages:

- `Link Production`
- `Compare with Production`
- `Promote to Production`
- `Pull Production to Sandbox`
- `Update Production from Sandbox`
- `Rollback Production`

The action labels should be environment-aware so the admin always understands which local org will be
changed.

---

## 10. First-time environment linking

The recommended first-time setup starts from the sandbox org because that matches the admin's natural
workflow: build in sandbox first, then link production when ready.

Confirmed decision:

```text
Environment linkage is initiated only from the sandbox org.
```

TwinaForms must know whether the current org is sandbox or production before showing link actions. The
`Link Production` action should appear only when the current org is confirmed as sandbox. In a production
org, the UI can show linked sandbox status and production actions, but it should not offer the first-time
`Link Production` setup flow.

Flow:

1. Admin installs and connects TwinaForms in the sandbox org.
2. Admin creates or opens sandbox `Form 22`.
3. Admin clicks `Link Production` on Connect or in the Designer environment panel.
4. Salesforce sandbox sends a Bootstrap V2 HMAC-signed request to AWS:
   - current sandbox `orgId`
   - current user context where available
   - requested action: `startProductionLink`
   - return URL back to the sandbox org
5. AWS verifies the signed sandbox request and confirms the sandbox tenant is active and connected.
6. AWS starts a Salesforce OAuth authorization flow for the production org.
7. The admin authenticates into production and approves the packaged TwinaForms External Client App.
8. AWS receives the OAuth callback, exchanges the code server-to-server, and verifies the returned
   production `orgId`.
9. AWS verifies that the source/current org is a sandbox and the OAuth-returned org is production.
10. AWS rejects the link if the returned org is the same as the sandbox org, is another sandbox, is already
   linked to another incompatible group, is disabled, or fails tenant/customer checks.
11. AWS stores/updates the production Salesforce connection secret independently from the sandbox secret.
12. AWS calls the production org's Bootstrap V2 endpoint to retrieve that org's HMAC signing secret.
13. AWS creates the Environment Group linking sandbox org and production org.
14. AWS returns the admin to the sandbox Connect/Designer page with linked status.

Result:

```text
Sandbox proved itself through Bootstrap V2 HMAC.
Production proved itself through Salesforce OAuth.
AWS stores the link.
Only then can definitions move.
```

This avoids asking the admin to type production org IDs manually. Typed org IDs can be displayed for
confirmation, but they are not the trust proof.

### 10.1 Detecting sandbox vs production

TwinaForms should capture environment type during tenant registration and OAuth/bootstrap verification.

Preferred sources:

- Salesforce Organization metadata such as `Organization.IsSandbox`, read in Apex and sent during signed
  tenant registration/status calls.
- OAuth identity/context and instance/login URL as supporting evidence only.
- AWS tenant record field such as `environmentType = sandbox | production`.

Do not infer sandbox status only from the login host (`test.salesforce.com`) because My Domain and
Salesforce routing can vary. The source of truth should be Salesforce org metadata when available.

Environment-sensitive UI rules:

- If current org is sandbox and no production link exists: show `Link Production`.
- If current org is sandbox and production link exists: show sandbox edit/test/promote/pullback actions.
- If current org is production and link exists: show production edit/preview/update-from-sandbox/rollback
  actions.
- If current org is production and no link exists: explain that linking starts from the sandbox org.

---

## 11. Authentication and authorization model

This feature uses the existing TwinaForms trust separation.

### 11.1 Tenant/org trust

Each org remains an independent tenant:

- sandbox has its own tenant record
- production has its own tenant record
- sandbox has its own Salesforce OAuth refresh token
- production has its own Salesforce OAuth refresh token
- sandbox has its own Bootstrap V2 HMAC signing secret
- production has its own Bootstrap V2 HMAC signing secret

Do not create one shared Salesforce connection for both orgs.

### 11.2 Link creation trust

Creating an environment link requires proof of control of both orgs:

- current/source org: Bootstrap V2 HMAC-signed package request
- linked/destination org: Salesforce OAuth callback, followed by Bootstrap V2 secret retrieval

AWS should store who created the link and enough org identity metadata for support/audit:

- sandbox org id
- production org id
- Salesforce instance URLs
- connected user id/name/email where available
- created timestamp
- last verified timestamp
- link status

### 11.3 Promotion/pullback trust

Every promotion or pullback request should require:

- signed package-to-AWS request from the current org
- active Environment Group
- current org is one side of the Environment Group
- requested target org is the other side of the same Environment Group
- both tenant records are active enough for the requested operation
- caller has packaged admin permission in the current org
- destination org connection is healthy
- source and target environment types match the requested direction

AWS should reject promotion if the target org was not linked through the stored Environment Group.

Direction rules:

- `sandbox_to_production` requires source `environmentType = sandbox` and target `environmentType =
  production`.
- `production_to_sandbox` requires source `environmentType = production` and target `environmentType =
  sandbox`.
- First-time linking is allowed only from `environmentType = sandbox`.

### 11.4 Public runtime trust

Public runtime still uses form trust:

- environment-specific route/form id
- per-environment publish token or test token
- stored server-side runtime definitions

Public runtime must not use the environment-link trust or tenant HMAC secret.

---

## 12. Global form number lifecycle

The global form number is the foundation of the feature.

Rules:

- `globalFormKey` is TwinaForms-owned and stable across linked orgs.
- Salesforce record IDs are never used as cross-org identity.
- The production public URL is based on `globalFormKey`.
- Creating a production counterpart for sandbox `form22` should preserve `form22`.
- Updating an existing production counterpart should keep `form22`.
- If production already has a different local form with the intended number, the admin must resolve the
  collision explicitly.

First production creation options:

```text
Create production Form 22 from sandbox Form 22
```

or:

```text
Link existing production form to sandbox Form 22
```

In both cases, the admin-facing promise is:

```text
This production form will keep the same form number: form22.
Production URL will remain /form22.
```

Collision handling must be conservative:

- Do not silently assign `form23` or another new number.
- Do not silently attach sandbox `form22` to an unrelated production form.
- Show the existing owner/title/status and ask the admin to choose.

---

## 13. Promotion behavior

Promotion should be implemented as the production org pulling the latest approved sandbox snapshot into
itself.

When the admin clicks `Update Production from Sandbox` in the production org, the system should:

1. Confirm sandbox and production orgs are linked.
2. Confirm the caller is authorized through the current org's package-to-AWS trust.
3. Resolve `globalFormKey = form22`.
4. Resolve the latest sandbox release snapshot for `form22`.
5. Validate the snapshot against production metadata.
6. Show a compare and compatibility report.
7. If valid, the production org imports the snapshot into its local `form22`.
8. Create a new inactive/draft production version.
9. Let the admin review and publish, or optionally publish as a later one-click enhancement.
10. On production publish, save a new production snapshot to AWS.
11. Keep the previous production version/snapshot available for rollback.
12. Write AWS audit history.

Promotion means:

```text
Make production Form 22 match sandbox Form 22.
```

Promotion must not silently overwrite a live production version.

The sandbox org may still show a convenience button named `Promote to Production`, but the safer technical
model is:

```text
Sandbox saves or marks a release snapshot.
Production pulls that snapshot into production.
```

This is easier to explain and safer for ISV review than AWS directly writing production records from a
sandbox-initiated operation.

---

## 14. Promote screen and compatibility report

Promotion should have a release-preview step before any production write.

Example:

```text
Promote Sandbox v11 to Production

Changes:
+ 2 new fields
~ 3 changed labels
~ Submit action changed: Contact.Email -> Contact.Work_Email__c
- 1 removed display block

Compatibility:
✓ All Salesforce objects exist in Production
✓ All mapped fields exist in Production
✓ User Verification is configured
✓ Production connection is healthy

Runtime:
Production URL will remain:
https://forms.twinaforms.com/acme/form22

Sandbox test URL:
https://forms.twinaforms.com/acme-sandbox/form22

Result:
Production will import sandbox snapshot v11 as a new draft.
Current Production v8 will remain available for rollback.
```

The final button should be explicit:

```text
Promote to Production
```

Blocking compatibility errors should create no production records.

Warnings may allow continuation only when the resulting production form remains safe and predictable.

---

## 15. Rollback behavior

Rollback means:

```text
Make production Form 22 match an older production version.
```

Rollback should create a new production version restored from the selected old version. It should not erase
history.

Example:

```text
Production v5 is live.
Production v6 is promoted and has a problem.
Admin rolls back to v5.
TwinaForms creates Production v7, restored from v5, and makes v7 live.
```

The production URL remains:

```text
https://forms.twinaforms.com/acme/form22
```

With AWS snapshots, rollback is snapshot-based:

```text
Production snapshots:
v4
v5
v6

Admin selects Restore v5.
Production imports the v5 snapshot as a new local production version.
```

This keeps rollback independent of whether old local Salesforce records were archived or changed, as long
as the snapshot exists.

---

## 16. Pullback behavior

Pullback means:

```text
Make sandbox Form 22 match current production Form 22.
```

This is useful when production was hotfixed, or when sandbox work became messy and the admin wants to reset
sandbox from the stable production version.

Pullback should also create a new sandbox version instead of deleting sandbox history.

Technically:

```text
Sandbox pulls the latest production snapshot from AWS.
Sandbox imports that snapshot as a new local sandbox version.
```

The preferred button label in sandbox is:

```text
Refresh Sandbox from Production
```

---

## 17. Snapshot behavior

AWS snapshots are the central release artifact for this feature.

Recommended automatic snapshot rules:

- On production publish: always save a production `published` snapshot to AWS.
- On sandbox publish/test-publish: always save a sandbox `testPublished` snapshot to AWS.
- On explicit `Prepare for Production` or `Save Release Snapshot`: save a sandbox `releaseCandidate`
  snapshot.
- On restore/rollback publish: save the resulting production snapshot as a normal new production snapshot.

Avoid saving every small autosave/keystroke as a durable AWS snapshot in V1. Store meaningful release
snapshots.

Snapshot contents:

- form metadata/settings
- version settings
- elements
- actions
- prefill/submit definitions in portable form
- lookup definitions
- conditional rules
- theme/settings
- User Verification settings
- PDF/settings where applicable
- manifest of referenced Salesforce metadata
- embedded image payloads where available

Snapshot must strip:

- Salesforce record IDs
- publish tokens
- publication records
- generated HTML/S3 references
- AWS response JSON
- submissions/logs
- tenant/OAuth/HMAC secrets

The snapshot should be immutable after creation. If the form changes, create a new snapshot.

---

## 18. Compare behavior

Compare should support two levels:

- admin-readable design diff
- technical mapping diff

Admin-readable examples:

- fields added/removed
- labels changed
- sections/groups moved
- required state changed
- verification settings changed
- thank-you/redirect behavior changed
- PDF setting/theme changed

Technical examples:

- prefill commands changed
- submit objects/fields changed
- lookup target object changed
- field mapping changed
- conditional visibility changed
- custom JavaScript changed
- upload/signature/PDF attachment target changed

The compare view should be available before promotion and as a standalone action.

Compare should compare local form state or local version against the linked environment's latest snapshot:

```text
Production compares current production draft/live version to latest sandbox release snapshot.
Sandbox compares current sandbox version to latest production published snapshot.
```

---

## 19. Phase 1 manual import/export UX

Phase 1 is manual and has no AWS environment-link dependency. It is the portability core that later AWS
snapshots will reuse.

User-facing rule:

```text
One button: Import Form.
The selected file must include a TwinaForms form number.
```

No legacy/no-number import is required for V1 of this feature. This is a new feature, so the exported JSON
can require `globalFormKey`.

### 19.1 Export package must include the form number

The exported package must include:

```json
{
  "schemaVersion": "v1",
  "globalFormKey": "form22",
  "sourceEnvironmentType": "sandbox",
  "sourceOrgId": "00D...",
  "sourceFormLabel": "Volunteer Registration"
}
```

The `globalFormKey` is required for sandbox/production-safe import.

### 19.2 Manual import decision logic

After the admin selects a file, TwinaForms inspects the package and checks the current org.

If the current org already has the same form number:

```text
Import Form 22

This file is for Form 22.
A new draft version will be created for the existing Form 22 in this org.

Current live version will not be changed.
You can review and publish the new version when ready.

[Import as New Version]
```

Behavior:

```text
Create new NF_Form_Version__c under existing Form 22.
Create copied elements/actions under that version.
Do not overwrite current version.
Do not publish automatically.
```

If the current org does not have that form number:

```text
Import Form 22

This file is for Form 22.
This org does not have Form 22 yet.

TwinaForms will create Form 22 in this org with a new draft version.

[Create Form 22]
```

Behavior:

```text
Create new NF_Form__c with globalFormKey = form22.
Create a new draft version.
Create elements/actions.
Do not publish automatically.
```

If the current org has the same form number but the imported package appears different:

```text
A Form 22 already exists in this org, but its details differ from the imported package.

Existing: Event Registration
Import file: Volunteer Registration

Importing will create a new draft version under the existing Form 22.
Current live version will not be changed.

[Import as New Version]
[Cancel]
```

If required metadata is missing:

```text
Cannot import Form 22

Missing in this org:
- Contact.Work_Email__c
- Volunteer_Shift__c

No records were created.
Fix the missing metadata and import again.
```

### 19.3 Manual import product rules

- The admin should not choose from many import modes.
- The file's `globalFormKey` decides the default behavior.
- If the form number exists locally, create a new version.
- If the form number does not exist locally, create the local counterpart with the same form number.
- Missing required metadata blocks import before DML.
- Import never publishes automatically.
- Import never silently changes `form22` to `form23`.
- Import never accepts a sandbox/production promotion file without a form number.

This keeps the manual feature aligned with the later AWS snapshot model.

---

## 20. Phase 2 AWS snapshot UX

Phase 2 keeps the same import behavior, but replaces the local JSON file with an AWS snapshot.

Manual Phase 1:

```text
Import Form -> choose JSON file -> create form/version
```

AWS Phase 2:

```text
Import from linked environment -> choose or use latest snapshot -> create form/version
```

Same importer. Different package source.

### 20.1 Existing linked forms

For forms that already exist in both environments, actions should live primarily on the Designer form page.

In sandbox `Form 22`:

```text
[Prepare for Production]
[Compare with Production]
[Refresh Sandbox from Production]
```

In production `Form 22`:

```text
[Update Production from Sandbox]
[Compare with Sandbox]
[Rollback Production]
```

### 20.2 Prepare for Production

In sandbox, `Prepare for Production` creates a release snapshot in AWS.

Flow:

```text
Click Prepare for Production
-> TwinaForms validates sandbox form locally
-> exports portable JSON
-> saves snapshot to AWS as Sandbox Release Candidate
-> shows Ready for Production
```

Message:

```text
Sandbox Form 22 is ready for production.

Snapshot:
Sandbox v9
Created: Aug 3, 2026
Production can now import this version.
```

This action must not write directly to production.

### 20.3 Update Production from Sandbox

In production, `Update Production from Sandbox` pulls the latest approved sandbox snapshot into production.

Flow:

```text
Click Update Production from Sandbox
-> AWS returns latest sandbox snapshot
-> Production validates snapshot against production metadata
-> show compatibility + compare report
-> admin confirms
-> create new production draft version
-> admin reviews/publishes
```

Message:

```text
Update Production Form 22 from Sandbox

This will import Sandbox v9 as a new draft version of Production Form 22.
Current live Production v5 will not be changed.
Production URL will remain /form22.

[Create Production Draft from Sandbox]
```

After import:

```text
Production draft v6 was created from Sandbox v9.
Review and publish when ready.
```

### 20.4 New forms that exist only in sandbox

The first production creation cannot happen from an existing production form page because production does
not yet have that form.

Production needs a Designer Home / Forms list action:

```text
Create from Sandbox
```

or a section:

```text
Ready from Sandbox

Form 22 - Volunteer Registration
Sandbox v9 prepared Aug 3
[Create Production Form 22]
```

Clicking this imports the sandbox snapshot and creates the production counterpart with the same form
number.

Rule:

```text
If current org already has form22 -> import snapshot as new version.
If current org lacks form22 -> create local form22 from the snapshot.
```

### 20.5 New forms that exist only in production

Sandbox may also need to create a local counterpart from production, especially after sandbox refreshes or
when production was created first.

Sandbox Designer Home can show:

```text
Available from Production

Form 18 - Donation Form
Production v5 published Aug 1
[Create Sandbox Form 18]
```

### 20.6 Refresh Sandbox from Production

In sandbox:

```text
Refresh Sandbox Form 22 from Production

This will import the latest Production published snapshot as a new Sandbox draft.
Your current sandbox work will remain in version history.

[Create Sandbox Draft from Production]
```

### 20.7 Rollback Production

Production uses production snapshots:

```text
Rollback Production Form 22

Available production snapshots:
- v5, published Aug 1
- v4, published Jul 20
- v3, published Jul 10

[Restore v4 as New Draft]
```

Behavior:

```text
Production imports old production snapshot as a new draft version.
No URL changes.
No current live version changes until publish.
```

### 20.8 Phase 2 product rules

- Existing-form update/import actions live on the Designer form page.
- New-form discovery lives on Designer Home or the Forms list.
- Sandbox `Prepare for Production` saves an AWS snapshot only.
- Production `Update Production from Sandbox` pulls/imports that snapshot.
- Each org imports into itself.
- No direct cross-org record mutation.
- No file selection in the normal AWS flow.

---

## 21. Runtime link behavior

AWS runtime links remain environment-specific.

Production and sandbox do not share one hosted link. They share the TwinaForms form number, while each org
has its own published URL and runtime security record.

```text
Production:
globalFormKey = form22
publishedPublicUrl = https://forms.twinaforms.com/acme/form22
runtimeFormId = production-specific
publishToken = production-specific
```

```text
Sandbox:
globalFormKey = form22
publishedPublicUrl = https://forms.twinaforms.com/acme-sandbox/form22
runtimeFormId = sandbox-specific
publishToken = sandbox-specific
```

Rules:

- No `source=sandbox` parameter is needed.
- Production URL serves production runtime only.
- Sandbox URL serves sandbox runtime only.
- Sandbox runtime writes only to the sandbox org.
- Production runtime writes only to the production org.
- The source org's published URL must not be imported into the target org.
- The target org generates its own published URL when it publishes.

---

## 22. What must stay separate

AWS must not truly combine the orgs. It should only broker identity, release movement, validation, and
audit.

Keep separate:

- Salesforce OAuth refresh tokens
- org IDs
- Salesforce record IDs
- production submissions
- sandbox submissions
- production publish token/runtime config
- sandbox publish token/runtime config
- runtime artifacts
- tenant state unless the product explicitly decides one billing account controls both

Move only form definitions and versioned design data.

Do not move:

- submissions
- logs
- publication records
- publish tokens
- S3 refs
- generated HTML refs
- AWS response JSON
- tenant secrets
- Salesforce OAuth secrets

---

## 23. ISV and security guardrails

The ISV/security story should be:

```text
AWS acts as the broker.
Each org authenticates independently.
Each org keeps its own Salesforce connection and HMAC signing secret.
AWS stores portable release snapshots.
Each org pulls snapshots into itself.
Production creates a new version.
Runtime artifacts are regenerated.
Submissions never move.
Every promotion is audited.
```

Specific guardrails:

- Never move or expose refresh tokens between orgs.
- Never let a browser-visible value authorize promotion.
- Never let one customer link to another customer's org without OAuth proof.
- Never move production submissions into sandbox or sandbox submissions into production.
- Never let sandbox runtime use production submit/prefill definitions.
- Never move publish tokens; regenerate or keep per-environment tokens.
- Validate destination metadata before writing records.
- Convert raw Salesforce/AWS errors into customer-safe messages.
- Store full technical details in admin/support logs.
- Keep rollback as version creation, not destructive history rewrite.
- Treat snapshots as immutable release artifacts.
- Validate snapshot hashes before import.

---

## 24. Suggested implementation phases

### Phase 1: Manual portability core

- Serializer
- Compatibility validator
- Importer
- Artifact stripper
- Image recreation
- Export JSON with required `globalFormKey`
- One-button manual import
- If form number exists, create a new local draft version
- If form number is missing locally, create the local counterpart with the same form number
- Missing metadata blocks import before DML

This is the reusable foundation from `Form_Export_Import_Implementation_Plan.md`.

### Phase 2: Global form identity

- Add/persist `NF_Global_Form_Key__c`
- Enforce same form number across linked copies
- Collision handling
- Local Designer display of form identity and environment

### Phase 3: Environment linking

- `Link Production` OAuth flow from sandbox
- AWS Environment Group storage
- Production Bootstrap V2 verification
- Link status UI

### Phase 4: AWS snapshots

- Save production snapshot on publish
- Save sandbox test/release snapshot on test-publish or prepare-for-production
- Snapshot manifest/hash
- Snapshot list APIs
- Snapshot retention policy

### Phase 5: Promote and pullback

- Compare
- Compatibility report
- Pull linked snapshot into current org
- Create target draft/local version
- Existing-form actions on Designer form page
- New-form discovery on Designer Home / Forms list
- Audit

### Phase 6: Release polish

- One-click promote-and-publish if desired
- Rollback UI
- Production/sandbox runtime routing
- Test checklist from logs
- Better visual diff

---

## 25. Product positioning

Do not position this as basic export/import.

Position it as:

```text
Linked Environments for TwinaForms forms.
```

or:

```text
Sandbox-to-Production Release Control.
```

The strongest customer-facing promise:

> Build and prove your form in sandbox, then release the same form number to production in one click, with
> rollback if needed.

This is a stronger promise than copy/migration because it protects the exact admin expectation:

- no broken production links
- no new form number
- no field-by-field remapping
- no lost production version
- no unclear sandbox/production state
- no direct cross-org record mutation

---

## 26. Relationship to existing move/export docs

This document supersedes the product framing of `Move_Forms_Between_Orgs.md`.

`Form_Export_Import_Implementation_Plan.md` remains useful as the lower-level portability core:

- serializer
- compatibility validator
- importer
- artifact stripper
- image recreation

But the final product feature should be Linked Environments, not manual form migration.
