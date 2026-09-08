# HTML Source Toggle for Display Text / Merged Document

**Status:** Proposed (not built)
**Area:** Designer LWC (`nativeFormsDesigner`) + Publisher (`NativeFormsPublisher.cls`)
**Author note:** Targeted for a release after 0.1.

---

## 1. What the feature is

The **Display Text** and **Merged Document** elements let an author write formatted content
(rich text) that is rendered on the published form. Today the author edits it through Salesforce's

This feature adds an **`</> HTML` toggle button** to that editor — exactly like competitors such as
Assembly. Pressing it switches the modal from the WYSIWYG view to a **raw HTML source view** (a plain
textarea showing the underlying markup), so the author can paste / hand-edit HTML directly and switch
back to the visual view.

### Why the author wants it
The rich-text toolbar cannot produce certain markup that authors need. The motivating example is a
"contact us" block with a styled WhatsApp link + inline image:

```html
<span style="font-weight: 700; font-size: 14.4px;">Questions?</span>
<span style="font-size: 14.4px;">&nbsp;</span><a href="https://wa.me/972586477235" target="_blank" style="background-color: rgb(255, 255, 255);">Write to us on&nbsp;</a>&nbsp;<span style="font-weight: 700;"><u>WhatsApp</u></span><u>&nbsp;</u><img src="https://upload.wikimedia.org/wikipedia/commons/6/6b/WhatsApp.svg" width="24" height="24" alt="WhatsApp"><br><span style="font-size: 14.4px;">Write to us at: <a href="mailto:one2one@enterpeoplehood.org" target="_blank">one2one@enterpeoplehood.org</a>&nbsp;</span>
```

This markup uses inline `style`, `target="_blank"`, an external `<img>`, and `<br>` — none of which the
standard toolbar exposes, and some of which the standard editor actively strips.

---

## 2. How it works today (current architecture)

| Piece | Detail | Reference |
|---|---|---|
| Editor component | Standard `lightning-input-rich-text` (Quill-based, Salesforce base component) | `nativeFormsDesigner.html:2846` |
| Stored value | The content is **already an HTML string**, kept in `modalDisplayText` / `editorDisplayText` and saved to the element config as `config.html` (and mirrored to `config.text`) | `nativeFormsDesigner.js:6318` |
| Publish (per-row + summary paths) | The stored HTML is injected into the generated public page **raw / unescaped** | `NativeFormsPublisher.cls:2564`, `:2566`, `:2846` |
| Current XSS protection | **Only** the Quill editor's input allowlist. There is **no** server-side sanitization at publish time. | (see §5) |

**Key implication:** because the value is already HTML and is published raw, exposing a source textarea
is mechanically easy — but the editor is currently the *only* sanitizer in the whole pipeline.

---

## 3. Implementation approach

### 3a. UI toggle (the easy part)
1. Add a boolean `showHtmlSource` to the component state.
2. Add an `</> HTML` toggle button inside the Display Text modal header.
3. In the modal body:
   - `if:false={showHtmlSource}` → existing `<lightning-input-rich-text>` bound to `modalDisplayText`.
   - `if:true={showHtmlSource}` → `<lightning-textarea>` (or plain `<textarea>`) bound to the **same**
     `modalDisplayText` string.
4. Both views write to the same property, and the save path (`handleSaveDisplayTextModal`,
   `nativeFormsDesigner.js:5196`) is unchanged — it just persists whatever string is in
   `modalDisplayText`.

Because both views share one source of truth, the string round-trips between them for free.

### 3b. The real decision: round-trip behaviour
`lightning-input-rich-text` runs an **allowlist sanitizer**. When the author types raw HTML in the
textarea and flips **back** to the visual view, Quill **silently strips** anything outside its allowed
set — inline `style`, `target`, external `<img>`, data-attributes, etc. So the WhatsApp example above
would be partially destroyed on the round-trip.

Two options:

- **Option A — Textarea is authoritative while open (recommended for this use case).**
  Treat the HTML textarea as the source of truth. The visual editor is a best-effort preview that may
  show *less* than what is saved. This is what lets the WhatsApp/styled-image markup survive.
- **Option B — Round-trip through Quill.** Cleaner two-way sync, but lossy — the editor eats the very
  markup the author is trying to add. Defeats the purpose here.

> The motivating example **requires Option A** (or a non-SF editor), because Quill will not preserve
> `style="background-color: rgb(...)"`, external `<img src>`, or `target="_blank"`.

### 3c. Sanitization (the part that makes this more than a button)
Since the publisher injects `richHtml` **raw** (`NativeFormsPublisher.cls:2566`), and Option A bypasses
Quill, **the published public form would otherwise have zero XSS protection**. Allowing arbitrary
author HTML on a public URL = stored-XSS risk (`<script>`, `onerror=`, `javascript:` URLs, etc.).

