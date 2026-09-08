# Linked Sandbox/Production Forms - Phase 3 AWS Connected Org Snapshots

**Status:** Implemented (connected-org sync, latest snapshot storage, listing, and import deployed)
**Scope:** AWS-backed connected org groups, latest-published portable snapshots, and import-from-connected-org UX
**Out of scope for Phase 3:** Draft sync, automatic target publish, approvals, full version history, AWS as form designer/source of truth
**Depends on:**
- `Linked_Sandbox_Production_Phase1_Manual_Import_Export_Design.md`
- `Linked_Sandbox_Production_Phase2_Portability_Design.md`

---

## 1. Goal

Phase 3 removes the manual download/upload step while keeping the same safe import behavior.

```text
Source org publishes a form.
Salesforce exports the latest Published version as portable JSON.
AWS stores that snapshot under the connected org group.
Target org lists available snapshots from connected orgs.
Admin selects one snapshot.
Existing import preview/import creates a local Draft version.
```

AWS is a snapshot broker only. Salesforce remains the design source of truth.

---

## 2. Product Shape

### 2.1 Admin Setup

Add a setup page/action:

```text
Connect Additional Org
```

Flow:

1. Admin opens connected-org setup in Org A.
2. Admin clicks `Connect Additional Org`.
3. Salesforce opens AWS OAuth/connect URL.
4. Admin authenticates Org B.
5. AWS verifies Org B identity.
6. AWS places Org A and Org B in the same connected org group.

### 2.2 Publish Snapshot Sync

After a successful publish in any connected org:

```text
Salesforce -> AWS: save latest Published portable JSON snapshot
```

Only latest Published version is stored/listed in Phase 3.

### 2.3 Import UX

The existing Designer import flow gets a second source:

```text
Import Form
- Upload JSON file
- Connected org snapshots
```

Admin selects a connected snapshot and then sees the same preview modal used by manual JSON import.

---

## 3. Core Decisions

### 3.1 Connected group instead of pairwise links

Use a group model:

```text
ConnectedOrgGroup group_abc123
- Production org
- Sandbox org
- QA/playground org
```

Any active member can list snapshots from the other active members in the same group.

Reason:

- Easier than pairwise links once there are more than two orgs.
- Better product language: "connected environments."
- Keeps authorization simple: current org must be an active group member.

### 3.2 Store metadata in DynamoDB, JSON in private S3

Do not store full portable JSON in DynamoDB.

Reason:

- DynamoDB item limit is 400 KB.
- Portable JSON can grow because image/logo assets are base64.
- S3 is better for snapshot blobs.

### 3.3 Latest Published only

Phase 3 stores and lists only:

```text
latest published portable snapshot per source org + form number
```

No draft snapshots and no historical snapshot picker in this phase.

Reason:

- Clearer UX.
- Lower storage cost.
- Lower support burden.
- Avoids accidentally importing unfinished drafts.

### 3.4 Import still creates Draft only

Target org import must continue to create a Draft version and never publish automatically.

---

## 4. AWS Storage Model

### 4.1 S3 bucket

Recommended bucket:

```text
nativeforms-portable-snapshots-{account}-{region}
```

If we want to avoid a new bucket for ISV timing, a private prefix in an existing private operational bucket is acceptable, but do not use the public published-form website paths.

Recommended S3 key:

```text
portable-snapshots/{groupId}/{sourceOrgId}/{globalFormKey}/latest.json
```

Optional future key:

```text
portable-snapshots/{groupId}/{sourceOrgId}/{globalFormKey}/{publishedVersionNumber}-{publishedAt}.json
```

Security:

- Block public access.
- Server-side encryption.
- No public URLs.
- Lambda reads/writes only through IAM.
- No presigned URL returned to Salesforce in Phase 3 unless needed; prefer proxy download through AWS route with auth.

### 4.2 DynamoDB table: `NativeFormsConnectedOrgGroups`

Purpose:

```text
Store group membership and connected-org status.
```

Recommended keys:

```text
PK = GROUP#{groupId}
SK = ORG#{orgId}
```

GSI:

```text
GSI1PK = ORG#{orgId}
GSI1SK = GROUP#{groupId}
```

Example item:

