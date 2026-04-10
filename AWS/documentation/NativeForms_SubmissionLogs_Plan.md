# NativeForms Submission Logging — Design & Plan

**Date:** 2026-04-09  
**Status:** Planned — not yet implemented

---

## Overview

Every form submission (success, failure, validation error) writes a log record to DynamoDB. A Salesforce page queries these logs via an Apex controller that calls a new Lambda endpoint.

---

## DynamoDB Design

**Table:** `NativeForms-SubmissionLogs`

**Primary Key:**
- Partition key: `tenantId` (the Salesforce org ID)
- Sort key: `submissionId` (UUID + timestamp, e.g. `2026-04-09T14:32:11Z#uuid`)

**Attributes per record:**

| Field | Description |
|---|---|
| `tenantId` | Org ID (partition key) |
| `submissionId` | Sort key |
| `formId` | Which form |
| `formVersionId` | Which version was active at submission time |
| `status` | `"success"` \| `"validation_error"` \| `"partial"` \| `"failed"` |
| `submittedAt` | ISO timestamp |
| `email` | Submitter email (if captured in form) |
| `recordId` | SF record ID created/updated (if success) |
| `errorMessage` | Human-readable error (if failed) |
| `errorCode` | Machine code e.g. `"SOQL_FAILED"`, `"MAPPING_ERROR"` |
| `payload` | Full submitted field values (JSON string) |
| `prefillSource` | What prefill data was loaded (optional) |
| `ipAddress` | Submitter IP (from Lambda event) |
| `userAgent` | Browser info |
| `durationMs` | How long the Lambda took to process |
| `expiresAt` | TTL — auto-delete after configurable retention period |

**GSI (Global Secondary Indexes):**
- `formId-submittedAt-index` — query logs by form
- `status-submittedAt-index` — filter by status across all forms

---

## Write Path (Lambda → DynamoDB)

**Where it writes:** `NativeForms-SubmitForm` Lambda — at the END of processing, after success or catch of any error.

**Important:** Write is **non-blocking** — a failure to write the log must never cause the form submission itself to fail.

**Log on every outcome:**

| Event | Status | Notes |
|---|---|---|
| SF record created/updated | `success` | Include `recordId` |
| SF field mapping failed | `mapping_error` | Which field failed |
| SOQL/DML error | `failed` | SF error message |
| Required field missing | `validation_error` | Field name list |
| Lambda crash / timeout | `failed` | Generic error |
| Prefill loaded | *(not a submit event — skip)* | |

---

## Read Path (SF → Lambda → DynamoDB)

**New Lambda:** `NativeForms-GetSubmissionLogs`

**Called by:** Apex controller → AWS API Gateway → Lambda → DynamoDB query

**Request parameters:**

| Parameter | Description |
|---|---|
| `tenantId` | Always scoped to calling org |
| `formId` | Filter by specific form (optional) |
| `status` | Filter by status (optional) |
| `dateFrom` | Start date (optional) |
| `dateTo` | End date (optional) |
| `pageSize` | Default 50 |
| `nextToken` | Pagination (DynamoDB `LastEvaluatedKey`) |

**Response:**

| Field | Description |
|---|---|
| `logs[]` | Array of log records |
| `nextToken` | For next page |
| `totalEstimate` | Approximate count (DynamoDB scan estimate) |

**Security:** Same tenant secret validation as existing Lambdas. Apex passes the stored tenant secret. Logs are always scoped to the calling org — cross-tenant access is impossible by design.

---

## Salesforce Page Design

**New LWC:** `nativeFormsSubmissionLogs`  
**New tab:** "Submission Logs" in the NativeForms app

**UI Layout:**

```
┌─────────────────────────────────────────────────────┐
│  Submission Logs                                     │
│                                                      │
│  Form: [All Forms ▼]  Status: [All ▼]  Date: [    ] │
│                                                      │
│  ┌──────────┬──────┬───────────┬────────┬──────────┐ │
│  │ Time     │ Form │ Email     │ Status │ Record   │ │
│  ├──────────┼──────┼───────────┼────────┼──────────┤ │
│  │ 14:32:11 │ Test │ yosi@...  │ ✅     │ 003xx... │ │
│  │ 14:28:44 │ Test │ john@...  │ ❌     │ —        │ │
│  └──────────┴──────┴───────────┴────────┴──────────┘ │
│                                                      │
│  [Load More]              Showing 50 of ~142         │
└─────────────────────────────────────────────────────┘
```

**Row expand (click to see detail):**
- Full submitted payload (field: value pairs)
- Error message if failed
- Duration, IP, user agent
- Link to SF record if created

---

## Apex Controller

**Class:** `NativeFormsSubmissionLogsController`

- Calls `NativeForms-GetSubmissionLogs` via `Http` callout
- Same pattern as existing controllers (named credential or stored endpoint)
- Handles pagination token
- Caches form list for the filter dropdown

---

## Retention & Storage Estimate

| Metric | Estimate |
|---|---|
| Record size | ~2–5 KB each |
| 1,000 submissions/month | ~5 MB/month |
| DynamoDB cost at this scale | Essentially free (On-Demand pricing) |
| Default TTL | 90 days |

TTL duration should be configurable via a NativeForms settings record in Salesforce.

---

## Open Questions to Decide Before Coding

1. **Payload storage** — store full field values in DynamoDB, or just metadata? *(Privacy/GDPR consideration)*
2. **TTL duration** — 30, 90, or 365 days? Or let admin configure it?
3. **Error alerting** — should a high failure rate trigger an email or Salesforce notification?
4. **Export** — is CSV export from the Logs page required?
