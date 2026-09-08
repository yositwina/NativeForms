# PDF → HTML→Chromium spike (seed for the real renderer)

Working proof-of-concept for the [PDF Rendering Engine Strategy](../PDF_Rendering_Engine_Strategy.md)
decision: generate the submission PDF as **HTML + CSS rendered by headless Chromium** (Puppeteer).

This produces a representative **"Submitted Response"** in Hebrew with logo, theme colors, a clean repeat
**table** (header once, single line between rows, bold borders), and per-row signatures — proving correct
Hebrew/RTL **with no bidi helper** (the browser does it). It's the starting point for the production
renderer, not production code.

## Files
- `html-full.cjs` — builds the HTML doc and prints it to PDF via Puppeteer/Chromium.
- `raster3.mjs` — renders a PDF's page 1 to PNG (visual QA helper).

## What it demonstrates (maps to the feature docs)
- Perfect Hebrew/RTL — logical-order text, `dir="rtl"`, no reordering code.
- The repeat **table** done right → [PDF_Repeat_Group_Table_Rendering](../PDF_Repeat_Group_Table_Rendering.md).
- **Theme** via CSS variables (`:root{ --primary … }`) → [PDF_Theme_Tab](../PDF_Theme_Tab.md).
- Per-row signatures (inline SVG), header/footer with page numbers.

## Run it (local, Windows)
```powershell
mkdir C:\tmp\pdf-spike; cd C:\tmp\pdf-spike
npm init -y
npm install puppeteer
npx puppeteer browsers install chrome
# copy html-full.cjs + raster3.mjs here, then:
node html-full.cjs
node raster3.mjs twinaforms-pdf-chromium-full.pdf out.png   # optional visual check
```

## Demo-only shortcuts to replace in production
- **Fonts:** the spike base64-embeds **Segoe UI** from `C:/Windows/Fonts`. Production must **bundle a
  licensed/open Hebrew-capable font** (e.g. Noto Sans Hebrew full) in the renderer image — Chromium in
  Lambda has no system fonts. See [strategy §4](../PDF_Rendering_Engine_Strategy.md).
- **Logo & content:** hardcoded sample data + a repo logo path. Production builds the HTML from the
  submission payload + the form's submission-PDF schema, and applies the form's **PDF theme tokens** as the
  CSS `:root` variables.
- **Runtime:** spike uses local Puppeteer + downloaded Chrome. Production target is a **container-image
  Lambda** with `@sparticuz/chromium` (or a Gotenberg service).
- **Security:** when rendering author-supplied HTML (Display Text / Merged Document), sanitize first and run
  the browser locked down (no network / controlled JS).
