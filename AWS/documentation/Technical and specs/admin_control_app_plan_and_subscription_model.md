# NativeForms Admin Control App - Plan and Subscription Model

## 1. Goal

Define a clean model for:

- plan definitions
- tenant subscriptions
- plan feature flags
- tenant-level overrides
- future usage enforcement

This document is intentionally focused on the data model first, before implementation.

---

## 2. Main Product Rule

NativeForms should not hardcode commercial plans inside frontend or Lambda logic.

Instead:

- plans are stored as data
- tenants point to a plan
- tenant-specific overrides are allowed
- effective limits/features are resolved from:

**tenant override -> otherwise plan default**

This makes the system much easier to evolve later.

---

## 3. Recommended DynamoDB Tables

For this area, use:

- `NativeFormsPlans`
- `NativeFormsTenants` (extend existing table)

Optional later:

- `NativeFormsAdminAudit`
- `NativeFormsSupportEvents`
- `NativeFormsUsageDaily`

For now, this document focuses on plans and tenant subscriptions.

---

## 4. NativeFormsPlans Table

## Purpose

Stores the master definition of each commercial plan.

Examples:

- Free
- Trial
- Starter
- Pro

## Partition key

- `planCode`

Suggested values:

- `free`
- `trial`
- `starter`
- `pro`

## Recommended item shape

```json
{
  "planCode": "starter",
  "label": "Starter",
  "description": "Small production plan without Pro-only features.",
  "isActive": true,
  "sortOrder": 30,

  "durationType": "forever",
  "durationDays": null,

  "limits": {
    "maxSfUsers": 1,
    "maxForms": 5,
    "maxSubmissionsPerMonth": 1000
  },

  "featureFlags": {
    "enableProConditionLogic": false,
    "enableProRepeatGroups": false,
    "enableProPrefillAliasReferences": false,
    "enableProAdvancedSubmitModes": false,
    "enableProFormulaFields": false,
    "enableProPostSubmitAutoLink": false,
    "enableProSfSecretCodeAuth": false,
    "enableProLoadFile": false
  },

  "createdAt": "2026-04-12T12:00:00.000Z",
  "updatedAt": "2026-04-12T12:00:00.000Z"
}
```

---

## 5. Recommended Fields In NativeFormsPlans

### Identity

- `planCode`
- `label`
- `description`
- `isActive`
- `sortOrder`

### Duration

- `durationType`
  - `forever`
  - `fixed_days`
- `durationDays`

### Limits

Store limits under one object:

- `limits.maxSfUsers`
- `limits.maxForms`
- `limits.maxSubmissionsPerMonth`

For unlimited values, use:

- `null`

That is simpler than magic numbers.

### Feature flags

Store all plan-level feature toggles under:

- `featureFlags`

This is where Pro feature defaults live.

### Audit timestamps

- `createdAt`
- `updatedAt`

---

## 6. Initial Plan Definitions

## Free

```json
{
  "planCode": "free",
  "label": "Free",
  "description": "Permanent low-volume entry plan.",
  "isActive": true,
  "sortOrder": 10,
  "durationType": "forever",
  "durationDays": null,
  "limits": {
    "maxSfUsers": 1,
    "maxForms": 1,
    "maxSubmissionsPerMonth": 100
  },
  "featureFlags": {
    "enableProConditionLogic": false,
    "enableProRepeatGroups": false,
    "enableProPrefillAliasReferences": false,
    "enableProAdvancedSubmitModes": false,
    "enableProFormulaFields": false,
    "enableProPostSubmitAutoLink": false,
    "enableProSfSecretCodeAuth": false,
    "enableProLoadFile": false
  }
}
```

## Trial

```json
{
  "planCode": "trial",
  "label": "Trial",
  "description": "Time-limited evaluation with all Pro features.",
  "isActive": true,
  "sortOrder": 20,
  "durationType": "fixed_days",
  "durationDays": 30,
  "limits": {
    "maxSfUsers": 1,
    "maxForms": 5,
    "maxSubmissionsPerMonth": null
  },
  "featureFlags": {
    "enableProConditionLogic": true,
    "enableProRepeatGroups": true,
    "enableProPrefillAliasReferences": true,
    "enableProAdvancedSubmitModes": true,
    "enableProFormulaFields": true,
    "enableProPostSubmitAutoLink": true,
    "enableProSfSecretCodeAuth": true,
    "enableProLoadFile": true
  }
}
```

## Starter

```json
{
  "planCode": "starter",
  "label": "Starter",
  "description": "Paid production plan without Pro-only features.",
  "isActive": true,
  "sortOrder": 30,
  "durationType": "forever",
  "durationDays": null,
  "limits": {
    "maxSfUsers": 1,
    "maxForms": 5,
    "maxSubmissionsPerMonth": 1000
  },
  "featureFlags": {
    "enableProConditionLogic": false,
    "enableProRepeatGroups": false,
    "enableProPrefillAliasReferences": false,
    "enableProAdvancedSubmitModes": false,
    "enableProFormulaFields": false,
    "enableProPostSubmitAutoLink": false,
    "enableProSfSecretCodeAuth": false,
    "enableProLoadFile": false
  }
}
```

