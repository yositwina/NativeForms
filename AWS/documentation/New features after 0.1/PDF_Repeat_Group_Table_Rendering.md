# PDF: Render Repeated/Related Records as a Real Table

**Status:** Implemented (Chromium renderer and PDF schema deployed)
**Area:** Submission PDF generator (new **HTML→Chromium** renderer) + Submission-PDF schema (`NativeFormsPublisher.cls`)
**Author note:** Targeted for a release after 0.1. Affects the generated "Submitted Response" PDF only.

> **ENGINE: build on HTML→Chromium.** Per [[PDF_Rendering_Engine_Strategy]] (backed by two spikes), the PDF
> generator is moving to **HTML→headless Chromium**. On Chromium this feature is essentially an HTML
> `<table>` + CSS — correct Hebrew/RTL for free, no manual geometry. A working demo of exactly this table
> exists: `C:\Users\Yosi\pdfmake-demo\twinaforms-pdf-chromium-full.pdf` (`html-full.cjs`).

---

## 1. What this is

The submission PDF renders **Repeated Records** (e.g. the *שעות נוכחות* / attendance-hours block) as a
**stack of cards** — one card per row, with **every field label repeated on each row**. Three enhancements,
all on the repeated-records block:

1. **Do not repeat the column headings on every row** — show the labels once, as a header row.
2. **Render it as a real table** — a single separator line between rows, not a boxed card per row.
3. **Make the table lines bolder.**

On the HTML→Chromium renderer these are one small thing: a themed HTML `<table>` with a single header row
and CSS borders. (Confirmed in the demo — see the *שעות נוכחות* table.)

---

## 2. Gating it on the existing toggle (decided)

Table mode **follows the existing `showLabelsOnEachRow` toggle** (default `true`):
- `showLabelsOnEachRow === false` → render the **table** (header once, value rows, separators) — matching
  what the *web form* already does (`NativeFormsPublisher.cls:2438-2446`).
- `true` → keep label-per-row behaviour.

The toggle already exists in the designer (`nativeFormsDesigner.js:6178,6610`) and flows to the web form,
**but is not currently emitted into the submission-PDF schema** (`NativeFormsPublisher.cls:3748-3764` puts
`columns/showTitle/boxed/text/rowSignature` — not this). So one small Apex change is required to pass the
flag through; the rest is renderer/HTML.

---

## 3. Implementation (HTML/CSS)

1. **Apex (schema passthrough):** add `showLabelsOnEachRow` to the `repeatGroup` item in
   `buildSubmissionPdfSchema` (`NativeFormsPublisher.cls:3748-3764`).
2. **Chromium renderer (HTML):** when `showLabelsOnEachRow === false`, emit the repeat group as:
   - one `<thead>` row of column labels (drawn once),
   - one `<tbody>` `<tr>` per submitted row (values only),
   - CSS borders for separators; **per-row signatures** as an `<img>`/inline SVG in a cell.
3. **The three asks become CSS** (from the working demo):
   ```css
   thead th { background: var(--head); color: var(--primary); font-weight:700;
              border-bottom: 2px solid var(--line-strong); }   /* header once, bold */
   tbody td { border-bottom: 1px solid var(--line); }          /* single line between rows */
   tbody tr:last-child td { border-bottom: 2px solid var(--line-strong); } /* bolder edge */
   ```
   "Bolder lines" = the `--line` / `--line-strong` weights; both come from the PDF theme (see
   [[PDF_Theme_Tab]]). Multi-page tables repeat the `<thead>` automatically.

---

## 4. Complexity

| Part | Complexity | Notes |
|---|---|---|
| Apex: emit `showLabelsOnEachRow` into the PDF schema | **Low** | One field in `buildSubmissionPdfSchema`. |
| HTML table (header once, separators, bolder lines, signatures) | **Low** | Native `<table>` + CSS; RTL correct for free. |
| **Overall** | **Low** | On Chromium this is HTML + CSS, not manual geometry. The whole table (incl. per-row signatures + theme + Hebrew) is already proven in the demo. |

**One-line answer:** Low — gate on the existing `showLabelsOnEachRow` toggle (one Apex passthrough) and
render an HTML `<table>` with themed CSS borders; Hebrew/RTL, multi-page header repeat, and per-row
signatures all come for free in the browser.

---

## 5. Design decisions
- **Table vs. always-table — DECIDED:** render the table when `showLabelsOnEachRow === false`; otherwise
  keep label-per-row. No new toggle.
- **`boxed`** (already on the container) can map to "outer table border" vs. "rule-only".
- **Line weights / colors** come from the PDF theme tokens → CSS variables ([[PDF_Theme_Tab]]).
- **Per-row signatures** render as an image cell in the row (demonstrated in the demo).

---

## 6. How to deploy

> AWS (Chromium renderer) + the Salesforce package (schema). Org alias: **TwinaFormsDevHub**.

### 6a. Components changed
- **AWS Chromium PDF renderer** — emit the repeat group as an HTML `<table>` in table mode. Deployed via
  the PDF renderer pipeline (see [[PDF_Rendering_Engine_Strategy]] §5).
- `force-app/main/default/classes/NativeFormsPublisher.cls` (+ `NativeFormsPublisherTest.cls`) — add
  `showLabelsOnEachRow` to the repeatGroup PDF schema item.

### 6b. IMPORTANT — re-publish affected forms
The submission-PDF **schema** is baked at publish time. The `showLabelsOnEachRow` flag only reaches a form
after it is **re-published**. The renderer change applies to new submissions immediately, but reads the new
flag only for re-published forms.

### 6c. Smoke test
1. Repeated Records block with **labels-per-row OFF** → re-publish → submit → confirm **one header row**,
   values-only rows, **single line between rows**, **bolder** header/edges.
2. Long description → confirm the row grows and the table stays aligned (browser handles it).
3. Many rows spanning a page → confirm the **header repeats** on the new page (`<thead>` auto-repeat).
4. Hebrew/RTL → confirm column order and text are correct (free in the browser).
5. Block with **row signatures** → confirm the signature image renders in each row.

---

## 7. Open questions
- Map `boxed` → outer border vs. rule-only?
- Totals/footer row in the table (sum of hours, etc.) — include now or later?
