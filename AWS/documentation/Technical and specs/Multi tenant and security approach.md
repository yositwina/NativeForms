# Multi tenant and security approach

## Goal
Define the NativeForms multi-tenant security model for a packaged Salesforce product that can support many customer orgs safely.

## Core idea
NativeForms has two different trust layers:

1. **Tenant trust**
   Used for Salesforce server-to-server admin operations such as:
   - tenant bootstrap
   - form registration
   - future publish / unpublish admin calls

2. **Form trust**
   Used for public runtime form execution:
   - prefill
   - submit

These two layers must stay separate.

## Why this is needed
For a multi-tenant package:
- each customer org must have its own trust record
- each customer org must have its own secret
- each form must belong to exactly one org
- public HTML must not use the tenant admin secret

## Tenant identity
Each customer tenant is identified by:
- `orgId`

This is the Salesforce org id and is the main tenant key.

## Tenant registration process

### Step 1: Salesforce org registers with AWS
Salesforce sends to the AWS tenant registration Lambda:
- `orgId`
- `adminEmail`
- `companyName`
- `loginBaseUrl`
- optional subscription control fields:
  - `subscriptionState`
  - `subscriptionStartDate`
  - `subscriptionEndDate`
  - `isActive`
  - `status`

Example:
```json
{
  "orgId": "00Dxxxxxxxxxxxx",
  "adminEmail": "admin@example.com",
  "companyName": "Acme Inc",
  "loginBaseUrl": "https://acme-dev-ed.develop.my.salesforce.com",
  "subscriptionState": "trial",
  "subscriptionStartDate": "2026-04-04",
  "subscriptionEndDate": "2026-05-04",
  "isActive": true,
  "status": "active"
}
```

### Why `loginBaseUrl` is stored
Some orgs do not work correctly with one generic login entry point.

So NativeForms should store the tenant-specific Salesforce login base URL during tenant registration and reuse it later for the first two-way auth flow.

This avoids assuming:
- `https://login.salesforce.com`
- `https://test.salesforce.com`
- or one fixed My Domain pattern

### Step 2: AWS creates the tenant record
AWS stores a tenant record and generates a per-org secret.

### Step 3: Secret is delivered to the admin
For the current prototype, AWS returns the tenant secret in the `/tenant/register` response so setup can be completed quickly.

Later product versions may email or rotate the secret through a fuller admin flow.

### Step 4: Admin stores the secret in Salesforce
The admin pastes the secret into the package External Credential / Named Credential setup.

After that, Salesforce can authenticate server-to-server requests to AWS for that org.

## Tenant record storage
Use a DynamoDB tenant table.

Example item:
```json
{
  "orgId": "00Dxxxxxxxxxxxx",
  "adminEmail": "admin@example.com",
  "companyName": "Acme Inc",
  "loginBaseUrl": "https://acme-dev-ed.develop.my.salesforce.com",
  "secret": "tenant-secret",
  "subscriptionState": "active",
  "subscriptionStartDate": "2026-04-04",
  "subscriptionEndDate": "2027-04-04",
  "isActive": true,
  "status": "active",
  "salesforceConnectionStatus": "connected",
  "salesforceConnectionUpdatedAt": "2026-04-04T12:05:00Z",
  "createdAt": "2026-04-04T12:00:00Z",
  "updatedAt": "2026-04-04T12:00:00Z"
}
```

## Two-way authentication first use
The first trust bootstrap should use the stored tenant `loginBaseUrl`.

That means:
- Salesforce provides the org-specific login URL during tenant registration
- AWS saves it
- later first-time auth or trust validation uses the stored login base URL for that tenant

This is safer than assuming one shared login domain for all customers.

## Server-to-server admin authentication
After tenant setup, Salesforce admin/backend calls authenticate with:
- `Authorization: Bearer <tenant-secret>`

These calls include:
- `orgId`
- request body data

