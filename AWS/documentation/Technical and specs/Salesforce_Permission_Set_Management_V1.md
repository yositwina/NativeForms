# Salesforce Permission Set Management V1

Last updated: 2026-04-21

## Purpose

Define the V1 model for:

- Salesforce user access to the customer-facing `TwinaForms` app
- a separate support/debug access path for the `TwinaForms Admin` app
- seat limits driven from AWS tenant data
- package-safe permission-set structure before Apex test work and packaging

This document is intentionally limited to the Salesforce package + AWS tenant contract for seat management.

---

## Main Product Decisions

### 1. Split the package into two permission sets

The package should no longer rely on one permission set that grants both apps.

V1 should use:

- `TwinaForms User`
- `TwinaForms Admin`

### 2. AWS is the source of truth for seat limits

The number of allowed Salesforce users comes from:

- `NativeFormsTenants.effectiveLimits.maxSfUsers`

This value is resolved in AWS from:

- tenant override if present
- otherwise the selected plan default

### 3. Salesforce counts real assignments locally

AWS owns the allowed limit.

Salesforce should count the actual assigned users by querying:

- `PermissionSetAssignment`

V1 rule:

- `TwinaForms User` assignments count against `maxSfUsers`
- `TwinaForms Admin` assignments do **not** count against `maxSfUsers`

Reason:

- the user seat limit is for the real customer-facing TwinaForms workspace
- the Admin app is a support/debug path, not a normal customer seat

### 4. TwinaForms Admin app is controlled by a tenant support flag

The Admin app should not be open by default.

V1 rule:

- default is closed
- it can be enabled per tenant from the AWS TwinaForms Admin console
- the flag is intended for support/debug use only

Recommended AWS field:

```json
{
  "supportFlags": {
    "enableSalesforceAdminApp": false
  }
}
```

This should be tenant-level only, not a commercial plan feature.

Reason:

- it is not part of Starter vs Pro packaging
- it is an operations/support control
- it should not appear in customer plan comparison

---

## Permission Set Model

## TwinaForms User

Purpose:

- grants access to the main `TwinaForms` app
- used for normal form-building/customer-admin users
- counted against `maxSfUsers`

Should include:

- `NativeForms` app visibility
- main customer-facing TwinaForms tabs
- Apex/class/object/field access needed for:
  - Home
  - Designer
  - Prefill
  - Submit
  - Themes
  - Logs
  - Connect/setup path needed for customer use

Should not include:

- `NativeForms_Admin` app visibility
- raw object tabs used only for debug/admin support
- `NativeForms_Admin_Features`

## TwinaForms Admin

Purpose:

- grants access to the separate `TwinaForms Admin` app
- used only for support/debug or advanced internal admin scenarios
- not counted against `maxSfUsers`

Should include:

- `NativeForms_Admin` app visibility
- admin/debug object tabs
- `NativeForms_Admin_Features`
- any admin/setup classes and object permissions required by that app

Should not be treated as the standard package assignment for ordinary users.

---

## AWS Tenant Contract

## Existing limit source

Keep using:

- `effectiveLimits.maxSfUsers`

This remains the seat cap for `TwinaForms User`.

## New support flag

Add tenant-level support flags:

```json
{
  "supportFlags": {
    "enableSalesforceAdminApp": false
  }
}
```

V1 behavior:

- if missing, treat as `false`
- the Admin console can toggle it per tenant
- this flag is not part of plan defaults and not part of commercial feature flags

## Home summary contract

The Salesforce Home/bootstrap response should continue to provide:

- `usage.maxSfUsers`

It should also provide:

- `supportFlags.enableSalesforceAdminApp`

or a flattened equivalent such as:

- `support.enableSalesforceAdminApp`

V1 note:

- `activeUsersCount` should no longer be hardcoded in AWS
- Salesforce should calculate the local count for display using permission-set assignments

---

## Salesforce Enforcement Model

## Counting seats

Seat usage is the number of active users assigned to:

- `TwinaForms User`

Recommended counting rule:

- count only active users
- ignore inactive users
- ignore `TwinaForms Admin` assignments

## Granting TwinaForms User

When assigning `TwinaForms User`:

1. read `maxSfUsers` from AWS tenant data
2. count current active `TwinaForms User` assignments locally
3. if the limit is not null and the assignment would exceed it, block with a customer-safe error

Example:

`This plan allows 1 TwinaForms user. Remove access from another user or upgrade the plan before adding a new one.`

## Granting TwinaForms Admin

When assigning `TwinaForms Admin`:

1. check `supportFlags.enableSalesforceAdminApp`
2. if false, block the assignment with a support/debug message

Example:

`TwinaForms Admin is currently closed for this tenant. Enable it from the TwinaForms Admin console before assigning access.`

## Revoking access

Revoking either permission set should always be allowed.

---

## Salesforce UI Recommendation

V1 should manage permission sets from the Salesforce `TwinaForms Connect` page.

Reason:

- this work is part of connection/setup readiness
- permission-set access and external credential access belong next to Connect troubleshooting
- it avoids splitting setup-related decisions across Home and Connect

## Connect page access section

Add a new section such as:

- `User Access`

Show:

- `TwinaForms Users: <assigned> / <maxSfUsers or Unlimited>`
- whether `TwinaForms Admin` is open or closed
- current assigned users

Recommended actions:

- grant/remove `TwinaForms User`
- grant/remove `TwinaForms Admin`

Recommended UX:

- normal user access is the main action
- admin/debug access is visually secondary
- if Admin app is closed, explain that it is controlled from the TwinaForms Admin console

---

## Package and Clean-Org Rules

### 1. Package both permission sets

The package should include:

- `TwinaForms User`
- `TwinaForms Admin`

### 2. Main app should not depend on the admin permission set

The current packaged setup should be refactored so ordinary use works with:

- `TwinaForms User`

only.

### 3. Admin app stays separate

The `TwinaForms Admin` app should remain packaged, but access should be intentionally separate.

### 4. Setup docs must be updated

Any current setup/help text saying:

- `Open the TwinaForms Admin permission set and assign it to the admins who will manage the app`

must be reviewed and rewritten to match the split model.

V1 likely needs wording closer to:

- `Assign TwinaForms User to people who should use the main TwinaForms workspace.`
- `Assign TwinaForms Admin only when support/debug admin access is needed.`

---

## V1 Scope

Included:

- split packaged permission sets
- local Salesforce seat counting
- enforcement against AWS `maxSfUsers`
- tenant support flag for Admin app open/closed
- admin-console toggle for that support flag
- Connect-page user access management in Salesforce

Not included:

- automatic syncing of seat counts back into AWS tenant metrics
- automatic assignment from the AWS admin console into Salesforce users
- complex role hierarchies or permission-set groups
- plan-level exposure of the Admin app flag

---

## Final Recommendation

V1 should be implemented with this simple model:

- `TwinaForms User` = standard seat, counted against AWS limit
- `TwinaForms Admin` = support/debug access, controlled by tenant support flag
- AWS owns the seat limit and the Admin-open flag
- Salesforce owns the real assignment count and local enforcement

This gives a package-safe design that is simple, commercially correct, and usable before Apex test work and packaging.
