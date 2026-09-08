/* NativeForms-PdfRenderer Lambda handler.
   Input envelope (from the Submit Lambda):
   { jobType:"submission"|"rowSignature", config, inputPayload, finalizedFiles,
     finalizedSignatures, finalizedRowSignatures, submittedAt, meta:{clientIp,userAgent,logoDataUrl},
     (rowSignature:) groupKey,row,rowIndex,submittedSignature,
     (large-payload fallback:) s3Staging:{bucket,key} }
   Output: { ok:true, pdfBase64, bytes, engine:"chromium" } | { ok:false, error } */
import { S3Client, GetObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3";
import { renderHtmlToPdf } from "./chromium.mjs";
import { buildSubmissionHtml, buildRowSignatureHtml } from "./htmlBuilder.mjs";

const s3 = new S3Client({});

async function readStaging(s3Staging) {
  const out = await s3.send(new GetObjectCommand({ Bucket: s3Staging.bucket, Key: s3Staging.key }));
  const body = await out.Body.transformToString();
  try {
    await s3.send(new DeleteObjectCommand({ Bucket: s3Staging.bucket, Key: s3Staging.key }));
  } catch (_) { /* best-effort cleanup */ }
  return JSON.parse(body);
}

export const handler = async (event) => {
  try {
    let envelope = event && typeof event === "object" ? event : JSON.parse(String(event || "{}"));
    if (envelope.s3Staging?.bucket && envelope.s3Staging?.key) {
      envelope = await readStaging(envelope.s3Staging);
    }

    const jobType = envelope.jobType === "rowSignature" ? "rowSignature" : "submission";
    const html = jobType === "rowSignature"
      ? buildRowSignatureHtml(envelope)
      : buildSubmissionHtml(envelope);

    const pdf = await renderHtmlToPdf(html);
    return { ok: true, pdfBase64: pdf.toString("base64"), bytes: pdf.length, engine: "chromium" };
  } catch (error) {
    console.error("PdfRenderer failed:", error?.stack || error?.message || error);
    return { ok: false, error: String(error?.message || error) };
  }
};