AWS validates:
1. bearer exists
2. `orgId` exists
3. tenant record exists
4. bearer matches the stored tenant secret
5. tenant status is active

Only then may the admin request continue.

## Form registration process

### Endpoint
- `POST /forms/register`

### Request
Salesforce sends:
- `Authorization: Bearer <tenant-secret>`
- request body containing:
  - `orgId`
  - `formId`
  - `publishedVersionId`
  - `publishToken`
  - policies
  - `prefillDefinition`
  - `submitDefinition`

### AWS validation
Before storing the form:
1. validate tenant bearer against tenant table
2. validate tenant status
3. validate `orgId`
4. then write/update the form record

## Form record storage
Use a separate DynamoDB form table.

Example item:
```json
{
  "formId": "support-form-1",
  "orgId": "00Dxxxxxxxxxxxx",
  "publishedVersionId": "v3",
  "status": "published",
  "securityMode": "public-prefill",
  "tokenHash": "sha256...",
  "prefillPolicy": { },
  "submitPolicy": { },
  "prefillDefinition": { },
  "submitDefinition": { },
  "createdAt": "2026-04-04T12:10:00Z",
  "updatedAt": "2026-04-04T12:10:00Z"
}
```

Important:
- every form record must store `orgId`

## Public form runtime security
Public HTML does **not** use the tenant secret.

Public HTML uses:
- `formId`
- per-form `publishToken`

### Prefill / Submit runtime validation
For each runtime request AWS should:
1. load form record by `formId`
2. validate `publishToken`
3. read `orgId` from the form record
4. load tenant record
5. verify tenant status is still active
6. continue only if both form and tenant are valid

So public runtime uses:
- form trust directly
- tenant trust indirectly through the form ownership record

## Separation of secrets

### Tenant secret
Used only for:
- Salesforce backend/admin calls
- bootstrap/register/unpublish/admin APIs

### Publish token
Used only for:
- public HTML prefill
- public HTML submit

This separation is required.

## Per-org Salesforce connection
The Salesforce API connection used by prefill and submit must also be tenant-specific.
The OAuth client app credential is not tenant-specific: AWS uses the TwinaForms-owned packaged External Client App client id/secret from central AWS configuration or Secrets Manager.

Recommended prototype storage:
- tenant metadata in DynamoDB
- one central OAuth client secret such as `TwinaForms/SalesforceOAuthClient`
- one Secrets Manager entry per org:
  - `NativeForms/SalesforceConnection/<orgId>`

Connection flow:
1. tenant registers in AWS
2. admin completes AWS `/connect?orgId=<orgId>`
3. callback uses the central TwinaForms OAuth client credentials to exchange the authorization code
4. callback stores the org-specific refresh token and instance URL under that org id
5. prefill/submit resolve `orgId` from the form, load that org's Salesforce connection, and refresh with the central OAuth client credentials

This replaces the older single shared backend Salesforce secret model.

## Recommended statuses

### Tenant status
- `active`
- `disabled`
- later maybe `suspended`

### Form status
- `published`
- `unpublished`
- maybe later `archived`

## Recommended V1 endpoints
- `POST /tenant/register`
- `POST /forms/register`
- existing public prefill endpoint
- existing public submit endpoint

## Recommended V1 storage
- DynamoDB tenant table
- DynamoDB form table
- Secrets Manager only for true app secrets such as Salesforce backend connection secrets if still needed

## Summary
The NativeForms multi-tenant security model should be:

- tenant key = Salesforce `orgId`
- tenant registration stores:
  - `orgId`
  - admin email
  - company name
  - tenant-specific `loginBaseUrl`
  - tenant secret
- admin/server calls authenticate with tenant bearer secret
- forms are registered under the owning `orgId`
- public runtime uses per-form `publishToken`
- public runtime also checks the owning tenant is still active

This gives NativeForms:
- tenant isolation
- packaged multi-tenant scalability
- cleaner separation between admin auth and public form auth
