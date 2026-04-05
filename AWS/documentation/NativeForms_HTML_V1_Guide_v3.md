# NativeForms V1 Specification Guide

## Overview
NativeForms V1 defines a standalone HTML form architecture. Each form is a self-contained artifact including UI, configuration (`FORM_DEF`), and runtime engine.

## Architecture
Each published form includes:
- HTML layout
- Embedded `FORM_DEF` JSON
- Generic runtime engine
- Optional custom CSS and JS
- only UI/runtime metadata in the browser

## FORM_DEF Structure
```js
{
  version: "1.0",
  formId: "example-form",
  endpoints: { prefillUrl: "...", submitUrl: "..." },
  tokens: { publish: "..." },
  settings: { debug: false },
  theme: {
    maxWidth: "760px",
    pageBackground: "#f7f7f7",
    formBackground: "#ffffff",
    buttonBackground: "#111827",
    buttonTextColor: "#ffffff",
    tableHeaderBackground: "#f3f4f6",
    tableHeaderTextColor: "#374151",
    direction: "ltr"
  },
  resources: { customCss: "", customJs: "" },
  ui: { title: "Form Title" },
  elements: [ ... ],
  prefill: {
    params: { email: "{input.email}" }
  }
}
```

## Element Types
Supported element types in the current runtime:
- heading
- text
- input
- textarea
- select
- checkbox
- radio
- image
- section
- columns
- hidden
- repeatGroup

Planned/documented but not yet implemented in this runtime sample:
- link
- divider
- spacer

## Server-Side Execution Model
The browser no longer sends prefill or submit commands.

Instead:
- HTML sends `formId`, `publishToken`, and user `params` / `input`
- AWS loads `prefillDefinition` and `submitDefinition` from DynamoDB
- Lambda executes only the stored server-side definitions

Stored in DynamoDB per form:
- `prefillDefinition.commands`
- `prefillDefinition.responseMapping`
- `prefillDefinition.onNotFound`
- `submitDefinition.commands`
- security policies and allowlists

## Prefill Structure In HTML
```js
prefill: {
  params: { email: "{input.email}" }
}
```

The full prefill commands and response mapping now belong to the published form record in DynamoDB, not the HTML.

## Expression Syntax
Supported expressions:
- `{input.field}`
- `{params.field}`
- `{commandResult.field}`

Supported functions:
- `firstNotBlank()`
- `concat()`
- `trim()`

## Conditional Visibility
Elements can define optional conditional visibility rules.

```js
{
  id: "existingCases",
  type: "repeatGroup",
  key: "existingCases",
  visibility: {
    mode: "conditional",
    logic: "all",
    conditions: [
      { field: "contactId", operator: "isNotBlank" }
    ],
    whenFalse: "hide",
    clearWhenHidden: false
  }
}
```

### Visibility Rules
- Default state is always visible.
- `logic` can be `all` or `any`.
- Supported operators:
  - `equals`
  - `notEquals`
  - `isBlank`
  - `isNotBlank`
  - `contains`
- `whenFalse` can be:
  - `hide`
  - `disable`
- `clearWhenHidden: true` clears the element value when the rule fails.

## Repeat Group Table View
`repeatGroup` supports a UI rendering option:

```js
{
  id: "existingCases",
  type: "repeatGroup",
  key: "existingCases",
  label: "Existing Cases",
  viewMode: "table",
  addButtonLabel: "+ Add another case row",
  maxRows: 20,
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
- `maxRows` limits how many rows can be displayed and added in the client.

## Repeat Group Data Contract
The Lambda contract does not change for table mode.

- Prefill still maps rows into `repeatGroups.<groupKey>`
- Submit still sends row data under `input.<groupKey>`
- `upsertMany` still uses row `Id` to decide update vs create
- Deleted row ids still live under `input._deletedRepeatGroups.<groupKey>`

### Repeat Group Query Extensions
The current prefill protocol now supports:
- `limit`
- `orderBy`

Example:
```js
{
  type: "findMany",
  objectApiName: "Case",
  where: { ContactId: "{foundContact.Id}" },
  orderBy: { field: "CreatedDate", direction: "DESC" },
  limit: 20
}
```

### Explicit Deferral
Still deferred for a later protocol revision:
- external-ID upsert for repeat groups
- pagination for `findMany`

## Appearance and Settings Contract
`settings`, `theme`, and `resources` are HTML/runtime concerns and do not change the Lambda payload shape.

### settings
```js
settings: {
  debug: true
}
```

### theme
```js
theme: {
  maxWidth: "900px",
  pageBackground: "linear-gradient(180deg, #dbeafe 0%, #93c5fd 45%, #60a5fa 100%)",
  formBackground: "#ffffff",
  buttonBackground: "#1d4ed8",
  buttonTextColor: "#ffffff",
  tableHeaderBackground: "#dbeafe",
  tableHeaderTextColor: "#1e3a8a",
  direction: "ltr"
}
```

### resources
```js
resources: {
  customCss: ".nf-form-wrapper { border: 2px solid #1d4ed8; }",
  customJs: "NativeForms.on('form:ready', () => console.log('hello'));"
}
```

### Current Runtime Support
- `settings.debug`
- theme colors and layout width
- `theme.direction` (`ltr` / `rtl`)
- injected `resources.customCss`
- executed `resources.customJs`

Not yet implemented in this runtime sample:
- logo
- font-size presets
- redirect URL
- show record reference after submit

## Runtime API and Events
Published forms expose a browser API at:

```js
window.NativeForms
```

Supported methods:
- `getValue(key)`
- `setValue(key, value)`
- `getAll()`
- `showElement(id)`
- `hideElement(id)`
- `on(eventName, handler)`
- `off(eventName, handler)`

Supported events:
- `form:init`
- `form:ready`
- `change`
- `prefill:before`
- `prefill:after`
- `prefill:error`
- `submit:before`
- `submit:after`
- `submit:error`

Events are also dispatched on `window` as browser events using the name:
- `nativeforms:<eventName>`

Example:
```js
NativeForms.on("submit:after", (detail) => {
  console.log(detail.response);
});

window.addEventListener("nativeforms:change", (event) => {
  console.log(event.detail.key, event.detail.value);
});
```

## Key Rules
1. `FORM_DEF.version` is required.
2. `elements` is ordered.
3. Input values are collected into the `input` object.
4. Tokens are required.
5. The engine handles UI/runtime behavior, while AWS handles execution definitions.
6. Custom JS is optional.
7. `repeatGroup.viewMode` is optional. Default rendering remains stacked.
8. Table view does not change Lambda payload shape.
9. Conditional visibility is an HTML/runtime concern unless later mirrored server-side.
