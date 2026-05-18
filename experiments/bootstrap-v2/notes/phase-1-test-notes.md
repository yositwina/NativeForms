# Phase 1 Test Notes

## What Phase 1 Proves

- Salesforce Apex can generate a per-org 256-bit signing secret.
- The secret is stored in protected package storage on `NativeForms_Protected_Config__c`.
- Apex can produce HMAC-SHA256 signatures for a canonical request.
- AWS can verify the same canonical request shape.

## What Phase 1 Does Not Prove Yet

- OAuth-authenticated bootstrap from AWS back into Salesforce.
- One-time bootstrap session creation and expiry.
- Nonce replay storage.
- Secret rotation/reconnect UX.
- Connect page simplification.

## Experimental AWS Route

`POST /tenant/bootstrap-v2/verify-signed-call`

This route verifies the signed request using `BOOTSTRAP_V2_SPIKE_SECRET_B64`.

The route is intentionally not connected to the current Connect UI and should not be promoted to production as-is.

## Live Test Results

Run date: 2026-05-06

- Local Node tests passed, including `tests/bootstrap-v2-hmac.test.mjs`.
- Salesforce deploy to `TwinaFormsDevHub` passed for the experimental signer class, test class, and protected config metadata.
- Salesforce test `NativeFormsBootstrapV2SignerTest` passed with 3/3 tests.
- AWS `NativeFormsBackend` was deployed on `nodejs24.x`.
- Existing backend smoke checks passed after deploy:
  - `GET /public/plans`
  - `GET /tenant/status?orgId=00Dg5000008sWZN`
- Experimental route correctly rejected signed verification while `BOOTSTRAP_V2_SPIKE_SECRET_B64` was absent.
- A temporary 256-bit spike secret was added to Lambda, one live signed request was accepted with `verified: true`, and the Lambda environment was restored.
- Final guard check confirmed `BOOTSTRAP_V2_SPIKE_SECRET_B64` is absent again after testing.

## Phase 2 Test Results

Run date: 2026-05-06

- Added experimental Apex REST endpoint:
  `/services/apexrest/nativeforms/bootstrap-v2/signing-secret`
- Added AWS OAuth callback helper:
  `AWS/bootstrap-v2-salesforce.mjs`
- Local Node tests passed, including `tests/bootstrap-v2-salesforce.test.mjs`.
- Apex validation against `TwinaFormsDevHub` passed with 6/6 Bootstrap V2 tests.
- Apex deploy to `TwinaFormsDevHub` passed with 6/6 Bootstrap V2 tests.
- Direct OAuth-authenticated REST smoke test against the Dev Hub endpoint passed:
  - `success: true`
  - `experimental: true`
  - `algorithm: HMAC-SHA256`
  - `secretBytes: 32`
- AWS `NativeFormsBackend` was redeployed with the Phase 2 helper module.
- Existing backend smoke checks still passed after deploy:
  - `GET /public/plans`
  - `GET /tenant/status?orgId=00Dg5000008sWZN`

## Phase 2 Manual Test Boundary

The remaining unproven path is the real browser OAuth callback:

1. Register or recreate a test tenant.
2. Open the current Connect flow.
3. Complete Salesforce OAuth in the browser.
4. Inspect the per-org AWS Salesforce connection secret.
5. Confirm it contains:
   - `bootstrap_v2_experimental: true`
   - `bootstrap_v2_status: ready`
   - `bootstrap_v2_signing_secret_b64`
   - `bootstrap_v2_algorithm: HMAC-SHA256`

If `bootstrap_v2_status` is `not_available`, the current OAuth flow should still be connected and the `bootstrap_v2_error` field should explain why the experimental bootstrap did not complete.

## Required Headers

- `x-twinaforms-org-id`
- `x-twinaforms-bootstrap-v2-timestamp`
- `x-twinaforms-bootstrap-v2-nonce`
- `x-twinaforms-bootstrap-v2-body-sha256`
- `x-twinaforms-bootstrap-v2-signature`
- `x-twinaforms-bootstrap-v2-algorithm`

## Canonical String

The canonical string is:

```text
METHOD
PATH
ORG_ID
TIMESTAMP
NONCE
BODY_SHA256_HEX
```

The signature is:

```text
base64(HMAC-SHA256(canonicalString, signingSecretBytes))
```

## Phase 3 Test Results

Run date: 2026-05-06

- Added Bootstrap V2 signature verification as an alternate tenant auth path in `AWS/NativeFormsBackend.mjs`.
- Existing bearer tenant authentication remains accepted as the fallback/current production path.
- Added nonce replay storage before accepting a Bootstrap V2 signed request.
- For the spike deployment, nonce records are written to `NativeFormsAdminAudit` using `auditId` because the current Codex AWS role cannot create or manage a dedicated nonce table.
- Production should move nonce storage to `NativeFormsBootstrapV2Nonces` with TTL.
- Added Bootstrap V2 signature headers to Salesforce package calls for tenant auth health, entitlements, disconnect, register form, unpublish form, and presign publish.
- Deployed the Apex signing changes to `TwinaFormsDevHub`.
- Local Node checks passed:
  - `node --check AWS\NativeFormsBackend.mjs`
  - `npm.cmd test`
- Salesforce test `NativeFormsBootstrapV2SignerTest` passed with 3/3 tests.
- A live Execute Anonymous call compiled and ran, but the callout could not access `NativeForms_Bootstrap` from that execution context. The result confirms Apex compile/runtime wiring, but not the full live callout path until the Dev Hub named credential/principal access is fixed.

## Phase 3 Security Cleanup Note

A real Dev Hub connection secret was exposed during manual chat verification. That test connection must be deleted/reconnected or rotated before the spike is considered clean.
