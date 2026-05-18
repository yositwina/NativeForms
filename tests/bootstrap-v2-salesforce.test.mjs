import assert from "node:assert/strict";
import {
  BOOTSTRAP_V2_APEX_SIGNING_SECRET_PATH,
  BOOTSTRAP_V2_APEX_SIGNING_SECRET_FALLBACK_PATH,
  buildBootstrapV2ConnectionFields,
  buildBootstrapV2UnavailableConnectionFields,
  fetchBootstrapV2SigningSecret,
  validateBootstrapV2SigningSecretResponse
} from "../AWS/bootstrap-v2-salesforce.mjs";

const orgId = "00Dg5000008sWZN";
const secretB64 = Buffer.alloc(32, 7).toString("base64");

const validated = validateBootstrapV2SigningSecretResponse({
  success: true,
  experimental: true,
  orgId,
  signingSecretB64: secretB64,
  algorithm: "HMAC-SHA256"
}, orgId);

assert.equal(validated.orgId, orgId.substring(0, 15));
assert.equal(validated.signingSecretB64, secretB64);

assert.throws(() => validateBootstrapV2SigningSecretResponse({
  success: true,
  orgId: "00D000000000000",
  signingSecretB64: secretB64,
  algorithm: "HMAC-SHA256"
}, orgId), /org did not match/);

assert.throws(() => validateBootstrapV2SigningSecretResponse({
  success: true,
  orgId,
  signingSecretB64: Buffer.alloc(8, 1).toString("base64"),
  algorithm: "HMAC-SHA256"
}, orgId), /256-bit/);

const successFetch = async (url, request) => {
  assert.equal(url, `https://example.my.salesforce.com${BOOTSTRAP_V2_APEX_SIGNING_SECRET_PATH}`);
  assert.equal(request.method, "POST");
  assert.equal(request.headers.Authorization, "Bearer access-token");
  assert.deepEqual(JSON.parse(request.body), {
    orgId: orgId.substring(0, 15),
    purpose: "oauth-bootstrap-v2-spike"
  });
  return {
    ok: true,
    text: async () => JSON.stringify({
      success: true,
      experimental: true,
      orgId,
      signingSecretB64: secretB64,
      algorithm: "HMAC-SHA256"
    })
  };
};

const fetched = await fetchBootstrapV2SigningSecret({
  instanceUrl: "https://example.my.salesforce.com/",
  accessToken: "access-token",
  orgId,
  fetchImpl: successFetch
});
assert.equal(fetched.signingSecretB64, secretB64);
assert.equal(fetched.apexPath, BOOTSTRAP_V2_APEX_SIGNING_SECRET_PATH);

const readyFields = buildBootstrapV2ConnectionFields(fetched, "2026-05-06T12:00:00.000Z");
assert.equal(readyFields.bootstrap_v2_status, "ready");
assert.equal(readyFields.bootstrap_v2_signing_secret_b64, secretB64);
assert.equal(readyFields.bootstrap_v2_apex_path, BOOTSTRAP_V2_APEX_SIGNING_SECRET_PATH);
assert.equal(readyFields.bootstrap_v2_error, null);

let fallbackCalls = 0;
const fallbackFetch = async (url) => {
  fallbackCalls += 1;
  if (url.endsWith(BOOTSTRAP_V2_APEX_SIGNING_SECRET_PATH)) {
    return {
      ok: false,
      status: 404,
      text: async () => JSON.stringify({ error: "not found" })
    };
  }
  assert.equal(url, `https://example.my.salesforce.com${BOOTSTRAP_V2_APEX_SIGNING_SECRET_FALLBACK_PATH}`);
  return {
    ok: true,
    text: async () => JSON.stringify({
      success: true,
      experimental: true,
      orgId,
      signingSecretB64: secretB64,
      algorithm: "HMAC-SHA256"
    })
  };
};

const fallbackFetched = await fetchBootstrapV2SigningSecret({
  instanceUrl: "https://example.my.salesforce.com/",
  accessToken: "access-token",
  orgId,
  fetchImpl: fallbackFetch
});
assert.equal(fallbackCalls, 2);
assert.equal(fallbackFetched.apexPath, BOOTSTRAP_V2_APEX_SIGNING_SECRET_FALLBACK_PATH);

const unavailableFields = buildBootstrapV2UnavailableConnectionFields(
  new Error("long ".repeat(100)),
  "2026-05-06T12:00:00.000Z"
);
assert.equal(unavailableFields.bootstrap_v2_status, "not_available");
assert.equal(unavailableFields.bootstrap_v2_signing_secret_b64, null);
assert(unavailableFields.bootstrap_v2_error.length <= 243);

console.log("Bootstrap V2 Salesforce bootstrap tests passed");
