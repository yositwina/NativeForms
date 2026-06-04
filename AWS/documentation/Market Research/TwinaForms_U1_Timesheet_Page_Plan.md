# U1 — Salesforce Timesheet Form (Page Plan)

**Page URL:** `/solutions/salesforce/timesheet-form/`
**Status:** Plan — awaiting screenshot from Gil and CTA decision before drafting HTML.
**Owner:** Gil
**Last updated:** 2026-05-28
**Parent strategy:** [TwinaForms_Use_Case_Pages_Strategy.md](./TwinaForms_Use_Case_Pages_Strategy.md)

---

## SEO target

| Element | Value |
|---|---|
| **Primary keyword** | `salesforce timesheet form` |
| **Secondary keywords** | `salesforce time tracking form`, `salesforce contractor hours form`, `weekly timesheet salesforce`, `track billable hours salesforce`, `signed timesheet salesforce` |
| **Long-tail** | `how to track contractor hours in salesforce without spreadsheets`, `salesforce timesheet with signature`, `salesforce timesheet form for consultants` |
| **Search intent** | Solution-aware: searcher knows they need a timesheet, looking for a Salesforce-connected way to do it |
| **Buyer persona** | Salesforce admin at a consultancy/agency/contractor shop; ops manager at services firm; nonprofit admin tracking grant-funded hours |
| **SERP competition** | Mostly generic Salesforce blog posts ("how to build a timesheet object") and AppExchange listings — beatable with a real, focused product page |

---

## SEO principle — lead with the problem, not the feature

The H1 must contain the keyword + name the pain in plain language. This serves both:
- **Google ranking** — exact-match keyword in H1 still matters; pain words signal relevance to long-tail queries
- **Reader conversion** — the searcher reads the first 5 words and decides whether to stay

**Recommended H1:**
> Salesforce Timesheet Form — stop tracking contractor hours in spreadsheets

**Recommended meta title (≤60 chars):**
> Salesforce Timesheet Form — Signed PDF, Auto-Logged | TwinaForms

**Recommended meta description (≤155 chars):**
> Collect signed weekly timesheets straight into Salesforce. Multiple time entries per submission, auto-generated PDF receipt, no spreadsheets, no rekey.

---

## Buyer pain (the problem section content)

Lead with these pains in the order a reader would feel them — operational first, then risk, then cost:

1. **Manual rekey** — contractors send hours by email, spreadsheet, or Slack. Admin types them into Salesforce. Hours of weekly busywork.
2. **No audit trail** — billing dispute hits and there's no signed copy of what the contractor claimed.
3. **Spreadsheet sprawl** — every contractor has their own template. Totals don't match. Currency, time format, project codes drift.
4. **Approval bottleneck** — manager approves over Slack/email, nothing logged.
5. **Payroll/billing handoff** — finance asks for signed PDFs; admin generates them manually from raw data.

All five are solved by combining four TwinaForms features in one form.

---

## Solution — features combined

| TwinaForms feature | Role on this page | Where it appears |
|---|---|---|
| **Repeated Records** | Multiple time entries per submission (Mon–Fri rows) | Lead feature — first sub-section after problem |
| **Prefill** | Contractor name, project list, billing rate prefilled from URL/session | Mentioned as friction-killer |
| **Submit to Salesforce** | Each row writes a Timesheet Entry record; header writes a Timesheet record | Mentioned as Salesforce-native proof point |
| **Submission PDF + Signature** | Contractor signs at the bottom; PDF auto-attached to Salesforce record | **Hero differentiator** — the "signed PDF" angle goes in the H1 and meta |

The PDF + Signature combo is what distinguishes this page from a generic "build a timesheet object" tutorial. It's the reason the page wins on `signed timesheet salesforce` queries.

---

## Page structure (section-by-section)

### 1. Hero
- **H1:** Salesforce Timesheet Form — stop tracking contractor hours in spreadsheets
- **Subhead:** Collect signed weekly timesheets directly into Salesforce. Multiple rows per submission, auto-generated PDF, every entry on the right record.
- **Hero CTA:** (canonical CTA — pending decision)
- **Trust pills:** Native to Salesforce · Signed PDF on every submission · No spreadsheets

### 2. The problem (3–5 short paragraphs)
Five bullets above, expanded to one short paragraph each. Use the exact phrases real admins use: "spreadsheet sprawl", "billing dispute", "rekey hours", "signed timesheet".

### 3. The solution — with the example screenshot
- **H2:** One form, one PDF, every hour on the right Salesforce record
- **Image:** Real TwinaForms timesheet form screenshot (Gil to provide)
  - **Image alt text:** "TwinaForms Salesforce timesheet form with weekly time entries and signature"
  - **Caption underneath:** "A real TwinaForms timesheet form — week view, project lookup per row, signature at the bottom, submits straight to Salesforce."
- 2–3 sentences explaining what the reader is looking at

### 4. Feature mechanics — 4 sub-sections, each with one screenshot or diagram

#### 4a. Multiple time entries per submission (Repeated Records)
- How the row-table works
- Day-by-day or per-task row entry
- Auto-totals at the bottom
- Each row writes a separate Salesforce record

#### 4b. Prefill what we already know (Prefill)
- Contractor identified by URL token or session
- Project picklist filtered to their assignments
- Billing rate auto-loaded from their Contact record
- "They only enter what changes — hours and notes"

#### 4c. Signed PDF, automatically (Submission PDF + Signature)
- Signature field at form bottom
- On submit, TwinaForms generates a PDF receipt — same fields, same signature
- PDF attached as Salesforce File on the Timesheet record
- "Payroll/finance never asks 'can you send me a signed copy?' again"

