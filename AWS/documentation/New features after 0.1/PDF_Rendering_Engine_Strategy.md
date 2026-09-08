# PDF Rendering Engine Strategy

**Status:** Implemented decision (HTML→Chromium renderer deployed)
**Area:** Submission PDF generator (AWS) — engine choice for all PDF output
**Author note:** Backed by two hands-on spikes (June 2026). Supersedes the earlier "build on pdfmake" lean.

---

## 1. Why this decision exists

The product needs **nicer PDFs** — warranty certificates, registration/summary confirmations — with
**colors, themes, fonts, logo, and real tables**. The current generator uses **PDFKit** (coordinate-based,
hand-drawn), which makes tables/theming hard. The product is **Hebrew-first** (RTL), and PDF generation
runs **on AWS** (post-submit, async). Most coding is **AI-assisted**, so an engine that's easy to author
and maintain matters. Extra AWS infrastructure (cost) is acceptable.

Candidates evaluated: **PDFKit** (current), **pdfmake**, **HTML→headless Chromium**.

---

## 2. Spikes & evidence (decisive)

Two real spikes rendering the **same** warranty/confirmation doc (logo + theme + tables + Hebrew), with a
bundled Hebrew font. Demo files: `C:\Users\Yosi\pdfmake-demo\`.

### Spike A — pdfmake (`twinaforms-pdfmake-demo.pdf`, `raw-segoe.pdf`)
- ✅ Look is good (logo, theme colors, bold font, bordered tables).
- ✅ Latin/numbers/dates/email correct.
- ❌ **Hebrew RTL is broken** — title "תעודת אחריות" rendered "אחריותתעודת"; multi-line paragraphs
  word-reversed; spaces collapse. **A `bidi-js` helper did not fix it.**
- **Root cause (structural):** pdfmake runs its **own line-layout** engine, bypassing the bidi PDFKit
  would otherwise do. A helper can reorder a single string, but pdfmake **wraps paragraphs after** the
  helper runs, and bidi must be applied per *visual* line *after* wrapping → multi-line Hebrew can't be
  reliably pre-processed.
- **Also confirmed:** the current **PDFKit** production code renders Hebrew **correctly** (the
  submitted-response PDF proves it) — so moving to pdfmake would *regress* working Hebrew.

### Spike B — HTML→Chromium (`twinaforms-html-chromium.pdf`) — Puppeteer + bundled Segoe UI font
- ✅ **Hebrew perfect** — title, multi-line wrapped paragraphs, RTL table column order — all correct,
  written in **plain logical order with zero helper code** (the browser does Unicode bidi).
- ✅ **Look excellent** — CSS theme/colors, real bold, clean tables, crisp logo; matches the target bar.
- ✅ **Smaller output** (189 KB vs 2.4 MB — Chromium re-encoded the logo).
- ⚠️ One cosmetic nit (footer colon/email boundary) — trivially fixable in CSS.

**Verdict: HTML→Chromium does *both* "nice look" and "correct Hebrew" with the least code.**

---

## 3. Decision

**Migrate the PDF generator to HTML→PDF via headless Chromium.** Reject pdfmake (structural Hebrew
failure). Keep PDFKit only until Chromium reaches parity, then retire it.

| Engine | Look | Hebrew RTL | Build/maintain (AI) | Footprint/ops | Verdict |
|---|---|---|---|---|---|
| PDFKit (current) | ⚠️ manual | ✅ works | ⚠️ coordinate math | ✅ tiny | Interim only |
| pdfmake | ✅ | ❌ broken | ✅ | ✅ tiny | **Rejected** |
| **HTML→Chromium** | ✅✅ | ✅✅ | ✅✅ | ⚠️ heavy (acceptable) | **Chosen** |

---

## 4. Pros / Cons of the chosen approach

**Pros**
- Perfect Hebrew/RTL bidi for free (browser engine).
- Best-in-class look; CSS themes/tables/logos; can reuse the web form's CSS for consistency.
- Most AI-/maintenance-friendly (HTML/CSS edits vs. coordinate math).
- The **PDF Theme** feature becomes trivial (theme tokens → CSS variables); the **PDF Table** feature
  becomes trivial (HTML `<table>`).

**Cons (all acceptable given infra budget + async generation)**
- Chromium is heavy (~50–60 MB) → use a **container-image Lambda** (or a Lambda layer).
- Cold start adds ~1–3s → **neutralized** because PDF generation is post-submit/async, off the user's path.
- Higher memory/cost per invocation (fine at our scale; infra cost accepted).
- **Must bundle Hebrew fonts** (Chromium has no system fonts in Lambda) — ship full Noto Sans Hebrew (or
  similar) via `@font-face` / in the image.
- Ops: Chromium needs periodic security patching; add a retry for rare browser crashes.
- **Security:** when rendering **author-supplied HTML** (Display Text / Merged Document), sanitize it
  (see [[HTML_Source_Toggle_for_Display_Text]]) and run the browser locked down (no network, controlled JS).

---

## 5. Architecture (AWS)

- **Container-image Lambda** running `@sparticuz/chromium` + Puppeteer, with **bundled Hebrew fonts**.
  (Alternative: a **Gotenberg** service on ECS/Fargate if PDF volume later warrants an always-warm,
  isolated renderer — the Lambda would just POST HTML.)
- Render flow: build the document **HTML (logical-order Hebrew, `dir="rtl"`, CSS theme)** → Chromium
  `page.pdf({ printBackground:true })` → upload buffer to S3 (same as today).
- **Templating:** an HTML template per document type; theme = CSS variables driven by the PDF theme tokens.
- Run Chromium with `--no-sandbox` equivalents appropriate for Lambda; disable remote resource loading;
  embed assets (logo/fonts) as data/bundled to avoid network.

---

## 6. Migration plan (parallel + flag)

1. **New Chromium renderer in parallel**, behind a **per-tenant flag** (server-side in the Submit Lambda).
2. **Freeze PDFKit** — no new features in it.
3. **Build the PDF Table and PDF Theme features ONLY on the Chromium/HTML renderer** (not PDFKit, not
   pdfmake). See [[PDF_Repeat_Group_Table_Rendering]] and [[PDF_Theme_Tab]].
4. **Reach parity** then flip default → bake → **delete PDFKit**. Parity/QA checklist:
   - Hebrew/RTL (paragraphs, tables, mixed numbers) — the headline win.
   - Bundled fonts render (no missing glyphs).
   - Repeat-group tables, row **signatures** (images), merged-doc/display-text (sanitized), images, header
     (title/IP/UA), multi-page tables with repeating headers, page numbers.
   - Output size/perf; cold-start behavior acceptable for async generation.

---

## 7. Open questions
- Container-image Lambda vs. Gotenberg service — start with container Lambda; revisit if volume grows.
- Which Hebrew font to bundle (Noto Sans Hebrew full vs. a licensed nicer face).
- Confirm the author-HTML sanitization boundary before enabling merged-doc/display-text in the browser.
- Per-tenant flag rollout order (internal/test tenants first).

---

## 8. Spike reproduction (for reference)
The **winning Chromium spike is saved in the repo**: [`pdf-chromium-spike/`](pdf-chromium-spike/README.md)
(`html-full.cjs` + `raster3.mjs` + README) — the seed for the production renderer. Fonts: bundled Segoe UI
in the demo; **production must bundle a licensed/open Hebrew font** in the renderer image. (The original
scratch project with the pdfmake comparison lives at `C:\Users\Yosi\pdfmake-demo\`.)
