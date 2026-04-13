# NativeForms Admin Control App - V1 Focused Spec

## 1. Product Decision

The NativeForms Admin Control App is a **standalone AWS-hosted internal web app**.

It is **not** part of Salesforce.

Its first job is not executive analytics or billing automation.
Its first job is:

**help an internal admin find any tenant, understand its plan/setup/health quickly, and take a small set of safe actions**

That makes V1 a practical operations and support console for Product and Support.

---

## 2. What V1 Must Solve

V1 should answer these questions fast:

1. Which tenants exist?
2. What plan and status is each tenant on?
3. Is setup complete or broken?
4. Is the tenant actively using NativeForms?
5. What safe admin action should we take next?

If V1 does this well, it is already valuable.

---

## 3. What V1 Should Include

### Core screens

- Login
- Overview dashboard
- Tenant list
- Tenant detail page
- Audit log

### Core data shown

- tenant name / company
- Salesforce org id
- admin email
- plan
- trial start / end
- active / suspended / expired status
- setup state
- Salesforce OAuth state
- tenant secret verification state
- last activity
- submission counts
- recent errors

### Safe actions for V1

- extend trial
- change plan
- suspend / reactivate tenant
- resend setup instructions
- regenerate tenant secret
- refresh / recheck connection status
- add internal support note

---

## 4. What V1 Should Not Include

These are useful later, but should not block V1:

- full billing integration
- CEO dashboard with advanced business analytics
- cohort analysis
- predictive churn scoring
- complex role matrix
- direct database editing
- raw infrastructure dashboards as the primary UI

---

## 5. Main V1 Navigation

Keep the app small and operational:

- **Overview**
- **Tenants**
- **Audit Log**
- **Settings**

That is enough for the first release.

---

## 6. Overview Screen

The overview page should answer: "what needs attention right now?"

### Top cards

- total active tenants
- trials in progress
- expiring trials
- tenants with connection/setup problems
- submissions today
- tenants needing support follow-up

### Action lists

- tenants with failed setup
- tenants with invalid tenant secret / OAuth issues
- trials ending soon
- recently suspended tenants
- recent admin actions

### V1 rule

Do not start with complicated charts.
Use counts and actionable lists first.

---

## 7. Tenant List Screen

This is the heart of the app.

Each row should show:

- company / org name
- Salesforce org id
- admin email
- plan
- tenant status
- setup state
- connection health
- last activity
- last submission time

### Filters

- active / suspended / expired
- trial / paid / internal / demo
- setup complete / setup blocked
- healthy / needs attention

### Search

Search by:

- company name
- admin email
- Salesforce org id

---

## 8. Tenant Detail Screen

Each tenant gets one detail page.

Recommended tabs:

- **Summary**
- **Plan**
- **Connection**
- **Usage**
- **Support**
- **Audit**

### Summary tab

Show:

- company / org information
- plan and status
- important dates
- latest setup state
- quick health summary

### Plan tab

Show:

- current plan
- trial start / end
- overrides
- feature flags if relevant

Actions:

- extend trial
- upgrade / downgrade
- suspend / reactivate

### Connection tab

Show:

- tenant secret state
- Salesforce OAuth state
- last successful connection check
- recent connection failures

Actions:

- resend setup instructions
- regenerate tenant secret
- force recheck connection health

### Usage tab

Show:

- submissions today / month
- active forms
- publish count
- recent usage trend

V1 can use simple counters and timestamps.
It does not need advanced graphs yet.

### Support tab

Show:

- support notes
- last reported problems
- recent operational issues

Actions:

- add note
- mark issue reviewed

### Audit tab

Show every internal action:

- who did it
- what changed
- before / after where relevant
- timestamp

---

## 9. Recommended V1 State Model

This app needs explicit tenant states instead of vague "health".

### Tenant business status

- active
- suspended
- expired
- internal
- demo

### Setup state

- not_registered
- secret_generated
- tenant_secret_verified
- oauth_pending
- connected
- setup_failed

### Health state

- healthy
- warning
- critical

This will make support much faster than showing raw technical fields only.

---

## 10. Data Model for V1

The app should be built around a strong tenant master record plus separate event logs.

### A. Tenant master record

Store:

- tenantId
- orgId
- companyName
- adminEmail
- plan
- businessStatus
- setupState
- tenantSecretStatus
- oauthStatus
- trialStartDate
- trialEndDate
- createdAt
- updatedAt
- lastActivityAt
- lastSubmissionAt
- supportStatus

### B. Usage summary record

Store:

- tenantId
- activeForms
- submissionsToday
- submissionsMonth
- publishCount
- lastUsageAt

### C. Support / operational events

Store:

- tenantId
- eventType
- severity
- message
- createdAt
- relatedObjectId if needed

