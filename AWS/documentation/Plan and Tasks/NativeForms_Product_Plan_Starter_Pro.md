# NativeForms Product Plan

## Purpose
This document defines:
- the commercial packaging for `Starter` and `Pro`
- the recommended launch sequence
- the minimum launch scope for `Starter`
- the current missing items before `Starter` is production-ready
- the trust, security, and load-readiness review for the current design

The current recommendation is:
- launch both plans commercially together
- but finish and harden the `Starter` package first
- then enable `Pro` features on top of the same stable platform

---

## Commercial Plan

### Starter
- price: `$70/month`
- active forms: up to `3`
- monthly submissions: up to `1,000`
- designer users: `1`
- prefill and submit engine: included
- repeatable prefill: not included
- repeat groups / repeatable sections: not included
- submission logs: included
- file uploads: not included
- advanced logic: one condition
- post-submit redirect: not included
- support: standard

### Pro
- price: `$200/month`
- active forms: unlimited
- monthly submissions: unlimited
- designer users: up to `5` users, with future paid extra-user option
- prefill and submit engine: included
- repeatable prefill: included
- repeat groups / repeatable sections: included
- submission logs: included
- file uploads: included
- advanced logic: multiple conditions
- post-submit redirect: included
- support: priority

---

## Support Definition

### Starter Support
- support channel: standard email support
- response target: within `2 business days`
- includes:
  - installation/setup help
  - bug acknowledgment
  - general troubleshooting
- does not include:
  - custom implementation work
  - priority debugging

### Pro Support
- support channel: priority email/support queue
- response target: within `1 business day`
- includes:
  - priority bug handling
  - faster troubleshooting
  - higher-priority onboarding/support
- future option:
  - premium onboarding / consulting add-on

---

## Product Positioning

### Starter is the core sellable product
Starter must already feel:
- stable
- secure
- easy to understand
- usable without internal/debug knowledge

Starter is not the "prototype tier".
Starter should already be good enough for real customers.

### Pro is the expansion tier
Pro adds:
- scale
- richer automation
- more advanced logic
- more UX control
- more admin/control features

---

## What Starter Must Include

Starter should include these product capabilities at launch:

### Core form lifecycle
- create form
- create/edit draft version
- publish form to AWS
- lock published version
- auto-create next draft after publish
- view published URL

### Designer
- usable `NativeForms Designer`
- clean left/center/right layout
- add basic field and display elements
- sections
- Salesforce lookup input field:
  - single-select lookup
  - live Salesforce search after the visitor types
  - no default/preloaded record list in the public form
  - selected record `Id` submits into a mapped Salesforce reference field
- image element
- display text element
- conditional view with one condition for fields, display elements, sections, and groups; Records List container visibility remains deferred
- basic validations:
  - text rule
  - number min/max
  - date from/to

### Prefill and Submit
- prefill mapping to Salesforce
- submit mapping to Salesforce
- prefill and submit actions working in runtime
- lookup fields can resolve a prefilled Salesforce Id into a display label
- one-condition logic only
- secure Salesforce update links:
  - public form link can be tied to an existing Salesforce record
  - User Verification protects the visitor flow with a one-time email code before sensitive prefill/update behavior
  - submit updates the intended Salesforce record without requiring the visitor to log in
- ready-to-use Salesforce registration form:
  - Starter template should support common event/webinar registration
  - default flow creates or updates Contact and creates/updates Campaign Member when Campaigns are used
  - demonstrates related Salesforce record creation without requiring custom development

### Published runtime
- clean public hosted form
- mobile-friendly runtime
- thank-you behavior at least in a basic form
- branding retained for Starter

### Visibility / audit
- submission logs included
- ability to view logs per form from Salesforce by pulling from AWS

### Security / trust
- tenant isolation by `orgId`
- Bootstrap V2 HMAC for package-to-AWS admin/server calls
- publish token for runtime
- server-side enforcement of object/field/command allowlists
- User Verification for secure public record-update flows
- User Verification session duration is configurable per form version:
  - default is the current short session behavior, based on the code expiry window
  - optional same-tab session stores the signed verification token in browser `sessionStorage`, survives refresh in that tab, expires at the visitor's local midnight, and is capped by AWS at 12 hours
  - closing the browser tab clears the session because V1 intentionally does not use `localStorage`
