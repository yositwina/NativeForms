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
- If a form element already has a configurable label, prefer no extra fixed helper headline. File upload and secret-code experiences should be structurally clear without relying on English-only filler text.
- Customer-visible button labels that appear in published forms should be configurable where practical, not hard-coded in English by default.
- Multi-form organization should use a first-class `Project` model above forms, not tags or reused categories.
- The primary create flow should stay lightweight: admins create projects inline from `+ New Form`, and the Designer should filter forms by the selected project.
- Seeded system projects should include `General` for active forms and an empty `Archive` project for later cleanup/organization.
- Formula Fields are a Pro feature. In V1, only `text` and `number` fields can be formula targets, the target field is system-controlled, and any customer-visible runtime formula copy must stay multilingual-safe.
- `Radio Group` should be treated as a Salesforce-backed picklist presentation, not as a separate free-text option list. `Picklist` and `Radio Group` should use the same Salesforce value source, with only the UI presentation differing.
- the technical element type remains `repeatGroup`, but customer-facing Builder / setup UI should label it as `Records List`

## Escalate When
- A screen feels internal, technical, or debug-oriented instead of customer-ready.
- A product message changes Starter vs Pro scope, onboarding expectations, or upgrade framing without matching the source docs.

## Source Docs
- `AWS/documentation/NativeForms_Product_Plan_Starter_Pro.md`
- `AWS/documentation/Starter_Immediate_List.md`
- `AWS/documentation/Starter_Launch_Remaining_Checklist.md`
- `AWS/documentation/TwinaForms_Home_Redesign_Phase.md`
