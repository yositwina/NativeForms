export const BOOTSTRAP_V2_APEX_SIGNING_SECRET_PATH =
  "/services/apexrest/twinaforms/nativeforms/bootstrap-v2/signing-secret";
export const BOOTSTRAP_V2_APEX_SIGNING_SECRET_FALLBACK_PATH =
  "/services/apexrest/nativeforms/bootstrap-v2/signing-secret";
export const BOOTSTRAP_V2_APEX_SIGNING_SECRET_PATHS = [
  BOOTSTRAP_V2_APEX_SIGNING_SECRET_PATH,
  BOOTSTRAP_V2_APEX_SIGNING_SECRET_FALLBACK_PATH
];

function normalizeOrgId(orgId) {
  if (typeof orgId !== "string") {
    return orgId;
  }
  const trimmed = orgId.trim();
  return trimmed.length >= 15 ? trimmed.substring(0, 15) : trimmed;
}

function decodeBase64Length(value) {
  try {
    return Buffer.from(String(value || ""), "base64").length;
  } catch (error) {
    return 0;
  }
}

function sanitizeBootstrapV2Error(error) {
  const rawMessage = String(error?.message || error || "").trim();
  if (!rawMessage) {
    return "Bootstrap V2 signing secret is not available.";
  }
  return rawMessage.length > 240 ? `${rawMessage.slice(0, 240)}...` : rawMessage;
}

export function validateBootstrapV2SigningSecretResponse(payload, expectedOrgId) {
  const normalizedExpectedOrgId = normalizeOrgId(expectedOrgId);
  const normalizedResponseOrgId = normalizeOrgId(String(payload?.orgId || ""));
  const signingSecretB64 = String(payload?.signingSecretB64 || "").trim();
  const algorithm = String(payload?.algorithm || "").trim().toUpperCase();

  if (payload?.success !== true) {
    throw new Error(payload?.message || "Bootstrap V2 signing secret request was not successful.");
  }
  if (!normalizedExpectedOrgId || normalizedResponseOrgId !== normalizedExpectedOrgId) {
    throw new Error("Bootstrap V2 signing secret response org did not match the OAuth org.");
  }
  if (algorithm !== "HMAC-SHA256") {
    throw new Error("Bootstrap V2 signing secret response used an unsupported algorithm.");
  }
  if (decodeBase64Length(signingSecretB64) < 32) {
    throw new Error("Bootstrap V2 signing secret response did not contain a 256-bit secret.");
  }

  return {
    orgId: normalizedResponseOrgId,
    signingSecretB64,
    algorithm,
    experimental: payload?.experimental === true
  };
}

export async function fetchBootstrapV2SigningSecret({
  instanceUrl,
  accessToken,
  orgId,
  fetchImpl = fetch
}) {
  const normalizedInstanceUrl = String(instanceUrl || "").replace(/\/+$/, "");
  const normalizedOrgId = normalizeOrgId(orgId);
  if (!normalizedInstanceUrl) {
    throw new Error("Bootstrap V2 cannot call Salesforce without an instance URL.");
  }
  if (!accessToken) {
    throw new Error("Bootstrap V2 cannot call Salesforce without an OAuth access token.");
  }
  if (!normalizedOrgId) {
    throw new Error("Bootstrap V2 cannot call Salesforce without an org id.");
  }

  const failures = [];

  for (const apexPath of BOOTSTRAP_V2_APEX_SIGNING_SECRET_PATHS) {
    const response = await fetchImpl(`${normalizedInstanceUrl}${apexPath}`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        orgId: normalizedOrgId,
        purpose: "oauth-bootstrap-v2-spike"
      })
    });
    const responseText = await response.text();
    let responsePayload = null;
    try {
      responsePayload = responseText ? JSON.parse(responseText) : {};
    } catch (error) {
      responsePayload = {};
    }

    if (response.ok) {
      return {
        ...validateBootstrapV2SigningSecretResponse(responsePayload, normalizedOrgId),
        apexPath
      };
    }

    failures.push(
      `${apexPath}: ${responsePayload?.message ||
        responsePayload?.error ||
        `status ${response.status}`}`
    );
  }

  throw new Error(`Bootstrap V2 signing secret request failed. Tried ${failures.join("; ")}`);
}

export function buildBootstrapV2ConnectionFields(result, nowIso = new Date().toISOString()) {
  return {
    bootstrap_v2_experimental: true,
    bootstrap_v2_status: "ready",
    bootstrap_v2_signing_secret_b64: result.signingSecretB64,
    bootstrap_v2_algorithm: result.algorithm,
    bootstrap_v2_apex_path: result.apexPath || BOOTSTRAP_V2_APEX_SIGNING_SECRET_PATH,
    bootstrap_v2_updated_at: nowIso,
    bootstrap_v2_error: null
  };
}

export function buildBootstrapV2UnavailableConnectionFields(error, nowIso = new Date().toISOString()) {
  return {
    bootstrap_v2_experimental: true,
    bootstrap_v2_status: "not_available",
    bootstrap_v2_signing_secret_b64: null,
    bootstrap_v2_algorithm: "HMAC-SHA256",
    bootstrap_v2_apex_path: BOOTSTRAP_V2_APEX_SIGNING_SECRET_PATH,
    bootstrap_v2_updated_at: nowIso,
    bootstrap_v2_error: sanitizeBootstrapV2Error(error)
  };
}