A correct implementation must add an **allowlist sanitizer** before the HTML is served — allow the
tags/attributes the example needs (`span/a/u/b/strong/img/br` + `style`, `href`, `src`, `target`,
`width`, `height`, `alt`) and strip scripts, event handlers, and dangerous URL schemes. This is the bulk
of the real engineering work. **Where** to run it (AWS vs Apex) and the AppExchange angle are decided in
§5 — short version: enforce on **AWS** at publish-upload with a proven library, with an optional Apex
fail-fast guard.

---

## 4. Complexity

| Part | Complexity | Notes |
|---|---|---|
| `</> HTML` toggle button + textarea view | **Low** (~half a day) | Pure LWC; both views share `modalDisplayText`; save path untouched. |
| Round-trip / "which view is authoritative" decision | **Low–Medium** | Mostly a product decision; Option A is simplest and matches the use case. |
| Allowlist sanitization on **AWS** (publish-upload) | **Medium** | This is the actual work and the gating risk. Done with a proven library (DOMPurify / `sanitize-html`), not hand-rolled. See §5. |
| Fail-fast guard in **Apex** (optional) | **Low** | A coarse "reject obvious `<script>`/`on*=`/`javascript:`" check for review optics + early errors. Not the real sanitizer. |
| **Overall** | **Low–Medium** | The button is trivial (author's assumption is correct). The non-trivial part is *safely publishing* arbitrary HTML, because the SF rich-text sanitizer is currently the only guard and the publisher emits raw HTML. |

**One-line answer to "how hard is the button":** the button itself is easy; making it *safe to publish*
arbitrary HTML is the part worth budgeting for.

---

## 5. Security note (do not skip)

### 5.1 Verified current state — there is NO server-side sanitization
Confirmed by reading the publisher and grepping all Apex classes:

- The Display Text / Merged Document HTML is injected **raw** into the published public page:
  - `NativeFormsPublisher.cls:2566` (heading) — `... + wrapperAttrs + '>' + richHtml + '</div>'`
  - `:2564` (merged-doc body raw; only the `data-...-template` *attribute* is escaped)
  - `:2575` (paragraph/richText uses raw `config.html`; only the *fallback plain text* at `:2577` is escaped)
  - `:2846` (repeat-row path, body raw)
- The only sanitize-looking helper is `escapeHtml` (`NativeFormsPublisher.cls:4188`) — a plain
  **entity-encoder** (`& < > " '` → entities). It is **not** a sanitizer (no allowlist, no DOM parse, no
  script stripping) and is deliberately **not** applied to the rich-text body.
- The save path stores config verbatim (`NativeFormsBuilderController.cls:296`); no sanitization there
  either. A grep for `sanitiz|stripScript|cleanHtml|allowlist|whitelist` across all classes matches
  **only** `NativeFormsPublisher.cls` (i.e. only the entity-encoder).
- **Net:** today the *only* thing scrubbing malicious markup from these elements is the **Quill editor on
  the client** (`lightning-input-rich-text`). The HTML-source toggle bypasses Quill, so it removes the
  one and only guard.

### 5.2 Why sanitize at all — two *separate* risks
Sanitization = keep harmless formatting, strip markup that can **run code or perform actions** in a
visitor's browser. Allowed: `span/a/u/b/strong/img/br` + `style/href/src/target/width/height/alt`.
Stripped: `<script>`, `on*=` handlers, `javascript:`/`data:` URLs. The motivating WhatsApp snippet (§1)
passes an allowlist untouched — sanitization does not block it.

These two risks are **not** the same and must be reasoned about separately:

- **Risk A — harm to the Salesforce org (XSS stealing a SF session / org compromise).**
- **Risk B — harm to the people filling the form (stealing PII, the verification OTP, phishing/redirect)
  on the public twinaforms.com page.**

### 5.3 The "it's only a static S3 file" argument — what it does and doesn't cover
The generated HTML is **never rendered inside Salesforce**. It is a static file uploaded to S3 and served
from AWS (twinaforms.com). It never runs on a `*.force.com` / `*.salesforce.com` origin, never sees a
Salesforce session cookie, never touches the Lightning DOM.

- ✅ **This fully resolves Risk A.** No Salesforce session is reachable from this page, so XSS here cannot
  compromise the org. This is a true, legitimate point.
- ✅ **It is a valid AppExchange-review explanation.** The Salesforce Code Analyzer / Checkmarx pass will
  likely flag the Apex string-into-HTML concatenation as a potential XSS sink. The accepted response is a
  written mitigation: *"this output is a static file served from an isolated AWS origin (twinaforms.com),
  not rendered in any Salesforce context."* That is a reasonable, commonly-accepted false-positive
  justification.
- ❌ **It does NOT resolve Risk B.** The form still collects PII (name, email, hours, **signature**) and
  runs a **verification OTP** flow. Stored XSS on twinaforms.com can still exfiltrate everything a visitor
  types, relay/steal the OTP, or redirect to a phishing page — on *our* domain, hurting *our* users and
  brand. This risk is unchanged by where the page is hosted.

### 5.4 Decision — where to sanitize: **AWS primary, Apex optional guard**
- **Enforce on AWS (the real sanitizer).** Run DOMPurify / `sanitize-html` with the allowlist at the
  **publish-upload step** (a Lambda sanitizes the HTML *before* it lands in S3, so the stored artifact is
  already clean). Prefer this over serve-time Lambda@Edge (which re-runs per request and interacts badly
  with CloudFront caching).
  - **Why AWS, not Apex:** Apex has **no** HTML sanitizer library. Sanitizing in Apex means hand-rolling a
    regex/string allowlist parser — the single most common source of XSS *bypasses*. Node/AWS has
    battle-tested libraries that handle malformed HTML, encoded payloads, and mutation XSS. Reliability is
    the deciding factor.
  - **Infra note:** today SF uploads via presigned PUT **directly to S3**. To insert AWS sanitization,
    route the publish HTML through a Lambda instead of (or in front of) the direct PUT. This is the one
    infrastructure change to weigh.
- **Optional fail-fast guard in Apex.** In `NativeFormsPublisher`, before injecting `richHtml`, do a
  coarse check (reject `<script`, `on*=`, `javascript:`) and fail the publish with a clear message. This
  is **not** the XSS defense — it is for (a) review optics (package isn't a naive raw sink) and (b) early,
  friendly errors. A dozen lines, no parser.
- **Why we still sanitize even though the reviewer may accept §5.3:** the isolated-origin argument lowers
  the *review* hurdle (Risk A), but Risk B — protecting our own form-fillers' data and our brand — is real
  regardless of what the reviewer accepts. AWS sanitization is the part that defends Risk B, so it should
  not be dropped.

### 5.5 Bottom line
Ship the HTML toggle **only together with AWS-side allowlist sanitization** (Risk B). For AppExchange
review, lean on the "static S3 file, never rendered in SF" justification plus an optional Apex fail-fast
guard (Risk A). Do **not** invest in a hand-rolled Apex HTML sanitizer.

---

## 6. How to deploy

> Org alias: **TwinaFormsDevHub** (per project deploy targets).

### 6a. Components changed
- `force-app/main/default/lwc/nativeFormsDesigner/*` (HTML/JS for the toggle).
- **AWS publish-upload Lambda** (allowlist sanitizer — DOMPurify / `sanitize-html`). This is the real
  enforcement point per §5.4, and is deployed via the AWS pipeline, **not** the SF package.
- `force-app/main/default/classes/NativeFormsPublisher.cls` (optional Apex fail-fast guard only — *not*
  the sanitizer) + `NativeFormsPublisherTest.cls` for its coverage.

### 6b. Deploy commands (PowerShell)
```powershell
# Deploy the designer LWC only (UI toggle)
sf project deploy start `
  --source-dir force-app/main/default/lwc/nativeFormsDesigner `
  --target-org TwinaFormsDevHub

# If sanitization is included, deploy the Apex + tests too
sf project deploy start `
  --source-dir force-app/main/default/classes/NativeFormsPublisher.cls `
  --source-dir force-app/main/default/classes/NativeFormsPublisherTest.cls `
  --target-org TwinaFormsDevHub

# Run Apex tests for the publisher
sf apex run test `
  --tests NativeFormsPublisherTest `
  --target-org TwinaFormsDevHub `
  --result-format human --wait 10
```

### 6c. IMPORTANT — published forms must be re-published
Display Text / Merged Document HTML is **baked into the form at publish time** by
`NativeFormsPublisher.cls`. Deploying the code does **not** change already-published forms.
After deploy, each affected form must be **re-published** in the Designer for the new HTML (and any new
sanitization) to take effect on the live AWS-hosted page.

### 6d. Smoke test after deploy
1. Open Designer → add/edit a Display Text element → press `</> HTML`.
2. Paste the WhatsApp example from §1, save, and re-publish the form.
3. Open the published public URL and confirm the styled link + WhatsApp image render.
4. Negative test: paste `<img src=x onerror=alert(1)>` and confirm it is stripped/neutralized in the
   published output (proves §3c sanitization works).

---

## 7. Open questions
- Trusted-author only, or all authors? (affects whether sanitization can be lighter.)
- Allowed tag/attribute list — confirm the final allowlist with security before enabling.
- Do we also want the toggle on the inline (non-modal) editor, or modal-only?
