# NativeForms Admin Control App - V1 Screen Structure

## 1. Goal

Define the screen-by-screen structure for the first useful version of the NativeForms Admin Control App.

This document assumes:

- the app is hosted outside Salesforce
- the frontend is a static web app hosted from S3
- backend APIs are provided by AWS Lambda
- authentication will later be handled by Cognito

The focus of V1 is:

**tenant lookup, plan management, setup/connection health, support actions, and auditability**

---

## 2. V1 Navigation

Keep the top-level navigation small:

- **Overview**
- **Tenants**
- **Audit Log**
- **Settings**

That is enough for the first working product.

---

## 3. App Shell

## Header

The header should include:

- NativeForms Admin Control App title
- current environment label
- current signed-in user
- logout button

Example:

- `NativeForms Admin`
- `Environment: Production`
- `Signed in as: yosi@...`

## Left navigation or top navigation

Simple and business-oriented:

- Overview
- Tenants
- Audit Log
- Settings

## Global utility behavior

The app shell should support:

- tenant search access from anywhere
- clear empty states
- clear success/error notifications

---

## 4. Overview Screen

## Purpose

The overview screen should answer:

**What needs attention right now?**

This page is for quick operational awareness.

## Layout

### Top summary cards

- active tenants
- trials in progress
- expiring trials
- tenants with setup or connection issues
- submissions today
- tenants needing support attention

### Middle action panels

- setup issues
- OAuth / tenant secret failures
- trials ending soon
- recently suspended tenants
- recent support notes

### Bottom section

Keep this simple in V1:

- recent admin actions
- recently active tenants
- optional small trend widgets later

## Important V1 rule

Do not build complicated charts first.
Use counts and actionable tables first.

---

## 5. Tenants Screen

## Purpose

This is the core working screen of the app.

Admins should be able to quickly find a tenant and understand whether it needs action.

## Main layout

### Filter bar

Filters should include:

- status: active / suspended / expired
- plan: free / trial / starter / pro
- setup: connected / pending / failed
- health: healthy / warning / critical

### Search

Search by:

- company name
- admin email
- Salesforce org id

### Tenant table

Columns should include:

- company name
- org id
- admin email
- plan
- status
- setup state
- health
- last activity
- submissions this month
- actions

### Row actions

Keep the row actions small:

- open tenant
- resend setup
- extend trial

The rest can live inside tenant detail.

---

## 6. Tenant Detail Screen

## Purpose

This becomes the single source of truth for one tenant.

The tenant detail page should have:

- a summary header
- quick actions
- tabs

## Header content

Show:

- company name
- org id
- admin email
- plan
- business status
- health status
- last activity

## Quick actions in header

- extend trial
- suspend / reactivate
- resend setup instructions
- regenerate tenant secret

These should have confirmation flows where appropriate.

---

## 7. Tenant Detail Tabs

Recommended V1 tabs:

- **Summary**
- **Plan**
- **Connection**
- **Usage**
- **Support**
- **Audit**

---

## 8. Summary Tab

## Purpose

A one-screen summary of the tenant.

## Sections

### Tenant info card

- company name
- org id
- admin email
- login base URL
- created date

### Commercial summary card

- plan
- plan status
- trial dates
- active / suspended / expired

### Setup and health card

- setup state
- tenant secret state
- OAuth state
- health state
- last successful check
- recent problem summary

### Activity card

- last activity
- last submission
- active forms count
- submissions this month

This tab should be fast to scan.

---

## 9. Plan Tab

## Purpose

Manage the tenant’s commercial plan and feature access.

## Main sections

### Current plan summary

- current plan
- plan status
- plan start
- plan end
- trial dates if relevant

### Effective limits table

Show:

- max Salesforce users
- max forms
- max submissions per month

For each row show:

- plan default
- tenant override
- effective value

### Effective Pro features table

Show the current feature flags:

- condition logic
- repeat groups
- prefill alias references
- advanced submit modes
- formula fields
- post-submit auto link
- secret code auth
- load file

For each feature show:

- plan default
- tenant override
- effective status

## Actions

- change plan
- extend trial
- add / remove override
- reset overrides back to plan defaults

## Important UX rule

This page should make it obvious why a tenant does or does not have a feature.

---

## 10. Connection Tab

## Purpose

Help support and product quickly diagnose setup and connection problems.

## Sections

### Setup state

Show:

- setup state
- tenant secret state
- OAuth status
- Salesforce connection status
- last connection update time

### Credentials / secret lifecycle summary

Show:

- tenant secret generated?
- tenant secret verified?
- central OAuth client configured?
- OAuth connected?

### Recent connection errors

Show:

- recent error message
- error timestamp
- failure category

## Actions

- resend setup instructions
- regenerate tenant secret
- force recheck health
- mark issue reviewed

## Important note

This should be business-readable, not just raw backend output.

Example wording:

- `Tenant secret not verified`
- `Salesforce OAuth not completed`
- `Connected successfully`

instead of raw infrastructure terms where possible.

---

## 11. Usage Tab

## Purpose

Show whether the tenant is active and approaching plan limits.

## Sections

### Usage summary cards

- active forms
- submissions today
- submissions this month
- last publish
- last submission

### Limits comparison

Show:

- forms used vs max forms
- submissions this month vs monthly limit

### Recent activity list

Later this can include:

- recent publish actions
- recent submission spikes
- recent usage anomalies

For V1 this can stay simple.

---

## 12. Support Tab

## Purpose

Let support and product track customer-specific context without database access.

## Sections

### Support notes list

Each note should show:

- author
- timestamp
- note text

### Tenant issue list

Examples:

- setup blocked
- OAuth failed
- subscription expired
- customer requested extension

## Actions

- add note
- mark issue resolved
- add follow-up tag

This tab should feel like a customer operations timeline.

---

## 13. Audit Tab

## Purpose

Show every internal action taken against the tenant.

## Each audit row should show

- timestamp
- actor
- action type
- short description
- before / after summary if relevant

Examples:

- plan changed from Starter to Pro
- trial extended from date A to date B
- tenant suspended
- tenant reactivated
- tenant secret regenerated

## Important rule

Every sensitive internal action should land here automatically.

---

## 14. Audit Log Screen

## Purpose

A global cross-tenant audit view.

This is useful for:

- compliance
- support review
- product operations

## Filters

- actor
- action type
- tenant
- date range

## Columns

- time
- actor
- tenant
- action type
- summary

This page can be table-first in V1.

---

## 15. Settings Screen

## Purpose

Keep this small in V1.

This is not a dumping ground for everything.

## Suggested content

- plan definitions overview
- internal environment info
- feature flag definitions reference
- admin help links

If plan editing is not ready yet, this page can be mostly informational at first.

---

## 16. V1 Screen Priorities

If you want the fastest path to a usable internal tool, build in this order:

1. App shell
2. Tenants screen
3. Tenant detail screen
4. Plan tab
5. Connection tab
6. Audit tab
7. Overview screen
8. Support tab
9. Settings

This order gets the most operational value earliest.

---

## 17. Suggested First Clickable Prototype Scope

If you want to prototype the UI quickly before full backend work, the first clickable version should include:

- app shell
- Overview
- Tenants list
- Tenant detail
  - Summary
  - Plan
  - Connection

That is enough to validate the information architecture.

---

## 18. Final Recommendation

The NativeForms Admin Control App V1 should be built around:

- one strong tenant list
- one strong tenant detail page
- clear plan and connection views
- safe support actions
- full auditability

If these screens are strong, the product will already feel useful even before advanced analytics exist.
