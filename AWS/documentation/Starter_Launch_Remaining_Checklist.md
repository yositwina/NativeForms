# Starter Launch Remaining Checklist

Last updated: 2026-04-15

## Purpose

This document turns the current review into one practical checklist for:

- what must be finished before the Starter package is considered ready
- what must be finished before paid commercial launch
- what can wait until after first customers
- what was reviewed and is intentionally not being auto-enforced yet

This list reflects both:

- current code/documentation review
- Yosi clarifications from this session

## Confirmed Product Decisions

### Manual block instead of automatic runtime block

Current decision:

- expired / over-limit tenants do not need to be auto-blocked immediately in runtime
- the system should send email alerts
- support/admin can block the customer manually when needed

Implication:

- this is not currently treated as a bug
- this must stay clearly documented so future work does not assume automatic enforcement already exists

### Cognito is still missing

Confirmed:

- Admin Control authentication is still prototype-level
- production Cognito login and protected admin API are still pending

### Starter limits are not fully enforced yet

Confirmed:

- plan limits are visible in admin data and docs
- full enforcement is still incomplete

### Plan definition and pricing

Current decision:

- Starter price: `80 USD / month`
- Pro price: `200 USD / month`
- trial includes all features

Product note:

- Starter vs Pro is already mostly defined in product documents
- before launch, one final published source of truth is still needed for:
- product behavior
- website copy
- AppExchange listing copy
- buy page / upgrade flow
- support expectations

## Must Finish Before Starter Package Is Ready

These are the highest-priority items for a credible Starter package.

### Core product completeness

- polish of the NativeForms screens inside Salesforce
- add a clear `New Form` button on the Designer page so admins can create a new form directly from the main Designer workflow
- improve demo-data creation records, especially demo forms, so the generated sample data feels clean, intentional, and launch-ready
- basic thank-you page / thank-you message after submit
- customer-safe runtime and setup error messages
- CAPTCHA activation once the production domain is in place
- replace hardcoded temporary runtime Lambda URLs in published HTML with environment/domain-driven URLs
- redesign published form URL structure to be customer-friendly under `forms.twinaforms.com`, with a clearer path pattern such as `/<company-name>/<form-name>` instead of the current less-friendly format

### QA and validation

- full testing / QA pass for all current Starter features
- end-to-end validation of setup, connect, publish, prefill, submit, themes, submission logs, and admin screens
- regression pass in a clean org before packaging

### Trust and release readiness

- production domain setup
- CloudFront / production hosting path
- Salesforce package creation
- Apex test classes for the package baseline

### Starter plan behavior

- decide and implement the final Starter enforcement model for:
- form count limits
- submission count limits
- Pro feature access limits

Note:

- automatic runtime blocking for expired or over-limit tenants is not required right now
- but the package still needs a clear and correct enforcement model somewhere in the product

## Must Finish Before Paid Commercial Launch

These may not block internal packaging work, but they do block a real paid go-live.

### Admin and operations

- Cognito login for the Admin Control app
- protected admin API flow
- real admin identity captured in audit logs instead of placeholder actor values

### Commercial operations

- Stripe payment site / checkout flow for customers to pay for a plan
- plan change operational flow tied to actual commercial process

### Salesforce entitlement enforcement

- implement plan-based Salesforce user permission limits based on customer limit data stored in AWS

### Product and commercial definition

- publish one final source of truth for Starter vs Pro
- publish final pricing everywhere consistently:
- website
- AppExchange listing
- in-product upgrade flow
- customer documentation
- define trial behavior and trial-to-paid conversion rules

## Must Finish Before AppExchange Submission

These items are needed for the AppExchange motion itself, not only for the product.

### Listing readiness

- AppExchange listing copy
- product description
- feature summary
- plan/pricing summary aligned with final launch decision
- screenshots and visual assets
- icon / logo assets
- category / positioning decisions

### Packaging and install readiness

- installation guide
- post-install guide
- admin setup guide
- trial-to-paid upgrade guide
- clean-org install validation
- package upgrade validation

### Security and review readiness

- security review readiness checklist
- dependency / endpoint / data-flow inventory
- clear explanation of AWS components used by the package
- customer-facing data handling summary for review and trust

## Must Finish Before First Customers

These items are required to start taking real customers with confidence.

### Customer buying journey

- public website / buy page
- plan comparison page
- upgrade path from trial to paid
- clear CTA path from installed trial to paid customer

### Customer onboarding

