# NativeForms-PdfRenderer (HTML → headless Chromium)

A **separate container-image Lambda** that renders the submission PDF as HTML/CSS via Puppeteer +
`@sparticuz/chromium`. It runs **in parallel** to the existing PDFKit renderer in the Submit Lambda; the
Submit Lambda chooses the engine per tenant via a flag. See
[`../documentation/New features after 0.1/PDF_Rendering_Engine_Strategy.md`](../documentation/New%20features%20after%200.1/PDF_Rendering_Engine_Strategy.md).

## Files
- `index.mjs` — handler: envelope → `htmlBuilder` → `chromium` → `{ ok, pdfBase64, bytes }`.
- `htmlBuilder.mjs` — schema + payload → HTML/CSS (parity with the PDFKit path + repeat group as a table).
- `schemaTree.mjs` — pure data helpers ported from `NativeForms-SubmitForm.mjs` (+ HTML escape/sanitize).
- `chromium.mjs` — warm browser singleton + locked-down `page.pdf` (JS off, offline, only `data:` URLs).
- `package.json`, `assets/fonts/` — deps + bundled font. Deployed as a **plain ZIP** (no Docker):
  `@sparticuz/chromium` fits the Lambda size quota for this dedicated function.

## Handler input/output
Input envelope (from Submit; renderer never touches DynamoDB/Salesforce):
```
{ jobType:"submission"|"rowSignature",
  config,                 // normalizeSubmissionPdfConfig output {title,rtlEnabled,includeEmptyFields,schema[]}
  inputPayload,           // { input:{...,signatures,repeatGroups} }
  finalizedFiles, finalizedSignatures, finalizedRowSignatures,
  submittedAt,
  meta:{ clientIp, userAgent, logoDataUrl? },
  // rowSignature job: groupKey, row, rowIndex, submittedSignature
  // oversized payloads: s3Staging:{ bucket, key }   (renderer fetches + deletes)
}
```
Output: `{ ok:true, pdfBase64, bytes, engine:"chromium" }` or `{ ok:false, error }`.

## Deploy (plain ZIP, no Docker)
```powershell
cd AWS/pdf-renderer && npm install --omit=dev && cd ../..
# zips the function + node_modules, uploads via S3 (chromium exceeds the 50MB direct-upload limit),
# then create/update the Lambda. First create reuses the Submit Lambda's role unless -RoleArn is given.
./AWS/deploy-nativeforms-pdf-renderer.ps1

# point Submit at it
./AWS/deploy-nativeforms-submit.ps1 -PdfRendererFunctionName NativeForms-PdfRenderer

# turn on globally for testing (or set the per-tenant flag instead)
./AWS/deploy-nativeforms-submit.ps1 -PdfRenderer chromium
```

## Flag & env (Submit Lambda)
- **Per-tenant:** featureFlag `usePdfChromiumRenderer = true` (via `tenantRecord.featureFlags` /
  `effectiveFeatureFlags`). Default OFF ⇒ PDFKit.
- **Global override `PDF_RENDERER`:** `chromium` (force on), `pdfkit` (kill switch), unset ⇒ per-tenant flag.
- `PDF_RENDERER_FUNCTION_NAME` — the renderer Lambda name (required for the chromium path).
- `PDF_RENDERER_FALLBACK=off` — disable auto-fallback to PDFKit on renderer error (default: falls back).

## IAM
- Submit Lambda role: `lambda:InvokeFunction` on `NativeForms-PdfRenderer`.
- Renderer Lambda role: `s3:GetObject` + `s3:DeleteObject` on the `UPLOAD_STAGING_BUCKET` prefix
  `pdf-renderer-staging/*` (only used for >5MB envelopes).

## ⚠️ Font
`assets/fonts/NotoSansHebrew-Regular.ttf` is a glyph **subset** (placeholder) — Hebrew will show boxes.
Before production, replace it with a **full Hebrew-capable TTF** (e.g. Noto Sans Hebrew full) or set
`PDF_FONT_PATH` in the image to a bundled full font.

## Local test
```powershell
cd AWS/pdf-renderer
npm install            # puppeteer-core + @sparticuz/chromium (Lambda runtime)
npm install puppeteer  # dev only: a full browser for local rendering
node local-test.mjs    # writes local-test.html + local-test.pdf (set PDF_FONT_PATH to a full font)
```
