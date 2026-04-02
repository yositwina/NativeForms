# Security Protocols

## Purpose
This document defines the current NativeForms security protocol for published forms hosted on AWS and designed in Salesforce.

## Core Model
Each published form has:
- a unique `formId`
- a published version id
- a per-form publish token
- a server-side security policy record stored in AWS

The browser sends:
- `formId` on submit
- `publishToken` on prefill and submit

AWS validates requests against the stored server-side policy before executing any Lambda commands.

## Server-Side Form Security Record
For every published form, AWS stores a DynamoDB record with:
- `formId`
- `publishedVersionId`
- `status`
- `securityMode`
- `rateLimitProfile`
- `tokenHash`
- `prefillPolicy`
- `submitPolicy`
- timestamps

Example shape:
```json
{
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
3. Salesforce sends the form security record to AWS
4. AWS stores the record under the form id
5. Salesforce publishes HTML that includes the matching publish token

Current AWS registration endpoint:
- `POST /forms/register`

Current read endpoint:
- `GET /forms/{formId}/security`

## Prefill Request Rules
The Prefill Lambda requires:
- `publishToken`
- `request.formId`

Before executing commands, Lambda:
1. loads the stored form security record
2. checks the form is published
3. hashes the incoming publish token and compares to the stored hash
4. validates that each prefill command type is allowed
5. validates that each prefill object is allowed

Blocked examples:
- `findMany` on an object not listed in `prefillPolicy.allowedObjects`
- any command type not listed in `prefillPolicy.allowedCommands`

## Submit Request Rules
The Submit Lambda requires:
- top-level `formId`
- top-level `publishToken`

Before executing commands, Lambda:
1. loads the stored form security record
2. checks the form is published
3. hashes the incoming publish token and compares to the stored hash
4. validates that each submit command type is allowed
5. validates that each submit object is allowed
6. validates writable fields for `create`, `update`, and `upsertMany`
7. checks whether the form security mode allows risky commands

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
- commands, objects, and fields are enforced server-side

## Current Implementation Note
For this prototype, the server-side registry is stored in AWS DynamoDB using one item per form in a table such as:
- `NativeFormsFormSecurity`

Salesforce connection credentials remain in AWS Secrets Manager.
