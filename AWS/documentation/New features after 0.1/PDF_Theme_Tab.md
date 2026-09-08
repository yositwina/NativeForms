# PDF Theme Tab (Phase 1 — colors, sizes, spacing)

**Status:** Proposed (not built)
**Area:** Designer LWC (new theme tab) + Submission-PDF config (`NativeFormsPublisher.cls`) + **HTML→Chromium** PDF renderer
**Author note:** Targeted for a release after 0.1. **Phase 1 only** — font *selection* is out of scope (see §6).

> **ENGINE: build on HTML→Chromium.** Per [[PDF_Rendering_Engine_Strategy]] (backed by two spikes), the PDF
> generator is moving to **HTML→headless Chromium**. Theming becomes trivial: theme tokens → **CSS
> variables** in one stylesheet, with correct Hebrew for free. A demo applying a CSS-variable theme exists:
> `C:\Users\Yosi\pdfmake-demo\twinaforms-pdf-chromium-full.pdf` (`html-full.cjs`, see the `:root{--primary…}` block).

---

## 1. What this is

A new **"PDF Theme"** tab in the designer where the author creates **standalone, reusable, named PDF
themes** — a set of style tokens (colors, sizes, spacing, line weight, optional logo). A theme is
**assigned to a form** via the existing **"add PDF"** feature (a **theme picker** next to it). At publish,
the selected theme's tokens are baked into the submission-PDF config; the Chromium renderer applies them as
**CSS variables** on the document.

### Theme model (decided)
- **Completely separate from the web-form theme** — no derivation, no link.
- **Reusable named themes** (a small library); different forms can use different themes.
- **Assigned per form, in the designer**, via a picker next to "add PDF".
- **AWS receives only the resolved token values** for the form being published — no theme-library concept.

**Phase 1 scope (style tokens only):** colors (body, headings, muted, table border / `--line-strong`,
accent), type **scale** (sizes), table **line weight**, spacing (page margins, section gaps), optional
**header logo**. **Not in Phase 1:** choosing the font *family* (§6).

---

## 2. Why this is easy on Chromium

The PDF is HTML+CSS, so a "theme" is just a set of **CSS custom properties** the template reads:

```css
:root{
  --primary:#0B5394; --accent:#1F7A4D; --ink:#14304A; --muted:#5B7185;
  --line:#9FB6CC; --line-strong:#5B7185; --head:#EAF1F8;
  --base-size:11pt; --page-margin:14mm;
}
```

Theme tokens map **1:1** onto these variables. Swapping a theme = swapping the values of one `:root` block.
The same variables drive the repeat **table** borders/weights ([[PDF_Repeat_Group_Table_Rendering]]), so
the two features share one theme system.

---

## 3. Implementation

1. **Designer — theme library:** new "PDF Theme" tab to create/edit/list named themes (color pickers,
   numeric size/spacing/line-weight inputs, optional logo). A built-in **"Default" theme = current look**,
   so existing PDFs are unchanged until a theme is assigned.
2. **Designer — per-form assignment:** the **"add PDF"** area gains a **"PDF theme" picker**; the selection
   is stored on the form/version (a theme reference).
3. **Storage:** named themes need a home — a new custom object (e.g. `NF_Pdf_Theme__c`) or settings store,
   plus a theme-reference field on the form/version.
4. **Publisher:** at publish, **resolve the assigned theme** and bake its tokens into
   `buildSubmissionPdfConfig` (`NativeFormsPublisher.cls:3700`). **Validate** here (hex colors, numeric
   ranges, allowlisted logo URL).
5. **Chromium renderer:** inject the resolved tokens as the document's `:root` CSS variables. No other
   render code changes — the template already reads the variables.

---

## 4. Complexity

| Part | Complexity | Notes |
|---|---|---|
| Designer "PDF Theme" tab — create/edit/list named themes | **Medium** | Theme-editor UI + manage a small library (CRUD). |
| Theme storage + per-form picker | **Low–Medium** | New `NF_Pdf_Theme__c` (or settings) + theme reference + picker by "add PDF". |
| Publisher: resolve theme → emit + validate tokens | **Low** | Resolve reference, bake tokens; validate hex/ranges/logo. |
| Chromium renderer: tokens → `:root` CSS variables | **Low** | Inject one CSS block; template already reads it. |
| **Overall** | **Low–Medium** | The reusable named-theme library + picker is the bulk; rendering is just CSS variables. |

**One-line answer:** Low–Medium — themes are CSS variables, so the renderer side is trivial; the work is
the designer's named-theme library + per-form picker + a small storage object.

---

## 5. Security
- Validate every token at publish time: hex-format colors, numeric values clamped to sane ranges, and (if a
  header logo is allowed) an **allowlisted** image URL. A malformed theme must not break the render.
- The renderer already runs locked-down for author HTML (see [[PDF_Rendering_Engine_Strategy]] §4) — theme
  tokens are injected as CSS values, not arbitrary CSS, so no style-injection surface.

## 6. Font selection is NOT supported (Phase 1)
Choosing a **font family** is out of scope for Phase 1. On Chromium, fonts must be **bundled in the
renderer image** (Chromium has no system fonts in Lambda; Hebrew especially must be bundled — see
[[PDF_Rendering_Engine_Strategy]] §4). Phase 1 ships a single bundled, Hebrew-capable family and the theme
controls **type *scale*** (sizes), not the family.

A **Phase 2** could offer font *selection from a curated, Hebrew-capable, bundled set* (each added to the
renderer image). Free-form font upload is not planned.

> UX note: do not show a "Font family" dropdown in Phase 1 — size/scale controls only.

---

## 7. How to deploy

> AWS (Chromium renderer) + the Salesforce package. Org alias: **TwinaFormsDevHub**.

### 7a. Components changed
- `force-app/main/default/lwc/nativeFormsDesigner/*` — the "PDF Theme" tab + per-form picker.
- New `NF_Pdf_Theme__c` (or settings store) + theme-reference field on the form/version.
- `force-app/main/default/classes/NativeFormsPublisher.cls` (+ test) — resolve + validate + emit `pdfTheme`
  tokens in `buildSubmissionPdfConfig`.
- **AWS Chromium PDF renderer** — inject tokens as `:root` CSS variables.

### 7b. IMPORTANT — re-publish affected forms
`pdfTheme` tokens are baked into the submission-PDF config at **publish time**. A form must be
**re-published** for its theme to reach AWS; until then the renderer uses the default theme.

### 7c. Smoke test
1. Create a theme (heading color, body color, table line color + weight, base size), assign it to a form,
   re-publish, submit → confirm the PDF reflects the theme.
2. Assign a **different** theme to another form → confirm each PDF differs.
3. Default (untouched) → confirm the PDF matches the current look.
4. Hebrew/RTL form → confirm theming applies and text renders correctly.
5. Invalid value (bad hex) → confirm publish-time validation rejects/normalizes it.

---

## 8. Decisions & open questions
**Decided:** separate from web-form theme; reusable named themes; per-form picker by "add PDF"; tokens →
CSS variables; no font-family selection in Phase 1.

**Open:**
- Storage shape: dedicated `NF_Pdf_Theme__c` vs. existing settings store.
- Ship a few starter themes, or start with "Default" only?
- Header logo: reuse the form's logo asset, or a separate per-theme logo?
- Pro-tier gating for theme management?
- Which Hebrew-capable family to bundle as the Phase-1 default.