#### 4d. Native to Salesforce (Submit)
- Form designed inside Salesforce
- Each submission writes records to your Timesheet + Timesheet Entry custom objects (or any objects you point it at)
- Approvals, reports, dashboards work out of the box because the data is in Salesforce

### 5. FAQ block (use FAQPage JSON-LD schema)

Targets long-tail "people also ask" queries. Recommended 5–6 Q/A:

- **Q:** Can the contractor add their own rows for different projects in one week?
  **A:** Yes — the Repeated Records feature lets the contractor add as many rows as they need in a single submission, each writing a separate Salesforce record.
- **Q:** Does the signature legally count?
  **A:** TwinaForms captures a drawn signature and embeds it in the auto-generated PDF, attached to the Salesforce record on submit. Combined with TwinaForms' identity verification, this gives you a defensible audit trail. (Consult your legal team for jurisdiction-specific e-signature requirements.)
- **Q:** Do I need a custom Timesheet object?
  **A:** TwinaForms writes to any standard or custom Salesforce object — you can use existing objects or create new ones in minutes.
- **Q:** Can the contractor's manager approve before it lands in Salesforce?
  **A:** Submissions can route through Salesforce Approval Processes once they hit the record. (Pre-submission approvals are a future feature.)
- **Q:** How is this different from a Salesforce Flow screen flow for timesheets?
  **A:** Screen flows require a Salesforce license per user. TwinaForms timesheet forms are public — contractors submit without a Salesforce login. The PDF receipt and signature are also not standard Flow capabilities.
- **Q:** Does it work with NPSP for tracking volunteer hours?
  **A:** Yes — see our [NPSP Volunteer Signup Form](/solutions/npsp/volunteer-signup-form/) for the nonprofit-specific version. *(internal cross-link to U2)*

### 6. Closing CTA section
- Restated value prop in one sentence
- Same canonical CTA as hero
- Single sentence: "Or email supportat@twinaforms.com to walk through your timesheet setup."

### 7. Footer cross-links
- → Homepage
- → [Page Layout → Form](/solutions/salesforce/...) (Tier 1 feature page when built)
- → [Contact Verification](/solutions/salesforce/...) (Tier 1 feature page when built)
- **Do NOT link to /help/.**

---

## CTA strategy

**Three placements minimum**, same CTA each time:
1. **Hero** (above fold)
2. **End of solution section** (after the screenshot and the "this is what it looks like" paragraph — the warmest conversion moment)
3. **Closing section** (last thing on the page)

CTA copy depends on the canonical CTA decision (open question in the priority map). My recommendation: **"Install in sandbox — free"** matches the homepage and removes the "what does it cost" hesitation in the same click.

---

## Schema markup to include

- `BreadcrumbList` — Home › Solutions › Salesforce › Timesheet Form
- `FAQPage` — wrap the FAQ block (eligible for SERP "people also ask" feature)
- `SoftwareApplication` — already on homepage, reference via `@id` if you want to avoid duplication
- `HowTo` — *optional* — if you decide to add a brief "How to build a Salesforce timesheet form with TwinaForms" steps section, this unlocks rich snippets. Worth considering.

---

## Image / screenshot spec (for Gil)

The page needs **one hero screenshot + ideally four supporting screenshots** (one per feature sub-section). At minimum, the hero screenshot.

**Hero screenshot requirements:**
- A real TwinaForms timesheet form, week-view layout
- Visible elements: project lookup column, hours-per-day columns (or task rows), running total, signature pad at the bottom
- 1600×900 or 1920×1080 PNG/WebP — high DPI, no blur on retina
- Light theme (matches the rest of the marketing site)
- Mask or use fake contractor name, project names, client name — no real client data

**Supporting screenshots (nice to have, in order of value):**
1. Close-up of the repeated-row mechanic — adding a row, totals updating
2. Close-up of the signature pad area
3. Sample of the auto-generated PDF receipt
4. Salesforce record screen showing the submitted Timesheet + Timesheet Entry records

If only one is provided, the hero shot is mandatory and everything else is a stylized SVG illustration or a generic feature graphic.

---

## What I need from Gil before drafting HTML

1. **Hero screenshot** of the real timesheet form (per spec above)
2. **CTA decision** — `Install in sandbox`, `Email us`, or new `Start free`? (Open question from priority map — applies to all pages, not just this one)
3. **Sandbox install link confirmation** — current homepage uses `https://test.salesforce.com/packaging/installPackage.apexp?p0=04tgL000000GFEPQA4` — confirm same link applies for new pages
4. **Confirm URL slug** — `/solutions/salesforce/timesheet-form/` vs. alternative
5. **Brand check** — page should be TwinaForms-only (no NativeForms residue), confirm

---

## Open questions

- Should the page include a price callout (e.g., "Pro plan, $200/mo, nonprofit discount") or stay price-silent and route price questions to `/#plans`? *Recommendation: price-silent, link to `/#plans` from the FAQ "how much does this cost" entry if added.*
- Should the FAQ include a competitor comparison line (e.g., "vs. Form Assembly")? *Recommendation: no — keep the page about the problem, not the comparison. Comparison pages are a separate SEO play.*
- Do we have a customer using TwinaForms for timesheets that would let us quote them? Even a one-line testimonial lifts conversion noticeably.

---

## Success metrics (track from launch)

- **Google Search Console:** impressions and avg. position for `salesforce timesheet form` (90-day moving avg)
- **Cloudflare Analytics:** page sessions, time on page, scroll depth
- **CTA click-through rate** on each of the 3 CTA placements
- **Trial signups / sandbox installs** attributed to this landing page (via UTM on the CTA link)

**Target:** rank top-10 for `salesforce timesheet form` within 90 days; 5+ qualified trial signups/month from this page within 6 months.
