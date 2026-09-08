/* Pure data helpers ported verbatim from NativeForms-SubmitForm.mjs (no PDFKit dependency)
   so the Chromium HTML renderer formats values identically to the PDFKit path.
   Plus HTML-safety helpers (escapeHtml, sanitizeAuthorHtml) used only by the HTML builder. */

// ---- ported from SubmitForm.mjs ----

export function stripHtmlForPdf(value) {
  return String(value || "")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p\s*>/gi, "\n")
    .replace(/<\/div\s*>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"")
    .replace(/&#39;/g, "'")
    .replace(/[ \t\v\f\r]+/g, " ")
    .replace(/\n\s+/g, "\n")
    .trim();
}

function readMergedDocumentPath(source, path) {
  if (!source || !path) {
    return source;
  }
  return String(path).split(".").reduce((current, segment) => {
    if (current == null) {
      return undefined;
    }
    return current[segment];
  }, source);
}

export function resolveMergedDocumentTextForPdf(template, inputPayload) {
  const aliases = inputPayload?.prefillSnapshot?.aliases && typeof inputPayload.prefillSnapshot.aliases === "object"
    ? inputPayload.prefillSnapshot.aliases
    : {};
  return String(template || "").replace(/\{\{\s*([A-Za-z][A-Za-z0-9_]*)\.([A-Za-z][A-Za-z0-9_.]*?)\s*\}\}/g, (_, alias, path) => {
    const value = readMergedDocumentPath(aliases[alias], path);
    if (value == null) {
      return "";
    }
    if (typeof value === "object") {
      try {
        return JSON.stringify(value);
      } catch (error) {
        return "";
      }
    }
    return String(value);
  });
}

export function pdfValueIsEmpty(value) {
  if (value == null) {
    return true;
  }
  if (typeof value === "string") {
    return value.trim() === "";
  }
  if (Array.isArray(value)) {
    return value.length === 0;
  }
  if (typeof value === "object") {
    return Object.keys(value).length === 0;
  }
  return false;
}

function optionLabelForPdf(schemaItem, value) {
  const options = Array.isArray(schemaItem?.options) ? schemaItem.options : [];
  const match = options.find((option) => String(option?.value ?? "") === String(value ?? ""));
  return match?.label || value;
}

function multiOptionLabelsForPdf(schemaItem, value) {
  const values = Array.isArray(value)
    ? value
    : String(value ?? "")
      .split(";")
      .map((item) => item.trim())
      .filter(Boolean);
  return values.map((item) => optionLabelForPdf(schemaItem, item)).join(", ");
}

export function formatPdfValue(schemaItem, value, inputPayload, finalizedFiles = [], finalizedSignatures = []) {
  if (schemaItem?.type === "checkbox") {
    return value === true || String(value).toLowerCase() === "true" || value === "on"
      ? (schemaItem.checkedLabel || "Yes")
      : (schemaItem.uncheckedLabel || "No");
  }
  if (schemaItem?.type === "select" || schemaItem?.type === "radio") {
    return optionLabelForPdf(schemaItem, value);
  }
  if (schemaItem?.type === "multiCheckbox") {
    return multiOptionLabelsForPdf(schemaItem, value);
  }
  if (schemaItem?.type === "ranking") {
    let values = value;
    if (typeof values === "string") {
      try {
        values = JSON.parse(values);
      } catch {
        values = values.split(",").map((item) => item.trim()).filter(Boolean);
      }
    }
    if (!Array.isArray(values)) {
      return "";
    }
    return values
      .map((item, index) => `${index + 1}. ${optionLabelForPdf(schemaItem, item)}`)
      .join("\n");
  }
  if (schemaItem?.type === "signature") {
    const signature = finalizedSignatures.find((item) => String(item?.fieldKey || "") === String(schemaItem.fieldKey || ""));
    if (signature?.fileName) {
      return `Signature saved as ${signature.fileName}`;
    }
    const submitted = inputPayload?.input?.signatures?.[schemaItem.fieldKey];
    return submitted?.dataUrl ? "Signature captured" : "";
  }
  if (schemaItem?.type === "fileUpload") {
    const files = finalizedFiles.filter((item) => String(item?.fieldKey || "") === String(schemaItem.fieldKey || ""));
    if (files.length) {
      return files.map((item) => item.fileName).join(", ");
    }
  }
  if (Array.isArray(value)) {
    return value.map((item) => (typeof item === "object" ? JSON.stringify(item) : String(item))).join(", ");
  }
  if (typeof value === "object" && value != null) {
    return JSON.stringify(value);
  }
  return value == null ? "" : String(value);
}

export function formatPdfRowValue(schemaItem, value) {
  if (schemaItem?.type === "checkbox") {
    return value === true || String(value).toLowerCase() === "true" || value === "on"
      ? (schemaItem.checkedLabel || "Yes")
      : (schemaItem.uncheckedLabel || "No");
  }
  if (schemaItem?.type === "select" || schemaItem?.type === "radio") {
    return optionLabelForPdf(schemaItem, value);
  }
  if (schemaItem?.type === "multiCheckbox") {
    return multiOptionLabelsForPdf(schemaItem, value);
  }
  if (schemaItem?.type === "ranking") {
    let values = value;
    if (typeof values === "string") {
      try {
        values = JSON.parse(values);
      } catch {
        values = values.split(",").map((item) => item.trim()).filter(Boolean);
      }
    }
    if (!Array.isArray(values)) {
      return "";
    }
    return values.map((item, index) => `${index + 1}. ${optionLabelForPdf(schemaItem, item)}`).join("\n");
  }
  if (Array.isArray(value)) {
    return value.map((item) => (typeof item === "object" ? JSON.stringify(item) : String(item))).join(", ");
  }
  if (typeof value === "object" && value != null) {
    return JSON.stringify(value);
  }
  return value == null ? "" : String(value);
}

