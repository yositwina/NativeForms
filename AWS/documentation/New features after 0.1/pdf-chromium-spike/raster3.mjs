import { createCanvas } from "@napi-rs/canvas";
import * as pdfjs from "pdfjs-dist/legacy/build/pdf.mjs";
import { writeFileSync, readFileSync } from "fs";

const inFile = process.argv[2];
const outFile = process.argv[3];
const data = new Uint8Array(readFileSync(inFile));
const doc = await pdfjs.getDocument({ data }).promise;
const page = await doc.getPage(1);
const vp = page.getViewport({ scale: 1.4 });
const canvas = createCanvas(vp.width, vp.height);
await page.render({ canvasContext: canvas.getContext("2d"), viewport: vp, canvasFactory: {
  create: (w, h) => { const c = createCanvas(w, h); return { canvas: c, context: c.getContext("2d") }; },
  reset: (cc, w, h) => { cc.canvas.width = w; cc.canvas.height = h; },
  destroy: (cc) => { cc.canvas.width = 0; cc.canvas.height = 0; }
} }).promise;
writeFileSync(outFile, canvas.toBuffer("image/png"));
console.log("wrote", outFile);
