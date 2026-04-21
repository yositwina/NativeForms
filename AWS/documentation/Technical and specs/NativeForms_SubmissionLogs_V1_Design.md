# NativeForms Submission Logs V1 Design

## Summary

V1 is delivered in this sequence:
1. **Finish AWS side completely first**
2. Validate AWS write/read/encryption behavior with test data
3. Only then start Salesforce controller/LWC design

Core product rules:
- Every submission attempt is logged
- Retention is **by customer/tenant plan**
- Detailed logs are **encrypted before saving to DynamoDB**
- Raw Salesforce/API failure reasons are saved only in the **private encrypted log**
- Plain metadata shows only a small public failure category
- V1 uses a **plan-driven hybrid encryption model**:
  - plan entitlement decides whether detailed logs are available
  - Salesforce stores a hidden org RSA keypair
  - only the public key is synced to AWS
  - AWS encrypts detailed payloads with a one-time AES key and encrypts that AES key with the org public key
  - the Salesforce `Submission Logs` LWC decrypts detailed logs client-side with the hidden org private key

## Key Design

### 1. What is always logged

Every handled submit attempt writes one log record with plain metadata:
- `tenantId`
- `submissionId`
- `submissionRef`
- `formId`
- `formVersionId`
- `submittedAt`
- `outcome = success | failed`
- `failureStage = none | validation | mapping | salesforce | system`
- `detailMode = metadata_only | encrypted_detail`
- `expiresAt`
- `recordId` on success if available

This satisfies the minimum operational requirement:
- org id
- date
- succeeded / failed

### 2. What is private

These go only into the encrypted detail payload:
- submitted field values
- prefill snapshot shown at submit time
- mapped values sent toward Salesforce
- submitter email
- raw Salesforce/API response reason
- validation-rule / business-rule response details
- error message and internal code
- IP address
- user agent
- duration and technical context

Rule:
- plain metadata never includes raw Salesforce/API failure text
- plain metadata only includes `failureStage`

### 3. Retention by plan

Retention is set when the log is written, based on the tenant's effective plan:

- `Free`: metadata only, `30 days`
- `Trial`: encrypted detail, `30 days`
- `Starter`: encrypted detail, `90 days`
- `Pro`: encrypted detail, `365 days`

Defaults:
- old records keep the TTL they were written with
- changing plan affects only new records
- `Free` still gets operational submit history, but no full private-detail log viewing

### 4. Encryption model

Use a plan-driven hybrid encryption model for V1.

Salesforce side:
- extend the NativeForms admin/settings experience with Submission Logs status
- Salesforce stores hidden org-level crypto material:
  - `submissionLogPublicKey`
  - `submissionLogPrivateKey`
  - `submissionLogKeyVersion`
- admins do not choose the mode or paste a key manually
- admins can repair/regenerate the hidden keypair, then sync only the public key to AWS

AWS side:
- store a synced copy of:
  - `submissionLogPublicKey`
  - `submissionLogKeyVersion`
- determine `metadata_only` vs `encrypted_detail` from plan entitlement plus public-key readiness

Encryption format:
- AES-256-CBC for the detailed payload
- RSA-OAEP SHA-256 for the one-time AES data key
- random IV per log record
- store:
  - `detailCiphertextB64`
  - `detailIvB64`
  - `detailEncryptedKeyB64`
  - `detailKeyVersion`
  - `detailSchemaVersion`
- the LWC decrypts the detail after Apex returns the encrypted package and hidden private key material for the org session

Reason for this choice:
- AWS never receives a secret symmetric log key
- end users/admins do not manage crypto settings manually
- protects stored detail in DynamoDB
- keeps implementation achievable for V1

## AWS-First Implementation

### Phase A - AWS foundation only

Build these pieces first:

- Create DynamoDB table `NativeFormsSubmissionLogs`
- Keys:
  - PK: `tenantId`
  - SK: `submittedAtSubmissionId`
- Add GSI:
  - `tenantFormKey` + `submittedAtSubmissionId`
