# NativeForms Custom JavaScript Pro Spec

## Summary
Expose `Custom JavaScript` as a Pro-only form-level feature in TwinaForms.

Admins should be able to open Form Settings, edit JavaScript in a dedicated modal, save it on the form version, publish the form, and have that script run in the published browser runtime through a small supported `window.TwinaForms` API.

This is not a Lambda feature. It is a browser/runtime feature with plan gating and strong warning copy.

## Current Repo State
The repo already contains partial plumbing:

- `NF_Form_Version__c.Custom_JS__c`
- `NF_Form_Version__c.Custom_CSS__c`
- publisher copies those values from draft to published version
- publisher injects raw CSS and raw JS into the final HTML

Current gaps:

- no Designer UI for editing Custom JS
- no supported TwinaForms runtime API implementation, even though docs already promise one
- no plan flag for Custom JS
- no Home / upgrade / compare-plans exposure
- current raw script injection is not product-safe enough

## Product Decision
Custom JavaScript should be a Pro-only advanced feature.

Customer-facing name:
- `Custom JavaScript`

Internal feature flag:
- `enableProCustomJs`

Positioning:
- advanced browser-side automation for published forms
- not needed for ordinary forms
- intended for customers who want light scripting similar to FormAssembly-style customization

## UX Decision
### Form Settings
Add a new advanced setting in Form Settings:

- section: `Advanced`
- row/entry: `Custom JavaScript`
- helper text: `Run advanced browser-side automation in the published form.`

The row should show one of:

- `Not configured`
- `Configured`

and an action button:

- `Edit Custom JavaScript`

### Editor Modal
Clicking the row opens a modal, not an inline textarea.

Modal content:

- title: `Custom JavaScript`
- large monospace textarea
- short help copy:
  - `Your code runs in the published browser form. Use the TwinaForms runtime API when possible.`
- help link:
  - `Learn Custom JavaScript`
  - opens `https://twinaforms.com/help/custom-javascript`
- warning box:
  - `Custom JavaScript can read and change form values in the browser. Use only trusted code.`

Buttons:

- `Save`
- `Cancel`
- `Clear Code`

Behavior:

- explicit save only
- no blur auto-save
- published/read-only versions show the code but cannot edit it

### Supported Runtime Guidance
Official support should target a small TwinaForms API, not arbitrary DOM selectors.

Supported customer guidance:

- `TwinaForms.getValue(key)`
- `TwinaForms.setValue(key, value)`
- `TwinaForms.getAll()`
- `TwinaForms.on(eventName, handler)`
- `TwinaForms.off(eventName, handler)`
- `TwinaForms.showElement(id)`
- `TwinaForms.hideElement(id)`

Direct DOM scripting may still work, but it should be documented as less stable than the supported API.

## Runtime Design
### Required Change
The current publisher injects raw JS directly:

- this is technically functional
- but syntax errors can break page execution
- and there is no supported API contract behind it yet

### New Runtime Contract
Before executing customer code, the publisher must create:

- `window.TwinaForms`

with the documented methods and event hooks.

Compatibility rule for V1:

- official public name: `window.TwinaForms`
- compatibility alias during transition: `window.NativeForms = window.TwinaForms`

Customer docs and help examples should use `TwinaForms`, not `NativeForms`.

Required events:

- `form:init`
- `form:ready`
- `change`
- `prefill:before`
- `prefill:after`
- `prefill:error`
- `submit:before`
- `submit:after`
- `submit:error`

### Safer Execution Model
Do not append the raw stored JS as a plain `<script>` block.

Instead:

1. store the raw code in `Custom_JS__c`
2. publisher serializes it safely into the page as a string
3. runtime executes it through a guarded function call
4. any script error is caught and logged without breaking the rest of the form boot

Recommended shape:

- build `window.TwinaForms`
- dispatch `form:init`
- finish runtime boot
- dispatch `form:ready`
- then execute custom JS with `TwinaForms` passed in

Outcome:

- syntax/runtime failures stay isolated
- published form still loads
- customer code gets a stable API object

### Error Handling
If custom JS fails:

- do not break publish output
- do not block the public form from rendering
- log a clear console error:
  - `TwinaForms custom JavaScript error`

Optional V1 behavior:

- only show console errors
- do not add end-user UI banners

## Salesforce Changes
### Data Model
No new form-version fields are required for V1:

- reuse `Custom_JS__c`

Keep `Custom_CSS__c` internal for now unless separately productized.

### Apex / DTO Changes
Extend the Designer workspace/version DTO so Form Settings can read and save:

- `customJs`
- `hasCustomJs`

### Feature Gating
Add:

- `NativeFormsFeatureFlags.isProCustomJsEnabled()`

Expose it in Designer workspace payload:

- `enableProCustomJs`

Designer behavior:

