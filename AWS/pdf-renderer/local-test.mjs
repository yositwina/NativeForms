/* Local dev test for htmlBuilder — renders a sample Hebrew submission to a PDF.
   Requires a full browser for local rendering:  npm install puppeteer
   Tip: point PDF_FONT_PATH at a full Hebrew font, e.g.
     PDF_FONT_PATH=C:/Windows/Fonts/segoeui.ttf node local-test.mjs           (PowerShell: $env:PDF_FONT_PATH=...) */
import fs from "fs";
import { buildSubmissionHtml } from "./htmlBuilder.mjs";

const sig = (n) => "data:image/svg+xml;base64," + Buffer.from(
  `<svg xmlns="http://www.w3.org/2000/svg" width="64" height="26"><path d="M2 ${16 + n} C 8 4,14 22,20 ${12 - n} S 30 4,38 16 S 50 22,62 ${8 + n}" fill="none" stroke="#10233f" stroke-width="1.5" stroke-linecap="round"/></svg>`
).toString("base64");

const envelope = {
  jobType: "submission",
  config: {
    title: "תגובה שהוגשה", rtlEnabled: true, includeEmptyFields: true,
    schema: [
      { elementId: "sec1", parentElementId: "", type: "section", label: "פרטים", columns: 2, showTitle: true, boxed: true, order: 1 },
      { elementId: "f1", parentElementId: "sec1", type: "text", fieldKey: "firstName", label: "שם פרטי", order: 1, sectionColumn: 1 },
      { elementId: "f2", parentElementId: "sec1", type: "text", fieldKey: "lastName", label: "שם משפחה", order: 2, sectionColumn: 2 },
      { elementId: "rt1", parentElementId: "", type: "richText", order: 2, html: "<b>אנא מלאו את דוח השעות</b> והוסיפו את חתימתכם." },
      { elementId: "rg1", parentElementId: "", type: "repeatGroup", fieldKey: "hours", label: "שעות נוכחות", order: 3, showTitle: true, rowSignature: { label: "חתימה" } },
      { elementId: "c1", parentElementId: "rg1", type: "text", fieldKey: "date", label: "תאריך", order: 1, sectionColumn: 1 },
      { elementId: "c2", parentElementId: "rg1", type: "text", fieldKey: "from", label: "משעה", order: 2, sectionColumn: 2 },
      { elementId: "c3", parentElementId: "rg1", type: "text", fieldKey: "to", label: "עד שעה", order: 3, sectionColumn: 3 },
      { elementId: "c4", parentElementId: "rg1", type: "text", fieldKey: "desc", label: "תיאור", order: 4, sectionColumn: 4 },
      { elementId: "rgsig", parentElementId: "rg1", type: "signature", fieldKey: "rowsig", label: "חתימה", order: 5 },
      { elementId: "sg1", parentElementId: "", type: "signature", fieldKey: "sign", label: "חתימת המגיש", order: 4 }
    ]
  },
  inputPayload: {
    input: {
      firstName: "יוסי", lastName: "טוינה",
      signatures: { sign: { dataUrl: sig(0) } },
      repeatGroups: { hours: { rows: [
        { date: "2026-05-20", from: "13:45", to: "19:45", desc: "Building Yard", _rowSignature: { dataUrl: sig(0) } },
        { date: "2026-05-21", from: "01:45", to: "02:00", desc: "בניית גדר", _rowSignature: { dataUrl: sig(2) } }
      ] } }
    }
  },
  finalizedFiles: [], finalizedSignatures: [], finalizedRowSignatures: [],
  submittedAt: "2026-06-15T10:23:00Z",
  meta: { clientIp: "93.173.54.184", userAgent: "Mozilla/5.0 (Windows NT 10.0) Chrome/148.0 Safari/537.36" }
};

const html = buildSubmissionHtml(envelope);
fs.writeFileSync("local-test.html", html);
console.log("wrote local-test.html");

try {
  const puppeteer = (await import("puppeteer")).default;
  const browser = await puppeteer.launch({ headless: "new", args: ["--no-sandbox"] });
  const page = await browser.newPage();
  await page.setContent(html, { waitUntil: "load" });
  await page.evaluateHandle("document.fonts.ready");
  await page.pdf({ path: "local-test.pdf", format: "A4", printBackground: true });
  await browser.close();
  console.log("wrote local-test.pdf");
} catch (error) {
  console.log("Skipped PDF render (install puppeteer for local rendering):", error?.message || error);
}