Examples:

- setup_failed
- oauth_failed
- invalid_tenant_secret
- publish_failed
- submission_failed

### D. Admin audit log

Store:

- auditId
- actorUserId
- actorEmail
- tenantId
- actionType
- beforeJson
- afterJson
- createdAt

---

## 11. Login and Authentication

This app is on AWS, so it needs a real AWS-side login.

## Recommended solution

Use **Amazon Cognito User Pool** with hosted login.

This is the cleanest V1 option for an internal admin web app.

### User experience

1. User opens the Admin Control App URL, for example:
   `https://admin.nativeforms.com`
2. If not logged in, user is redirected to the Cognito hosted login page.
3. User signs in with email and password.
4. Cognito can require MFA.
5. After successful login, Cognito redirects back to the app.
6. The app receives tokens and stores the session securely.
7. Every API call from the app sends the access token.
8. The backend verifies the token before allowing any admin action.

### What this means in plain language

The AWS page itself does not "own" the username/password form.
Cognito does.

So the login page is managed by AWS, and your admin app trusts Cognito after login.

### Why this is the right choice

- secure and standard
- supports MFA
- supports password reset
- supports internal user management
- separates authentication from app code
- better than a hidden HTML page or shared password

---

## 12. Recommended AWS Architecture

### Frontend

Host the admin app as a static web app:

- S3 + CloudFront

or

- AWS Amplify Hosting

Either is fine.
Amplify is simpler for fast iteration.

### Authentication

- Amazon Cognito User Pool
- Cognito hosted login
- MFA enabled for admin users

### Backend API

Recommended for the admin app:

- API Gateway
- Lambda functions
- Cognito authorizer on the API

### Data

- DynamoDB for tenant master records, usage summary, support events, and audit log

### Important note

For the **Admin Control App**, prefer **API Gateway + Cognito authorizer** over public Lambda URLs.

Why:

- much cleaner authentication
- easier route management
- easier future role control
- easier audit and protection

You can keep existing public Lambda URL flows for customer-facing setup/runtime if needed, but the admin app should use a more controlled admin API.

---

## 13. Recommended Auth Roles for V1

Keep this simple.

Use Cognito groups such as:

- `admin`
- `support`
- `read_only`

### V1 permissions

#### admin

- full tenant actions
- plan changes
- suspend / reactivate
- regenerate tenant secret
- resend setup instructions

#### support

- view all tenants
- add support notes
- resend setup instructions
- refresh connection checks
- cannot change commercial plan or suspend tenant

#### read_only

- view dashboards and tenant details only

---

## 14. Safe Actions and Guardrails

Every mutating action should:

- require authenticated user
- verify authorization
- write an audit log
- show success / failure clearly

### Actions that should require confirmation

- suspend tenant
- reactivate tenant
- regenerate tenant secret
- plan downgrade

### Recommended extra protection

For the most sensitive actions, require:

- confirmation modal
- reason text field

That will help later when support and product teams grow.

---

## 15. Suggested Admin API Endpoints

These are examples for V1:

- `GET /admin/overview`
- `GET /admin/tenants`
- `GET /admin/tenants/{tenantId}`
- `GET /admin/tenants/{tenantId}/usage`
- `GET /admin/tenants/{tenantId}/events`
- `GET /admin/tenants/{tenantId}/audit`
- `POST /admin/tenants/{tenantId}/extend-trial`
- `POST /admin/tenants/{tenantId}/change-plan`
- `POST /admin/tenants/{tenantId}/suspend`
- `POST /admin/tenants/{tenantId}/reactivate`
- `POST /admin/tenants/{tenantId}/resend-setup`
- `POST /admin/tenants/{tenantId}/regenerate-secret`
- `POST /admin/tenants/{tenantId}/refresh-health`
- `POST /admin/tenants/{tenantId}/support-note`

---

## 16. Recommended V1 Build Order

Build in this order:

### Phase 1

- Cognito login
- app shell
- tenant list
- tenant detail summary

### Phase 2

- plan and trial actions
- connection tab
- resend setup
- regenerate tenant secret
- audit logging

### Phase 3

- usage counters
- support notes
- overview dashboard

This order gets the operational backbone working first.

---

## 17. Best Practical Next Step

The best next product step is:

**design the exact V1 screens and data objects for a standalone AWS admin console focused on tenant lookup, setup/connection health, plan management, and safe support actions**

That is the version most likely to become real quickly.

---

## 18. Final Recommendation

For NativeForms, V1 Admin Control App should be:

**an internal AWS-hosted support and operations console with Cognito login, tenant search, tenant detail, connection/setup status, plan actions, and full audit logging**

That is a strong first version.
It is realistic, useful, and expandable.
