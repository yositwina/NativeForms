# Auto-create Prefill & Submit Aliases for the Verified Contact

**Status:** Completed by implemented verified-email prefill flow; automatic alias abstraction superseded
**Area:** Designer LWC + Prefill/Submit alias system + User Verification (Apex) + AWS Prefill/Submit Lambdas
**Author note:** Targeted for a release after 0.1.

---

## 1. What the feature is

When an author adds a **User Verification** block to a form, automatically create:

1. A **prefill alias** (`PrefillVerifiedContact`) bound to the Contact matched by the verified email, so
   later form fields can prefill from that Contact — `{{PrefillVerifiedContact.FirstName}}`,
   `{{PrefillVerifiedContact.Account.Name}}`, billing rate, etc. — with no manual prefill query.
2. A **submit alias** bound to that same Contact, so submitted data can be written back to the verified
   Contact (or related child records) without the author hand-wiring the target record.

The pitch: User Verification *already* identifies exactly one Contact by email server-side. Exposing that
identity as a first-class alias means the verified person's Contact is available for both prefill and
submit "for free" — a strong building block for later form design.

The aliases are named **`PrefillVerifiedContact`** and **`SubmitVerifiedContact`**.

---

## 1a. Agreed scope (MVP decision)

This is the **scoped MVP we are committing to** — narrower than the full design in §3:

1. **Auto-create both aliases when the User Verification block is added** —
   `PrefillVerifiedContact` and `SubmitVerifiedContact` appear in the alias dropdowns, staged for later
   use. Remove them when the block is deleted. *(This is the easy, low-risk part — do it.)*
2. **`PrefillVerifiedContact` resolves to the Contact matched by the email entered in the User
   Verification module — but ONLY after that email passes verification (correct code entered).** It must
   never resolve from the raw typed email before verification.

### The one hard rule (do not violate)
> **Do not prefill from the typed email value before verification.**
> The Prefill Lambda is public and keys on a client-supplied email. Resolving `PrefillVerifiedContact`
> from the *typed* email (pre-code) means anyone can type any email and pull that Contact's PII without
> ever verifying — a PII leak that also makes the User Verification block pointless. The alias must bind
> to the **verified** identity only. See §3a / §5.

### Practical consequence
The verified Contact isn't known until *after* the code is entered, so this prefill does **not** run at
page load like normal prefill — it fires **after verification succeeds**. That post-verification trigger
is the only work beyond pure designer config, and it's modest. The fuller "signed trusted token across
Apex + Lambdas" design (§3b) is the robust way to enforce the hard rule; at minimum the runtime must
guarantee resolution happens only on a verified session, not on a request parameter.

---

## 2. How the pieces work today (verified by reading the code)

| Piece | Detail | Reference |
|---|---|---|
| User Verification resolves the Contact | `findExactlyOneContactByEmail(email)` — server-side, exactly-one match | `NativeFormsUserVerificationApi.cls:69,94,181` |
| Verify result | Sets `NF_User_Verification_Verified_At__c`, returns `approved = true`. **No token is minted** tying the verified identity to anything downstream. | `NativeFormsUserVerificationApi.cls:124-129` |
| Prefill runtime | A **separate AWS Lambda** (not the Apex verification API). Page calls it with `publishToken` + `params` (e.g. `email`); Lambda runs `prefillDefinition.commands` against a `prefillPolicy` (allowedCommands/objects/params) and returns `aliases`. | `AWS/NativeForms-PrefillForm.mjs` (`:1042-1061`, `:374-383`, `:678-705`) |
| Prefill alias surface in designer | `prefillAliasDetails` / `prefillAliasOptions`, populated from the prefill workspace | `nativeFormsDesigner.js:187,2199,2395`; `NativeFormsPrefillActionsController.cls:46-65` |
| Submit alias surface | Submit field mappings built per element into the submit definition | `NativeFormsPublisher.cls:1157-1215`; `NativeFormsSubmitActionsController.cls` |

### The decisive fact
**User Verification (Apex REST) and Prefill/Submit (AWS Lambdas) are separate systems with no shared
verified-session token.** The verify step knows the Contact, but that trust is **not** propagated to the
Lambdas. The Prefill Lambda today keys on **client-supplied** `params.email`.

