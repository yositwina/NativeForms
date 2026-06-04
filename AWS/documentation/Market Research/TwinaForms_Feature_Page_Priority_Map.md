# TwinaForms Feature Page Priority Map

**Status:** Reference / backup strategy. Primary SEO push is use-case pages — see [TwinaForms_Use_Case_Pages_Strategy.md](./TwinaForms_Use_Case_Pages_Strategy.md).
**Owner:** Gil
**Last updated:** 2026-05-28
**Audience:** English-only customers. Hebrew/Israeli market handled separately.

---

## Purpose

Dedicated SEO landing pages per TwinaForms feature, designed for **acquisition** (not docs). Different from `/help/` — these are problem→solution→CTA pages where the "TwinaForms solves this" message repeats 3–5× and every internal link points to homepage or signup, never to docs.

Two versions per feature where the NPSP buyer uses meaningfully different vocabulary or has a distinct pain. Some features get one page only because the NPSP/Regular split would be a find-and-replace clone (duplicate-content risk).

---

## Tiering decision — 2026-05-28

User feedback: features 3, 4, 7, 8 are commodities that every competitor offers. Lead with differentiators; treat commodities as backstop pages built only after use-case pages are live.

### Tier 1 — Build first (genuine differentiators)

| # | Feature | Regular SF angle | NPSP angle | Pages |
|---|---|---|---|---|
| 1 | **Page Layout → Form** | "Turn any Salesforce page layout into a public form in one click" — targets `salesforce form from page layout`, `salesforce object to form builder` | "Turn NPSP page layouts into volunteer-friendly forms — no admin time" — targets `npsp volunteer form`, `npsp intake form` | 2 |
| 2 | **Contact Verification** | "Verify form respondent identity before they see prefilled Salesforce data" — targets `secure salesforce form`, `email otp form`, `verify form user identity` | "Protect donor and household privacy — verify identity before any form access" — targets `secure donor form`, `npsp privacy form`, `verify donor email` | 2 |
| 5 | **Repeated Records** | "Collect multiple line items in one form — timesheets, expenses, products" — targets `salesforce timesheet form`, `salesforce child records form`, `salesforce form multiple rows` | "Log household members or volunteer shifts — one form, many rows" — targets `npsp household form`, `volunteer hours form npsp` | 2 |

**Tier 1 total: 6 pages.** Cross-link as a coherent story: clone layout → verify identity → collect multi-row data.

### Tier 2 — Build after Tier 1 + use cases

| # | Feature | Pages | Why later |
|---|---|---|---|
| 6 | **Conditional Logic** | 1 (Regular only — no NPSP vocabulary split) | Real pain, real searches, but commodity across form builders. |
| 9 | **Submission PDF** | 1 (Regular only — NPSP variant if donor-receipt data warrants it) | Useful differentiator (built-in, no add-on), but moderate search volume. |

**Tier 2 total: 2 pages.** Cumulative: 8 pages.

### Tier 3 — Commodity backstop (build only if Tier 1+2 + use cases are paying off)

User note: "basic features for all competitors, maybe its good to add maybe not, let put them at the end."

| # | Feature | Pages | Reason at the end |
|---|---|---|---|
| 3 | **Prefill** | 1–2 | Every form builder claims prefill. Hard to rank, low differentiation in the H1. |
| 4 | **Submit to Salesforce** | 1–2 | Same — commodity feature claim. |
| 7 | **Signature** | 1–2 | DocuSign etc. own this keyword space. Niche angle (no DocuSign cost) is OK, not great. |
| 8 | **File Uploads (AWS malware-scanned)** | 1 | Malware scanning IS a real differentiator — reconsider promoting if competitor research shows nobody else mentions it. |

**Tier 3 total: 4–7 pages if all built.**

### Skip — do not build standalone pages

These are *feature mentions*, not buyer search queries. Keep them as bullet points within other pages.

- Formula Fields
- Custom JavaScript
- Themes
- Designer Basics
- Survey Fields
- Post-Submit Redirect
- Detailed Submission Logs
- Advanced Prefill / Submit (fold into Prefill / Submit pages if those get built)

---

## Page structure standard (applies to every feature page)

Every Tier 1–3 page follows the same skeleton:

1. **H1** matching the primary search query exactly (or a close variant)
2. **Subhead** with the value prop in one sentence
3. **Hero CTA** — "Install in sandbox" (or whichever single CTA is canonical — see open questions)
4. **The problem section** — current pain (without TwinaForms)
5. **The solution section** — how TwinaForms solves it, with screenshot
6. **Feature mechanics** — 2–4 sub-sections explaining how it actually works
7. **FAQ block** — 4–6 Q/A (use `FAQPage` schema for SERP snippets)
8. **Closing CTA** — same as hero
9. **Footer cross-links** — to homepage and to 2 other Tier 1 pages in this map. **Never to /help/.**

CTA repeats: hero, end of solution section, end of page = 3× minimum.

---

## URL structure

```
/solutions/salesforce/<verb-phrase>/    e.g. /solutions/salesforce/verify-form-respondent-identity/
/solutions/npsp/<verb-phrase>/          e.g. /solutions/npsp/verify-donor-identity/
```

- `/solutions/` matches buyer search intent ("salesforce form solutions")
- Product segment (`salesforce` / `npsp`) in the path signals audience to Google
- Verb-phrase slugs match how people search ("verify X" not "user-verification")
- Scales later: `/solutions/health-cloud/`, `/solutions/education-cloud/`

---

## Open questions (decide before drafting)

1. **Canonical CTA** — "Install in sandbox", "Email us", or new "Start free" path? Pick one and repeat it everywhere.
2. **Brand consistency** — all new pages TwinaForms-only (no NativeForms residue), confirm.
3. **Duplicate-content guardrail** — for NPSP variants, every page must have distinct H1, distinct screenshots, distinct vocabulary, distinct FAQ. No find-and-replace.
