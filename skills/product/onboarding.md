# Product Onboarding

## Purpose
Keep Codex aligned with Starter-first product quality, setup clarity, demo posture, and customer-facing UX tone.

## Use When
Use for Home, Connect, setup flows, demo data, thank-you behavior, upgrade framing, launch readiness, or customer-facing copy and guidance.

## NativeForms Rules
- Treat Starter as a real sellable product, not a prototype tier.
- Prefer compact, clear, customer-safe UX over technical/status-heavy screens.
- Surface setup state, plan state, limits, and next steps in plain language.
- Demo/sample data is helpful but secondary; it should support onboarding without overshadowing real product readiness.
- Seeded demo/sample forms should feel launch-ready, use standard customer-safe `formN` keys, and keep public query params simple and predictable such as lowercase `email`.
- Upgrade messaging should reflect the actual plan model and never drift from AWS plan data.
- Prioritize the short Starter sequence already defined: UI polish, demo quality, runtime/setup clarity, thank-you flow, QA, package readiness, then admin-auth hardening.
- Form experiences must stay multilingual-safe. Avoid fixed English instructional/decorative copy in the public form when the admin has not explicitly configured it.
- Supported form runtime language codes are `en`, `he`, `es`, `de`, and `fr`; keep English fallback active and treat Hebrew as the RTL QA priority.
- New Designer elements should use default labels in the selected form language. Existing/admin-edited labels must not be overwritten when the language changes.
- If a form element already has a configurable label, prefer no extra fixed helper headline. File upload and secret-code experiences should be structurally clear without relying on English-only filler text.
- Customer-visible button labels that appear in published forms should be configurable where practical, not hard-coded in English by default.
- Multi-form organization should use a first-class `Project` model above forms, not tags or reused categories.
- Starter killer feature pairing: secure Salesforce update links plus secret-code verification. The product story is that a public form can be tied to an existing Salesforce record, protected by a secret-code step, and then update that intended record without requiring the visitor to log in.
- Secret-code verification session duration is a basic form setting. Default behavior is the short code window. The optional same-tab mode stores the signed verification token in `sessionStorage`, survives refresh in that tab, expires at the visitor's local midnight, and AWS caps it at 12 hours. V1 should not use `localStorage`, so closing the tab/browser asks for verification again.
- Salesforce Lookup is a Starter/basic input field, not a Pro feature. V1 is single-select, live-search only: no default/preloaded records in the public form, browser sends only `formId`/`publishToken`/`fieldKey`/search text, AWS uses server-stored lookup definitions, and submit writes the selected Salesforce `Id` to the mapped reference field.
- Starter should include a ready-to-use Salesforce registration form story. The lightweight launch version should use Contact create/update plus Campaign Member create/update when Campaigns are used. A richer Pro registration kit can later add optional TwinaForms Event/Registration objects, capacity, waitlist, cancellation/update links, and attendance status.
- The primary create flow should stay lightweight: admins create projects inline from `+ New Form`, and the Designer should filter forms by the selected project.
- Seeded system projects should include `General` for active forms and an empty `Archive` project for later cleanup/organization.
- Formula Fields are a Pro feature. In V1, only `text` and `number` fields can be formula targets, the target field is system-controlled, and any customer-visible runtime formula copy must stay multilingual-safe.
- Post-submit redirect formulas are a Pro feature using the same formula engine and `{fieldKey}` references as Formula Fields. Formula redirect output must be blank or an absolute `http://` / `https://` URL.
- Custom JavaScript should be treated as an advanced Pro feature. If it is exposed in product UI, it must use plan gating, strong warning copy, a `Learn Custom JavaScript` help link, and a documented TwinaForms runtime API instead of relying on unsupported DOM hacks as the official contract.
- The Designer Custom JavaScript modal intentionally uses a simple packaged-safe textarea. Avoid third-party code-editor static resources unless there is a strong launch reason, because they add loading edge cases and security-review surface without changing the runtime/security contract for customer-authored JavaScript.
- Current competitor-parity Pro backlog ordered easiest to most complex is: clone field/section, Salesforce-focused template library, multi-page forms with progress, registration kit, create form from Salesforce page layout, save and resume.
- Create form from Salesforce page layout is a Pro productivity feature gated by `enableProPageLayoutClone`: admins choose an object, AWS uses the stored Salesforce OAuth connection to read the assigned Salesforce page layout via UI API, and TwinaForms creates a draft form from supported layout sections/fields. The form adds prefill by `recordId` and configures submit to update-or-create the same object. V1 should skip read-only/unsupported fields and always use Salesforce Contact/email secret-code verification for secure update flows, regardless of the target object. If the visitor email is not a Salesforce Contact, the visitor cannot edit through secret-code mode; V1 does not attempt generic arbitrary-object identity verification. V1 does not retrieve arbitrary unassigned layout files by Metadata API.
- Sections, Groups, and Records List row layouts support 1 through 10 columns. Keep Designer options, Apex validation, generated HTML CSS, and submission PDF rendering aligned with that range.
- Records List row label mode is a basic prefill/readability setting: admins choose either labels on each row or a table-style header row on desktop. Mobile runtime must always show labels inside each row and hide the desktop header.
- Records List Row Signature + PDF is a Pro feature using `enableProRecordsListRowSignaturePdf` and depends on Electronic Signature plus Submission PDF. Configure it on each Records List; when enabled, Designer must automatically enable and save the form-level Submission PDF setting. Capture `_rowSignature` per submitted row, validate required row signatures before Salesforce writes, render row cards with signatures in the final PDF, and optionally attach each row signature PNG to its saved child row record.
- Survey fields are a Pro feature using `enableProSurveyFields`: designers can add `1-5 star rating`, `NPS 0-10`, `Likert scale`, `ranking`, and `satisfaction scale` presentations that submit simple Salesforce-friendly values. Rating and NPS map cleanly to Number, Likert/satisfaction to Picklist or Text, and ranking to Long Text Area.
- Electronic signature is a Pro feature using `enableProElectronicSignature`: designers add a Signature field, select a target Submit action, and AWS saves the drawn PNG as a Salesforce File attached to that submit target record.
- Submission PDF is a Pro feature using `enableProSubmissionPdf`: designers enable it in Form Settings, choose whether to attach it to a submit target record, and AWS generates a readable PDF with fields, display text, images, and signatures in form order after a successful submit.
- Do not list "attach uploaded files to Salesforce" as a missing Pro feature unless behavior changes; TwinaForms already attaches uploaded files to the Salesforce submit target object.
- `Radio Group` should be treated as a Salesforce-backed picklist presentation, not as a separate free-text option list. `Picklist` and `Radio Group` should use the same Salesforce value source, with only the UI presentation differing.
- `Time` is a simple input field that stores/submits `HH:mm` values. V1 should not use native browser time inputs because locale can force unwanted AM/PM display. Use a TwinaForms-controlled text input with `Time Format`: `24-hour (19:00)` or `12-hour (8:00 PM)`. In 12-hour mode, convert display input to `HH:mm` before submit. Do not add AWS Time normalization or GMT conversion.
- the technical element type remains `repeatGroup`, but customer-facing Builder / setup UI should label it as `Records List`
- `effectiveLimits.maxForms` is enforced in Salesforce Designer against local `NF_Form__c` count. When the limit is reached, block new form creation with a clear upgrade link; if AWS entitlements cannot load, allow creation rather than blocking customers because of temporary connectivity issues.
- Deleting a form is a destructive `Form Settings > Danger Zone` action. It should delete the Salesforce Designer form definition, disable the AWS public runtime first, keep historical submission logs under normal retention, and block delete if runtime disable fails for a published form.

## Escalate When
- A screen feels internal, technical, or debug-oriented instead of customer-ready.
- A product message changes Starter vs Pro scope, onboarding expectations, or upgrade framing without matching the source docs.

## Source Docs
- `AWS/documentation/NativeForms_Product_Plan_Starter_Pro.md`
- `AWS/documentation/Starter_Immediate_List.md`
- `AWS/documentation/Starter_Launch_Remaining_Checklist.md`
- `AWS/documentation/TwinaForms_Home_Redesign_Phase.md`