---

## 3. Why this is not just "save two alias records"

The designer-side "create the aliases" work is easy config plumbing. The hard part is making the aliases
resolve to the **server-verified** Contact at runtime — safely.

### 3a. The security trap (IDOR / PII leak) — this is the core challenge
If the `PrefillVerifiedContact` prefill alias is implemented as the obvious `findOne Contact where Email =
params.email`, then **any caller can pass any email** to the public Prefill Lambda and receive that
Contact's data. That is a classic IDOR / PII-disclosure hole, and it *defeats the entire point of
verification*. The alias must resolve from a **trusted, server-proven identity**, never from a parameter
the browser controls.

### 3b. What's actually missing: trusted identity propagation
To bind the alias to the verified Contact safely, the verification step must mint a **signed,
short-lived token** (containing the verified ContactId / email, form id, expiry) that the prefill and
submit calls present, and the AWS Lambdas must trust **that token**, not raw params. Today no such token
exists (`verifyCode` returns only a boolean — `:126-129`). Building this bridge across the Apex
verification API and the AWS Lambdas is the real engineering work.

### 3c. Runtime sequencing change
Prefill currently runs at **form load**. The verified Contact isn't known until the user **completes
verification** (later in the session). So "prefill the verified Contact" is a **new, post-verification
prefill trigger** — prefill (or a second prefill pass) fires after `approved = true`, keyed on the
verified identity from 3b. That's a runtime flow change in the published form, not just a config toggle.

### 3d. Submit-side binding
Writing back to the verified Contact requires the **Submit Lambda** to receive the verified ContactId as
a **trusted** value (same token from 3b) — otherwise a submitter could redirect the writeback to an
arbitrary Contact Id. Submit mapping to an alias already exists; binding it to a trusted verified id is
the new part.

### 3e. Lifecycle / edge cases
- Remove the auto-created aliases when the User Verification block is deleted.
- Assume/enforce a single User Verification block per form (which Contact is "the verified one" otherwise?).
- `findExactlyOneContactByEmail` returns nothing when 0 or >1 Contacts share the email — define alias
  behaviour (empty prefill, no writeback) for those cases.

---

## 4. Complexity

| Part | Complexity | Notes |
|---|---|---|
| Designer: auto-create prefill + submit alias entries when UV block is added | **Low–Medium** | Config plumbing into the existing alias workspaces (`prefillAliasDetails`, submit mappings) + lifecycle on delete. |
| **Trusted identity token** (verify → mint signed token → Prefill/Submit Lambdas trust it) | **Medium–High** | The gating, security-critical work. Bridges two currently-separate systems. Without it the feature is an IDOR/PII leak (§3a). |
| Post-verification prefill trigger (runtime sequencing) | **Medium** | Prefill today runs at load; verified prefill must run after `approved`. New flow in the published form. |
| Submit-side trusted ContactId binding | **Low–Medium** | Reuses the token from above; maps an existing submit alias to the trusted id. |
| Lifecycle / multi-block / 0-or-many-match handling | **Low** | Defined behaviour + cleanup. |
| **Overall** | **Medium–High** | The *idea* (expose the verified Contact as an alias) is clean and high-value. The cost is not the aliases — it's safely propagating a **server-verified identity** across the Apex verification API and the AWS prefill/submit Lambdas, which have no shared session today. |

**One-line answer:** auto-creating the aliases is easy; making them resolve to the *verified* Contact
**without** opening a PII-leak is the real, security-critical work — because verification and
prefill/submit are separate systems with no shared trusted token today.

### MVP scope vs. full design
The **agreed MVP (§1a)** ships rows 1 + 3 of the table (auto-create the aliases + the post-verification
trigger) and treats "resolve only on a verified session" as the hard rule. The **full signed-token
design** (row 2) is the robust enforcement and the recommended end state, but the MVP can land first as
long as the runtime guarantees resolution never happens from a request-supplied email (§5).

---

## 5. Security note (do not skip)

- The Prefill Lambda is **public** and currently keys on client-supplied `params.email`
  (`NativeForms-PrefillForm.mjs`). Naively pointing the `verifiedContact` alias at `params.email` =
  **anyone can prefill anyone's Contact** (IDOR / PII disclosure). See §3a.
