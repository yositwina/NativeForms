# NativeForms Admin Control App - V1 API Contract

## 1. Goal

Define the first backend API contract for the NativeForms Admin Control App.

This API is for the internal admin console only.

It should support:

- overview data
- tenant list
- tenant detail
- plan management
- connection/support actions
- audit and support history

This document defines the **shape** of the API before implementation.

---

## 2. API Style

Recommended style for V1:

- REST-style JSON API
- one admin backend service
- authenticated requests
- business-readable responses

Base path:

`/admin`

Examples:

- `GET /admin/overview`
- `GET /admin/tenants`
- `GET /admin/tenants/{orgId}`

---

## 3. Authentication Model

For production use, every admin API request should include a valid Cognito access token.

Expected header:

```http
Authorization: Bearer <token>
```

For early S3-only dev/testing, auth can be temporarily relaxed if needed, but the contract should still assume authenticated requests.

---

## 4. Response Conventions

Every response should be JSON.

### Success shape

```json
{
  "success": true,
  "data": {}
}
```

### Error shape

```json
{
  "success": false,
  "error": {
    "code": "TENANT_NOT_FOUND",
    "message": "Tenant was not found."
  }
}
```

### Why this matters

The admin UI should never need to parse raw backend text.
Keep errors structured and user-friendly.

---

## 5. Shared Objects

## Tenant summary object

Used in lists and overview panels.

```json
{
  "orgId": "00Dxxxxxxxxxxxx",
  "companyName": "Acme Inc",
  "adminEmail": "admin@acme.com",
  "planCode": "starter",
  "planLabel": "Starter",
  "status": "active",
  "setupState": "connected",
  "healthStatus": "healthy",
  "lastActivityAt": "2026-04-12T11:42:00.000Z",
  "submissionsMonth": 164,
  "activeFormsCount": 3
}
```

## Tenant detail object

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

## Plan object

```json
{
  "planCode": "starter",
  "label": "Starter",
  "description": "Paid production plan without Pro-only features.",
  "isActive": true,
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

## Audit entry object

```json
{
  "auditId": "aud_001",
  "orgId": "00Dxxxxxxxxxxxx",
  "actorEmail": "support@nativeforms.com",
  "actionType": "extend_trial",
  "summary": "Extended tenant trial by 30 days",
  "reason": "Customer onboarding delay",
  "before": {
    "trialEndsAt": "2026-05-01T00:00:00.000Z"
  },
  "after": {
    "trialEndsAt": "2026-05-31T00:00:00.000Z"
  },
  "createdAt": "2026-04-12T13:10:00.000Z"
}
```

## Support note object

```json
{
  "eventId": "evt_001",
  "orgId": "00Dxxxxxxxxxxxx",
  "eventType": "support_note",
  "severity": "info",
  "message": "Customer asked for setup help on OAuth step.",
  "createdBy": "support@nativeforms.com",
  "createdAt": "2026-04-12T13:15:00.000Z"
}
```

---

## 6. GET /admin/overview

## Purpose

Loads the overview dashboard.

## Response

```json
{
  "success": true,
  "data": {
    "summary": {
      "activeTenants": 18,
      "trialsInProgress": 6,
      "expiringTrials": 2,
      "tenantsWithIssues": 3,
      "submissionsToday": 412,
      "tenantsNeedingSupport": 4
    },
    "lists": {
      "setupIssues": [],
      "expiringTrials": [],
      "recentSupportNotes": [],
      "recentAdminActions": []
    }
  }
}
```

---

## 7. GET /admin/tenants

## Purpose

Load the tenant list screen.

## Query params

- `q`
- `status`
- `planCode`
- `setupState`
- `healthStatus`
- `limit`
- `cursor`

Example:

`GET /admin/tenants?q=acme&planCode=starter&status=active`

## Response

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "orgId": "00Dxxxxxxxxxxxx",
        "companyName": "Acme Inc",
        "adminEmail": "admin@acme.com",
        "planCode": "starter",
        "planLabel": "Starter",
        "status": "active",
        "setupState": "connected",
        "healthStatus": "healthy",
        "lastActivityAt": "2026-04-12T11:42:00.000Z",
        "submissionsMonth": 164,
        "activeFormsCount": 3
      }
    ],
    "page": {
      "limit": 25,
      "nextCursor": null
    }
  }
}
```

---

## 8. GET /admin/tenants/{orgId}

## Purpose

Load the tenant detail page.

## Response

```json
{
  "success": true,
  "data": {
    "tenant": {
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
  }
}
```

---

## 9. GET /admin/plans

## Purpose

Load all plan definitions.

## Response

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "planCode": "free",
        "label": "Free",
        "description": "Permanent low-volume entry plan.",
        "isActive": true,
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
    ]
  }
}
```

---

## 10. GET /admin/tenants/{orgId}/audit

## Purpose

Load tenant-specific audit history.

## Response

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "auditId": "aud_001",
        "orgId": "00Dxxxxxxxxxxxx",
        "actorEmail": "support@nativeforms.com",
        "actionType": "extend_trial",
        "summary": "Extended tenant trial by 30 days",
        "reason": "Customer onboarding delay",
        "before": {
          "trialEndsAt": "2026-05-01T00:00:00.000Z"
        },
        "after": {
          "trialEndsAt": "2026-05-31T00:00:00.000Z"
        },
        "createdAt": "2026-04-12T13:10:00.000Z"
      }
    ]
  }
}
```

---

## 11. GET /admin/tenants/{orgId}/support

## Purpose

Load support notes and support events for a tenant.