- onboarding emails
- first-run guidance
- support contact path
- customer documentation / FAQ / help content
- demo or walkthrough content

### Customer operations

- support SLA definition
- internal support workflow
- manual operations process for expired / over-limit customers
- customer issue triage flow

## Business / Legal / Operations Readiness

These items should be explicitly tracked before launch, even if some are handled outside engineering.

### Business and legal

- Terms of Service
- Privacy Policy
- billing / refund policy
- data handling / retention statement

### Production operations

- production monitoring and alerting
- production environment checklist
- incident response / rollback plan
- backup / recovery thinking for critical config and customer-impacting settings
- who receives alerts and how they are handled

## Important, But Can Potentially Follow Right After First Package Cut

These are important, but may not need to block the very first package candidate if the goal is an internal or pilot release.

- full customer-facing publish/setup error polish
- stronger audit/user attribution in admin flows
- nicer lifecycle handling for old published runtime endpoints
- monitoring and alerting improvements
- admin secret rotation and recovery polish

## Can Wait Until After First Customers If Needed

These are useful, but they do not appear to be the next critical step.

- full automatic runtime enforcement for expired / over-limit customers
- richer admin dashboards and analytics
- deeper support workflow polish
- richer commercial automations after Stripe basics exist

## Items Reviewed And Still Open

### Confirmed open

- Salesforce Native app screen polish
- add a clear `New Form` button on the Designer page
- improve demo-data creation records, especially forms
- thank-you page
- customer-safe error handling
- production domain / CloudFront setup
- CAPTCHA enablement after domain
- Starter plan-limit enforcement is incomplete
- full QA testing across all current features
- Salesforce user-limit enforcement by plan is incomplete
- Stripe payment site
- Apex test coverage for package readiness
- Salesforce package creation
- Cognito admin auth
- AppExchange listing and submission readiness
- customer website / buy flow / onboarding readiness
- legal and production operations readiness

### Clarified and not treated as a current bug

- runtime does not auto-block expired / over-limit tenants
- email alert plus manual admin block is the current intended model

### Clarified technical risks

- published forms currently bake in temporary runtime endpoints, so domain/runtime changes require republish unless this is fixed
- admin audit history currently uses placeholder actor identity in some flows, so admin traceability is incomplete until real auth is connected
- published form URLs are not yet in the intended friendly format like `forms.twinaforms.com/company-name/form-name`

## Recommended Next-Step Options

### Starter critical path

1. Salesforce Native app UI polish
2. domain and runtime endpoint cleanup
3. thank-you page
4. customer-safe error handling
5. full QA across current features
6. Apex test classes
7. Salesforce package creation
8. Cognito for Admin

Note:

- `Cognito for Admin` is intentionally the last step in this path
- it is required before real commercial admin operations, but it does not need to block earlier product-core Starter completion work

Recommended order:

1. Package readiness baseline
2. Salesforce Native app screen polish
3. Domain and runtime endpoint cleanup
4. Thank-you page and error-message polish
5. Full QA pass for current features
6. Apex tests
7. Salesforce package creation
8. AppExchange submission materials and install docs
9. Customer buy flow and website readiness
10. Cognito admin auth
11. Stripe payment flow
12. Salesforce plan-based user entitlement enforcement
13. Legal / ops launch baseline

### Recommended next step now

Best next step:

- finish the package readiness baseline first

That means:

- polish the NativeForms Salesforce screens
- lock the production/domain approach
- remove hardcoded temporary runtime URLs from published forms
- finish thank-you page support
- clean customer-facing errors
- run a full QA pass on all current features
- prepare Apex tests
- prepare the install / post-install / customer-facing launch path

Reason:

- this reduces technical debt in every published form
- it improves package credibility immediately
- it keeps Cognito and Stripe from blocking product-core Starter work

## Suggested Execution Sequence

### Phase 1: Starter package baseline

- Salesforce Native app UI polish
- domain/runtime URL strategy
- thank-you page
- safer error handling
- CAPTCHA enablement on production domain
- full QA across current features
- Apex test classes

### Phase 2: Packaging and release candidate

- create Salesforce package
- validate install/setup flow end to end
- verify Starter behavior in a clean org
- prepare AppExchange listing materials
- prepare install and post-install documentation

### Phase 3: Commercial launch readiness

- publish final Starter / Pro / trial messaging
- customer website and buy flow
- Cognito for admin app
- real audit actor identity
- Stripe payment site
- Salesforce plan-based user-limit enforcement
- legal / support / production ops baseline
