/* Build the submission PDF as HTML/CSS for headless Chromium.
   Mirrors the PDFKit traversal in NativeForms-SubmitForm.mjs (buildSubmissionPdfBuffer /
   renderPdfSection / renderPdfRepeatGroup / renderPdfSchemaItemAt) but emits HTML —
   so Hebrew/RTL is correct for free and repeat groups render as a real table. */
import fs from "fs";
import {
  stripHtmlForPdf, resolveMergedDocumentTextForPdf, pdfValueIsEmpty,
  formatPdfValue, formatPdfRowValue, clampPdfColumn, isPdfContainer, isPdfDisplayText,
  isPdfHiddenItem, buildPdfSchemaTree, submittedRepeatRows, parseBrowserForDisplay,
  escapeHtml, sanitizeAuthorHtml
} from "./schemaTree.mjs";

// ---- theme tokens (Phase 1 defaults; later driven by the PDF Theme feature) ----
const THEME = {
  primary: "#0B5394", accent: "#1F7A4D", ink: "#14304A", muted: "#5B7185",
  line: "#9FB6CC", lineStrong: "#5B7185", head: "#EAF1F8"
};

let cachedFontFaceCss = null;
function fontFaceCss() {
  if (cachedFontFaceCss !== null) {
    return cachedFontFaceCss;
  }
  const fontPath = process.env.PDF_FONT_PATH || new URL("./assets/fonts/NotoSansHebrew-Regular.ttf", import.meta.url).pathname;
  try {
    const b64 = fs.readFileSync(fontPath).toString("base64");
    cachedFontFaceCss = `@font-face{font-family:'NFHeb';src:url(data:font/ttf;base64,${b64}) format('truetype');font-weight:400 700;font-style:normal;}`;
  } catch (error) {
    console.warn("PDF font not loaded, falling back to system stack:", error?.message || error);
    cachedFontFaceCss = "";
  }
  return cachedFontFaceCss;
}

function baseCss(rtl) {
  return `
${fontFaceCss()}
:root{--primary:${THEME.primary};--accent:${THEME.accent};--ink:${THEME.ink};--muted:${THEME.muted};--line:${THEME.line};--line-strong:${THEME.lineStrong};--head:${THEME.head};}
*{box-sizing:border-box;-webkit-print-color-adjust:exact;print-color-adjust:exact;}
@page{size:A4;margin:14mm;}
body{font-family:'NFHeb','Noto Sans Hebrew','Arial',sans-serif;color:var(--ink);font-size:11pt;margin:0;direction:${rtl ? "rtl" : "ltr"};}
.hdr{display:flex;justify-content:space-between;align-items:flex-start;border-bottom:2px solid var(--primary);padding-bottom:10px;margin-bottom:14px;}
.hdr h1{font-size:18pt;color:var(--primary);margin:0;}
.hdr .meta{color:var(--muted);font-size:8.5pt;line-height:1.5;}
.sec{border:1px solid #c9d8ea;border-radius:8px;padding:12px 14px;margin:10px 0;}
.sec.plain{border:none;padding:0;}
.sec h2{font-size:12pt;color:var(--ink);margin:0 0 8px;}
.sec .desc{color:var(--muted);margin:0 0 10px;white-space:pre-line;}
.grid{display:grid;gap:10px 18px;}
.field .lbl{color:var(--muted);font-size:9pt;}
.field .val{font-size:11pt;white-space:pre-line;}
.disp{margin:8px 0;line-height:1.5;}
.sig img{max-width:280px;max-height:120px;}
img.inl{max-width:100%;height:auto;}
table.rep{width:100%;border-collapse:collapse;font-size:10.5pt;margin:6px 0 12px;}
table.rep thead th{background:var(--head);color:var(--primary);font-weight:700;text-align:center;padding:9px 8px;border-bottom:2px solid var(--line-strong);}
table.rep tbody td{text-align:center;padding:9px 8px;border-bottom:1px solid var(--line);white-space:pre-line;}
table.rep tbody tr:last-child td{border-bottom:2px solid var(--line-strong);}
table.rep td .sig img{max-width:120px;max-height:44px;}
.rep-title{font-size:12pt;color:var(--ink);margin:12px 0 4px;font-weight:700;}
.rep-empty{color:var(--muted);margin:6px 0 12px;}
`;
}

function fieldHtml(item, value) {
  const label = escapeHtml(item?.label || item?.fieldKey || "Field");
  return `<div class="field"><div class="lbl">${label}</div><div class="val">${escapeHtml(value)}</div></div>`;
}

export function columnTemplate(columns, layout) {
  const count = Math.min(Math.max(Number.parseInt(String(columns || 1), 10) || 1, 1), 10);
  if (count === 1) return "1fr";
  if (count === 2 && layout === "narrowFirst") return "minmax(0,1fr) minmax(0,2fr)";
  if (count === 2 && layout === "wideFirst") return "minmax(0,2fr) minmax(0,1fr)";
  if (count === 3 && layout === "wideFirst") return "minmax(0,2fr) minmax(0,1fr) minmax(0,1fr)";
  if (count === 3 && layout === "wideMiddle") return "minmax(0,1fr) minmax(0,2fr) minmax(0,1fr)";
  if (count === 3 && layout === "wideLast") return "minmax(0,1fr) minmax(0,1fr) minmax(0,2fr)";
  return `repeat(${count},minmax(0,1fr))`;
}

