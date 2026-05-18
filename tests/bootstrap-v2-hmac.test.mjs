import assert from "node:assert/strict";
import crypto from "node:crypto";
import {
  buildBootstrapV2CanonicalString,
  verifyBootstrapV2SignedPayload
} from "../AWS/bootstrap-v2-hmac.mjs";

const method = "POST";
const path = "/tenant/bootstrap-v2/verify-signed-call";
const orgId = "00Dg5000008sWZN";
const timestamp = "2026-05-06T12:00:00.000Z";
const nonce = "6f4f8a8b72e847a8a0a8d4d6a2c86f9f";
const body = JSON.stringify({ message: "hello bootstrap v2" });
const signingSecretB64 = crypto.randomBytes(32).toString("base64");
const bodyHash = crypto.createHash("sha256").update(body, "utf8").digest("hex");

function signatureFor(overrides = {}) {
  const canonical = buildBootstrapV2CanonicalString({
    method: overrides.method || method,
    path: overrides.path || path,
    orgId: overrides.orgId || orgId,
    timestamp: overrides.timestamp || timestamp,
    nonce: overrides.nonce || nonce,
    bodyHash: overrides.bodyHash || bodyHash
  });
  return crypto
    .createHmac("sha256", Buffer.from(overrides.signingSecretB64 || signingSecretB64, "base64"))
    .update(canonical, "utf8")
    .digest("base64");
}

function headersFor(overrides = {}) {
  return {
    "x-twinaforms-org-id": overrides.orgId || orgId,
    "x-twinaforms-bootstrap-v2-timestamp": overrides.timestamp || timestamp,
    "x-twinaforms-bootstrap-v2-nonce": overrides.nonce || nonce,
    "x-twinaforms-bootstrap-v2-body-sha256": overrides.bodyHash || bodyHash,
    "x-twinaforms-bootstrap-v2-signature": overrides.signature || signatureFor(overrides),
    "x-twinaforms-bootstrap-v2-algorithm": overrides.algorithm || "HMAC-SHA256"
  };
}

{
  const result = verifyBootstrapV2SignedPayload({
    method,
    path,
    headers: headersFor(),
    body,
    signingSecretB64,
    nowMs: Date.parse(timestamp)
  });

  assert.equal(result.ok, true);
  assert.equal(result.orgId, orgId);
  assert.equal(result.bodyHash, bodyHash);
}

{
  const result = verifyBootstrapV2SignedPayload({
    method,
    path,
    headers: headersFor(),
    body: JSON.stringify({ message: "tampered" }),
    signingSecretB64,
    nowMs: Date.parse(timestamp)
  });

  assert.equal(result.ok, false);
  assert.equal(result.statusCode, 401);
  assert.match(result.error, /body hash/i);
}

{
  const result = verifyBootstrapV2SignedPayload({
    method,
    path,
    headers: headersFor({ signature: signatureFor({ bodyHash: "0".repeat(64) }) }),
    body,
    signingSecretB64,
    nowMs: Date.parse(timestamp)
  });

  assert.equal(result.ok, false);
  assert.equal(result.statusCode, 401);
}

{
  const result = verifyBootstrapV2SignedPayload({
    method,
    path,
    headers: headersFor({ timestamp: "2026-05-06T12:10:01.000Z" }),
    body,
    signingSecretB64,
    nowMs: Date.parse(timestamp)
  });

  assert.equal(result.ok, false);
  assert.equal(result.statusCode, 401);
  assert.match(result.error, /timestamp/i);
}

console.log("Bootstrap V2 HMAC verifier tests passed");
