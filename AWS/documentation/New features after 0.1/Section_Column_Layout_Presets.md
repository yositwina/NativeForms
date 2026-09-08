# Section & Records List: Column Layout Presets

**Status:** Implemented (DevHub and Chromium PDF renderer deployed)
**Area:** Designer LWC (section / group / repeatGroup property panel) + Publisher (grid CSS)
**Related:** unblocks [Layout → Form: Related Records Table](Layout_to_Form_Related_Records_Table.md) fidelity work (see §9)

---

## 1. What the feature is

Today every multi-column container renders **equal-width columns**. This adds a small, named set of
**uneven column layouts** the author picks from a thumbnail list — `Equal`, `Wide first`, `N W N`, and so on
— for sections, groups and Records Lists.

It is deliberately **not** per-field width configuration (the FormTitan / FormAssembly model). See §2.

**Example:** a Records List row with `Date | Hours | Notes`. Equal thirds squeezes the date column until
`20/05/2026` truncates to `20/05`. With `N N W` the notes column absorbs the extra space and the date fits.

---

## 2. Key decisions (and why)

| Decision | Rationale |
|---|---|
| **Presets, not per-field widths** | Per-field width makes every field a decision, forever — the consultant-led workflow TwinaForms is positioned against. Presets keep the "no consultant" promise while removing the real pain. |
| **Named by *order*, not by side** | `left narrow / right wide` is **wrong on RTL forms** — CSS grid columns flow along the inline axis, so column 1 renders on the *right* in Hebrew. Use `Narrow first` / `Wide first`; one `grid-template-columns` string is then correct in both directions with no branching. |
| **Ratio is 1:2, not 1:3** | 1:3 puts a narrow column right back into the truncated-date problem this feature exists to solve. `1fr` vs `2fr` is visibly uneven while keeping the narrow column usable for a date or short number. |
| **Column count stays its own control** | The layout picker *modifies* the existing count picker rather than replacing it. Otherwise choosing a layout silently changes the column count — two controls fighting over one value. |
| **Applies to Records Lists too** | This is where the need is sharpest; repeat groups already share the same column machinery. |
| **Generated CSS class, not inline `style`** | Inline `style` attributes require `style-src 'unsafe-inline'`, which works against the Cloudflare CSP hardening and shows up in ZAP reports. Emit a rule into the existing `<style>` block instead. |
| **`Equal` is the default** | Every existing form renders byte-identically until an author opts in. No migration. |

**Explicitly out of scope:** per-field widths, px/% units, drag-to-resize handles. Presets compile to the
same `grid-template-columns` string those would produce, so none of this is wasted if they are added later.

---

## 3. UX

A second picker in the section / group / Records List property panel, directly under the existing
**Columns** count picker. Its options depend on the chosen count:

| Columns | Layout options | `grid-template-columns` |
|---|---|---|
| 1 | *(picker hidden)* | `1fr` |
| 2 | Equal | `repeat(2,minmax(0,1fr))` |
| 2 | Narrow first | `minmax(0,1fr) minmax(0,2fr)` |
| 2 | Wide first | `minmax(0,2fr) minmax(0,1fr)` |
| 3 | Equal | `repeat(3,minmax(0,1fr))` |
| 3 | Wide first (W N N) | `minmax(0,2fr) minmax(0,1fr) minmax(0,1fr)` |
| 3 | Wide middle (N W N) | `minmax(0,1fr) minmax(0,2fr) minmax(0,1fr)` |
| 3 | Wide last (N N W) | `minmax(0,1fr) minmax(0,1fr) minmax(0,2fr)` |
| 4–10 | Equal only | `repeat(N,minmax(0,1fr))` |

Keep `minmax(0,…)` on every track — without the `0` floor, grid items refuse to shrink below their
content size and the container overflows.

### Present the options as thumbnails, not words

▭▭ · ▭▬ · ▬▭ rather than "Narrow first" / "Wide first". A picture is read instantly, survives translation
into all five supported languages, and mirrors Lightning App Builder's region-template picker — which every
Salesforce admin has already used. The familiarity *is* the feature; keep the text label as the
`title`/`aria-label` for accessibility.

**Mirror the thumbnail under RTL** so it matches what the author will actually see. The designer preview
already has an RTL branch (`.designer-form-surface--rtl .preview-section__grid`).

---

## 4. Data model

Add one key to the **parent container's** existing `Config_JSON__c`, alongside the current `columns`:

```json
{ "columns": 3, "columnLayout": "wideLast" }
```

Allowed values: `equal` (default), `narrowFirst`, `wideFirst`, `wideMiddle`, `wideLast`.

- **No new custom field.** Fields cannot be deleted from a released managed package — a `Config_JSON__c`
  key costs nothing and stays reshapeable.
- **Absent / unrecognised value ⇒ `equal`.** Covers every existing form and any future rename.
- **Validate against the count at render time, not just at save.** If `columns` changes from 3 to 2 while
  `columnLayout` is `wideMiddle`, the renderer must fall back to `equal` rather than emit a 3-track string
  into a 2-column container. Same guard as `safeSectionColumnCount`.

