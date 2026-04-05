# Security Protocols

## Purpose
This document defines the current NativeForms security protocol for published forms hosted on AWS and designed in Salesforce.

## Core Model
NativeForms now has two trust layers:
- tenant trust for Salesforce admin/server calls
- form trust for public prefill and submit

Each published form has:
- a unique `formId`
- an owning `orgId`
- a published version id
- a per-form publish token
- a server-side security policy record stored in AWS

The browser sends:
- `request.formId` on prefill
- top-level `formId` on submit
- `publishToken` on prefill and submit
- only user `params` or `input`

AWS validates requests against the stored server-side policy before executing any Lambda commands.

## Tenant Registration and Admin Auth
Each Salesforce org is treated as a tenant identified by `orgId`.

AWS stores a tenant DynamoDB record with:
- `orgId`
- `adminEmail`
- `companyName`
- `loginBaseUrl`
- `secret`
- `subscriptionState`
- `subscriptionStartDate`
- `subscriptionEndDate`
- `isActive`
- `status`
- timestamps

Current tenant bootstrap endpoint:
- `POST /tenant/register`

Current bootstrap behavior:
- creates or updates the tenant record
- generates a per-org secret if one does not exist
- returns that tenant secret in the response for setup

Admin/server calls such as form registration must send:
- `Authorization: Bearer <tenant-secret>`
- `orgId` in the request body

Tenant records can also be used to control subscription access per org by setting:
- `subscriptionState`
- `subscriptionStartDate`
- `subscriptionEndDate`
- `isActive`
- `status`

## Server-Side Form Security Record
For every published form, AWS stores a DynamoDB record with:
- `formId`
- `orgId`
- `publishedVersionId`
- `status`
- `securityMode`
- `rateLimitProfile`
- `tokenHash`
- `prefillPolicy`
- `submitPolicy`
- `prefillDefinition`
- `submitDefinition`
- timestamps

Example shape:
```json
{
  "orgId": "00Dxxxxxxxxxxxx",
  "formId": "problem-report-demo",
  "publishedVersionId": "v1",
  "status": "published",
  "securityMode": "secure-edit",
  "rateLimitProfile": "standard",
  "tokenHash": "sha256-hex-value",
  "prefillPolicy": {
    "allowedCommands": ["findOne", "getById", "findMany"],
    "allowedObjects": ["Contact", "Case"]
  },
  "submitPolicy": {
    "allowedCommands": ["create", "update", "upsertMany"],
    "allowedObjects": ["Contact", "Case"],
    "allowedWriteFields": {
      "Contact": ["FirstName", "LastName", "Email"],
      "Case": ["Subject", "Description", "Status", "Origin", "ContactId"]
    }
  },
  "prefillDefinition": {
    "onNotFound": "ignore",
    "commands": [],
    "responseMapping": {}
  },
  "submitDefinition": {
    "commands": []
  }
}
```

## Publish Token
The publish token is:
- unique per form
- stored as a hash on AWS
- embedded in the published HTML
- sent by the browser to the Lambdas

The publish token is used to:
- identify a real published form
- separate one form from another
- prevent one form token from working for all forms

The publish token is not enough by itself. AWS also enforces:
- form publish status
- security mode
- command allowlists
- object allowlists
- field allowlists

## Salesforce Publish Flow
When Salesforce publishes a form:
1. Salesforce generates or stores `formId`
2. Salesforce generates a per-form publish token
3. Salesforce authenticates with the tenant bearer secret
4. Salesforce sends the form security record and executable form definitions to AWS
5. AWS validates the tenant and stores the form record under that org
6. Salesforce publishes HTML that includes the matching publish token

Current AWS registration endpoint:
- `POST /forms/register`

Current read endpoint:
- `GET /forms/{formId}/security`

## Prefill Request Rules
The Prefill Lambda requires:
- `publishToken`
- `request.formId`
- browser `params`

Before executing commands, Lambda:
1. loads the stored form security record
2. checks the form is published
3. hashes the incoming publish token and compares to the stored hash
4. loads the owning tenant using `form.orgId`
5. checks the tenant is active
6. loads `prefillDefinition` from DynamoDB
7. validates that each stored prefill command type is allowed
8. validates that each stored prefill object is allowed

The browser does not send:
- prefill commands
- response mapping
- object names to execute

Blocked examples:
- `findMany` on an object not listed in `prefillPolicy.allowedObjects`
- any command type not listed in `prefillPolicy.allowedCommands`

## Submit Request Rules
The Submit Lambda requires:
- top-level `formId`
- top-level `publishToken`
- browser `input`

Before executing commands, Lambda:
1. loads the stored form security record
2. checks the form is published
3. hashes the incoming publish token and compares to the stored hash
4. loads the owning tenant using `form.orgId`
5. checks the tenant is active
6. loads `submitDefinition` from DynamoDB
7. validates that each stored submit command type is allowed
8. validates that each stored submit object is allowed
9. validates writable fields for `create`, `update`, and `upsertMany`
10. checks whether the form security mode allows risky commands

The browser does not send:
- submit commands
- object names to execute
- writable field allowlists

Blocked examples:
- updating an object not listed in `submitPolicy.allowedObjects`
- writing a field not listed in `submitPolicy.allowedWriteFields`
- using `update`, `delete`, or `upsertMany` in a non-edit security mode

## Security Modes
Current modes:

### public-create
- intended for public create-only forms
- risky update/delete behavior should be blocked

### public-prefill
- intended for public forms that may safely prefill data
- risky update/delete behavior should still be blocked by default

### secure-edit
- intended for forms allowed to update existing records
- may allow `update`, `delete`, and `upsertMany` if policy allows them

## Why This Model
This model improves security over a single shared static token because:
- each form has its own token
- each form has its own server-side policy
- Lambdas do not trust the incoming JSON blindly
- commands, mappings, objects, and fields are enforced server-side
- the browser cannot tamper with execution definitions per request

## Current Implementation Note
For this prototype, the server-side registry is stored in AWS DynamoDB using:
- one item per tenant in a table such as `NativeFormsTenants`
- `NativeFormsFormSecurity`
- one item per form in a table such as `NativeFormsFormSecurity`

Salesforce connection credentials are stored per org in AWS Secrets Manager using names such as:
- `NativeForms/SalesforceConnection/<orgId>`