- Designer UX names the feature `User Verification` and offers it under `Special Elements`, because it changes the visitor journey rather than displaying passive content. Adding the fixed-position canvas gate enables verification and removing it disables verification after confirmation. Its message, button, rule, and session controls live in the right-side properties panel as a system block, not a normal submitted field. Customer-facing copy should say `verification number`, not `secret code`. Internal/runtime `secretCode...` identifiers may remain only for compatibility with existing published forms and package versions; new package-visible metadata should avoid `Secret Code` naming when a safe migration path exists.
- Designer drag/drop reordering should be optimistic and narrow: update the canvas locally, preserve the selected right-panel state, save a parent/column/index move to Salesforce in the background, and reload the workspace only on failure. This applies to top-level moves and moves within section/group/records-list columns.

### Support
- standard support process defined

---

## What Pro Adds

Pro should build on Starter and add:

### Usage / capacity
- unlimited forms
- unlimited submissions
- more designer users

### Runtime / designer power
- repeatable prefill
- repeat groups bound to `findMany` prefill aliases
- repeat-group add/remove rows
- repeat-group submit via multi-row upsert behavior
- file uploads
- multi-condition logic
- AND/OR logic
- future chained logic based on previous prefill or submit outcomes
- post-submit redirect
- AWS-backed Country / State / City autocomplete:
  - feature flag: `enableProLocationFields`
  - uses TwinaForms-owned GeoNames data in AWS, not Google APIs
  - renders one grouped Location field with dependent country, state/region, and city autocomplete
  - Salesforce submit mapping exposes three explicit output fields: Country Name, State/Region Name, and City Name

### Experience / control
- richer branding controls
- custom logo
- more advanced submission logs and filters
- create form from Salesforce page layout:
  - feature flag: `enableProPageLayoutClone`
  - admin chooses an object and page layout
  - V1 reads Salesforce layout metadata through the org's stored AWS OAuth connection using Salesforce UI API; the imported source is the assigned Salesforce page layout for the connected admin/profile and record type
  - TwinaForms creates a draft form from supported fields in the returned layout sections, preserving section grouping where possible
  - Salesforce ownership/audit/system fields such as Owner, Created By, Created Date, Last Modified By, Last Modified Date, and System Modstamp are ignored instead of shown as skipped import problems
  - create-only fields returned by the layout, including reference/lookup fields, can be imported for secure update-or-create mode with locked-when-prefilled behavior; publish emits them as create-only submit mappings so updates omit them but fallback creates include them
  - after creation, the Designer opens a required acknowledgement modal that summarizes imported fields, create-only behavior, skipped fields, and how the admin can change the outcome in Salesforce or by choosing a different submit mode
  - prefill can load an existing record by `recordId`
  - submit updates the intended record or creates a new record when configured and no existing record is found
  - V1 secure update must always use User Verification with the existing Salesforce Contact/email matching model, regardless of the target form object
  - if the visitor email is not found as a Salesforce Contact, the visitor cannot edit the form through User Verification
  - V1 does not attempt generic arbitrary-object identity verification; create-only flows remain available when Contact/email verification is not appropriate
  - V1 does not retrieve arbitrary unassigned layout files by Metadata API; that remains an explicit expansion option if customers need to select a layout that is not assigned to the connected admin/profile

### Competitor-parity Pro backlog
This is the current corrected list of competitor-driven Pro features that are not yet treated as complete product scope:

Ordered from easiest to most complex:

| Order | Feature | Complexity | Notes |
|---:|---|---|---|
| 1 | Clone field / clone section | Low | Designer-only productivity improvement. Reuse existing element/config copy behavior and generate fresh element keys. |
| 2 | Clone form | Implemented as Pro productivity foundation | Copy form, latest draft/version, elements, prefill actions, submit actions, and settings into a new draft form. |
| 3 | Salesforce-focused template library | Medium | Seed polished starter templates such as Lead Capture, Contact Update, Case Request, Campaign Event Registration, Volunteer Signup, Donation/Pledge, Consent, File Request, and Feedback Survey. |
| 4 | Survey field styles | Implemented as Pro V1 foundation | `enableProSurveyFields` gates survey-focused presentations that still save simple values: 1-5 star rating, NPS 0-10, Likert scale, ranking, and satisfaction scale. Rating and NPS map cleanly to Salesforce Number fields, Likert/satisfaction map to Picklist or Text, and ranking maps to Long Text Area as an ordered value list. |
| 5 | Multi-page forms with progress | Medium-high | Add page/step containers, runtime navigation, validation per page, and progress display. |
| 6 | Registration kit | Medium-high | Pro expansion of the registration template with optional TwinaForms Event / Registration objects, capacity, waitlist, cancellation/update link, and attendance status. |
| 7 | Create form from Salesforce page layout | Medium-high | Admin selects an object and TwinaForms reads the assigned Salesforce page layout through AWS/UI API, then creates a draft form from supported layout sections/fields, adds prefill by `recordId`, and configures submit to update-or-create the same object. V1 ignores Salesforce ownership/audit/system fields, imports create-only lookup fields as create-only mappings where possible, shows an acknowledgement modal for import effects, skips unsupported fields, and always uses User Verification with Salesforce Contact/email matching for secure update links; visitors without a matching Contact cannot edit. |
| 8 | Submission PDF | Implemented as Pro V1 foundation | `enableProSubmissionPdf` gates Form Settings for a readable submitted-response PDF. V1 copies fields, display text, images, and signatures in published form order and can attach the PDF to the chosen Salesforce submit target record. A Signature placed inside a Records List automatically enables and requires this PDF output; there is no separate row-signature-PDF product feature. |
| 9 | Merged Document | Planned Pro V1 foundation | `enableProMergedDocument` gates a document-style rich text element that can insert prefill alias values with tokens such as `{{Contact.FirstName}}`. V1 does not create hidden fields, supports prefill alias field paths only, resolves values in published runtime, and includes the resolved text in Submission PDF when PDF is enabled. |
| 9 | Save and resume | High | Store draft responses securely, issue resume link/code, reload draft state, and handle expiry/cleanup. |
| 10 | Electronic signature | Implemented as Pro V1 foundation | `enableProElectronicSignature` gates the Signature element in Designer, including one Signature per Records List in V1. Published forms capture a drawn PNG; normal Signatures may attach to a submit target record, and row Signatures may attach to their saved row record while appearing in Submission PDF. |