- Starter: show locked Pro row with upgrade framing
- Pro/trial: show active editable row

### LWC / Designer
Add to Form Settings:

- `Custom JavaScript` row in `Advanced`
- modal editor state and save flow

Do not use field blur auto-save.
Save should happen only from the modal save action.

### Publish
Publisher must:

- continue copying `Custom_JS__c` from draft to published version
- change execution from raw direct append to guarded runtime execution
- build the `window.NativeForms` API before running custom code

## DynamoDB / AWS Changes
### Required
Add a new plan feature flag:

- `enableProCustomJs`

This belongs in:

- `NativeFormsPlans.featureFlags`
- tenant plan overrides
- effective feature flags payloads

### Not Required
No new submit/prefill Lambda behavior is required.
AWS should not execute custom JS.

### Optional Support Metadata
Optional future enhancement:

- include `hasCustomJs` or `customJsEnabled` in published form registration metadata for support visibility

This is not required for V1.

## Admin Console Changes
### Plan Definitions
Add `enableProCustomJs` to:

- plan seeds
- feature metadata map
- tenant override editing

Customer-facing label:

- `Custom JavaScript`

Description:

- `Run advanced browser-side automation inside published forms.`

### Admin UX
Place it with other advanced Pro features.
Do not bury it under security or logs.

## Home Page In Salesforce
Add Custom JavaScript as a plan-driven upgrade feature item on Home.

Recommended label:

- `Custom JavaScript`

Recommended detail:

- `Add advanced browser-side automation to published forms.`

It should appear only when:

- the current plan does not include `enableProCustomJs`
- and the compare/upgrade block is already being shown

## Upgrade / Compare Plans HTML
Add a feature tile/row:

- `Custom JavaScript`

Short description:

- `Run advanced browser-side automation in published forms.`

Do not oversell this as everyday form logic.
It should be grouped under advanced automation/customization, not basic setup.

## Security and Trust Position
This feature is powerful and risky.

Important truths:

- it runs in the customer’s public browser form
- it can read and change user-entered data
- it can call external endpoints from the browser
- it must be treated as trusted admin-authored code only

V1 rules:

- Pro only
- editable only by Salesforce admins already using Designer
- strong warning copy in the editor modal
- supported API documented clearly
- TwinaForms supports the runtime API, not every arbitrary DOM hack

## Recommended Customer Example
Example value proposition:

- map a country field to a phone country code field
- build a display field from multiple inputs
- lightweight show/hide logic beyond standard builder conditions

## Help Page and In-Product Help
### Required External Help Page
Add a TwinaForms help page:

- URL: `https://twinaforms.com/help/custom-javascript`

The editor modal should link to this page with:

- `Learn Custom JavaScript`

### Help Page Content
The help page should include:

- what Custom JavaScript is
- warning that it runs in the browser
- official supported API reference using `TwinaForms.*`
- note that `TwinaForms` is the supported contract and direct DOM selectors are less stable
- a short getting-started example
- several practical examples

### Required Example Topics
At minimum include:

- country to phone country code
- build one field from two input fields
- show or hide a block based on a checkbox
- set a default message when a field changes

### Example Style
Examples should be:

- short
- copy-paste friendly
- written with `TwinaForms`, not `NativeForms`
- based on real field keys like `text5` and `text6`

## Testing Plan
### Apex
Add/extend tests for:

- workspace returns `enableProCustomJs`
- version DTO round-trip for `Custom_JS__c`
- publisher includes runtime API and guarded custom JS execution block
- publish copy draft -> published keeps `Custom_JS__c`

### LWC
Manual QA:

- Pro org can open modal, save code, republish, and run code
- Starter org sees locked upgrade path
- published form still loads when code contains runtime errors
- supported API methods work for simple examples

### AWS
Verify:

- Starter effective flag = false
- Pro effective flag = true
- tenant override support works in Admin Console
- Home / compare / upgrade payloads expose the feature correctly

## Rollout Order
1. add plan flag and Admin Console metadata
2. add Salesforce entitlement plumbing
3. add Form Settings modal and save flow
4. implement `window.NativeForms` runtime API
5. change publisher to guarded custom JS execution
6. update Home and compare/upgrade surfaces
7. add docs/examples

## Scope Recommendation
V1 should include:

- one JS editor modal
- one supported runtime API
- one Pro feature flag
- one Home / upgrade message

V1 should not include:

- CSS editor productization
- script libraries
- external package imports
- server-side JS execution
- marketplace/template gallery for scripts

## Final Recommendation
This feature is worth adding because much of the storage/publish plumbing already exists.

But it should not be exposed as a normal customer feature until TwinaForms adds:

- Pro gating
- a supported runtime API
- guarded execution
- clear warning copy
- consistent upgrade/admin-plan exposure

Without those pieces, it remains an internal backdoor rather than a launch-safe feature.