function dataImageOnly(url) {
  return /^data:image\//i.test(String(url || "").trim()) ? String(url).trim() : "";
}

function leafHtml(item, ctx) {
  if (isPdfHiddenItem(item)) {
    return "";
  }
  if (isPdfDisplayText(item)) {
    if (item.type === "richText" || item.type === "mergedDocument") {
      const raw = item.type === "mergedDocument"
        ? resolveMergedDocumentTextForPdf(item.html || item.text || item.label || "", ctx.inputPayload)
        : (item.html || item.text || item.label || "");
      return `<div class="disp">${sanitizeAuthorHtml(raw)}</div>`;
    }
    const text = stripHtmlForPdf(item.text || item.html || item.label || "");
    if (!text) return "";
    return `<div class="disp">${escapeHtml(text)}</div>`;
  }
  if (item.type === "image") {
    const src = dataImageOnly(item.imageUrl);
    if (!src) return "";
    const w = Math.min(100, Math.max(1, Number(item.imageWidthPercent) || 100));
    return `<div class="disp"><img class="inl" style="width:${w}%" src="${src}"></div>`;
  }
  const fieldKey = String(item?.fieldKey || "").trim();
  if (!fieldKey) return "";
  const rawValue = ctx.inputPayload?.input?.[fieldKey];
  if (!ctx.includeEmptyFields && pdfValueIsEmpty(rawValue) && item.type !== "signature") {
    return "";
  }
  const value = formatPdfValue(item, rawValue, ctx.inputPayload, ctx.finalizedFiles, ctx.finalizedSignatures);
  if (!ctx.includeEmptyFields && !value && item.type !== "signature") {
    return "";
  }
  if (item.type === "signature") {
    const sig = ctx.inputPayload?.input?.signatures?.[fieldKey];
    const img = sig?.dataUrl ? `<div class="sig"><img src="${dataImageOnly(sig.dataUrl)}"></div>` : "";
    return `<div class="field"><div class="lbl">${escapeHtml(item.label || fieldKey)}</div>${img || `<div class="val">${escapeHtml(value)}</div>`}</div>`;
  }
  return fieldHtml(item, value);
}

function repeatGroupHtml(container, children, ctx) {
  const groupKey = String(container?.fieldKey || "").trim();
  const rows = submittedRepeatRows(ctx.inputPayload, groupKey);
  const title = container?.showTitle === false ? "" : String(container?.label || groupKey || "Records").trim();
  const titleHtml = title ? `<div class="rep-title">${escapeHtml(title)}</div>` : "";
  if (!rows.length) {
    return `${titleHtml}<div class="rep-empty">No rows submitted.</div>`;
  }
  // column children: visible, non-container, non-signature fields, in column/order
  const cols = (children || [])
    .filter((c) => !isPdfContainer(c) && !isPdfDisplayText(c) && !isPdfHiddenItem(c) && c.type !== "signature" && c.type !== "fileUpload" && String(c?.fieldKey || "").trim());
  const maxColumns = cols.length || 1;
  // Emit columns in LOGICAL order; the dir=rtl table reverses them visually (no manual RTL flip).
  cols.sort((a, b) => clampPdfColumn(a?.sectionColumn, maxColumns) - clampPdfColumn(b?.sectionColumn, maxColumns));
  const rowSig = container?.rowSignature && typeof container.rowSignature === "object" ? container.rowSignature : null;
  const sigLabel = rowSig ? (String(rowSig.label || "Signature").trim() || "Signature") : "";

  const head = `<tr>${cols.map((c) => `<th>${escapeHtml(c.label || c.fieldKey)}</th>`).join("")}${rowSig ? `<th>${escapeHtml(sigLabel)}</th>` : ""}</tr>`;
  const body = rows.map((row) => {
    const cells = cols.map((c) => `<td>${escapeHtml(formatPdfRowValue(c, row?.[c.fieldKey]))}</td>`).join("");
    let sigCell = "";
    if (rowSig) {
      const dataUrl = dataImageOnly(row?._rowSignature?.dataUrl);
      sigCell = `<td><div class="sig">${dataUrl ? `<img src="${dataUrl}">` : ""}</div></td>`;
    }
    return `<tr>${cells}${sigCell}</tr>`;
  }).join("");
  return `${titleHtml}<table class="rep"><thead>${head}</thead><tbody>${body}</tbody></table>`;
}

