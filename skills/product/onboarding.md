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

## Escalate When
- A screen feels internal, technical, or debug-oriented instead of customer-ready.
- A product message changes Starter vs Pro scope, onboarding expectations, or upgrade framing without matching the source docs.

## Source Docs
- `AWS/documentation/NativeForms_Product_Plan_Starter_Pro.md`
- `AWS/documentation/Starter_Immediate_List.md`
- `AWS/documentation/Starter_Launch_Remaining_Checklist.md`
- `AWS/documentation/TwinaForms_Home_Redesign_Phase.md`