export function clampPdfColumn(value, maxColumns) {
  const parsed = Number.parseInt(String(value || ""), 10);
  if (!Number.isFinite(parsed) || parsed < 1) {
    return 1;
  }
  return Math.min(Math.max(1, parsed), Math.max(1, maxColumns || 1));
}

export function pdfColumnIndex(value, maxColumns, rtl = false) {
  const oneBased = clampPdfColumn(value, maxColumns);
  return rtl ? Math.max(1, maxColumns || 1) - oneBased : oneBased - 1;
}

export function isPdfContainer(schemaItem) {
  return ["section", "sectionBreak", "group", "repeatGroup"].includes(String(schemaItem?.type || ""));
}

export function isPdfDisplayText(schemaItem) {
  return ["heading", "paragraph", "richText", "mergedDocument"].includes(String(schemaItem?.type || ""));
}

export function isPdfHiddenItem(schemaItem) {
  return String(schemaItem?.type || "") === "hidden" || String(schemaItem?.fieldBehavior || "") === "hidden" || schemaItem?.hidden === true;
}

export function buildPdfSchemaTree(schema) {
  const byParent = new Map();
  const byElementId = new Map();
  for (const item of Array.isArray(schema) ? schema : []) {
    if (isPdfHiddenItem(item)) {
      continue;
    }
    const elementId = String(item?.elementId || "").trim();
    if (elementId) {
      byElementId.set(elementId, item);
    }
    const parent = String(item?.parentElementId || "").trim();
    if (!byParent.has(parent)) {
      byParent.set(parent, []);
    }
    byParent.get(parent).push(item);
  }
  for (const items of byParent.values()) {
    items.sort((left, right) => Number(left?.order || 0) - Number(right?.order || 0));
  }
  return { byParent, byElementId };
}

const HEBREW_RANGE = new RegExp("[\\u0590-\\u05FF]", "u");
export function containsHebrewText(value) {
  return HEBREW_RANGE.test(String(value || ""));
}

export function submittedRepeatRows(inputPayload, groupKey) {
  const rows = inputPayload?.input?.repeatGroups?.[groupKey]?.rows;
  return Array.isArray(rows) ? rows : [];
}

export function parseBrowserForDisplay(userAgent) {
  const value = String(userAgent || "").trim();
  if (!value) {
    return "";
  }
  const browserMatchers = [
    { name: "Microsoft Edge", pattern: /\bEdg\/([\d.]+)/i },
    { name: "Chrome", pattern: /\bChrome\/([\d.]+)/i },
    { name: "Firefox", pattern: /\bFirefox\/([\d.]+)/i },
    { name: "Safari", pattern: /\bVersion\/([\d.]+).*?\bSafari\//i }
  ];
  const browserMatch = browserMatchers
    .map((matcher) => {
      const match = matcher.pattern.exec(value);
      return match ? { name: matcher.name, version: match[1] } : null;
    })
    .find(Boolean);
  const os = /\bWindows NT\b/i.test(value)
    ? "Windows"
    : /\bMac OS X\b/i.test(value)
      ? "macOS"
      : /\bAndroid\b/i.test(value)
        ? "Android"
        : /\b(iPhone|iPad|iPod)\b/i.test(value)
          ? "iOS"
          : /\bLinux\b/i.test(value)
            ? "Linux"
            : "";
  if (!browserMatch) {
    return os ? `Unknown browser on ${os}` : "Unknown browser";
  }
  const majorVersion = String(browserMatch.version || "").split(".")[0];
  return `${browserMatch.name}${majorVersion ? ` ${majorVersion}` : ""}${os ? ` on ${os}` : ""}`;
}

// ---- HTML-safety helpers (new; used only by the HTML builder) ----

export function escapeHtml(value) {
  return String(value == null ? "" : value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// Conservative allowlist-ish strip of dangerous markup for author-supplied rich text
// (richText / mergedDocument / section text). The real guard is the locked-down browser
// (JS disabled, offline, request interception in chromium.mjs); this removes the obvious
// execution/exfiltration vectors. Replace with a full sanitizer (sanitize-html) if needed.
export function sanitizeAuthorHtml(html) {
  let out = String(html == null ? "" : html);
  out = out.replace(/<\s*(script|style|iframe|object|embed|link|meta|base)\b[\s\S]*?<\s*\/\s*\1\s*>/gi, "");
  out = out.replace(/<\s*(script|iframe|object|embed|link|meta|base)\b[^>]*>/gi, "");
  out = out.replace(/\son\w+\s*=\s*"[^"]*"/gi, "");
  out = out.replace(/\son\w+\s*=\s*'[^']*'/gi, "");
  out = out.replace(/\son\w+\s*=\s*[^\s>]+/gi, "");
  out = out.replace(/(href|src|xlink:href)\s*=\s*("|')\s*javascript:[^"']*\2/gi, "$1=$2#$2");
  out = out.replace(/(href|src|xlink:href)\s*=\s*("|')\s*data:text\/html[^"']*\2/gi, "$1=$2#$2");
  return out;
}