File uploads are already in Pro scope, and uploaded files already attach to the submit target object in Salesforce. Do not track "attach uploads to Salesforce Files" as a missing competitor-parity item unless that behavior regresses or the target-object attachment model changes.

### Support
- priority support

---

## Starter Gap Analysis

Below is the current assessment of what is still missing before `Starter` should be considered production-ready.

### 1. UX / Designer polish
Status:
- partially implemented

Still missing:
- prefill and submit look-and-feel cleanup in Designer
- right-panel polish
- smaller / calmer typography across Designer
- sticky left/right panes with only center canvas scrolling
- canvas should reflect real CSS/theme more accurately
- form title/readable settings polish

Why it matters:
- AppExchange customers will judge quality immediately from setup and designer screens
- prototype-level UI will reduce trust, even if functionality works

### 2. Theme / visual control
Status:
- partially present in data model, not complete as a product feature

Still missing:
- real form theme editor
- clear page width control
- real CSS design theme support in Designer and runtime
- preview fidelity between Designer and published runtime

Decision:
- theme support should be included in Starter, at least at a basic level
- page background supports an optional background image. Without an image, it uses a start color and a gradient color; setting both colors to the same value publishes a solid background on desktop and mobile.
- theme branding supports a header image and optional footer image. Uploaded theme images are stored as Salesforce Files and embedded into published HTML when under the current embedded-image size limit.
- theme typography offers safe system fonts plus selected Google Fonts. Published HTML loads only selected Google Fonts and falls back to Arial if the external font request is blocked.

### 3. Prefill / submit UX model
Status:
- functional prototype exists

Still missing:
- production-grade prefill page UI
- production-grade submit page UI
- clearer action/condition builders
- cleaner form/version/action presentation
- more understandable mapping UX

Starter requirement:
- single-condition logic only
- structured field / operator / value conditions

### 4. Submission logs
Status:
- desired, not complete as finished product feature

Still missing:
- log each submit in DynamoDB
- Salesforce-side log viewer per form
- basic recent log experience for Starter

Starter requirement:
- included

### 5. Thank-you / post-submit UX
Status:
- not finished

Still missing:
- basic thank-you page/message support

Starter:
- basic thank-you support should exist

Pro:
- post-submit redirect URL

### 6. Mobile responsiveness
Status:
- direction is good, but not finished productized behavior
- recommended as the next highest-priority Starter item

Still missing:
- explicit responsive runtime behavior review
- section/column collapse rules
- mobile test pass on published forms

Starter requirement:
- yes

### 7. Clean app packaging
Status:
- not finished

Still missing:
- remove raw object tabs from customer-facing app
- reduce internal/debug exposure
- improve setup navigation

Starter requirement:
- yes

### 8. Numbering and record hygiene
Status:
- not fully standardized

Still missing:
- action and element numbering/indexing per form
- cleanup strategy for old/orphaned records
- clean draft/published lifecycle consistency

Starter requirement:
- yes

### 9. Security / trust review
Status:
- foundation is good

Still missing before production:
- full secret rotation/admin recovery flow
- plan enforcement tied to tenant record on AWS
- better operational monitoring
- customer-safe error handling and auditability

Details are in the security review section below.

### 10. AWS production setup
Status:
- prototype works

