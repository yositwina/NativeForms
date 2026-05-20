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
- multiCheckbox
- checkbox
- radio
- lookup
- time
- image
- section
- columns
- hidden
- repeatGroup

### Time Field V1
`time` is a simple input field for time-of-day values.

- Time fields are rendered as TwinaForms-controlled text inputs, not native browser time inputs.
- This avoids browser/OS locale surprises such as showing AM/PM to users who expect 24-hour time.
- Field setting: `Time Format`.
  - `24-hour (19:00)` accepts `00:00` through `23:59`.
  - `12-hour (8:00 PM)` accepts `1:00 AM` through `12:59 PM`, with optional leading zero.
- The value submitted to AWS/Salesforce remains the plain `HH:mm` string.
- In 12-hour mode, TwinaForms converts the display value to `HH:mm` before submit.
- AWS submit does not normalize Time fields or add GMT/UTC suffixes in V1.
- The field can be mapped directly to Salesforce Time or Text fields when the customer expects `HH:mm`.
- Custom JavaScript and formulas read the field as a text value, for example `TwinaForms.getValue("time1")`.

### Salesforce Multi Checkbox Field V1
`multiCheckbox` is a Starter/basic input field for Salesforce Multi-Select Picklist fields.

- The customer-facing Designer label is `Multi Checkbox`.
- V1 maps only to Salesforce fields with `Schema.DisplayType.MultiPicklist`.
- The field renders as a checkbox group, not as a multi-select dropdown.
- Stored, prefilled, and submitted values use Salesforce's native semicolon string format, for example `A;B;C`.
- Prefill converts a semicolon string into checked boxes.
- Submit converts checked boxes back into a semicolon string.
- Required means at least one option is checked.
- `TwinaForms.getValue(fieldKey)` returns the semicolon string.
- `TwinaForms.setValue(fieldKey, "A;B")` checks matching option values.
- Records List rows support `multiCheckbox` using the same semicolon value format per row.
- Submission PDF displays selected option labels joined by comma, not raw API values.
- Create From Layout maps Salesforce `MultiPicklist` fields to `multiCheckbox` and uses translated Salesforce picklist labels when available.
- Deferred: manual free-text option editing for Text fields, option-column layout settings, dependent multi-picklists.

### Salesforce Lookup Field V1
`lookup` is a Starter/basic input field for selecting one Salesforce record and submitting that record Id into a Salesforce reference field.

- Lookup fields do not preload records into the published HTML.
- The public form starts empty and searches Salesforce only after the visitor types the minimum search length.
- Default V1 search behavior:
  - minimum search length: `2`
  - debounce: about `400ms`
  - result limit: `10`
- The browser sends only `formId`, `publishToken`, `fieldKey`, and search text to the lookup endpoint.
- The browser must not send object names, SOQL, filters, or field lists.
- AWS loads the server-side lookup definition for the published form and field key, then queries only the configured target object and fields.
- The selected value submitted with the form is the Salesforce record `Id`.
- The visible lookup label is UI state only.
- Prefill can resolve an existing lookup Id into a display label through the same lookup definition.
- V1 supports single-select lookups only.
- Deferred: default/preloaded records, multi-select lookup, dependent lookup filters, lookup inside `repeatGroup`, and create-new-from-lookup.

Example registered lookup definition:
```json
{
  "lookupDefinition": {
    "fields": {
      "volunteerContact": {
        "targetObject": "Contact",
        "searchFields": ["Name", "Email"],
        "displayFields": ["Name", "Email"],
        "valueField": "Id",
        "limit": 10,
        "minSearchLength": 2
      }
    }
  }
}
```

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

Customer-facing naming:
- the technical element type remains `repeatGroup`
- the Builder / setup UI should label this element as `Records List`

## Section / Group Column Limit
Sections, Groups, and Records List row layouts share the same column-count model.

- Supported column counts are `1` through `10`.
- The Designer, Apex publisher, generated public HTML, and submission PDF renderer must all accept the same range.
- Published forms should collapse multi-column section grids to a single column on mobile.
- Values outside the supported range should be rejected or clamped by the layer that reads them.

## Records List Row Label Mode
Records List rows support a label display choice for desktop layout.

- `showLabelsOnEachRow: true` shows each field label inside every row.
- `showLabelsOnEachRow: false` shows a single table-style header row on desktop and hides repeated row labels.
- Mobile runtime must always show labels inside each row and hide the table-style header, regardless of the desktop choice.
- The Designer should expose this as an explicit Records List setting, not as a hidden runtime behavior.

## Records List Row Signature + PDF
Records List row signatures are an opt-in Pro capability for timesheet-style related-record workflows.

- Feature flag: `enableProRecordsListRowSignaturePdf`.
- The feature also requires Electronic Signature and Submission PDF entitlements.
- The setting lives on each Records List element so admins choose exactly which repeated rows require signatures.
- When an admin enables row signatures on a Records List, Designer should automatically enable and save the form-level Submission PDF setting.
- Normal Signature elements remain top-level fields and should still be blocked inside Records List rows.
- Runtime payload stores row signatures under each submitted row as `_rowSignature`; top-level `input.signatures` remains reserved for normal Signature fields.
- AWS validates required row signatures before Salesforce submit actions run.
- AWS maps each submitted row to the corresponding `upsertMany` result row id after submit.
- The final Submission PDF renders Records List rows as readable row cards and embeds each captured row signature below its row.
- Optional row signature file attachment can save each row signature PNG to the saved child row record.
- Submission logs must sanitize row signature image data and keep only metadata such as file name, signed time, and hash.

Example row payload:
```json
{
  "repeatGroups": {
    "timeRows": {
      "rows": [
        {
          "Id": "a01...",
          "Work_Date__c": "2026-05-14",
          "Hours__c": "8",
          "_rowSignature": {
            "dataUrl": "data:image/png;base64,...",
            "contentType": "image/png",
            "fileName": "timeRows-row-1-signature.png",
            "signedAt": "2026-05-14T09:00:00.000Z"
          }
        }
      ]
    }
  }
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
