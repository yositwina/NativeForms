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
- image element
- display text element
- conditional view with one condition
- basic validations:
  - text rule
  - number min/max
  - date from/to

### Prefill and Submit
- prefill mapping to Salesforce
- submit mapping to Salesforce
- prefill and submit actions working in runtime
- one-condition logic only

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
- tenant secret for admin/server calls
- publish token for runtime
- server-side enforcement of object/field/command allowlists

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

### Experience / control
- richer branding controls
- custom logo
- more advanced submission logs and filters

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
