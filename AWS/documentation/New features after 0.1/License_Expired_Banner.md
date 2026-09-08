# License / Trial Expired — Banner Across All App Tabs

**Status:** Proposed (not built)
**Area:** Entitlements (AWS `/tenant/entitlements` + `NativeFormsTenantEntitlements.cls`) + shared LWC banner on every app tab + **hard publish block** in the publish path
**Author note:** Targeted after 0.1. Banner (informational) **+ a hard block on new publishes when expired** (§4).

---

## 1. What this is

When a customer's **trial or subscription has ended**, **every TwinaForms app tab** shows a prominent
message:

> **Your TwinaForms license ended on {date}.** To continue using TwinaForms, please contact
> **supportat@twinaforms.com**.

Shown on all managed-package tabs (Designer, Connect, Submission Logs). Reuse an existing notice area at
the top of the tab if there is one; otherwise a small **shared banner component** included by each tab.

In addition, when expired, **block any new publish** with a clear message (§4) — existing live forms keep
working, but no new/updated version can be published until the license is renewed.

---

## 2. The good news — the data already exists in AWS

The backend already models trial/subscription expiry end-to-end; this feature mostly **surfaces** it.

| Already computed in AWS | Reference |
|---|---|
| Effective access end date (trial vs plan) | `getEffectiveAccessEndDate` → `trialEndsAt` / `planEndsAt` / `subscriptionEndDate` (`NativeFormsAdminApi.mjs:947-954`) |
| Is the tenant past its end date? | `isTenantDateExpired` (`:956-960`) |
| Access state + alert type | `deriveTenantAccessState` → `status` (`active`/`alert`/`blocked`), `alertType: "end_date_passed"`, `subscriptionStatus` (`:962-1011`) |
| Lifecycle dates exposed on the tenant record | `normalizeTenantLifecycle` → `trialEndsAt`, `planEndsAt`, `planStatus`, `subscriptionStatus` (`:1013-1050`, `:1190-1202`) |

So "is it expired, and on what date" is **already known** — it's computed in the admin/tenant model and
also naturally drops the Pro feature flags on expiry.

### The gap
The **app reads a different endpoint** — `GET /tenant/entitlements` — via
`NativeFormsTenantEntitlements.cls`, and today that snapshot only carries `planCode`,
`effectiveFeatureFlags`, `effectiveLimits` (`NativeFormsTenantEntitlements.cls:5-12,78-83`). It does
**not** carry the **subscription status** or the **end date**. So the banner has nothing to read yet.

---

## 3. What to build

1. **AWS — expose status + date on the app endpoint.** Add to the `GET /tenant/entitlements` response the
   fields the app needs, reusing the existing helpers (§2): e.g. `subscriptionStatus` / `accessStatus`
   (`active` | `expired`), `alertType`, and `accessEndDate` (the resolved `getEffectiveAccessEndDate`).
   Data already computed — this is exposing it on the app-facing endpoint.
2. **Apex — capture + expose.** Extend `EntitlementSnapshot` with `accessStatus` + `accessEndDate`, parse
   them in `loadCurrentOrgEntitlements`, and add an `@AuraEnabled` getter the banner LWC calls (small
   addition; the HTTP call + per-transaction cache already exist).
3. **LWC — shared banner on every tab.** A small reusable component (e.g. `nativeFormsLicenseBanner`) that
   reads the snapshot and, when `accessStatus === "expired"`, renders the message with the formatted
   `accessEndDate` + the `supportat@twinaforms.com` contact. Include it at the top of `nativeFormsDesigner`,
   `nativeFormsConnect`, and `nativeFormsSubmissionLogs` (or drop it into an existing top notice region).

---

## 4. Scope & behaviour (decided)

### 4.1 Hard block on new publishes when expired (DECIDED)
When expired, **block any new publish** — not just a message.
- **Enforce server-side in the publish path** (`NativeFormsPublisher`), so it cannot be bypassed from the
  client. Check the tenant access status at the top of the publish entry (the same place existing Pro
  gates live, e.g. the merged-document gate at `NativeFormsPublisher.cls:157`) and **reject with a clear
  message**: *"Your TwinaForms license ended on {date}. Publishing is disabled. Contact
  supportat@twinaforms.com to continue."*
- **Reflect in UI:** disable the Publish button in the Designer with the same message/tooltip, so the
  block is obvious before the user clicks.