Still missing:
- CloudFront to the production website/domain
- production hosting/branding path
- submission log APIs
- plan-limit enforcement in AWS

Starter requirement:
- yes

---

## Items Missing for Starter

This is the practical Starter to-do list.

### Product / UX
- clean up prefill and submit UX
- smaller overall fonts / more polished visual hierarchy
- canvas should reflect real CSS/theme
- right-panel polish
- sticky side panes with center scroll
- readable form title/settings
- clean app navigation and remove raw object tabs
- **"Create Sample Records" onboarding button** — a one-click action in the NativeForms app that seeds a new user's org with ready-to-use sample data so they can immediately try the full product end-to-end:
  - creates `1` sample Contact
  - creates `4` sample Cases linked to that Contact
  - creates a sample Form that shows the Contact details and a repeatable Cases section (prefill + submit)
  - creates a second sample Form with a prefill query by `Email` that loads the matching Contact and lets the end user update the Contact's details

### Designer / Runtime
- basic theme editor
- form width setting
- mobile responsive runtime review and fixes
- basic thank-you page/message
- richer validation polish

### Prefill / Submit
- single-condition structured builder
- one-condition logic in production UX
- stable runtime behavior and clearer admin editing flow

### AWS / Logging / Limits
- log every submit in DynamoDB
- log viewer in Salesforce
- plan limits enforced in AWS:
  - forms
  - submissions
  - designer users

### Security / Trust / Readiness
- production tenant/admin secret management flow
- operational monitoring and alerting
- safer customer-facing error handling
- full trust review before AppExchange launch

---

## Security / Trust Review

Based on the current documents:
- [Multi tenant and security approach.md](/c:/Users/Yosi/NativeFormsAWS/AWS/documentation/Multi%20tenant%20and%20security%20approach.md)
- [Security Protocols.md](/c:/Users/Yosi/NativeFormsAWS/AWS/documentation/Security%20Protocols.md)

### What is already strong
- tenant isolation by `orgId`
- separate trust layers:
  - tenant trust
  - form trust
- per-form publish token
- tenant secret not used in public runtime
- server-side allowlists for:
  - commands
  - objects
  - writable fields
- tenant status checks
- form status checks

This is a strong foundation for a multi-tenant AppExchange product.

### What still needs work before production

#### Secret lifecycle
- admin-friendly secret rotation
- secret reset / recovery flow
- clearer setup lifecycle if credential configuration is broken

#### Operational trust
- monitoring for failed prefill/submit calls
- monitoring for abnormal submit spikes
- monitoring for tenant status / connection issues

#### Customer-safe errors
- current prototype still leaks technical-style errors sometimes
- production runtime should show safer customer messages
- admin logs should keep the technical detail separately

#### Plan enforcement trust
- AWS should be the source of truth for plan state
- per-tenant limits should be enforced server-side, not just hidden in UI

#### File/image asset review
- image/file behavior should be reviewed for storage, hosting, and access safety
- especially if Pro adds file uploads

### Security conclusion
The current architecture is directionally correct for production.
The missing work is not "rebuild security from scratch".
It is mainly:
- operations
- lifecycle management
- hardening
- admin recovery/monitoring

---

## Load / Scale Review

### Current strengths
- AWS-hosted runtime
- form definitions stored server-side
- direct publish architecture already working
- DynamoDB is appropriate for form/security/log storage

### Still needed for production
- submission logging design finalized
- CloudFront on production domain
- rate/usage monitoring
- plan-limit enforcement
- possible protection for abuse spikes

### Load conclusion
The current architecture can grow into production, but Starter launch still needs:
- monitoring
- log visibility
- usage-limit enforcement

---

## Recommended Launch Sequence

### Phase A: Finish Starter
1. versioning and lifecycle complete
2. clean app UX
3. theme/basic styling support
4. prefill/submit UX cleanup
5. mobile runtime polish
6. submission logs
7. thank-you page/message
8. AWS plan/log/domain setup
9. trust/security hardening pass

### Phase B: Launch Starter + Pro together
At launch:
- Starter fully supported
- Pro plan exists and is sellable
- but only enable Pro features that are already stable

### Phase C: Expand Pro
After launch:
- repeatable prefill
- repeat groups / repeatable sections
- file uploads
- AND/OR multi-condition builder
- post-submit redirect
- richer logs and filters
- future secure code / verification flow

---

## Recommendation

Do not treat Starter as a lightweight prototype plan.

Starter should be:
- polished
- stable
- secure
- commercially credible

Pro should be:
- the scale/power upgrade

So the next execution focus should be:
1. finish Starter completely
2. enforce plans in AWS
3. then finish remaining Pro-only features