## Response

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "eventId": "evt_001",
        "orgId": "00Dxxxxxxxxxxxx",
        "eventType": "support_note",
        "severity": "info",
        "message": "Customer asked for setup help on OAuth step.",
        "createdBy": "support@nativeforms.com",
        "createdAt": "2026-04-12T13:15:00.000Z"
      }
    ]
  }
}
```

---

## 12. GET /admin/audit

## Purpose

Load the global audit log screen.

## Query params

- `actorEmail`
- `actionType`
- `orgId`
- `dateFrom`
- `dateTo`
- `limit`
- `cursor`

## Response

```json
{
  "success": true,
  "data": {
    "items": [],
    "page": {
      "limit": 50,
      "nextCursor": null
    }
  }
}
```

---

## 13. POST /admin/tenants/{orgId}/change-plan

## Purpose

Change the tenant’s assigned plan.

## Request

```json
{
  "planCode": "pro",
  "reason": "Customer upgraded"
}
```

## Response

```json
{
  "success": true,
  "data": {
    "tenant": {
      "orgId": "00Dxxxxxxxxxxxx",
      "planCode": "pro",
      "planLabel": "Pro",
      "planStatus": "active"
    },
    "auditId": "aud_002"
  }
}
```

---

## 14. POST /admin/tenants/{orgId}/extend-trial

## Purpose

Extend a tenant’s trial.

## Request

```json
{
  "extendByDays": 30,
  "reason": "Customer requested more onboarding time"
}
```

## Response

```json
{
  "success": true,
  "data": {
    "trialEndsAt": "2026-05-31T00:00:00.000Z",
    "auditId": "aud_003"
  }
}
```

---

## 15. POST /admin/tenants/{orgId}/suspend

## Purpose

Suspend tenant access.

## Request

```json
{
  "reason": "Manual suspension for account review"
}
```

## Response

```json
{
  "success": true,
  "data": {
    "status": "suspended",
    "auditId": "aud_004"
  }
}
```

---

## 16. POST /admin/tenants/{orgId}/reactivate

## Purpose

Reactivate a suspended tenant.

## Request

```json
{
  "reason": "Issue resolved"
}
```

## Response

```json
{
  "success": true,
  "data": {
    "status": "active",
    "auditId": "aud_005"
  }
}
```

---

## 17. POST /admin/tenants/{orgId}/resend-setup

## Purpose

Resend setup instructions to the tenant admin.

## Request

```json
{
  "reason": "Customer lost setup email"
}
```

## Response

```json
{
  "success": true,
  "data": {
    "emailSent": true,
    "auditId": "aud_006"
  }
}
```

---

## 18. POST /admin/tenants/{orgId}/regenerate-secret

## Purpose

Generate a new tenant secret.

## Important

This is a sensitive action and should always create an audit record.

## Request

```json
{
  "reason": "Testing or secret reset requested"
}
```

## Response

```json
{
  "success": true,
  "data": {
    "secretRegenerated": true,
    "emailSent": true,
    "auditId": "aud_007"
  }
}
```

The new secret itself should not be returned in plaintext to the admin console unless explicitly intended by product design.

---

## 19. POST /admin/tenants/{orgId}/refresh-health

## Purpose

Force a recheck of setup/connection health.

## Request

```json
{}
```

## Response

```json
{
  "success": true,
  "data": {
    "setupState": "oauth_pending",
    "tenantSecretStatus": "verified",
    "oauthStatus": "pending",
    "healthStatus": "warning"
  }
}
```

---

## 20. POST /admin/tenants/{orgId}/support-note

## Purpose

Add a support note to the tenant timeline.

## Request

```json
{
  "message": "Customer requested help with OAuth setup.",
  "severity": "info"
}
```

## Response

```json
{
  "success": true,
  "data": {
    "eventId": "evt_002"
  }
}
```

---

## 21. Optional Later Endpoints

These are useful later but do not need to block V1:

- `POST /admin/plans`
- `PUT /admin/plans/{planCode}`
- `POST /admin/tenants/{orgId}/overrides`
- `DELETE /admin/tenants/{orgId}/overrides/{key}`
- `GET /admin/tenants/{orgId}/usage-daily`

---

## 22. Error Codes

Use stable machine-readable error codes.

Suggested initial set:

- `UNAUTHORIZED`
- `FORBIDDEN`
- `TENANT_NOT_FOUND`
- `PLAN_NOT_FOUND`
- `INVALID_REQUEST`
- `INVALID_PLAN_CHANGE`
- `TRIAL_EXTENSION_NOT_ALLOWED`
- `SECRET_REGENERATION_FAILED`
- `SETUP_EMAIL_FAILED`
- `HEALTH_CHECK_FAILED`
- `INTERNAL_ERROR`

Example:

```json
{
  "success": false,
  "error": {
    "code": "TENANT_NOT_FOUND",
    "message": "Tenant was not found."
  }
}
```

---

## 23. Recommended V1 Implementation Order

Implement endpoints in this order:

1. `GET /admin/tenants`
2. `GET /admin/tenants/{orgId}`
3. `GET /admin/plans`
4. `POST /admin/tenants/{orgId}/change-plan`
5. `POST /admin/tenants/{orgId}/extend-trial`
6. `POST /admin/tenants/{orgId}/suspend`
7. `POST /admin/tenants/{orgId}/reactivate`
8. `GET /admin/tenants/{orgId}/audit`
9. `GET /admin/tenants/{orgId}/support`
10. `POST /admin/tenants/{orgId}/support-note`
11. `GET /admin/overview`
12. connection/setup actions

This gives the admin app useful value quickly.

---

## 24. Final Recommendation

The V1 admin API should stay narrow and business-focused.

It should:

- expose clear tenant and plan data
- support a small set of safe actions
- return structured errors
- write audit records for all sensitive changes

That is enough to build the first real Admin Control App.