- Add GSI:
  - `tenantOutcomeKey` + `submittedAtSubmissionId`

Add write path in `NativeForms-SubmitForm`:
- generate `submissionRef` at submit start
- write one best-effort log on every handled outcome
- log writing must remain non-blocking
- do not change submission result because of log-write failure

Add a new AWS read/config Lambda:
- `NativeFormsSubmissionLogsApi`

Routes:
- `GET /submission-log-config/status`
  - return plan entitlement, retention, and crypto readiness for the current org
- `POST /submission-log-config/sync`
  - sync tenant/org public-key config from Salesforce to AWS
- `GET /submission-logs`
  - list logs for current tenant with filters:
    - `formId`
    - `outcome`
    - `dateFrom`
    - `dateTo`
    - `pageSize`
    - `nextToken`
- `GET /submission-logs/{submissionId}`
  - get one log record including encrypted detail package

Tenant security:
- same tenant-secret validation pattern as the current Salesforce-to-AWS backend flow
- tenant scope always enforced server-side

AWS validation must be completed before Salesforce UI work begins:
- table creation
- write path
- read path
- config sync
- encryption/decryption compatibility sample data
- retention stamping by plan
- tenant isolation checks

### Phase B - Salesforce integration after AWS is stable

Add Salesforce-side support only after Phase A passes.

Apex:
- `NativeFormsSubmissionLogsController`
- methods:
  - get submission-log status
  - save hidden org keypair
  - list logs
  - get one log detail
  - sync submission-log config to AWS

Salesforce settings:
- extend current NativeForms org-level admin settings with a new Submission Logs section
- show:
  - plan entitlement
  - retention display by current tenant plan
  - encryption readiness
  - key version
  - repair / sync actions

### Phase C - Salesforce UX after AWS validation

Add a new NativeForms app tab:
- `Submission Logs`

LWC UX:
- top summary cards:
  - Total
  - Failed
  - Success
  - Last 24h
- filters:
  - Form
  - Outcome
  - Date range
- table columns:
  - Time
  - Form
  - Outcome
  - Submission Ref
  - Detail Mode
- row detail panel sections:
  - Submission
  - Prefill
  - Salesforce Result
  - Error
  - Technical Context

UX rules:
- triage-first, not raw-JSON-first
- if `detailMode = metadata_only`, show clear explanation
- if `detailMode = encrypted_detail`, show decrypted detail only in the detail panel
- support/admin should be able to search/find by `submissionRef`

## Test Plan

AWS foundation tests:
- success submit writes one log
- failure submit writes one log
- `failureStage` is correct for:
  - validation
  - mapping
  - salesforce
  - system
- `Free` writes metadata-only logs with 30-day TTL
- `Trial` writes encrypted-detail logs with 30-day TTL
- `Starter` writes encrypted-detail logs with 90-day TTL
- `Pro` writes encrypted-detail logs with 365-day TTL
- raw Salesforce/API error reason is stored only in encrypted detail
- plain metadata never exposes raw error message
- log write failure does not fail submit
- tenant isolation works
- AWS only receives the org public key, never a secret log key

Salesforce integration tests:
- Apex can list tenant-scoped logs
- Apex can fetch one detail record
- the `Submission Logs` LWC can decrypt encrypted detail with the org private key
- config sync updates AWS tenant log settings
- `submissionRef` shown to end user matches the stored log record

UX tests:
- failed logs are easy to spot
- metadata-only rows explain why full detail is unavailable
- encrypted-detail rows show meaningful decrypted support information
- filters and pagination behave correctly

## Assumptions and Defaults

- V1 uses a public-key hybrid model with client-side detail decryption in the LWC
- `failureStage` is the only public failure classification in metadata
- raw Salesforce/API responses stay private in encrypted detail
- `Free` gets metadata-only history
- `Trial`, `Starter`, and `Pro` get encrypted detailed logs
- no Salesforce page/LWC design starts until AWS side is finished and validated