function sectionHtml(container, ctx) {
  if (String(container?.type || "") === "repeatGroup") {
    const children = ctx.tree.byParent.get(String(container.elementId || "")) || [];
    return repeatGroupHtml(container, children, ctx);
  }
  const children = ctx.tree.byParent.get(String(container.elementId || "")) || [];
  const title = container?.showTitle === false ? "" : String(container?.label || "").trim();
  const desc = (container?.text && String(container.text).trim() && String(container.text).trim() !== "Section description")
    ? `<div class="desc">${escapeHtml(stripHtmlForPdf(container.text))}</div>` : "";
  const columns = Math.min(Math.max(Number.parseInt(String(container?.columns || 2), 10) || 2, 1), 10);
  const layout = ["narrowFirst", "wideFirst", "wideMiddle", "wideLast"].includes(String(container?.columnLayout || ""))
    ? String(container.columnLayout)
    : "equal";
  const template = columnTemplate(columns, layout);

  const inner = (children || []).map((child) => {
    if (isPdfContainer(child)) {
      return `<div style="grid-column:1 / -1">${sectionHtml(child, ctx)}</div>`;
    }
    return leafHtml(child, ctx);
  }).filter(Boolean).join("");

  const boxed = container?.boxed !== false && String(container?.type || "") !== "sectionBreak";
  return `<div class="sec${boxed ? "" : " plain"}">${title ? `<h2>${escapeHtml(title)}</h2>` : ""}${desc}<div class="grid" style="grid-template-columns:${template}">${inner}</div></div>`;
}

function headerHtml(config, meta, submittedAt) {
  const lines = [`Submitted: ${submittedAt || new Date().toISOString()}`];
  if (meta?.clientIp) lines.push(`IP Address: ${meta.clientIp}`);
  if (meta?.userAgent) lines.push(`Browser: ${parseBrowserForDisplay(meta.userAgent)}`);
  const logo = dataImageOnly(meta?.logoDataUrl);
  const logoHtml = logo ? `<img src="${logo}" style="height:56px">` : "";
  return `<div class="hdr"><h1>${escapeHtml(config.title || "Submitted Response")}</h1><div style="display:flex;gap:16px;align-items:flex-start"><div class="meta">${lines.map(escapeHtml).join("<br>")}</div>${logoHtml}</div></div>`;
}

export function buildSubmissionHtml({ config, inputPayload, finalizedFiles = [], finalizedSignatures = [], finalizedRowSignatures = [], submittedAt, meta = {} }) {
  const rtl = config?.rtlEnabled === true;
  const tree = buildPdfSchemaTree(config?.schema || []);
  const ctx = { tree, inputPayload, finalizedFiles, finalizedSignatures, finalizedRowSignatures, includeEmptyFields: config?.includeEmptyFields !== false, rtl };
  const root = tree.byParent.get("") || [];
  const body = root.map((item) => isPdfContainer(item) ? sectionHtml(item, ctx) : leafHtml(item, ctx)).filter(Boolean).join("");
  return `<!doctype html><html dir="${rtl ? "rtl" : "ltr"}" lang="${rtl ? "he" : "en"}"><head><meta charset="utf-8"><style>${baseCss(rtl)}</style></head><body>${headerHtml(config, meta, submittedAt)}${body}</body></html>`;
}

export function buildRowSignatureHtml({ config, groupKey, row, rowIndex, submittedSignature, submittedAt, meta = {} }) {
  const rtl = config?.rtlEnabled === true;
  const tree = buildPdfSchemaTree(config?.schema || []);
  const group = (config?.schema || []).find((it) => String(it?.type || "") === "repeatGroup" && String(it?.fieldKey || "").trim() === String(groupKey || "").trim());
  const children = group ? (tree.byParent.get(String(group.elementId || "")) || []) : [];
  const ctx = { tree, inputPayload: { input: {} }, finalizedFiles: [], finalizedSignatures: [], includeEmptyFields: true, rtl };
  const groupLabel = String(group?.label || groupKey || "Record").trim();
  const title = `${groupLabel} - Row ${Number(rowIndex || 0) + 1}`;

  const cols = children.filter((c) => !isPdfContainer(c) && !isPdfDisplayText(c) && !isPdfHiddenItem(c) && c.type !== "signature" && c.type !== "fileUpload" && String(c?.fieldKey || "").trim());
  const fields = cols.map((c) => fieldHtml(c, formatPdfRowValue(c, row?.[c.fieldKey]))).join("");
  const sig = dataImageOnly(submittedSignature?.dataUrl);
  const sigHtml = sig ? `<div class="field"><div class="lbl">${escapeHtml(group?.rowSignature?.label || "Signature")}</div><div class="sig"><img src="${sig}"></div></div>` : "";

  return `<!doctype html><html dir="${rtl ? "rtl" : "ltr"}" lang="${rtl ? "he" : "en"}"><head><meta charset="utf-8"><style>${baseCss(rtl)}</style></head><body>`
    + `<div class="hdr"><h1>${escapeHtml(title)}</h1><div class="meta">${escapeHtml(`Submitted: ${submittedAt || new Date().toISOString()}`)}${meta?.clientIp ? "<br>" + escapeHtml("IP Address: " + meta.clientIp) : ""}</div></div>`
    + `<div class="sec"><div class="grid" style="grid-template-columns:repeat(2,1fr)">${fields}${sigHtml}</div></div></body></html>`;
}
