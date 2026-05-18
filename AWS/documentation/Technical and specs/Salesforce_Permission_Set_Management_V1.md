# Salesforce Permission Set Management V1

Last updated: 2026-05-06

## Purpose

Define the V1 model for:

- Salesforce user access to the customer-facing `TwinaForms` app
- a gated support/debug access path inside the main `TwinaForms` app
- seat limits driven from AWS tenant data
- package-safe permission-set structure

This document is intentionally limited to Salesforce package access and the AWS tenant contract for seat management.

## Main Product Decisions

### 1. Use Two Packaged Permission Sets

V1 uses:

- `TwinaForms User`
- `TwinaForms Admin`

There is no separate subscriber-created service-access permission set. The package-to-AWS service trust is handled by Bootstrap V2 HMAC signatures, not by Salesforce External Credential Principal Access.

### 2. AWS Is The Source Of Truth For Seat Limits

The number of allowed Salesforce users comes from:

- `NativeFormsTenants.effectiveLimits.maxSfUsers`

This value is resolved in AWS from:

- tenant override if present
- otherwise the selected plan default

### 3. Salesforce Counts Real Assignments Locally

AWS owns the allowed limit. Salesforce counts the actual assigned users by querying:

- `PermissionSetAssignment`

V1 rule:

- `TwinaForms User` assignments count against `maxSfUsers`
- `TwinaForms Admin` assignments do not count against `maxSfUsers`

### 4. TwinaForms Admin Access Is Controlled By A Tenant Support Flag

The admin/debug area is closed by default.

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

## Permission Set Model

## TwinaForms User

Purpose:

- grants access to the main `TwinaForms` app
- used for normal form-building/customer-admin users
- counted against `maxSfUsers`

Should include:

- `TwinaForms` app visibility
- main customer-facing TwinaForms tabs
- Apex/class/object/field access needed for Home, Designer, Prefill, Submit, Themes, Logs, and Connect

Should not include:

- admin/debug-only tabs or object access
- visible access to `NativeForms_Admin_Features`

## TwinaForms Admin

Purpose:

- grants access to the gated admin/debug area inside the main `TwinaForms` app
- used only for support/debug or advanced internal admin scenarios
- not counted against `maxSfUsers`

Should include:

- `TwinaForms` app visibility
- admin/debug object tabs
- `NativeForms_Admin_Features`
- any admin/setup classes and object permissions required by that app

## Salesforce Enforcement Model

## Counting Seats

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
4. assign only the packaged `TwinaForms User` permission set

The server-side assignment method must enforce the seat limit from a freshly fetched access summary. The UI can disable obvious over-limit actions, but Apex must not trust the UI's current count.

Example:

`This plan allows 1 TwinaForms user. Remove access from another user or upgrade the plan before adding a new one.`

## Granting TwinaForms Admin

When assigning `TwinaForms Admin`:

1. check `supportFlags.enableSalesforceAdminApp`
2. if false, block the assignment with a support/debug message

Example:

`TwinaForms Admin is currently closed for this tenant. Enable it from the TwinaForms Admin console before assigning access.`

## Revoking Access

Revoking either permission set should always be allowed.

Revoking `TwinaForms User` removes only the packaged `TwinaForms User` assignment. There is no paired service-access permission set to remove.

## Salesforce UI Recommendation

V1 should manage permission sets from the Salesforce `TwinaForms Connect` page.

Reason:

- this work is part of connection/setup readiness
- access troubleshooting belongs next to Connect
- it avoids splitting setup-related decisions across Home and Connect

## Connect Page Access Section

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
- if admin/debug access is closed, explain that it is controlled from the TwinaForms Admin console
- after the connection becomes complete, reload the access summary immediately so stale browser state cannot offer invalid seat actions

## Package And Clean-Org Rules

The package should include:

- `TwinaForms User`
- `TwinaForms Admin`

The package should not include:

- Salesforce Named Credential metadata
- Salesforce External Credential metadata
- setup instructions that ask the subscriber to create External Credential Principal Access
- a separate service-access permission set

Ordinary use should work with:

- `TwinaForms User`

Admin/debug tooling stays inside the main `TwinaForms` app and is gated by:

- `TwinaForms Admin`
- AWS support flag

## Final Recommendation

V1 should be implemented with this simple model:

- `TwinaForms User` = standard seat, counted against AWS limit
- `TwinaForms Admin` = support/debug access inside the main app, controlled by tenant support flag
- AWS owns the seat limit and the Admin-open flag
- Salesforce owns the real assignment count and local enforcement
- Bootstrap V2 HMAC owns package-to-AWS service authentication
