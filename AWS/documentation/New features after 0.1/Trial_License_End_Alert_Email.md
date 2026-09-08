# Pre-End Alert Email (Trial / License expiry) — to Customer + Yosi

**Status:** Proposed (not built)
**Area:** AWS — scheduled job + SES (reuse existing `yosi@harmony-it.co.il` sender) + tenant model
**Author note:** Targeted after 0.1. This is the **email mechanism** referenced by
[[License_Expired_Banner]] §4.4 (in-app shows the expired banner; email gives the pre-end heads-up).

---

## 1. What this is

Today, on customer **status changes**, AWS emails **Yosi** from `yosi@harmony-it.co.il`
(`sendStatusChangeEmail`, `NativeFormsAdminApi.mjs:722`). This feature adds a **scheduled pre-end alert**:
AWS, **from the same `yosi@harmony-it.co.il` sender**, emails the **customer admin (and Yosi)** that their
**trial / license period is ending** (and when it has ended), pointing them to `supportat@twinaforms.com`
to continue.

**Why the harmony-it sender:** we cannot yet send from a `twinaforms.com` address — that sender/domain is
**not approved in SES** and no alternate sender is configured. So we reuse the **already-verified,
production-approved `yosi@harmony-it.co.il`** identity (`SES_FROM`, `NativeFormsAdminApi.mjs:29`), sending
via **`us-east-1`** where harmony-it has SES production access (§2).

---

## 2. SES region — send via us-east-1 (where harmony-it is production-approved)

Emailing **arbitrary customer addresses** (`tenant.adminEmail`) requires SES **production access** (out of
sandbox). **Good news:** the `harmony-it` SES account **is production-approved in `us-east-1`**. The catch
is that **SES production access and verified identities are per-region**, and the current SES client
defaults to **`eu-north-1`** (`SES_REGION || AWS_REGION || "eu-north-1"`, `NativeFormsAdminApi.mjs:13`) —
which may still be in sandbox.

**Resolution:** send these alert emails through **`us-east-1`**, i.e. set/confirm `SES_REGION=us-east-1`
(or instantiate a dedicated `new SESClient({ region: "us-east-1" })` for the alerts). Cross-region sending
from a `eu-north-1` Lambda to the `us-east-1` SES endpoint is fine.

**Two things to confirm (per-region):**
1. `yosi@harmony-it.co.il` (the `SES_FROM` sender) is a **verified identity in `us-east-1`**.
2. Production access is active in `us-east-1` (so unverified customer recipients can receive mail).