- The fix is a **signed, short-lived, single-form verified-identity token** minted at verify time and
  validated server-side by the Prefill/Submit Lambdas. The token — not any request parameter — supplies
  the ContactId.
- Same principle on submit: the writeback target Contact Id must come from the **trusted token**, never
  from a client field, or a submitter can redirect the write to an arbitrary record.
- This is also an **AppExchange / DAST** concern: a public endpoint returning Contact PII based on an
  unauthenticated email parameter is exactly what the security scans look for. Tie it to the verified
  token before shipping.

---

## 6. How to deploy

> Org alias: **TwinaFormsDevHub** (per project deploy targets).

### 6a. Components likely changed
- `force-app/main/default/lwc/nativeFormsDesigner/*` — auto-create/remove the aliases when the UV block
  is added/deleted.
- `force-app/main/default/classes/NativeFormsUserVerificationApi.cls` (+ test) — **mint the signed
  verified-identity token** on `approved`.
- `force-app/main/default/classes/NativeFormsPublisher.cls` (+ test) — emit the post-verification prefill
  trigger and submit binding into the published form.
- `NativeFormsPrefillActionsController.cls` / `NativeFormsSubmitActionsController.cls` — surface the
  auto-created aliases in the workspaces.
- **AWS `NativeForms-PrefillForm.mjs`** — accept + validate the verified token, resolve the verified
  ContactId from it (not from params).
- **AWS `NativeForms-SubmitForm.mjs`** — accept the verified token for trusted writeback target.

### 6b. Deploy commands (PowerShell)
```powershell
# Salesforce package pieces
sf project deploy start `
  --source-dir force-app/main/default/lwc/nativeFormsDesigner `
  --source-dir force-app/main/default/classes/NativeFormsUserVerificationApi.cls `
  --source-dir force-app/main/default/classes/NativeFormsUserVerificationApiTest.cls `
  --source-dir force-app/main/default/classes/NativeFormsPublisher.cls `
  --source-dir force-app/main/default/classes/NativeFormsPublisherTest.cls `
  --source-dir force-app/main/default/classes/NativeFormsPrefillActionsController.cls `
  --source-dir force-app/main/default/classes/NativeFormsSubmitActionsController.cls `
  --target-org TwinaFormsDevHub

sf apex run test `
  --tests NativeFormsUserVerificationApiTest --tests NativeFormsPublisherTest `
  --target-org TwinaFormsDevHub --result-format human --wait 10
```

AWS Lambdas deploy via their own pipeline (e.g. `deploy-nativeforms-submit.ps1` for the Submit Lambda;
the Prefill Lambda via its deploy script). The **token-signing secret** must be shared between Salesforce
and the Lambdas (config/secret, not code).

### 6c. IMPORTANT — re-publish affected forms
The published form's prefill/submit wiring is **baked at publish time** by `NativeFormsPublisher.cls`.
Deploying code does not change already-published forms. After deploy, each form using User Verification
must be **re-published** for the auto-aliases and the post-verification prefill trigger to take effect.

### 6d. Smoke test after deploy
1. Add a User Verification block → confirm `verifiedContact` prefill alias + submit alias auto-appear in
   the alias dropdowns.
2. Map a field to `{{verifiedContact.FirstName}}`; verify in the form, confirm it prefills **after**
   verification.
3. **Negative (security):** call the Prefill Lambda directly with `params.email` of a Contact you have
   *not* verified — confirm it returns **no** Contact data without a valid verified token.
4. Submit and confirm the writeback lands on the verified Contact, and that tampering with the submitted
   Contact Id does **not** redirect the write.

---

## 7. Open questions
- One User Verification block per form — enforce it, or define "which Contact" when there are several?
- Behaviour when the email matches 0 or >1 Contacts (`findExactlyOneContactByEmail` returns null).
- Token TTL and scope (per form + per session); where the signing secret lives.
- Should the verified-Contact submit alias allow **create** (new related child records) or **update only**
  on the Contact itself?
- Pro-tier gating — is this a Pro feature like merged documents / prefill alias references?