```json
{
  "pk": "GROUP#group_abc123",
  "sk": "ORG#00D_SANDBOX",
  "gsi1pk": "ORG#00D_SANDBOX",
  "gsi1sk": "GROUP#group_abc123",
  "groupId": "group_abc123",
  "orgId": "00D_SANDBOX",
  "orgName": "Customer Sandbox",
  "orgType": "Sandbox",
  "loginBaseUrl": "https://test.salesforce.com",
  "instanceUrl": "https://customer--sandbox.my.salesforce.com",
  "status": "active",
  "role": "member",
  "connectedByOrgId": "00D_PROD",
  "connectedAt": "2026-08-05T00:00:00Z",
  "lastSeenAt": "2026-08-05T00:00:00Z"
}
```

Status values:

```text
active | disconnected | revoked
```

### 4.3 DynamoDB table: `NativeFormsPortableSnapshots`

Purpose:

```text
List searchable snapshot metadata without reading S3 blobs.
```

Recommended keys:

```text
PK = GROUP#{groupId}
SK = SNAPSHOT#{sourceOrgId}#{globalFormKey}
```

Optional GSI:

```text
GSI1PK = ORG#{sourceOrgId}
GSI1SK = FORM#{globalFormKey}
```

Example item:

```json
{
  "pk": "GROUP#group_abc123",
  "sk": "SNAPSHOT#00D_SANDBOX#form35",
  "groupId": "group_abc123",
  "sourceOrgId": "00D_SANDBOX",
  "sourceOrgName": "Customer Sandbox",
  "globalFormKey": "form35",
  "formName": "Contact Update Form",
  "schemaVersion": "linked-env-portable-form-v2",
  "publishedVersionNumber": 7,
  "publishedAt": "2026-08-05T00:00:00Z",
  "snapshotSavedAt": "2026-08-05T00:01:00Z",
  "features": ["prefill", "submit", "imageElement"],
  "themeKey": "deep-blue",
  "themeName": "Deep Blue",
  "assetCount": 1,
  "assetBytes": 11542,
  "elementCount": 51,
  "actionCount": 2,
  "snapshotS3Key": "portable-snapshots/group_abc123/00D_SANDBOX/form35/latest.json",
  "contentSha256": "optional-for-dedup-not-integrity-contract"
}
```

Important:

- `contentSha256` may be useful for dedup/cache, but Phase 3 should not present it as a security integrity block unless the integrity design is reopened.
- Snapshot metadata must never include Salesforce refresh tokens.

---

## 5. Auth And Trust

### 5.1 Existing trust model

Use the existing NativeForms rule:

```text
tenant identity = Salesforce orgId
Salesforce package/admin calls use authenticated/signed org trust
public runtime trust remains separate
```

Do not use public form `publishToken` for connected-org admin APIs.

### 5.2 Connecting an additional org

Recommended:

1. Current org calls AWS to start connection.
2. AWS creates short-lived `connectSessionId`.
3. Browser redirects to Salesforce OAuth for the additional org.
4. OAuth callback returns to AWS.
5. AWS validates token identity using Salesforce identity endpoint.
6. AWS verifies callback org is the org that authenticated.
7. AWS links authenticated org into the current org's connected group.

If current package already has Bootstrap V2 connection material, use it to prove the initiating org.

### 5.3 Token storage

For this Phase 3 feature, AWS does not need to call Salesforce later on behalf of connected orgs if snapshots are pushed by Salesforce after publish.

Therefore:

```text
Do not store connected-org refresh tokens just for snapshot listing/import.
```

Store only:

- org id
- org name
- instance URL
- login base URL
- group membership
- audit metadata

If future features require AWS-to-Salesforce calls, reopen token storage design and store per-org refresh tokens in Secrets Manager, not DynamoDB.

### 5.4 Authorization checks

Every snapshot API must check:

```text
requestingOrgId is active member of groupId
snapshot.sourceOrgId is active member of same groupId
snapshot.groupId == requester.groupId
```

Target org may list snapshots from:

- other orgs in the group
- optionally itself, if we want "restore from latest published snapshot" convenience

Recommended Phase 3:

```text
List other orgs by default. Hide current org snapshots unless explicitly requested.
```

---

## 6. AWS API Design

Routes can live in `NativeFormsBackend` because it already owns publish lifecycle routes and signed Salesforce admin-assist routes.

### 6.1 Start connection

```http
POST /connected-orgs/connect/start
```

Request:

```json
{
  "requestingOrgId": "00D_PROD",
  "returnUrl": "https://..."
}
```

Auth:

- signed Salesforce package/admin request

Response:

```json
{
  "connectUrl": "https://..."
}
```

### 6.2 OAuth callback

```http
GET /connected-orgs/oauth/callback
```

AWS handles Salesforce OAuth response and creates/updates group membership.

### 6.3 List connected orgs

```http
GET /connected-orgs
```

Response:

```json
{
  "groupId": "group_abc123",
  "orgs": [
    {
      "orgId": "00D_SANDBOX",
      "orgName": "Customer Sandbox",
      "orgType": "Sandbox",
      "status": "active",
      "connectedAt": "2026-08-05T00:00:00Z"
    }
  ]
}
```

### 6.4 Disconnect org

```http
POST /connected-orgs/disconnect
```

Request:

```json
{
  "orgId": "00D_SANDBOX"
}
```

Behavior:

- Mark membership `disconnected`.
- Hide snapshots from that org.
- Do not immediately delete snapshots unless user requests cleanup.

### 6.5 Save latest published snapshot

```http
POST /portable-snapshots/latest
```

Request:

```json
{
  "sourceOrgId": "00D_SANDBOX",
  "globalFormKey": "form35",
  "publishedVersionNumber": 7,
  "publishedAt": "2026-08-05T00:00:00Z",
  "portableJson": "{...}"
}
```

Auth:

- signed Salesforce package/admin request from source org

AWS behavior:

1. Validate source org is connected/known.
2. Parse lightweight metadata from portable JSON.
3. Save full JSON to private S3 latest key.
4. Upsert DynamoDB metadata.
5. Return snapshot metadata.

Response:

```json
{
  "success": true,
  "snapshotId": "00D_SANDBOX#form35",
  "snapshotSavedAt": "2026-08-05T00:01:00Z"
}
```

### 6.6 List available snapshots

```http
GET /portable-snapshots
```

Response:

```json
{
  "snapshots": [
    {
      "sourceOrgId": "00D_SANDBOX",
      "sourceOrgName": "Customer Sandbox",
      "globalFormKey": "form35",
      "formName": "Contact Update Form",
      "publishedVersionNumber": 7,
      "publishedAt": "2026-08-05T00:00:00Z",
      "features": ["prefill", "submit", "imageElement"],
      "themeName": "Deep Blue",
      "assetCount": 1
    }
  ]
}
```

### 6.7 Get snapshot JSON

```http
GET /portable-snapshots/{sourceOrgId}/{globalFormKey}
```

Response:

```json
{
  "portableJson": "{...}"
}
```

Salesforce then passes `portableJson` into existing `inspectImport` and `importForm`.

---

## 7. Salesforce Package Design

### 7.1 Setup UI

Add a small setup area:

```text
Connected Orgs
- Connect Additional Org
- Connected org list
- Disconnect
```

Minimum fields shown:

- org name
- org id
- org type
- status
- connected date

### 7.2 Publish hook

After successful publish:

1. Existing publish flow completes.
2. Salesforce exports the same portable JSON for the published version.
3. Salesforce calls AWS `POST /portable-snapshots/latest`.
4. Failure should not fail the publish in Phase 3 unless we explicitly choose strict mode.

Recommended Phase 3 behavior:

```text
Publish succeeds even if snapshot sync fails.
Show non-blocking warning: Published, but connected-org snapshot sync failed.
```

Reason:

- Snapshot sync is convenience.
- Publish should not be blocked by cross-org feature failure.

### 7.3 Import UI

Existing Import modal adds source choice:

```text
Import from file
Import from connected org
```

Connected snapshot list columns:

- source org
- form number
- form name
- published version
- published date
- theme
- images/assets
- features summary

Selecting a row:

1. Salesforce fetches snapshot JSON from AWS.
2. Existing import preview opens.
3. Existing import button creates Draft.

### 7.4 Permissions

Use existing admin/designer permissions where possible.

Recommended:

- only admins can connect/disconnect orgs
- designers/admins who can import forms can import from connected snapshots
- publishing users trigger snapshot upload only if package org is connected

---

## 8. Snapshot Payload Rules

AWS stores the exact portable export JSON produced by Phase 2, with these constraints:

- no source `Form_Id__c`
- no source publish token
- no source publication record ids
- no source Salesforce file ids in portable image configs
- no source Salesforce file URLs in image configs
- no inactive post-submit runtime URL templates
- latest published version only

AWS should validate basic shape before storing:

```text
schemaVersion is supported
packageType is twinaformsFormDefinition
globalFormKey is present
form.description is present
version exists
manifest exists
```

AWS should reject unknown payloads.

---

## 9. UX Copy

### 9.1 Connected org setup

```text
Connected orgs let you import latest published forms from another Salesforce org.
Imported forms are always created as Draft versions for review.
```

### 9.2 Snapshot list empty state

```text
No published form snapshots are available from connected orgs yet.
Publish a form in a connected org, then return here.
```

