import crypto from "crypto";

export const BOOTSTRAP_V2_SIGNATURE_WINDOW_MS = 5 * 60 * 1000;

function normalizeOrgId(orgId) {
  if (typeof orgId !== "string") {
    return orgId;
  }
  const trimmed = orgId.trim();
  return trimmed.length >= 15 ? trimmed.substring(0, 15) : trimmed;
}

function validateOrgId(orgId) {
  return typeof orgId === "string" && /^00D[A-Za-z0-9]{12,15}$/.test(normalizeOrgId(orgId));
}

function getHeaderValue(headers, name) {
  const target = String(name).toLowerCase();
  for (const [headerName, value] of Object.entries(headers || {})) {
    if (String(headerName).toLowerCase() === target) {
      return value;
    }
  }
  return undefined;
}

function sha256Hex(value) {
  return crypto.createHash("sha256").update(String(value ?? ""), "utf8").digest("hex");
}

export function buildBootstrapV2CanonicalString({
  method,
  path,
  orgId,
  timestamp,
  nonce,
  bodyHash
}) {
  return [
    String(method || "POST").trim().toUpperCase(),
    String(path || "/").trim().startsWith("/") ? String(path || "/").trim() : `/${String(path || "/").trim()}`,
    normalizeOrgId(String(orgId || "").trim()),
    String(timestamp || "").trim(),
    String(nonce || "").trim(),
    String(bodyHash || "").trim().toLowerCase()
  ].join("\n");
}

function timingSafeBase64Equals(leftValue, rightValue) {
  let left;
  let right;
  try {
    left = Buffer.from(String(leftValue || ""), "base64");
    right = Buffer.from(String(rightValue || ""), "base64");
  } catch (error) {
    return false;
  }
  if (left.length !== right.length || left.length === 0) {
    return false;
  }
  return crypto.timingSafeEqual(left, right);
}

function decodeBootstrapV2Secret(signingSecretB64) {
  if (!signingSecretB64) {
    const error = new Error("Bootstrap V2 spike secret is not configured.");
    error.statusCode = 503;
    throw error;
  }
  const secret = Buffer.from(String(signingSecretB64), "base64");
  if (secret.length < 32) {
    const error = new Error("Bootstrap V2 spike secret must be at least 256 bits.");
    error.statusCode = 500;
    throw error;
  }
  return secret;
}

export function verifyBootstrapV2SignedPayload({
  method,
  path,
  headers,
  body,
  signingSecretB64,
  nowMs = Date.now(),
  maxClockSkewMs = BOOTSTRAP_V2_SIGNATURE_WINDOW_MS
}) {
  const orgId = String(getHeaderValue(headers, "x-twinaforms-org-id") || "").trim();
  const timestamp = String(getHeaderValue(headers, "x-twinaforms-bootstrap-v2-timestamp") || "").trim();
  const nonce = String(getHeaderValue(headers, "x-twinaforms-bootstrap-v2-nonce") || "").trim();
  const bodyHash = String(getHeaderValue(headers, "x-twinaforms-bootstrap-v2-body-sha256") || "").trim().toLowerCase();
  const signature = String(getHeaderValue(headers, "x-twinaforms-bootstrap-v2-signature") || "").trim();
  const algorithm = String(getHeaderValue(headers, "x-twinaforms-bootstrap-v2-algorithm") || "").trim().toUpperCase();

  if (!validateOrgId(orgId)) {
    return { ok: false, statusCode: 400, error: "Invalid or missing org id." };
  }
  if (algorithm !== "HMAC-SHA256") {
    return { ok: false, statusCode: 400, error: "Unsupported or missing signature algorithm." };
  }
  if (!timestamp || !nonce || !bodyHash || !signature) {
    return { ok: false, statusCode: 400, error: "Missing Bootstrap V2 signature headers." };
  }

  const parsedTimestamp = Date.parse(timestamp);
  if (!Number.isFinite(parsedTimestamp)) {
    return { ok: false, statusCode: 400, error: "Invalid Bootstrap V2 timestamp." };
  }
  if (Math.abs(nowMs - parsedTimestamp) > maxClockSkewMs) {
    return { ok: false, statusCode: 401, error: "Bootstrap V2 signature timestamp is outside the allowed window." };
  }

  const actualBodyHash = sha256Hex(body);
  if (bodyHash !== actualBodyHash) {
    return { ok: false, statusCode: 401, error: "Bootstrap V2 body hash mismatch." };
  }

  const canonical = buildBootstrapV2CanonicalString({
    method,
    path,
    orgId,
    timestamp,
    nonce,
    bodyHash
  });
  const expectedSignature = crypto
    .createHmac("sha256", decodeBootstrapV2Secret(signingSecretB64))
    .update(canonical, "utf8")
    .digest("base64");

  if (!timingSafeBase64Equals(signature, expectedSignature)) {
    return { ok: false, statusCode: 401, error: "Bootstrap V2 signature mismatch." };
  }

  return {
    ok: true,
    statusCode: 200,
    orgId: normalizeOrgId(orgId),
    timestamp,
    nonce,
    bodyHash
  };
}