- **Existing live forms are unaffected** — they already serve from S3/AWS. Only **new/updated** publishes
  are blocked. (This is the right model: don't break production forms; just stop new releases.)
- Pro feature flags already drop on expiry too, so Pro capabilities lock naturally; this block adds the
  explicit publish stop on top.

### 4.2 The banner — expired only, no in-app pre-expiry warning (DECIDED)
**No in-app pre-expiry warning.** Pre-expiry notification is handled **by email to the admin** (separate
mechanism — see §4.4), not by a UI banner. This keeps the app screens clean.

The banner therefore has just **two states**:

| State | When | Style | Dismissible |
|---|---|---|---|
| **None** | Active (or fail-open) | renders nothing | — |
| **Expired** | Past the end date | red | **No** (persists) + publish block (§4.1) |

Simpler as a result: no warning window, no thresholds, no `localStorage` dismiss logic — the banner only
ever shows when `accessStatus === "expired"`, and it is non-dismissible until the license is renewed.

### 4.3 Other rules
- **Trial vs subscription = same banner**, correct date (`getEffectiveAccessEndDate` picks trial vs plan);
  copy reads "trial" vs "subscription" from `subscriptionStatus`.
- **Fail open.** If entitlements fail to load (`loadedSuccessfully === false`), show **nothing** and
  **do not** block publishing — never penalize on a transient error.
- **i18n / RTL.** Hebrew orgs — banner + block message must be translatable and render RTL (runtime i18n).

### 4.4 Pre-expiry notification = email to admin (separate)
Heads-up before expiry is delivered by **email to the org admin**, not by the app UI. This is a **separate
mechanism** (an AWS-side scheduled job over the tenant `accessEndDate`) specified in
[[Trial_License_End_Alert_Email]], and is **out of scope of this UI feature** — noted here so the in-app
side stays "expired banner + publish block" only.

---

## 5. Complexity

| Part | Complexity | Notes |
|---|---|---|
| AWS: add `accessStatus` + `accessEndDate` to `/tenant/entitlements` | **Low** | Data already computed (`isTenantDateExpired`, `getEffectiveAccessEndDate`); expose on the app endpoint. |
| Apex: extend snapshot + `@AuraEnabled` getter | **Low** | Add two fields + parsing + a getter; HTTP + cache already there. |
| **Apex: hard publish block** in publish path | **Low** | One access check at the top of the publish entry (`NativeFormsPublisher.cls:157` area) + a clear error; mirror the existing Pro-gate pattern. |
| LWC: shared banner (2-state) + include on each tab + disable Publish | **Low** | New small component; show only when expired; wire into 3 tabs; disable Publish on expiry; i18n/RTL. No warning-window/dismiss logic. |
| **Overall** | **Low** | Mostly plumbing existing expiry data to a simple expired-only banner + one publish-path guard; no new licensing logic, no warning UX. |

**One-line answer:** Low — the backend already knows the tenant is expired and the end date; the
work is exposing those fields on the app's entitlements endpoint, capturing them in Apex, adding **one
server-side publish guard**, and showing a simple expired-only banner on each tab. (Pre-expiry heads-up is
email, handled separately.)

---

## 6. How to deploy

> Org alias: **TwinaFormsDevHub** + AWS backend. No form re-publish needed (this is app-tab UI, not published forms).

### 6a. Components changed
- **AWS** backend handler for `GET /tenant/entitlements` — include `accessStatus` + `accessEndDate`
  (+ `subscriptionStatus`/`alertType`). Reuse `getEffectiveAccessEndDate` / `isTenantDateExpired`.
- `force-app/main/default/classes/NativeFormsTenantEntitlements.cls` (+ test) — snapshot fields + parsing.
- `force-app/main/default/classes/NativeFormsPublisher.cls` (+ test) — **hard publish block** on expiry
  (access check at the publish entry, near `:157`).
- A small `@AuraEnabled` getter (new or on an existing designer controller) for the banner.
- New LWC `nativeFormsLicenseBanner` (expired-only, non-dismissible) + include in
  `nativeFormsDesigner`, `nativeFormsConnect`, `nativeFormsSubmissionLogs`; disable Publish on expiry.

### 6b. Deploy commands (PowerShell)
```powershell
sf project deploy start `
  --source-dir force-app/main/default/lwc `
  --source-dir force-app/main/default/classes/NativeFormsTenantEntitlements.cls `
  --target-org TwinaFormsDevHub
sf apex run test --target-org TwinaFormsDevHub --result-format human --wait 10

# AWS: deploy the backend that serves /tenant/entitlements via its pipeline.
```

### 6c. Smoke test
1. Tenant **past** its end date → open each tab → confirm the red banner shows with the correct
   `{date}` and the `supportat@twinaforms.com` contact, and is **non-dismissible**.
2. Expired tenant → attempt to **publish** → confirm it is **blocked** with the message (server-side),
   the Publish button is disabled, **and an already-live form still serves**.
3. Active tenant → confirm **no** banner and publishing works normally.
4. Trial vs paid expiry → confirm the right date and wording.
5. Entitlements endpoint failing → confirm **no** false "expired" banner **and publishing still works**
   (fail open).
6. Hebrew org → confirm translated, RTL-correct banner + block message.

---

## 7. Decisions & open questions

**Decided:**
- **Hard block on new publishes when expired** (server-side + disabled Publish button) — §4.1.
- **Expired-only banner, no in-app pre-expiry warning** — §4.2.
- **Pre-expiry heads-up is email to the admin**, handled separately — §4.4.
- **Fail open** — no banner and no block if entitlements can't load.

**Open:**
- Exact copy + localize "trial" vs "subscription" wording.
- Does the standalone **admin console** app need the same banner, or package tabs only?
- Block only **publish**, or also other write actions on expiry (default: publish only)?