---

## 5. Rendering

### Publisher

`.nf-section__grid--N` classes are pre-generated 1–10 at
[NativeFormsPublisher.cls:1906-1910](../../../force-app/main/default/classes/NativeFormsPublisher.cls#L1906-L1910)
and consumed at **four** call sites:

| Line | Context |
|---|---|
| [2608](../../../force-app/main/default/classes/NativeFormsPublisher.cls#L2608) | Records List **header row** |
| [2638](../../../force-app/main/default/classes/NativeFormsPublisher.cls#L2638) | Records List **row body** |
| [2667](../../../force-app/main/default/classes/NativeFormsPublisher.cls#L2667) | Group |
| [2700](../../../force-app/main/default/classes/NativeFormsPublisher.cls#L2700) | Section |

Add one shared helper — `columnTemplate(Integer count, String layout)` → the `grid-template-columns` string —
and one emitter that writes a per-container rule into the existing `<style>` block:

```css
.nf-grid-{elementId}{grid-template-columns:minmax(0,1fr) minmax(0,1fr) minmax(0,2fr);}
```

Keep the `--N` classes for `equal` so existing output is unchanged; only emit a generated class when the
layout is not `equal`.

> **The header row and the row body must receive the same class.** They share `--N` today; if the two
> paths drift, Records List headers stop lining up with the fields beneath them.

### Designer preview

`.preview-section__grid--1..--10` are hand-written at
[nativeFormsDesigner.css:916-949+](../../../force-app/main/default/lwc/nativeFormsDesigner/nativeFormsDesigner.css#L916).
The preview needs the same computed template or it lies to the author — which is worse than not shipping
the feature. Since LWC CSS cannot be generated per element, set the template via a CSS custom property on
the grid element and have the static class consume it:

```css
.preview-section__grid{grid-template-columns:var(--preview-grid-template,repeat(2,minmax(0,1fr)));}
```

---

## 6. Implementation sketch

1. **Designer config** — `columnLayout` on section / group / repeatGroup; a `layoutOptions` getter that
   filters by the current `columns` value; reset to `equal` whenever the count changes to one that does not
   support the current layout.
2. **Designer panel** — thumbnail radio group under the existing Columns picker; hidden when `columns === 1`.
3. **Designer preview** — compute the template string, apply via the custom property above.
4. **Publisher** — `columnTemplate()` helper + generated-class emitter; wire the four call sites.
5. **Submission PDF (required — see §9)** — add `columnLayout` to the PDF schema in
   `buildSubmissionPdfSchema`, and consume it in the Chromium renderer's `sectionHtml`. One line each side.
6. **Tests** — `NativeFormsPublisherTest`: assert the generated rule appears for a non-equal layout, that
   the header row and row body carry the *same* class, that the PDF schema carries `columnLayout`, and that
   an out-of-range layout falls back to equal. Plus a `pdf-renderer` test pinning the template string for a
   known (count, layout) pair, so the Apex and JS builders cannot drift.

---

## 7. Complexity

**Low–Medium.** All four render paths already funnel through a single `grid-template-columns` declaration,
so the rendering change is genuinely small. The work is the panel UI, the preview mirroring, and the
count/layout reconciliation.

The expensive variants were considered and rejected: free px/% widths (adds unit validation and mobile
overflow) and drag-to-resize handles (pointer handling, snapping, undo integration).

---

## 8. Notes & edge cases

- **Presets do not remove the need for responsive collapse.** They control *proportion*, not *minimum
  size*. A 3-column section still needs the container-query collapse to stop columns shrinking toward zero
  on narrow viewports and inside Records List rows. That is a separate change and should land first.
- **RTL:** verify against a Hebrew form. The template string needs no mirroring — grid handles it — but the
  thumbnail does.
- **Empty columns:** a wide column with no fields still reserves its space. Acceptable and matches Salesforce
  page layout behaviour; do not auto-collapse.
- **Column deletion:** reducing the count already reassigns children (`sectionColumn` clamping in
  `NativeFormsDesignerController`); the layout value must be reconciled in the same operation.
- **Nested containers:** a group inside a section inherits nothing — each container carries its own layout.

---

## 9. Where the HTML/CSS is produced — and what AWS has to change

**The published form needs no AWS work.** Its HTML and CSS are generated entirely in Apex by
`NativeFormsPublisher.cls` and uploaded to S3. AWS stores and serves that file; it never generates form
markup. No Lambda change, no API contract change, no backend deploy.

**The submission PDF is generated in AWS, and supporting it is REQUIRED scope for this feature** — a form
whose PDF does not match the form is a bug report waiting to happen. Fortunately the work is very small.

The PDF schema **already carries `columns` and `sectionColumn`** per element
([NativeFormsPublisher.cls:4007,4012](../../../force-app/main/default/classes/NativeFormsPublisher.cls#L4007)),
so adding `columnLayout` is one more key in the same map.

### The active engine is Chromium

`resolvePdfEngine` ([NativeForms-SubmitForm.mjs:3132-3141](../../../AWS/NativeForms-SubmitForm.mjs#L3132-L3141))
checks the `PDF_RENDERER` env override **before** the `usePdfChromiumRenderer` feature flag. Verified on the
live `NativeForms-SubmitForm` Lambda (eu-north-1, 2026-09):

```
PDF_RENDERER = chromium
PDF_RENDERER_FUNCTION_NAME = NativeForms-PdfRenderer
```

Every production PDF therefore goes through the Chromium renderer.

### Required change — `AWS/pdf-renderer/htmlBuilder.mjs`

`sectionHtml` already emits a CSS grid
([htmlBuilder.mjs:162](../../../AWS/pdf-renderer/htmlBuilder.mjs#L162)):

```js
<div class="grid" style="grid-template-columns:repeat(${columns},1fr)">
```

Replace that one expression with the same template the form uses, derived from `columns` + `columnLayout`.
**One line, plus keeping the template helper in step with the Apex one.**

Since the same string now exists in Apex and in JS, add a renderer test asserting a known
(count, layout) pair produces the expected `grid-template-columns` — that is the only guard against the
two drifting.

### PDFKit is legacy — out of scope

`AWS/NativeForms-SubmitForm.mjs` still contains a coordinate-based PDFKit renderer that divides width
equally at three sites ([2745](../../../AWS/NativeForms-SubmitForm.mjs#L2745),
[2887](../../../AWS/NativeForms-SubmitForm.mjs#L2887),
[2993](../../../AWS/NativeForms-SubmitForm.mjs#L2993)). **Do not spend effort on it.** It is unreachable
while `PDF_RENDERER=chromium`.

> Caveat: it is inactive by *configuration*, not by deletion. `deploy-nativeforms-submit.ps1` only writes
> `PDF_RENDERER` when the parameter is passed and otherwise preserves the existing value — so the variable
> must survive future deploys. If PDFKit is genuinely finished with, deleting the path outright is cleaner
> than leaving a renderer that silently produces different output if a variable goes missing.

### Records Lists in PDF already differ between engines

Worth knowing before anyone files it as a bug caused by this feature:

Chromium renders a Records List as an HTML `<table>` whose column count comes from the *number of child
fields*, not the container's `columns`
([htmlBuilder.mjs:124-126](../../../AWS/pdf-renderer/htmlBuilder.mjs#L124-L126)). Widths auto-size to
content — arguably better than any preset would give. **A layout preset will not, and need not, apply to
Records List PDFs.**

Expect this to be reported as "the preset didn't work in the PDF." It is by design; state it in the help
page so support has an answer.

Separately, the per-row PDF hardcodes `repeat(2,1fr)`
([htmlBuilder.mjs:199](../../../AWS/pdf-renderer/htmlBuilder.mjs#L199)) regardless of the container. Small
pre-existing inconsistency, unrelated to this spec.

### Deploy script

`AWS/deploy-nativeforms-pdf-renderer.ps1` — the Chromium renderer Lambda (`NativeForms-PdfRenderer`).
`NativeForms-SubmitForm` needs no redeploy for this feature.

---

## 10. Follow-on — page layout import fidelity

The Page Layout → Form importer walks `sections` → `fields`
([NativeFormsDesignerController.cls:2957-2975](../../../force-app/main/default/classes/NativeFormsDesignerController.cls#L2957-L2975))
and **ignores the layout's column structure entirely**, so a two-column Salesforce layout imports flattened.

Salesforce layout sections are 1- or 2-column with fields distributed across `layoutColumns`. Once
containers can express a layout, the importer can carry that structure across instead of discarding it.

This matters beyond tidiness: Page-Layout-to-Form is the product's proof point — *"your Salesforce, already
configured, becomes a form."* Today the imported form does not resemble the layout it came from. Making it
match is a visible fidelity win on the headline feature, and this spec is its prerequisite.

---

## 11. How to deploy

> Org alias: **TwinaFormsDevHub**.

```powershell
sf project deploy start `
  --source-dir force-app/main/default/classes/NativeFormsPublisher.cls `
  --source-dir force-app/main/default/classes/NativeFormsPublisherTest.cls `
  --source-dir force-app/main/default/lwc/nativeFormsDesigner `
  --target-org TwinaFormsDevHub

sf apex run test --tests NativeFormsPublisherTest `
  --target-org TwinaFormsDevHub --result-format human --wait 10
```

AWS side (Chromium PDF renderer only — `NativeForms-SubmitForm` does not need a redeploy):

```powershell
./AWS/deploy-nativeforms-pdf-renderer.ps1
```

**Re-publish affected forms.** The grid CSS is baked at publish time by `NativeFormsPublisher.cls`; a deploy
alone changes the designer but not any live form.

Also update the public help site (`AWS/marketing-site/help/`) — and hold that upload until the package
version ships, or the docs will describe a control customers do not have yet.
