# NativeForms Prefill Engine PDG - V2

## Purpose
Define the JSON protocol for the NativeForms Prefill Lambda. This Lambda is separate from the Submit Lambda and is responsible for reading Salesforce data and returning normalized JSON for an S3-hosted HTML form.

## Architecture Role
The Prefill Lambda is a dedicated read engine.

- S3 HTML: presentation and client-side field binding
- Prefill Lambda: read data, execute read commands, map results to normalized JSON
- Submit Lambda: execute write commands on submit
- Salesforce: source of truth

## Top-Level Request Contract
```json
{
  "prefillToken": "abc123",
  "request": {
    "formId": "supportForm1",
    "onNotFound": "ignore",
    "params": {
      "email": "user@example.com"
    },
    "commands": [ ... ],
    "responseMapping": { ... }
  }
}
```

## Supported Command Types

### findOne
- Finds a single record using equality filters joined by `AND`
- Returns the first matching record or `null`

### getById
- Reads one record directly by Salesforce Id

### findMany
- Returns multiple records using equality filters plus `limit`
- Supports optional `orderBy`

Example:
```json
{
  "type": "findMany",
  "commandKey": "findCases",
  "objectApiName": "Case",
  "where": {
    "ContactId": "{foundContact.Id}"
  },
  "fieldsToReturn": ["Id", "CaseNumber", "Subject", "Status"],
  "orderBy": {
    "field": "CreatedDate",
    "direction": "DESC"
  },
  "limit": 20,
  "storeResultAs": "foundCases"
}
```

## orderBy Contract
`findMany.orderBy` is optional.

Single-field shape:
```json
{
  "field": "CreatedDate",
  "direction": "DESC"
}
```

Rules:
- `field` is required
- `direction` may be `ASC` or `DESC`
- default direction is `ASC`

## Variable Resolution
Supported forms:
- `{params.email}`
- `{foundContact.Id}`
- `{firstNotBlank(contact.Id, foundContact.Id)}`

## responseMapping
`responseMapping` converts raw command results into normalized JSON for the page.

```json
{
  "input.email": "{foundContact.Email}",
  "hidden.contactId": "{foundContact.Id}",
  "repeatGroups.existingCases": "{foundCases}"
}
```

## Normalized Response Contract
```json
{
  "success": true,
  "formId": "supportForm1",
  "input": { ... },
  "hidden": { ... },
  "meta": { ... },
  "repeatGroups": {
    "existingCases": [ ... ]
  },
  "results": [ ... ]
}
```

## Not Found Behavior
`request.onNotFound` or command-level `onNotFound` controls behavior when `findOne` or `getById` returns no record.

Supported values:
- `ignore`
- `error`

Object shape is also allowed:
```json
{
  "action": "error",
  "message": "No matching Contact found"
}
```

## Boundaries
Supported now:
- `findOne`
- `getById`
- `findMany`
- `limit`
- `orderBy`
- normalized `repeatGroups` output

Still deferred:
- pagination
- arbitrary SOQL from the client
- write actions in the Prefill Lambda
