# NativeForms V1 Specification Guide

## Overview
NativeForms V1 defines a standalone HTML form architecture. Each form is a self-contained artifact including UI, configuration (`FORM_DEF`), and runtime engine.

## Architecture
Each published form includes:
- HTML layout
- Embedded `FORM_DEF` JSON
- Generic runtime engine
- Optional custom CSS and JS

## FORM_DEF Structure
```js
{
  version: "1.0",
  formId: "example-form",
  endpoints: { prefillUrl: "...", submitUrl: "..." },
  tokens: { prefill: "...", submit: "..." },
  settings: { debug: false },
  theme: { maxWidth: "760px" },
  resources: { customCss: "", customJs: "" },
  ui: { title: "Form Title" },
  elements: [ ... ],
  prefill: { ... },
  submit: { ... }
}
```

## Element Types
Supported element types:
- heading
- text
- link
- image
- divider
- spacer
- input
- textarea
- select
- checkbox
- hidden
- section
- columns
- repeatGroup

## Prefill Structure
```js
prefill: {
  enabled: true,
  params: { email: "{input.email}" },
  commands: [ ... ],
  responseMapping: {
    "input.firstName": "{foundContact.FirstName}",
    "repeatGroups.existingCases": "{foundCases}"
  }
}
```

## Submit Structure
```js
submit: {
  commands: [
    { type: "update", objectApiName: "Contact", ... },
    { type: "upsertMany", objectApiName: "Case", rows: "{input.existingCases}", ... }
  ]
}
```

## Expression Syntax
Supported expressions:
- `{input.field}`
- `{params.field}`
- `{commandResult.field}`

Supported functions:
- `firstNotBlank()`
- `concat()`
- `trim()`

## Repeat Group Table View
`repeatGroup` now supports a UI rendering option:

```js
{
  id: "existingCases",
  type: "repeatGroup",
  key: "existingCases",
  label: "Existing Cases",
  viewMode: "table",
  addButtonLabel: "+ Add another case row",
  fields: [
    { key: "CaseNumber", label: "Case Number", readOnly: true, columnWidth: "140px" },
    { key: "Subject", label: "Subject", columnWidth: "220px" },
    { key: "Status", label: "Status", columnWidth: "140px" },
    { key: "Description", label: "Description", type: "textarea", columnWidth: "320px" },
    { key: "Id", type: "hidden" }
  ]
}
```

### Table Rendering Rules
- `viewMode: "table"` renders repeat-group rows in a grid instead of stacked cards.
- Each visible field becomes a column.
- `label` is used as the table header text.
- `columnWidth` is optional UI-only metadata for column sizing.
- `readOnly: true` keeps cells visible but not editable.
- Hidden fields still travel in the row data but do not render as columns.

## Repeat Group Data Contract
The Lambda contract does not change for table mode.

- Prefill still maps rows into `repeatGroups.<groupKey>`
- Submit still sends row data under `input.<groupKey>`
- `upsertMany` still uses row `Id` to decide update vs create
- Deleted row ids still live under `input._deletedRepeatGroups.<groupKey>`

This means `viewMode: "table"` is an HTML/runtime concern only, not a Lambda protocol change.

## Lifecycle and API
Custom JS can interact via NativeForms API:
- `getValue(key)`
- `setValue(key, value)`
- `showElement(id)`
- `hideElement(id)`
- `on(event, handler)`

Supported events:
- `form:init`
- `form:ready`
- `prefill:before`
- `prefill:after`
- `submit:before`
- `submit:after`
- `submit:error`
- `change`

## Key Rules
1. `FORM_DEF.version` is required.
2. `elements` is ordered.
3. Input values are collected into the `input` object.
4. Tokens are required.
5. The engine handles execution.
6. Custom JS is optional.
7. `repeatGroup.viewMode` is optional. Default rendering remains stacked.
8. Table view does not change Lambda payload shape.
