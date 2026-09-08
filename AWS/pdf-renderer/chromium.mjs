/* Headless Chromium launcher for AWS Lambda (container image).
   Warm-reuses a single browser; locks the page down (JS off, offline, only data: URLs)
   so rendering author-supplied HTML cannot execute or fetch anything. */
import chromium from "@sparticuz/chromium";
import puppeteer from "puppeteer-core";

let browserPromise = null;
let rendersSinceLaunch = 0;
const MAX_RENDERS_PER_BROWSER = 50;

async function getBrowser() {
  if (!browserPromise) {
    browserPromise = puppeteer.launch({
      args: [...chromium.args, "--no-sandbox"],
      executablePath: await chromium.executablePath(),
      headless: chromium.headless,
      defaultViewport: chromium.defaultViewport
    });
  }
  return browserPromise;
}

async function recycleBrowser() {
  const current = browserPromise;
  browserPromise = null;
  rendersSinceLaunch = 0;
  try {
    const b = await current;
    await b.close();
  } catch (_) { /* ignore */ }
}

const FOOTER = `<div style="width:100%;font-size:8px;color:#5B7185;padding:0 14mm;text-align:left;direction:ltr"><span class="pageNumber"></span> / <span class="totalPages"></span></div>`;

export async function renderHtmlToPdf(html) {
  const browser = await getBrowser();
  const page = await browser.newPage();
  try {
    await page.setJavaScriptEnabled(false);
    await page.setOfflineMode(true);
    await page.setRequestInterception(true);
    page.on("request", (req) => {
      const url = req.url();
      if (url.startsWith("data:") || url.startsWith("about:")) {
        req.continue();
      } else {
        req.abort();
      }
    });
    await page.setContent(html, { waitUntil: "load", timeout: 30000 });
    const buffer = await page.pdf({
      format: "A4",
      printBackground: true,
      displayHeaderFooter: true,
      headerTemplate: "<span></span>",
      footerTemplate: FOOTER
    });
    return Buffer.isBuffer(buffer) ? buffer : Buffer.from(buffer);
  } finally {
    await page.close().catch(() => {});
    rendersSinceLaunch += 1;
    if (rendersSinceLaunch >= MAX_RENDERS_PER_BROWSER) {
      await recycleBrowser();
    }
  }
}