### 9.3 Publish warning

```text
Published successfully, but TwinaForms could not update the connected-org snapshot.
You can publish again later or use manual JSON export.
```

### 9.4 Import preview source note

```text
Loaded from connected org: Customer Sandbox.
Published version 7 from August 5, 2026.
```

---

## 10. Error Handling

| Condition | Behavior |
| --- | --- |
| Current org not connected | Hide connected snapshot tab or show setup prompt |
| Connected org disconnected | Hide its snapshots |
| Snapshot missing in S3 | Show `Snapshot is no longer available` |
| Snapshot schema unsupported | Show `This connected snapshot uses an unsupported TwinaForms schema` |
| AWS unavailable during publish | Publish succeeds; show non-blocking sync warning |
| AWS unavailable during import list | Show retryable error |
| Target metadata missing | Existing import preview blocks |
| Theme conflict | Existing Phase 2 theme conflict choice |
| Asset too large | Existing Phase 2 asset warning/import behavior |

---

## 11. Security And ISV Notes

Security review topics:

- Cross-org data flow: published form definitions move from one connected org to AWS and then to another connected org.
- Admin-controlled connection: orgs are linked only after OAuth/authenticated setup.
- Tenant isolation: AWS checks connected group membership before list/download.
- Private storage: snapshots are private S3 objects, not public form assets.
- No public runtime tokens are used for admin snapshot APIs.
- Snapshot imports create Drafts only.
- Disconnect hides future access.

Recommended documentation for ISV:

```text
Connected Org Snapshots store latest published TwinaForms form definitions in AWS so another connected Salesforce org can import them as Draft versions. Form submissions, Salesforce data records, source publish tokens, source file ids, and source runtime publication records are not copied.
```

---

## 12. Implementation Slices

### Slice 1: AWS storage and APIs

- Create connected org group table.
- Create snapshot metadata table.
- Create private S3 snapshot storage.
- Add signed routes for list/save/get snapshots.
- Add minimal AWS tests.

### Slice 2: Salesforce connected-org setup

- Add setup UI.
- Add connect start action.
- Add connected org list.
- Add disconnect action.

### Slice 3: Publish snapshot sync

- After successful publish, export latest Published portable JSON.
- Send snapshot to AWS.
- Show non-blocking warning on sync failure.

### Slice 4: Import from connected org

- Add connected snapshot tab/list to import modal.
- Fetch selected snapshot JSON.
- Reuse existing inspect/import flow.

### Slice 5: QA and ISV packet notes

- Same-org manual JSON still works.
- Cross-org connected snapshot import works.
- Disconnected org hidden.
- Unauthorized org cannot list/download snapshots.
- Publish succeeds when snapshot sync fails.
- Security documentation updated.

---

## 13. Testing Plan

### 13.1 Unit tests

AWS:

- create group membership
- list connected orgs by requester org id
- reject non-member snapshot list
- save latest snapshot metadata
- fetch snapshot JSON only for group member
- reject unsupported schema

Salesforce:

- connected org list parses AWS response
- publish sync payload uses latest Published version
- sync failure does not roll back publish
- import-from-connected snapshot calls existing inspect/import

### 13.2 Manual QA

1. Connect DevHub and second Developer Edition.
2. Publish form in source org.
3. Confirm AWS metadata exists.
4. In target org, list connected snapshots.
5. Import form as Draft.
6. Verify theme and image are target-org records/files.
7. Disconnect source org.
8. Confirm source snapshots no longer appear.
9. Confirm manual JSON import still works.

---

## 14. Open Questions Before Coding

1. Should the first connected org create a new group automatically, or should every org already have a default single-org group after Connect?
2. Should target org list snapshots from itself, or only from other connected orgs?
3. Should snapshot sync failure create a visible Salesforce log row, toast only, or both?
4. Should disconnect hide snapshots only, or also delete S3 snapshot objects after a retention period?
5. Should we allow multiple groups per org later, or enforce one group per org in Phase 3?

Recommended Phase 3 defaults:

- create default group automatically
- list other orgs only
- log plus non-blocking warning
- hide on disconnect, retain snapshots for support/cleanup
- one active group per org

---

## 15. Completion Definition

Phase 3 is complete when:

- An admin can connect a second Salesforce org.
- Publishing a form in source org saves latest Published portable JSON to AWS.
- Target org can list connected snapshots.
- Target org can select a snapshot and use the existing import preview.
- Import creates a Draft version with portable theme/images.
- Unauthorized orgs cannot list or download snapshots.
- Manual JSON export/import still works.
