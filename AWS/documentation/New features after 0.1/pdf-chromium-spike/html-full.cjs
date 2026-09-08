/* FULL Chromium demo — representative "Submitted Response" with:
   theme (CSS vars), Hebrew RTL, fields, a clean repeat-records TABLE (header once,
   single line between rows, bold header), per-row signatures, footer with page numbers. */
const fs = require("fs");
const path = require("path");
const puppeteer = require("puppeteer");

const REPO = "C:\\Users\\Yosi\\NativeFormsAWS";
const b64 = (p) => fs.readFileSync(p).toString("base64");
const logo = b64(path.join(REPO, "AWS", "marketing-site", "assets", "Twinaformslogo.png"));
const fReg = b64("C:/Windows/Fonts/segoeui.ttf");
const fBold = b64("C:/Windows/Fonts/segoeuib.ttf");

const sig = (s) => `<svg width="64" height="26" viewBox="0 0 64 26"><path d="M2 ${16 + s} C 8 4, 14 22, 20 ${12 - s} S 30 4, 38 16 S 50 22, 62 ${8 + s}" fill="none" stroke="#10233f" stroke-width="1.5" stroke-linecap="round"/></svg>`;

const rows = [
  { d: "2026-05-20", a: "13:45", b: "19:45", t: "Building Yard", s: 0 },
  { d: "2026-05-21", a: "01:45", b: "02:00", t: "Build Fence", s: 2 },
  { d: "2026-05-23", a: "17:00", b: "18:00", t: "תחזוקת מערכת", s: -1 },
  { d: "2026-05-24", a: "08:30", b: "12:00", t: "פגישת לקוח", s: 1 },
  { d: "2026-05-25", a: "09:00", b: "17:30", t: "התקנת ציוד באתר", s: -2 }
];
const tableRows = rows.map(r => `<tr>
  <td>${r.d}</td><td>${r.a}</td><td>${r.b}</td><td class="desc">${r.t}</td><td class="sigcell">${sig(r.s)}</td>
</tr>`).join("");

const html = `<!doctype html><html dir="rtl" lang="he"><head><meta charset="utf-8">
<style>
@font-face{font-family:'Heb';src:url(data:font/ttf;base64,${fReg}) format('truetype');font-weight:400;}
@font-face{font-family:'Heb';src:url(data:font/ttf;base64,${fBold}) format('truetype');font-weight:700;}
/* === THEME (this is exactly what the PDF Theme tab would drive) === */
:root{
  --primary:#0B5394; --accent:#1F7A4D; --ink:#14304A; --muted:#5B7185;
  --line:#9FB6CC; --line-strong:#5B7185; --head:#EAF1F8; --pagefont:'Heb';
}
*{box-sizing:border-box;-webkit-print-color-adjust:exact;print-color-adjust:exact;}
@page{size:A4;margin:14mm;}
body{font-family:var(--pagefont);color:var(--ink);font-size:11pt;direction:rtl;margin:0;}
.top{display:flex;justify-content:space-between;align-items:flex-start;border-bottom:2px solid var(--primary);padding-bottom:10px;margin-bottom:14px;}
.top img{height:72px;}
.htitle{font-weight:700;font-size:18pt;color:var(--primary);}
.meta{color:var(--muted);font-size:8.5pt;line-height:1.5;text-align:left;}
h2{color:var(--primary);font-size:13pt;margin:14px 0 6px;}
.fields{display:flex;gap:40px;flex-wrap:wrap;margin-bottom:6px;}
.field{min-width:160px;}
.field .lbl{color:var(--muted);font-size:9pt;}
.field .val{font-weight:700;font-size:12pt;}
.note{color:var(--muted);margin:8px 0 4px;}
/* === REPEAT TABLE: header once, single line between rows, BOLD header === */
table{width:100%;border-collapse:collapse;font-size:10.5pt;margin-top:6px;}
thead th{background:var(--head);color:var(--primary);font-weight:700;text-align:center;
  padding:9px 8px;border-bottom:2px solid var(--line-strong);}
tbody td{text-align:center;padding:9px 8px;border-bottom:1px solid var(--line);}
tbody tr:last-child td{border-bottom:2px solid var(--line-strong);}
td.desc{font-weight:600;}
td.sigcell svg{vertical-align:middle;}
.foot{position:fixed;bottom:0;left:0;right:0;display:flex;justify-content:space-between;
  color:var(--muted);font-size:8pt;border-top:1px solid var(--line);padding-top:6px;}
</style></head><body>
<div class="top">
  <div><div class="htitle">תגובה שהוגשה</div></div>
  <div style="display:flex;gap:18px;align-items:flex-start">
    <div class="meta">הוגש: 2026-06-15 10:23<br>כתובת IP: 93.173.54.184<br>דפדפן: Chrome on Windows</div>
    <img src="data:image/png;base64,${logo}">
  </div>
</div>

<h2>פרטים</h2>
<div class="fields">
  <div class="field"><div class="lbl">שם פרטי</div><div class="val">יוסי</div></div>
  <div class="field"><div class="lbl">שם משפחה</div><div class="val">טוינה</div></div>
</div>

<div class="note">אנא מלאו את דוח השעות והוסיפו את חתימתכם.</div>
<h2>שעות נוכחות</h2>
<table>
  <thead><tr><th>תאריך</th><th>משעה</th><th>עד שעה</th><th>תיאור</th><th>חתימה</th></tr></thead>
  <tbody>${tableRows}</tbody>
</table>

<div class="foot"><span>לפניות ותמיכה: supportat@twinaforms.com</span><span>TwinaForms</span></div>
</body></html>`;

(async () => {
  const browser = await puppeteer.launch({ headless: "new", args: ["--no-sandbox"] });
  const page = await browser.newPage();
  await page.setContent(html, { waitUntil: "load" });
  await page.evaluateHandle("document.fonts.ready");
  const out = path.join(__dirname, process.env.OUT || "twinaforms-pdf-chromium-full.pdf");
  await page.pdf({ path: out, format: "A4", printBackground: true,
    displayHeaderFooter: true, headerTemplate: "<span></span>",
    footerTemplate: `<div style="width:100%;font-size:8px;color:#5B7185;padding:0 14mm;text-align:left;direction:ltr"><span class="pageNumber"></span> / <span class="totalPages"></span></div>` });
  await browser.close();
  console.log("wrote", out, fs.statSync(out).size, "bytes");
})().catch((e) => { console.error(e.message); process.exit(1); });
