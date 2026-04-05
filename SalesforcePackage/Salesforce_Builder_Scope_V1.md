# Salesforce Builder Scope V1

## Goal
Define the first supported scope for the NativeForms Salesforce builder so development can start with clear boundaries.

## V1 Principles
- Support the flows already proven on AWS
- Keep the builder practical and simple
- Prefer a smaller stable scope over a broad unstable one
- Defer advanced features that are not needed to start delivering value

## V1 Supported Form Capabilities

### Supported form lifecycle
- create a form
- create versions
- edit a draft version
- publish a version
- republish a version
- unpublish a version
- track publication history

### Supported UI element types
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

### Supported input styles in V1
- text
- email
- number
- date
- textarea
- select
- checkbox
- radio
- hidden

### Supported repeat group capabilities
- stacked or table rendering
- add row
- remove row
- `maxRows`
- prefill rows from AWS
- submit rows with `upsertMany`
- delete tracked removed rows

### Supported client-side UI behavior
- required field validation
- repeat-row validation
- conditional visibility
  - `equals`
  - `notEquals`
  - `isBlank`
  - `isNotBlank`
  - `contains`
- `whenFalse = hide`
- `whenFalse = disable`
- `clearWhenHidden`

### Supported theme/settings behavior
- form width
- page background
- form background
- button colors
- table header colors
- direction `ltr/rtl`
- debug on/off

### Supported extensibility
- custom CSS
- custom JS
- runtime event API

## V1 Supported AWS action types

### Prefill
- `findOne`
- `getById`
- `findMany`

### Submit
- `create`
- `update`
- `delete`
- `upsertMany`

### Shared command features
- `runIf`
- `fieldsToReturn`
- `where`
- `orderBy`
- `limit`
- `storeResultAs`
- `responseMapping`
- `onNotFound`

## V1 Supported security model
- per-form `publishToken`
- per-form DynamoDB record
- server-side `prefillDefinition`
- server-side `submitDefinition`
- server-side command/object/field allowlists
- security modes:
  - `public-create`
  - `public-prefill`
  - `secure-edit`

## Recommended V1 Builder UX

### Builder areas
- Form setup
- Version settings
- Elements designer
- Actions designer
- Theme/settings
- Publish panel

### Elements designer in V1
Keep it simple:
- ordered list editor
- add element
- edit element
- reorder elements

### Actions designer in V1
Keep it structured:
- choose scope: Prefill or Submit
- choose command type
- choose object
- edit command JSON/config
- reorder commands

This is simpler than trying to build a full no-code graph editor in V1.

## Explicitly Deferred In V1

### UI components
- file upload

### Advanced runtime
- pagination in repeat-group prefill
- external-id upsert
- advanced conditional formulas
- cross-form shared runtime packages

### Security/ops deferred
- rate limiting
- CAPTCHA / honeypot
- stronger operational logging / monitoring
- cleaner stripping of Salesforce `attributes` in prefill rows

### Enterprise governance deferred
- approval workflow before publish
- multi-step release workflow
- environment promotion pipeline

## Recommendation For First Build
Build the first Salesforce app to support:
1. versioned form design
2. ordered element builder
3. ordered action builder
4. theme/settings
5. publish to AWS
6. publication log

This is enough to reproduce the working AWS prototype from Salesforce.

## Exit Criteria For V1
V1 is successful when a Salesforce admin can:
- create a form and version
- define elements
- define prefill and submit actions
- publish the form
- generate HTML
- register the form in AWS
- use the published form successfully end to end