> Note: the *existing* status email to Yosi may run via `eu-north-1`; pointing **at least the customer
> alerts** to `us-east-1` is what unblocks customer delivery. Simplest is to set `SES_REGION=us-east-1`
> globally (verify Yosi's sender there too).

---

## 3. The good news — most plumbing exists

| Building block | Exists | Reference |
|---|---|---|
| SES client + send command | ✅ | `import { SESClient, SendEmailCommand }` (`NativeFormsAdminApi.mjs:9,13`) |
| Verified sender | ✅ | `SES_FROM = "yosi@harmony-it.co.il"` (`:29`) |
| A working send function to clone | ✅ | `sendStatusChangeEmail()` (`:722-764`) |
| Customer recipient | ✅ | `tenant.adminEmail` |
| Effective end date + expired check | ✅ | `getEffectiveAccessEndDate` / `isTenantDateExpired` (`:947-960`) |
| Default alert recipient (Yosi) | ✅ | `DEFAULT_STATUS_ALERT_EMAIL` / `statusAlertEmailRecipient` (`:28,647`) |

The new work is a **scheduled scan + threshold logic + idempotency + a customer-facing email body** — not
new email infrastructure.

---

## 4. How it works

1. **Schedule.** A daily **EventBridge cron** invokes a new handler (in the Admin API Lambda or a small
   dedicated function).
2. **Scan tenants.** For each tenant, compute **days-until-end** from `getEffectiveAccessEndDate`
   (trial vs plan, already handled).
3. **Thresholds.** Send an alert at configured points — e.g. **14, 7, 1 day(s) before** end, and **on/after
   expiry**. (Confirm the exact thresholds.)
4. **Recipients.** **From** `yosi@harmony-it.co.il`; **To** the customer `adminEmail`; **also Yosi**
   (cc/bcc, or the `statusAlertEmailRecipient`) so Yosi is always aware. *(Interim: To Yosi only — §2.)*
5. **Body.** Clear copy: *"Your TwinaForms {trial/subscription} ends on {date}"* (or *"ended on {date}"*),
   *"to continue, contact `supportat@twinaforms.com`."* Reply-to could be set to `supportat@twinaforms.com`
   even though the sender is `yosi@harmony-it.co.il`.
6. **Idempotency (important).** Record which alerts were already sent per tenant (e.g. a
   `endAlerts: { "14": sentAt, "7": sentAt, "expired": sentAt }` map on the tenant record) so the **daily**
   scan sends each threshold **once**, not every day.

---

## 5. Decisions / details
- **Sender stays `yosi@harmony-it.co.il`** (env `SES_FROM`), kept overridable so we can switch to a
  TwinaForms sender later (see §7).
- **Trial vs subscription** wording from `planCode` / `subscriptionStatus`; date from
  `getEffectiveAccessEndDate`.
- **Reply-To = `supportat@twinaforms.com`** so replies reach support even though the From is harmony-it.
- **i18n:** Hebrew customers — provide a Hebrew email body (the customer base includes Israeli nonprofits).
- **Quiet on failure:** a tenant with no `adminEmail` or an SES error is logged and skipped, not retried in
  a tight loop.

---

## 6. Complexity

| Part | Complexity | Notes |
|---|---|---|
| Scheduled scan (EventBridge cron) + handler | **Low–Medium** | New daily trigger + a scan over tenants. |
| Threshold + days-until-end logic | **Low** | Reuses `getEffectiveAccessEndDate`. |
| Customer-facing email body (clone `sendStatusChangeEmail`) | **Low** | New body + To customer + Yosi; same SES sender. |
| Idempotency (per-threshold sent tracking) | **Low–Medium** | Store `endAlerts` flags on the tenant record. |
| SES region → `us-east-1` (production-approved) | **Low** | Set `SES_REGION=us-east-1` / dedicated client; verify sender there (§2). |
| **Overall** | **Low–Medium** | All email infra exists; work is the cron + thresholds + idempotency + body, plus pointing SES at `us-east-1`. No external blocker — production access already exists there. |

**One-line answer:** Low–Medium — reuse the existing SES sender + send function, add a daily scan with
thresholds and per-tenant idempotency, and send via **`us-east-1`** where harmony-it is production-approved
(verify the `yosi@` sender in that region).

---

## 7. How to deploy

> AWS-only. No Salesforce change, no form re-publish.

### 7a. Components changed
- **AWS `NativeFormsAdminApi.mjs`** (or a new small Lambda): the scheduled scan handler + a
  `sendTrialEndAlertEmail(tenant, daysLeft)` cloned from `sendStatusChangeEmail`.
- **EventBridge rule** (daily cron) → invoke the handler.
- **Tenant record**: add `endAlerts` (sent-threshold tracking) fields.
- **Env/config:** `SES_REGION=us-east-1` (production-approved region — §2), `SES_FROM` (stays
  `yosi@harmony-it.co.il`, verified in us-east-1), and the alert thresholds.

### 7b. Smoke test
1. Tenant ending in 7 days → run the scan → confirm one email **from `yosi@harmony-it.co.il`** to the
   customer **and** Yosi, correct date/wording, reply-to `supportat@twinaforms.com`.
2. Run the scan again same day → confirm **no duplicate** (idempotency).
3. Tenant already expired → confirm the "ended on {date}" email goes once.
4. Send to a **non-verified external test address** via `us-east-1` → confirm it delivers (proves
   production access in that region).
5. Hebrew customer → confirm Hebrew body.

---

## 8. Open questions
- Exact thresholds (14/7/1 before + on expiry?) and whether trial and paid differ.
- Confirm `yosi@harmony-it.co.il` is a **verified SES identity in `us-east-1`** (§2).
- One combined email to customer+Yosi, or separate internal vs customer copies?
- When do we migrate the sender to a `twinaforms.com` address (verify domain + leave SES sandbox), and
  retire the harmony-it sender for customer-facing mail?
- Localize per the customer's language setting, or default by some tenant attribute?
