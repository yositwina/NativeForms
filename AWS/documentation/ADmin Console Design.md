Here is a strong high-level design for a **NativeForms Admin Controller** that serves internal business users such as **Product Manager, Sales Manager, CEO, and Support**.

## Purpose

The Admin Controller is the **business control center** of NativeForms.
It is not the form designer itself. It is the place where the company manages:

* customers and tenants
* plans and trial status
* usage and limits
* health and issues
* support actions
* product insights

Think of it as the **operating back office** for the SaaS.

---

## 1. Main design idea

Split the Admin Controller into **6 clear domains**:

### A. Customer / Tenant Management

Manage every installed customer org as one account/tenant.

Should show:

* company / org name
* Salesforce org identifier
* install date
* environment type if relevant
* status: active, suspended, trial, expired
* plan
* owner/admin contact
* last activity

Main actions:

* open tenant profile
* change plan
* extend trial
* suspend / reactivate
* resend onboarding / connection instructions

This is the heart of the system.

---

### B. Subscription, Licensing, and Billing

This area controls commercial status.

Should include:

* trial start/end
* current package/plan
* add-ons
* license state
* payment status
* renewal date
* manual overrides
* grace period handling

Main actions:

* start 1-month trial
* upgrade / downgrade
* apply manual extension
* mark account as internal/demo/partner
* block premium features when needed

This domain is very important for CEO and Sales.

---

### C. Usage and Limits Monitoring

This shows whether the customer is actively using the product and whether they are near limits.

Examples:

* number of active forms
* submissions this month
* storage / upload usage
* API/prefill/submit usage
* number of designer users
* feature usage by category

Why it matters:

* helps detect customers ready for upsell
* helps detect abnormal usage
* helps enforce plan limits
* helps Product understand real adoption

This should include both:

* current snapshot
* monthly trend

---

### D. Operational Health and Technical Status

This is the operations view.

Should show:

* AWS connectivity health
* Salesforce connection health
* token/auth status
* last successful submission
* last failed submission
* Lambda/API error rate
* email delivery status
* storage / queue / background job status

Main goal:
quickly answer:

* Is the platform healthy?
* Is one tenant broken?
* Is there a widespread issue?

This area is essential for Support and Product.

---

### E. Support and Customer Success Console

This gives internal teams safe support actions without deep technical access.

Examples:

* search tenant by company / email / org id
* view recent errors
* inspect recent submissions metadata
* re-send setup email
* re-generate connection secret/token
* unlock tenant after issue
* enable temporary support mode
* view audit trail of changes

Important principle:
support should be able to help customers fast **without direct database access**.

---

### F. Analytics and Executive Dashboard

This is the management layer for CEO / Product / Sales.

Should show:

* total active customers
* trials started this month
* trial-to-paid conversion
* active forms across all tenants
* total submissions
* churn / expired tenants
* top feature adoption
* support volume / issue categories
* usage by plan

This area is not for operations only.
It is for business decisions:

* which features matter
* where users drop off
* which accounts are likely to convert
* which plans are working

---

## 2. Recommended user-role view

The same controller can have role-based views.

### Product Manager

Needs:

* usage trends
* feature adoption
* onboarding funnel
* tenant health
* common support issues
* roadmap signals

### Sales Manager

Needs:

* trial accounts
* high-usage prospects
* accounts nearing upgrade point
* expired trials
* customer activity score

### CEO

Needs:

* ARR/MRR direction if billing exists
* active customers
* trial conversion
* churn risk
* product usage growth
* major incidents

### Support

Needs:

* tenant lookup
* connection status
* last errors
* support actions
* audit trail
* recent activity log

So the design should be one platform, but each role sees a slightly different default dashboard.

---

## 3. Suggested top-level navigation

A clean structure could be:

* **Overview**
* **Customers**
* **Plans & Trials**
* **Usage**
* **Health**
* **Support**
* **Analytics**
* **Settings**

That is enough for version 1 or 2.

---

## 4. Recommended homepage structure

The Admin Controller home screen should feel like an executive console, not a technical admin table.

### Top summary cards

* active tenants
* trials in progress
* expiring trials
* failed tenants / connection issues
* submissions today
* upgrade opportunities

### Middle section

* recent alerts
* tenants needing attention
* trial accounts nearing end
* top active customers
* recent support events

### Bottom section

* usage trends
* conversion funnel
* platform health trend

This gives one-screen situational awareness.

---

## 5. Tenant profile page

Each tenant should have a dedicated profile page with tabs.

Suggested tabs:

* **Summary**
* **Plan**
* **Usage**
* **Connection**
* **Support Log**
* **Audit History**

That page becomes the single source of truth for one customer.

---

## 6. Data design at a high level

The Admin Controller likely needs a central tenant record in AWS.

For each tenant, store high-level business and operational metadata such as:

* tenant id
* Salesforce org info
* plan
* trial dates
* status
* usage counters
* feature flags
* connection state
* important timestamps
* support notes/events

Then keep event logs separately for:

* submissions
* errors
* admin actions
* billing/license changes
* onboarding steps

So conceptually:

* **Tenant master record**
* **Usage metrics**
* **Operational events**
* **Audit/support events**

---

## 7. Design principles

### Keep business-first, not engineering-first

Use language like:

* customer
* plan
* trial
* health
* activity
  instead of raw infrastructure terms as the main UI.

### Show actionability

Every dashboard section should lead to action:

* extend trial
* contact customer
* investigate failure
* suggest upgrade
* fix connection

### Separate summary from deep detail

Executives want fast signal.
Support wants drill-down.
Do not show raw logs first.

### Keep auditability

Every internal change should be tracked:

* who changed plan
* who extended trial
* who suspended tenant
* who regenerated token

This is important as the product grows.

---

## 8. Best V1 scope

For an initial version, I would include only:

* Overview dashboard
* Customer/Tenant list
* Tenant profile
* Trial/plan management
* Usage counters
* Connection health
* Support actions
* Audit log

And postpone:

* full billing integration
* advanced cohort analytics
* predictive churn scoring
* complex role management

That gives you a strong and realistic first version.

---

## 9. Simple one-line positioning

You can think of it as:

**“NativeForms Admin Controller is the internal command center for managing customers, plans, usage, health, and support across all tenant orgs.”**

---

## 10. My recommendation

For NativeForms, the Admin Controller should primarily be built around these 4 business questions:

1. **Who are our customers and what plan are they on?**
2. **Are they actively using the product and approaching limits?**
3. **Is anything broken or at risk right now?**
4. **What action should Product, Sales, CEO, or Support take next?**

If you want, I can next turn this into a **screen-by-screen UI structure** or a **one-page product spec / PDF-ready summary**.

## Login to Console
The best practical design is:

User opens admin.yourdomain.com
If not signed in, redirect to Cognito hosted login
User enters username/password
Cognito asks for second factor:
preferably Authenticator app
optionally SMS
After successful login, Cognito returns tokens
Your HTML/JS app loads
Every Lambda/API call sends the token, and backend verifies it

That gives you real login protection, not just a hidden page. Cognito’s managed login supports MFA, including TOTP authenticator apps and SMS-based MFA.