## Pro

```json
{
  "planCode": "pro",
  "label": "Pro",
  "description": "Full plan with no product limits.",
  "isActive": true,
  "sortOrder": 40,
  "durationType": "forever",
  "durationDays": null,
  "limits": {
    "maxSfUsers": null,
    "maxForms": null,
    "maxSubmissionsPerMonth": null
  },
  "featureFlags": {
    "enableProConditionLogic": true,
    "enableProRepeatGroups": true,
    "enableProPrefillAliasReferences": true,
    "enableProAdvancedSubmitModes": true,
    "enableProFormulaFields": true,
    "enableProPostSubmitAutoLink": true,
    "enableProSfSecretCodeAuth": true,
    "enableProLoadFile": true
  }
}
```

---

## 7. NativeFormsTenants - Existing Fields

Today the tenant record already includes fields like:

- `orgId`
- `adminEmail`
- `companyName`
- `loginBaseUrl`
- `status`
- `subscriptionState`
- `subscriptionStartDate`
- `subscriptionEndDate`
- `isActive`
- `salesforceConnectionStatus`
- `salesforceConnectionUpdatedAt`
- `connectedUsername`
- `createdAt`
- `updatedAt`

This is a good start, but it is not yet a full subscription model.

---

## 8. NativeFormsTenants - Recommended Added Fields

Add these fields to support plan management and Admin Control App.

## Commercial fields

- `planCode`
- `planLabel`
- `planStatus`
- `planStartedAt`
- `planEndsAt`
- `trialStartedAt`
- `trialEndsAt`

## Effective limit snapshot

- `effectiveLimits`

Example:

```json
{
  "maxSfUsers": 1,
  "maxForms": 5,
  "maxSubmissionsPerMonth": 1000
}
```

## Effective feature snapshot

- `effectiveFeatureFlags`

Example:

```json
{
  "enableProConditionLogic": false,
  "enableProRepeatGroups": false,
  "enableProPrefillAliasReferences": false,
  "enableProAdvancedSubmitModes": false,
  "enableProFormulaFields": false,
  "enableProPostSubmitAutoLink": false,
  "enableProSfSecretCodeAuth": false,
  "enableProLoadFile": false
}
```

## Tenant overrides

- `planOverrides`

Example:

```json
{
  "limits": {
    "maxForms": 10
  },
  "featureFlags": {
    "enableProFormulaFields": true
  }
}
```

## Admin summary / usage fields

- `activeFormsCount`
- `submissionsToday`
- `submissionsMonth`
- `lastSubmissionAt`
- `lastActivityAt`

## Operational / support fields

- `setupState`
- `tenantSecretStatus`
- `oauthStatus`
- `healthStatus`
- `supportStatus`
- `lastSupportNoteAt`

---

## 9. Suggested NativeFormsTenants Item Shape

```json
{
  "orgId": "00Dxxxxxxxxxxxx",
  "companyName": "Acme Inc",
  "adminEmail": "admin@acme.com",
  "loginBaseUrl": "https://acme.my.salesforce.com",

  "status": "active",
  "isActive": true,

  "planCode": "starter",
  "planLabel": "Starter",
  "planStatus": "active",
  "planStartedAt": "2026-04-12T12:00:00.000Z",
  "planEndsAt": null,

  "trialStartedAt": null,
  "trialEndsAt": null,

  "effectiveLimits": {
    "maxSfUsers": 1,
    "maxForms": 5,
    "maxSubmissionsPerMonth": 1000
  },

  "effectiveFeatureFlags": {
    "enableProConditionLogic": false,
    "enableProRepeatGroups": false,
    "enableProPrefillAliasReferences": false,
    "enableProAdvancedSubmitModes": false,
    "enableProFormulaFields": false,
    "enableProPostSubmitAutoLink": false,
    "enableProSfSecretCodeAuth": false,
    "enableProLoadFile": false
  },

  "planOverrides": {
    "limits": {},
    "featureFlags": {}
  },

  "setupState": "connected",
  "tenantSecretStatus": "verified",
  "oauthStatus": "connected",
  "healthStatus": "healthy",
  "supportStatus": "normal",

  "activeFormsCount": 3,
  "submissionsToday": 12,
  "submissionsMonth": 164,
  "lastSubmissionAt": "2026-04-12T11:42:00.000Z",
  "lastActivityAt": "2026-04-12T11:42:00.000Z",

  "salesforceConnectionStatus": "connected",
  "salesforceConnectionUpdatedAt": "2026-04-12T11:30:00.000Z",
  "connectedUsername": "admin@acme.com",

  "createdAt": "2026-04-12T10:00:00.000Z",
  "updatedAt": "2026-04-12T12:10:00.000Z"
}
```

---

## 10. Current Pro Feature Flags That Belong In Plans

Based on the current NativeForms Admin Features page, these flags belong in the plan model:

- `enableProConditionLogic`
- `enableProRepeatGroups`
- `enableProPrefillAliasReferences`
- `enableProAdvancedSubmitModes`
- `enableProFormulaFields`
- `enableProPostSubmitAutoLink`
- `enableProSfSecretCodeAuth`
- `enableProLoadFile` internally, shown to admins/customers as `File Uploads`

These should be treated as:

- plan defaults in `NativeFormsPlans.featureFlags`
- tenant override candidates in `NativeFormsTenants.planOverrides.featureFlags`
- resolved values in `NativeFormsTenants.effectiveFeatureFlags`

---

## 11. Rule For Resolving Effective Values

Use these rules:

### Effective plan limits

`effective limit = tenant override if present, else plan default`

### Effective feature flags

`effective feature flag = tenant override if present, else plan default`

This should be resolved server-side and stored on the tenant record for fast reads.

That way:

- the UI stays simple
- enforcement logic stays simple
- tenant detail loads quickly

---

## 12. Why Store Effective Values On Tenant

You could compute effective values every time, but storing them directly on the tenant has advantages:

- easier reads from the Admin app
- easier reporting
- easier enforcement
- easier debugging

When a plan changes or a tenant override changes:

- update `planCode`
- recompute `effectiveLimits`
- recompute `effectiveFeatureFlags`
- write audit entry

---

## 13. Plans Section In Admin Control App

The Admin app should have a **Plans** area later, even if not in the first small UI.

### Plan list should show

- plan name
- duration model
- user limit
- form limit
- submission limit
- number of enabled Pro features
- active / inactive

### Plan detail page should allow

- editing description
- editing limits
- editing default feature flags
- enabling/disabling a plan

V1 can start read-only if needed.

---

## 14. Tenant Plan Editor

On the tenant detail page, the Plan tab should allow:

- change plan
- extend trial
- suspend / reactivate
- edit per-tenant limit override
- edit per-tenant feature override

### Important UI concept

For every feature and limit, show:

- plan default
- tenant override if exists
- effective value

That will make support much easier.

Example:

| Setting | Plan Default | Tenant Override | Effective |
|---|---|---|---|
| Max Forms | 5 | 10 | 10 |
| Formula Fields | Off | On | On |

---

## 15. Usage Enforcement

Plan limits are managed in AWS and enforced at the platform edge that owns the action.

### Form creation enforcement

`effectiveLimits.maxForms` is enforced in Salesforce when an admin creates a form from Designer.

- `maxForms = null` means unlimited.
- The Salesforce enforcement count is the number of local `NF_Form__c` records in the org.
- The check runs before inserting a new `NF_Form__c`.
- The Designer should warn and link to upgrade when the org is at the limit.
- Apex must still enforce the limit because client-side state can be stale.
- If AWS entitlements cannot be loaded, Salesforce should allow form creation rather than blocking customers because of a temporary service/connectivity issue.

Customer-facing limit message:

`You have reached your plan limit for forms. Upgrade your plan or remove an existing form before creating a new one.`

### Other enforcement examples

- stop form submission if `submissionsMonth >= effectiveLimits.maxSubmissionsPerMonth`
- hide or block Pro features if `effectiveFeatureFlags.<flag> = false`

### Important design note

AWS/Admin Console can report published/runtime form usage separately, but Salesforce Designer creation enforcement uses local `NF_Form__c` count because draft forms also consume customer workspace capacity.

### Form delete / unpublish behavior

Deleting a form from Designer is a destructive workspace action and should also disable the public runtime for that form.

- The action is initiated from `Form Settings > Danger Zone`.
- The admin must confirm by typing the form name or form key.
- Salesforce deletes the Designer form definition:
  - `NF_Form__c`
  - child versions
  - child elements
  - child Prefill/Submit actions
  - related publish records
- AWS disables public runtime access:
  - the form security record is marked `unpublished`
  - if the generated HTML key is known, the hosted page is replaced with a small unavailable page
- Historical submission logs are not deleted. They remain governed by the existing plan retention policy.
- If AWS runtime disable fails for a published form, Salesforce should block the delete so a live public form is not orphaned.

Customer-facing delete warning:

`This permanently deletes the form from Designer, including versions, fields, Prefill actions, and Submit actions. Published links will stop working. Existing submission logs are kept according to your plan retention settings. This cannot be undone.`

---

## 16. Best Practical V1 Recommendation

For the first usable Admin Control App:

1. create `NativeFormsPlans`
2. extend `NativeFormsTenants`
3. define the 4 initial plans
4. support plan assignment and trial dates
5. support tenant override editing
6. store effective values on tenant
7. leave runtime enforcement for the next phase

That will give you a solid commercial and support backbone.

---

## 17. Final Recommendation

NativeForms should treat plans as structured data, not code.

The clean model is:

- **plan definitions** in `NativeFormsPlans`
- **tenant subscription + overrides** in `NativeFormsTenants`
- **effective values** stored on tenant for fast reads

This gives you the right foundation for:

- the Plans section
- the Tenant Plan editor
- feature control
- future usage enforcement
