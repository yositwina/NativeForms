/*
NativeForms Submit Engine - V1 Command Spec

Purpose
-------
Generic Lambda execution engine for Salesforce-backed forms.
The browser sends only the form identity and raw user-entered values.
Lambda loads the ordered submit commands from the server-side DynamoDB
form definition for that form.

Top-level payload
-----------------
{
  "publishToken": "abc123",
  "formId": "supportForm1",
  "input": {
    "email": "user@example.com",
    "problem": "Something is wrong"
  }
}

Execution model
---------------
- Commands run in array order.
- Commands are loaded from the stored server-side form definition, not from the browser.
- Later commands may reference:
  - input values:              {input.email}
  - previous stored results:   {foundContact.Id}
  - created/update ids:        {createdContact.id}
- Lambda stores command outputs under storeResultAs.
- Commands are generic. Lambda does not contain form-specific business logic.

Supported command types
-----------------------
1) findOne
   - Queries one Salesforce record by equality filters.
   - Returns first matching record or null.
   Required fields:
   - type = "findOne"
   - objectApiName
   - where (object of field/value equality filters)
   Optional:
   - fieldsToReturn (array of field API names). Default: ["Id"]
   - storeResultAs

2) create
   - Creates one Salesforce record.
   Required fields:
   - type = "create"
   - objectApiName
   - fields (object of Salesforce field values)
   Optional:
   - storeResultAs

3) update
   - Updates one Salesforce record.
   Required fields:
   - type = "update"
   - objectApiName
   - id OR fields.Id
   - fields (object of Salesforce field values)
   Optional:
   - storeResultAs

runIf support
-------------
Each command may include optional runIf:
{
  "var": "foundContact.Id",
  "isBlank": true
}
Supported conditions:
- isBlank: true
- isNotBlank: true
- equals: <value>
- notEquals: <value>

Resolution rules
----------------
- Strings may contain one whole-token expression:
    "{input.email}"
    "{foundContact.Id}"
    "{firstNotBlank(foundContact.Id, createdContact.id)}"
- Mixed embedded text is not supported in V1.
- Object and array values are resolved recursively.

V1 simplifications
------------------
- Only ordered execution, no branching graphs.
- findOne only supports simple equality filters joined by AND.
- No delete.
- No arbitrary SOQL from the client.
- No rollback across multiple commands.
- No update-or-create by external ID in V1.
- Security should later be tightened with signed tokens, object allowlists, field allowlists, CAPTCHA, etc.
*/
import https from "https";
import querystring from "querystring";
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";
import { DynamoDBClient, GetItemCommand, PutItemCommand } from "@aws-sdk/client-dynamodb";
import { S3Client, GetObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3";
import crypto from "crypto";

const FORM_SECURITY_TABLE = process.env.FORM_SECURITY_TABLE || "NativeFormsFormSecurity";
const TENANT_TABLE = process.env.TENANT_TABLE || "NativeFormsTenants";
const PLAN_TABLE = process.env.PLAN_TABLE || "NativeFormsPlans";
const SUBMISSION_LOG_TABLE = process.env.SUBMISSION_LOG_TABLE || "NativeFormsSubmissionLogs";
const CAPTCHA_SECRET_KEY = String(process.env.CAPTCHA_SECRET_KEY || "").trim();
const PUBLISH_BUCKET = process.env.PUBLISH_BUCKET || "nativeformspublish";
const SALESFORCE_API_VERSION = "v60.0";
const SALESFORCE_CONNECTION_SECRET_PREFIX = "NativeForms/SalesforceConnection";
const SUBMISSION_LOG_SCHEMA_VERSION = "v2";

const secretsClient = new SecretsManagerClient({});
const dynamoClient = new DynamoDBClient({});
const s3Client = new S3Client({});
const salesforceDescribeCache = new Map();

function jsonResponse(statusCode, payload) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type"
    },
    body: JSON.stringify(payload)
  };
}

function httpsRequest(options, body = null) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = "";

      res.on("data", (chunk) => {
        data += chunk;
      });

      res.on("end", () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: data
        });
      });
    });

    req.on("error", reject);

    if (body) {
      req.write(body);
    }

    req.end();
  });
}

async function getSecret(secretName) {
  const result = await secretsClient.send(
    new GetSecretValueCommand({ SecretId: secretName })
  );

  if (!result.SecretString) {
    throw new Error("SecretString is empty");
  }

  return JSON.parse(result.SecretString);
}

function getSalesforceConnectionSecretName(orgId) {
  return `${SALESFORCE_CONNECTION_SECRET_PREFIX}/${orgId}`;
}

function hashToken(token) {
  return crypto.createHash("sha256").update(String(token)).digest("hex");
}

function fromAttributeValue(attributeValue) {
  if (attributeValue.S != null) return attributeValue.S;
  if (attributeValue.N != null) return Number(attributeValue.N);
  if (attributeValue.BOOL != null) return attributeValue.BOOL;
  if (attributeValue.NULL) return null;
  if (attributeValue.L) return attributeValue.L.map(fromAttributeValue);
  if (attributeValue.M) {
    const obj = {};
    for (const [key, nestedValue] of Object.entries(attributeValue.M)) {
      obj[key] = fromAttributeValue(nestedValue);
    }
    return obj;
  }
  return undefined;
}

function unmarshallItem(item) {
  const unmarshalled = {};
  for (const [key, value] of Object.entries(item || {})) {
    unmarshalled[key] = fromAttributeValue(value);
  }
  return unmarshalled;
}

async function getFormSecurityRecord(formId) {
  const result = await dynamoClient.send(new GetItemCommand({
    TableName: FORM_SECURITY_TABLE,
    Key: {
      formId: { S: formId }
    }
  }));

  return result.Item ? unmarshallItem(result.Item) : null;
}

async function getTenantRecord(orgId) {
  const result = await dynamoClient.send(new GetItemCommand({
    TableName: TENANT_TABLE,
    Key: {
      orgId: { S: orgId }
    }
  }));

  return result.Item ? unmarshallItem(result.Item) : null;
}

async function getPlanDefinition(planCode) {
  const normalizedPlanCode = normalizePlanCode(planCode);
  try {
    const result = await dynamoClient.send(new GetItemCommand({
      TableName: PLAN_TABLE,
      Key: {
        planCode: { S: normalizedPlanCode }
      }
    }));

    return result.Item ? unmarshallItem(result.Item) : null;
  } catch (error) {
    if (error?.name !== "ResourceNotFoundException") {
      console.warn("Submission log plan lookup failed:", error);
    }
    return null;
  }
}

function toAttributeValue(value) {
  if (value === undefined) return undefined;
  if (value === null) return { NULL: true };
  if (typeof value === "string") return { S: value };
  if (typeof value === "number") return { N: String(value) };
  if (typeof value === "boolean") return { BOOL: value };
  if (Array.isArray(value)) {
    return {
      L: value
        .map((item) => toAttributeValue(item))
        .filter(Boolean)
    };
  }
  if (typeof value === "object") {
    const mapped = {};
    for (const [key, nestedValue] of Object.entries(value)) {
      const converted = toAttributeValue(nestedValue);
      if (converted !== undefined) {
        mapped[key] = converted;
      }
    }
    return { M: mapped };
  }
  return { S: String(value) };
}

function marshallItem(item) {
  const marshalled = {};
  for (const [key, value] of Object.entries(item || {})) {
    const converted = toAttributeValue(value);
    if (converted !== undefined) {
      marshalled[key] = converted;
    }
  }
  return marshalled;
}

function buildFailureError(message, statusCode, failureStage, extra = {}) {
  const error = new Error(message);
  error.statusCode = statusCode;
  error.failureStage = failureStage;
  Object.assign(error, extra);
  return error;
}

function generateSubmissionId(submittedAt) {
  return `${submittedAt}#${crypto.randomUUID()}`;
}

function generateSubmissionRef() {
  const timestamp = new Date()
    .toISOString()
    .replace(/[-:.TZ]/g, "")
    .slice(0, 14);
  return `NF-${timestamp}-${crypto.randomBytes(3).toString("hex").toUpperCase()}`;
}

function getUserAgent(event) {
  return event?.headers?.["user-agent"] || event?.headers?.["User-Agent"] || null;
}

function normalizePlanCode(planCode) {
  const normalizedPlan = String(planCode || "").trim().toLowerCase();
  if (normalizedPlan === "free") {
    return "free";
  }
  if (normalizedPlan === "trial") {
    return "trial";
  }
  if (normalizedPlan === "pro") {
    return "pro";
  }
  return normalizedPlan || "starter";
}

function getDefaultSubmissionLogPlanPolicy(planCode) {
  const normalizedPlan = normalizePlanCode(planCode);
  if (normalizedPlan === "free") {
    return {
      planCode: "free",
      retentionDays: 30,
      detailedLogsIncludedByPlan: false
    };
  }
  if (normalizedPlan === "trial") {
    return {
      planCode: "trial",
      retentionDays: 30,
      detailedLogsIncludedByPlan: true
    };
  }
  if (normalizedPlan === "pro") {
    return {
      planCode: "pro",
      retentionDays: 365,
      detailedLogsIncludedByPlan: true
    };
  }
  return {
    planCode: "starter",
    retentionDays: 90,
    detailedLogsIncludedByPlan: true
  };
}

function parsePositiveInteger(value) {
  if (value == null || value === "") {
    return null;
  }

  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return null;
  }

  return Math.trunc(parsed);
}

function parseSubmissionLogPublicKey(publicKeyValue) {
  if (!publicKeyValue) {
    return null;
  }

  try {
    const keyBuffer = Buffer.from(String(publicKeyValue).trim(), "base64");
    if (!keyBuffer.length) {
      return null;
    }
    return crypto.createPublicKey({
      key: keyBuffer,
      format: "der",
      type: "spki"
    });
  } catch (error) {
    return null;
  }
}

function resolveSubmissionLogPolicy(tenantRecord, planDefinition) {
  const defaultPolicy = getDefaultSubmissionLogPlanPolicy(tenantRecord?.planCode);
  const effectiveFeatureFlags = tenantRecord?.effectiveFeatureFlags || {
    enableDetailedSubmissionLogs: planDefinition?.featureFlags?.enableDetailedSubmissionLogs
  };
  const effectiveLimits = tenantRecord?.effectiveLimits || {
    submissionLogRetentionDays: planDefinition?.limits?.submissionLogRetentionDays
  };
  const detailedLogsIncludedByPlan =
    effectiveFeatureFlags?.enableDetailedSubmissionLogs == null
      ? defaultPolicy.detailedLogsIncludedByPlan
      : effectiveFeatureFlags.enableDetailedSubmissionLogs === true;
  const retentionDays =
    parsePositiveInteger(effectiveLimits?.submissionLogRetentionDays) ||
    parsePositiveInteger(planDefinition?.limits?.submissionLogRetentionDays) ||
    defaultPolicy.retentionDays;
  const publicKey = parseSubmissionLogPublicKey(tenantRecord?.submissionLogPublicKey);
  const detailMode =
    detailedLogsIncludedByPlan && !!publicKey
      ? "encrypted_detail"
      : "metadata_only";

  return {
    planCode: defaultPolicy.planCode,
    retentionDays,
    detailMode,
    keyVersion: tenantRecord?.submissionLogKeyVersion || "v2",
    publicKey,
    detailedLogsIncludedByPlan
  };
}

function encryptSubmissionLogDetail(detailPayload, publicKey, keyVersion) {
  if (!publicKey) {
    throw new Error("Submission log public key is invalid");
  }

  const dataKey = crypto.randomBytes(32);
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv("aes-256-cbc", dataKey, iv);
  const plaintext = Buffer.from(JSON.stringify(detailPayload), "utf8");
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const encryptedDataKey = crypto.publicEncrypt(
    {
      key: publicKey,
      oaepHash: "sha256"
    },
    dataKey
  );

  return {
    detailCiphertextB64: ciphertext.toString("base64"),
    detailIvB64: iv.toString("base64"),
    detailEncryptedKeyB64: encryptedDataKey.toString("base64"),
    detailKeyVersion: keyVersion || "v2",
    detailSchemaVersion: SUBMISSION_LOG_SCHEMA_VERSION
  };
}

function getFailureStage(error, fallbackStage = "system") {
  if (error?.failureStage) {
    return error.failureStage;
  }

  const message = String(error?.message || "").toLowerCase();
  if (message.includes("captcha") || message.includes("missing required field") || message.includes("invalid publish token")) {
    return "validation";
  }
  if (message.includes("command") || message.includes("allowed") || message.includes("unsupported")) {
    return "mapping";
  }
  if (
    message.includes("token refresh failed") ||
    message.includes("query failed") ||
    message.includes("create failed") ||
    message.includes("update failed") ||
    message.includes("delete failed")
  ) {
    return "salesforce";
  }
  return fallbackStage;
}

function maybeGetSubmitterEmail(inputPayload) {
  const input = inputPayload?.input || {};
  for (const candidate of ["email", "Email", "emailAddress", "EmailAddress"]) {
    if (input[candidate]) {
      return String(input[candidate]);
    }
  }
  return null;
}

function extractPrimaryRecordId(results) {
  for (let index = results.length - 1; index >= 0; index -= 1) {
    const result = results[index];
    if (result?.id) {
      return result.id;
    }
    if (Array.isArray(result?.createdIds) && result.createdIds.length > 0) {
      return result.createdIds[0];
    }
    if (Array.isArray(result?.updatedIds) && result.updatedIds.length > 0) {
      return result.updatedIds[0];
    }
  }
  return null;
}

function buildCommandTraceSnapshot(command, context) {
  const snapshot = {
    commandKey: command?.commandKey || null,
    type: command?.type || null,
    objectApiName: command?.objectApiName || null
  };

  if (command?.type === "findOne") {
    if (command.where) {
      snapshot.where = resolveValue(command.where, context);
    }
    if (command.whereClause) {
      snapshot.whereClause = interpolateWhereClause(command.whereClause, context);
    }
    if (Array.isArray(command.fieldsToReturn)) {
      snapshot.fieldsToReturn = command.fieldsToReturn;
    }
    return snapshot;
  }

  if (command?.type === "create" || command?.type === "update") {
    snapshot.fields = resolveValue(command.fields || {}, context);
    if (command.id) {
      snapshot.id = resolveValue(command.id, context);
    }
    return snapshot;
  }

  if (command?.type === "delete") {
    snapshot.id = resolveValue(command.id, context);
    return snapshot;
  }

  if (command?.type === "upsertMany") {
    snapshot.rows = resolveRowsSource(command.rows, context);
    snapshot.fields = resolveValue(command.fields || {}, context);
    snapshot.relationshipField = command.relationshipField || null;
    if (command.relationshipValue !== undefined) {
      snapshot.relationshipValue = resolveValue(command.relationshipValue, context);
    }
    if (command.deleteIds !== undefined) {
      snapshot.deleteIds = resolveValue(command.deleteIds, context);
    }
    return snapshot;
  }

  return snapshot;
}

function buildErrorDetail(error) {
  return {
    message: error?.message || "Unknown submission error",
    failureStage: getFailureStage(error),
    statusCode: error?.statusCode || null,
    commandKey: error?.commandKey || null,
    commandType: error?.commandType || null,
    objectApiName: error?.objectApiName || null,
    responseBody: error?.responseBody || null
  };
}

async function writeSubmissionLog(item) {
  await dynamoClient.send(new PutItemCommand({
    TableName: SUBMISSION_LOG_TABLE,
    Item: marshallItem(item)
  }));
}

async function writeSubmissionLogSafely({
  tenantRecord,
  formSecurity,
  inputPayload,
  event,
  submissionId,
  submissionRef,
  submittedAt,
  startedAtMs,
  outcome,
  failureStage,
  results,
  commandTrace,
  error
}) {
  if (!formSecurity?.orgId) {
    return;
  }

  try {
    const planDefinition = await getPlanDefinition(tenantRecord?.planCode);
    const submissionLogPolicy = resolveSubmissionLogPolicy(tenantRecord, planDefinition);
    const expiresAt = Math.floor(new Date(submittedAt).getTime() / 1000) + (submissionLogPolicy.retentionDays * 86400);
    const baseItem = {
      tenantId: formSecurity.orgId,
      submittedAtSubmissionId: submissionId,
      submissionId,
      submissionRef,
      formId: formSecurity.formId || inputPayload?.formId || null,
      formVersionId: formSecurity.publishedVersionId || null,
      submittedAt,
      outcome,
      failureStage,
      detailMode: submissionLogPolicy.detailMode,
      recordId: outcome === "success" ? extractPrimaryRecordId(results || []) : null,
      expiresAt,
      tenantFormKey: `${formSecurity.orgId}#${formSecurity.formId || inputPayload?.formId || "unknown"}`,
      tenantOutcomeKey: `${formSecurity.orgId}#${outcome}`
    };

    if (submissionLogPolicy.detailMode === "encrypted_detail") {
      const detailPayload = {
        tenantId: formSecurity.orgId,
        planCode: submissionLogPolicy.planCode,
        submissionId,
        submissionRef,
        formId: formSecurity.formId || inputPayload?.formId || null,
        formVersionId: formSecurity.publishedVersionId || null,
        submittedAt,
        outcome,
        failureStage,
        durationMs: Math.max(Date.now() - startedAtMs, 0),
        submitterEmail: maybeGetSubmitterEmail(inputPayload),
        submittedPayload: inputPayload?.input || {},
        prefillSnapshot: inputPayload?.prefillSnapshot || null,
        commandTrace: commandTrace || [],
        partialResults: results || [],
        error: error ? buildErrorDetail(error) : null,
        technicalContext: {
          ipAddress: getClientIp(event),
          userAgent: getUserAgent(event),
          securityMode: formSecurity.securityMode || null
        }
      };

      Object.assign(
        baseItem,
        encryptSubmissionLogDetail(
          detailPayload,
          submissionLogPolicy.publicKey,
          submissionLogPolicy.keyVersion
        )
      );
    }

    await writeSubmissionLog(baseItem);
  } catch (logError) {
    console.error("NativeForms submission log write failed:", logError);
  }
}

function deriveTenantRuntimeStatus(tenantRecord) {
  if (!tenantRecord) {
    return {
      status: "missing",
      reason: "Owning tenant was not found"
    };
  }

  const normalizedStatus = String(tenantRecord.status || "").toLowerCase();
  if (["blocked", "suspended"].includes(normalizedStatus) || tenantRecord.isActive === false) {
    return {
      status: "blocked",
      reason: tenantRecord.statusReason || "Data could not be updated in Salesforce because this customer is blocked."
    };
  }

  return {
    status: normalizedStatus || "active",
    reason: tenantRecord.statusReason || ""
  };
}

function ensureFormToken(formSecurity, publishToken, options = {}) {
  const requireSubmitDefinition = options.requireSubmitDefinition !== false;
  if (!publishToken) {
    throw buildFailureError("Missing required field: publishToken", 401, "validation");
  }

  if (!formSecurity || formSecurity.status !== "published") {
    throw buildFailureError("Form is not published", 403, "validation");
  }

  if (formSecurity.tokenHash !== hashToken(publishToken)) {
    throw buildFailureError("Unauthorized: invalid publish token", 401, "validation");
  }

  if (requireSubmitDefinition && !formSecurity.submitPolicy) {
    throw buildFailureError("Submit policy is not configured for this form", 403, "mapping");
  }

  if (
    requireSubmitDefinition &&
    (!formSecurity.submitDefinition || !Array.isArray(formSecurity.submitDefinition.commands))
  ) {
    throw buildFailureError("Submit definition is not configured for this form", 403, "mapping");
  }
}

async function ensureActiveTenantForForm(formSecurity) {
  if (!formSecurity?.orgId) {
    const error = new Error("Form is missing owning orgId");
    error.statusCode = 403;
    throw error;
  }

  const tenantRecord = await getTenantRecord(formSecurity.orgId);
  const runtimeStatus = deriveTenantRuntimeStatus(tenantRecord);
  if (runtimeStatus.status === "blocked") {
    const error = new Error(runtimeStatus.reason);
    error.statusCode = 403;
    throw error;
  }

  return tenantRecord;
}

function isRiskySubmitCommand(commandType) {
  return ["update", "delete", "upsertMany"].includes(commandType);
}

function allowsCommandForSecurityMode(commandType, securityMode) {
  const mode = securityMode || "public-create";
  if (!isRiskySubmitCommand(commandType)) {
    return true;
  }
  if (mode === "secure-edit") {
    return true;
  }
  if (mode === "public-find-update-create" && (commandType === "update" || commandType === "create" || commandType === "findOne")) {
    return true;
  }
  return false;
}

function validateFieldsForObject(objectApiName, fields, allowedWriteFields) {
  if (!fields || typeof fields !== "object") {
    return;
  }

  const allowed = allowedWriteFields?.[objectApiName] || [];
  for (const fieldName of Object.keys(fields)) {
    if (!allowed.includes(fieldName)) {
      throw new Error(`Field '${fieldName}' is not allowed for object '${objectApiName}'`);
    }
  }
}

function validateSubmitCommandAgainstPolicy(command, formSecurity) {
  const submitPolicy = formSecurity.submitPolicy || {};
  const allowedCommands = submitPolicy.allowedCommands || [];
  const allowedObjects = submitPolicy.allowedObjects || [];
  const allowedWriteFields = submitPolicy.allowedWriteFields || {};

  if (!allowedCommands.includes(command.type)) {
    throw new Error(`Command type '${command.type}' is not allowed for submit on form '${formSecurity.formId}'`);
  }

  if (command.objectApiName && !allowedObjects.includes(command.objectApiName)) {
    throw new Error(`Object '${command.objectApiName}' is not allowed for submit on form '${formSecurity.formId}'`);
  }

  if (!allowsCommandForSecurityMode(command.type, formSecurity.securityMode)) {
    throw new Error(`Security mode '${formSecurity.securityMode}' does not allow command '${command.type}'`);
  }

  if (command.type === "create" || command.type === "update") {
    validateFieldsForObject(command.objectApiName, command.fields, allowedWriteFields);
  }

  if (command.type === "upsertMany") {
    validateFieldsForObject(command.objectApiName, command.fields, allowedWriteFields);
    if (command.relationshipField) {
      const allowed = allowedWriteFields?.[command.objectApiName] || [];
      if (!allowed.includes(command.relationshipField)) {
        throw new Error(`Relationship field '${command.relationshipField}' is not allowed for object '${command.objectApiName}'`);
      }
    }
  }
}

async function refreshAccessToken(secret, loginUrl) {
  const tokenBody = querystring.stringify({
    grant_type: "refresh_token",
    client_id: secret.client_id,
    client_secret: secret.client_secret,
    refresh_token: secret.refresh_token
  });

  const response = await httpsRequest(
    {
      hostname: new URL(loginUrl).hostname,
      path: "/services/oauth2/token",
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Content-Length": Buffer.byteLength(tokenBody)
      }
    },
    tokenBody
  );

  if (response.statusCode !== 200) {
    throw buildFailureError(
      `Token refresh failed. Status: ${response.statusCode}. Body: ${response.body}`,
      502,
      "salesforce",
      {
        responseBody: response.body
      }
    );
  }

  return JSON.parse(response.body).access_token;
}

function assertSecret(secret) {
  if (!secret.client_id || !secret.client_secret || !secret.refresh_token || !secret.instance_url) {
    throw new Error("Secret is missing required fields");
  }
}

function base64UrlEncode(value) {
  return Buffer.from(value)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function base64UrlDecode(value) {
  const normalized = String(value || "")
    .replace(/-/g, "+")
    .replace(/_/g, "/");
  const padding = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  return Buffer.from(normalized + padding, "base64").toString("utf8");
}

function buildUploadSigningSecret(tenantRecord) {
  return String(tenantRecord?.secret || "");
}

function verifySignedUploadToken(tenantRecord, token) {
  const signingSecret = buildUploadSigningSecret(tenantRecord);
  if (!signingSecret) {
    return null;
  }

  const parts = String(token || "").split(".");
  if (parts.length !== 2) {
    return null;
  }

  const [encodedPayload, signature] = parts;
  const expectedSignature = crypto
    .createHmac("sha256", signingSecret)
    .update(encodedPayload)
    .digest("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
  if (signature !== expectedSignature) {
    return null;
  }

  try {
    return JSON.parse(base64UrlDecode(encodedPayload));
  } catch (error) {
    return null;
  }
}

function getEffectiveFeatureFlagsForTenant(tenantRecord, planDefinition) {
  return {
    ...(planDefinition?.featureFlags || {}),
    ...(tenantRecord?.planFeatureFlags || {}),
    ...(tenantRecord?.featureFlags || {}),
    ...(tenantRecord?.planOverrides?.featureFlags || {}),
    ...(tenantRecord?.effectiveFeatureFlags || {})
  };
}

function getUploadFieldDefinition(formSecurity, fieldKey) {
  const normalizedFieldKey = String(fieldKey || "").trim();
  if (!normalizedFieldKey) {
    return null;
  }
  const uploadFields = Array.isArray(formSecurity?.uploadFields) ? formSecurity.uploadFields : [];
  return uploadFields.find((item) => String(item?.fieldKey || "").trim() === normalizedFieldKey) || null;
}

function normalizeSubmittedUploadMap(fileUploads) {
  if (!fileUploads || typeof fileUploads !== "object" || Array.isArray(fileUploads)) {
    return {};
  }
  return fileUploads;
}

function resolveUploadTargetRecordId(targetSubmitActionKey, results) {
  if (!targetSubmitActionKey) {
    return null;
  }

  const exactMatch = (results || []).find((result) => result?.commandKey === targetSubmitActionKey && result?.id);
  if (exactMatch?.id) {
    return exactMatch.id;
  }

  const createFallback = (results || []).find((result) => result?.commandKey === `${targetSubmitActionKey}_create` && result?.id);
  if (createFallback?.id) {
    return createFallback.id;
  }

  const prefixFallback = [...(results || [])]
    .reverse()
    .find((result) => String(result?.commandKey || "").startsWith(`${targetSubmitActionKey}`) && result?.id);
  return prefixFallback?.id || null;
}

function streamToBuffer(streamBody) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    streamBody.on("data", (chunk) => chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)));
    streamBody.on("error", reject);
    streamBody.on("end", () => resolve(Buffer.concat(chunks)));
  });
}

function normalizeSecretCodeConfig(formSecurity) {
  const raw = formSecurity?.secretCodeConfig;
  if (!raw || typeof raw !== "object") {
    return {
      enabled: false,
      expiryMinutes: 10,
      maxAttempts: 5,
      allowResend: true
    };
  }

  const expiryMinutes = parsePositiveInteger(raw.expiryMinutes) || 10;
  const maxAttempts = parsePositiveInteger(raw.maxAttempts) || 5;

  return {
    enabled: raw.enabled === true,
    expiryMinutes,
    maxAttempts,
    allowResend: raw.allowResend !== false,
    introText: typeof raw.introText === "string" ? raw.introText : "",
    sentMessage: typeof raw.sentMessage === "string" ? raw.sentMessage : "",
    invalidMessage: typeof raw.invalidMessage === "string" ? raw.invalidMessage : "",
    verifiedMessage: typeof raw.verifiedMessage === "string" ? raw.verifiedMessage : ""
  };
}

function normalizeSecretCodeAction(action) {
  const normalized = String(action || "").trim();
  return normalized === "sendCode" || normalized === "verifyCode" ? normalized : "";
}

async function callSalesforceApex(instanceUrl, accessToken, path, payload) {
  const url = new URL(instanceUrl);
  const body = JSON.stringify(payload || {});
  const response = await httpsRequest(
    {
      hostname: url.hostname,
      path,
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(body)
      }
    },
    body
  );

  let data = {};
  try {
    data = response.body ? JSON.parse(response.body) : {};
  } catch (error) {
    data = {};
  }

  if (response.statusCode < 200 || response.statusCode >= 300 || data?.success === false) {
    throw buildFailureError(
      data?.message || `Apex request failed. Status: ${response.statusCode}.`,
      response.statusCode >= 500 ? 502 : 400,
      "salesforce",
      {
        responseBody: response.body
      }
    );
  }

  return data;
}

function buildSecretVerificationSigningSecret(secret) {
  return String(secret?.client_secret || "");
}

function createSecretVerificationToken(formSecurity, email, sessionId, secret) {
  const signingSecret = buildSecretVerificationSigningSecret(secret);
  if (!signingSecret) {
    throw buildFailureError("Secret verification signing secret is missing", 500, "system");
  }

  const expiryMinutes = Math.max(5, normalizeSecretCodeConfig(formSecurity).expiryMinutes);
  const payload = {
    kind: "secretVerification",
    orgId: formSecurity.orgId,
    formId: formSecurity.formId,
    publishedVersionId: formSecurity.publishedVersionId || null,
    email: String(email || "").trim().toLowerCase(),
    sessionId: String(sessionId || "").trim(),
    exp: Math.floor(Date.now() / 1000) + (expiryMinutes * 60)
  };
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signature = crypto
    .createHmac("sha256", signingSecret)
    .update(encodedPayload)
    .digest("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
  return `${encodedPayload}.${signature}`;
}

function verifySecretVerificationToken(formSecurity, token, sessionId, secret, email) {
  const signingSecret = buildSecretVerificationSigningSecret(secret);
  if (!signingSecret) {
    return false;
  }

  const parts = String(token || "").split(".");
  if (parts.length !== 2) {
    return false;
  }

  const [encodedPayload, signature] = parts;
  const expectedSignature = crypto
    .createHmac("sha256", signingSecret)
    .update(encodedPayload)
    .digest("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
  if (signature !== expectedSignature) {
    return false;
  }

  let payload;
  try {
    payload = JSON.parse(base64UrlDecode(encodedPayload));
  } catch (error) {
    return false;
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  return (
    payload?.kind === "secretVerification" &&
    payload?.orgId === formSecurity.orgId &&
    payload?.formId === formSecurity.formId &&
    String(payload?.publishedVersionId || "") === String(formSecurity.publishedVersionId || "") &&
    String(payload?.sessionId || "") === String(sessionId || "") &&
    String(payload?.email || "").trim().toLowerCase() === String(email || "").trim().toLowerCase() &&
    Number(payload?.exp || 0) > nowSeconds
  );
}

function ensureSecretVerificationAllowed(formSecurity) {
  const secretCodeConfig = normalizeSecretCodeConfig(formSecurity);
  if (!secretCodeConfig.enabled) {
    throw buildFailureError("Secret code verification is not enabled for this form.", 403, "validation");
  }
  return secretCodeConfig;
}

function escapeSoqlValue(value) {
  return String(value)
    .replace(/\\/g, "\\\\")
    .replace(/'/g, "\\'");
}

function getByPath(obj, path) {
  if (!path) return undefined;

  const normalized = String(path).replace(/\[(\d+)\]/g, ".$1");
  return normalized.split(".").reduce((acc, key) => {
    if (acc == null) return undefined;
    return acc[key];
  }, obj);
}

function splitArgs(value) {
  const args = [];
  let current = "";
  let depth = 0;

  for (const char of value) {
    if (char === "," && depth === 0) {
      if (current.trim()) {
        args.push(current.trim());
      }
      current = "";
      continue;
    }

    if (char === "(") depth += 1;
    if (char === ")") depth -= 1;
    current += char;
  }

  if (current.trim()) {
    args.push(current.trim());
  }

  return args;
}

function stripQuotes(value) {
  if (
    (value.startsWith("'") && value.endsWith("'")) ||
    (value.startsWith("\"") && value.endsWith("\""))
  ) {
    return value.slice(1, -1);
  }

  return value;
}

function resolveToken(token, context) {
  if (token === "true") return true;
  if (token === "false") return false;
  if (token === "null") return null;
  if (/^-?\d+(\.\d+)?$/.test(token)) return Number(token);
  if ((/^['"].*['"]$/).test(token)) return stripQuotes(token);
  return getByPath(context, token);
}

function parseExpression(expr) {
  const trimmed = String(expr).trim();

  for (const fnName of ["firstNotBlank", "concat", "trim"]) {
    if (trimmed.startsWith(`${fnName}(`) && trimmed.endsWith(")")) {
      const inner = trimmed.slice(fnName.length + 1, -1);
      return {
        type: "function",
        fnName,
        args: splitArgs(inner)
      };
    }
  }

  return { type: "path", path: trimmed };
}

function resolveExpression(expr, context) {
  const parsed = parseExpression(expr);

  if (parsed.type === "path") {
    return resolveToken(parsed.path, context);
  }

  if (parsed.fnName === "firstNotBlank") {
    for (const arg of parsed.args) {
      const value = resolveToken(arg, context);
      if (value !== undefined && value !== null && value !== "") {
        return value;
      }
    }
    return null;
  }

  if (parsed.fnName === "concat") {
    return parsed.args
      .map((arg) => {
        const value = resolveToken(arg, context);
        return value == null ? "" : String(value);
      })
      .join("");
  }

  if (parsed.fnName === "trim") {
    if (parsed.args.length === 0) {
      return "";
    }

    const value = resolveToken(parsed.args[0], context);
    return value == null ? "" : String(value).trim();
  }

  return undefined;
}

function resolveValue(value, context) {
  if (typeof value === "string") {
    const match = value.match(/^\{(.+)\}$/);
    if (match) {
      return resolveExpression(match[1], context);
    }
    return value;
  }

  if (Array.isArray(value)) {
    return value.map((item) => resolveValue(item, context));
  }

  if (value && typeof value === "object") {
    const out = {};
    for (const [key, nestedValue] of Object.entries(value)) {
      out[key] = resolveValue(nestedValue, context);
    }
    return out;
  }

  return value;
}

function shouldRunCommand(runIf, context) {
  if (!runIf) return true;

  const actual = getByPath(context, runIf.var);

  if (runIf.isBlank === true) {
    return actual === undefined || actual === null || actual === "";
  }

  if (runIf.isNotBlank === true) {
    return !(actual === undefined || actual === null || actual === "");
  }

  if (Object.prototype.hasOwnProperty.call(runIf, "equals")) {
    return actual === runIf.equals;
  }

  if (Object.prototype.hasOwnProperty.call(runIf, "notEquals")) {
    return actual !== runIf.notEquals;
  }

  return true;
}

function buildRowContext(context, row, rowIndex) {
  return {
    ...context,
    row,
    rowIndex
  };
}

function resolveRowsSource(rows, context) {
  const resolvedRows = resolveValue(rows, context);
  return Array.isArray(resolvedRows) ? resolvedRows : [];
}

async function getSalesforceObjectDescribe(instanceUrl, accessToken, objectApiName) {
  const cacheKey = `${instanceUrl}::${objectApiName}`;
  if (salesforceDescribeCache.has(cacheKey)) {
    return salesforceDescribeCache.get(cacheKey);
  }

  const url = new URL(instanceUrl);
  const response = await httpsRequest({
    hostname: url.hostname,
    path: `/services/data/${SALESFORCE_API_VERSION}/sobjects/${encodeURIComponent(objectApiName)}/describe`,
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`
    }
  });

  if (response.statusCode !== 200) {
    throw buildFailureError(
      `Describe failed. Status: ${response.statusCode}. Body: ${response.body}`,
      response.statusCode >= 500 ? 502 : 400,
      "salesforce",
      {
        responseBody: response.body
      }
    );
  }

  const parsed = JSON.parse(response.body || "{}");
  salesforceDescribeCache.set(cacheKey, parsed);
  return parsed;
}

function parseFlexibleDateString(value) {
  const raw = String(value || "").trim();
  if (!raw) {
    return null;
  }

  let match = raw.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (match) {
    const year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);
    const test = new Date(Date.UTC(year, month - 1, day));
    if (test.getUTCFullYear() === year && test.getUTCMonth() + 1 === month && test.getUTCDate() === day) {
      return { year, month, day };
    }
    return null;
  }

  const normalized = raw.replace(/[.\-]/g, "/");
  match = normalized.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (!match) {
    return null;
  }

  const first = Number(match[1]);
  const second = Number(match[2]);
  const year = Number(match[3]);
  const candidates = [
    { month: first, day: second },
    { month: second, day: first }
  ];

  for (const candidate of candidates) {
    const test = new Date(Date.UTC(year, candidate.month - 1, candidate.day));
    if (
      test.getUTCFullYear() === year &&
      test.getUTCMonth() + 1 === candidate.month &&
      test.getUTCDate() === candidate.day
    ) {
      return {
        year,
        month: candidate.month,
        day: candidate.day
      };
    }
  }

  return null;
}

function formatDatePartsAsIso(parts) {
  if (!parts) {
    return null;
  }
  const year = String(parts.year).padStart(4, "0");
  const month = String(parts.month).padStart(2, "0");
  const day = String(parts.day).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

async function coerceFieldsForSalesforce(instanceUrl, accessToken, objectApiName, fields) {
  if (!fields || typeof fields !== "object" || Array.isArray(fields)) {
    return fields;
  }

  const describe = await getSalesforceObjectDescribe(instanceUrl, accessToken, objectApiName);
  const fieldTypeByName = {};
  for (const field of describe?.fields || []) {
    if (field?.name) {
      fieldTypeByName[field.name] = field.type;
    }
  }

  const coerced = { ...fields };
  for (const [fieldName, value] of Object.entries(coerced)) {
    if (value == null || value === "") {
      continue;
    }

    const fieldType = fieldTypeByName[fieldName];
    if (fieldType === "date") {
      const parsed = parseFlexibleDateString(value);
      if (parsed) {
        coerced[fieldName] = formatDatePartsAsIso(parsed);
      }
    }
  }

  return coerced;
}

async function querySalesforce(instanceUrl, accessToken, soql) {
  const url = new URL(instanceUrl);
  const path = `/services/data/${SALESFORCE_API_VERSION}/query?q=${encodeURIComponent(soql)}`;

  const response = await httpsRequest({
    hostname: url.hostname,
    path,
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`
    }
  });

  if (response.statusCode !== 200) {
    throw buildFailureError(
      `Query failed. Status: ${response.statusCode}. Body: ${response.body}`,
      response.statusCode >= 500 ? 502 : 400,
      "salesforce",
      {
        responseBody: response.body
      }
    );
  }

  return JSON.parse(response.body);
}

function getClientIp(event) {
  const sourceIp = event?.requestContext?.http?.sourceIp;
  if (sourceIp) {
    return sourceIp;
  }

  const forwardedFor = event?.headers?.["x-forwarded-for"] || event?.headers?.["X-Forwarded-For"];
  if (!forwardedFor) {
    return null;
  }

  return String(forwardedFor).split(",")[0].trim() || null;
}

async function verifyCaptcha(formSecurity, inputPayload, event) {
  const captchaConfig = formSecurity?.captcha;
  if (!captchaConfig || captchaConfig.enabled !== true) {
    return;
  }

  if (!CAPTCHA_SECRET_KEY) {
    throw buildFailureError(
      "CAPTCHA is enabled for this form, but the server is missing the shared CAPTCHA secret key.",
      500,
      "system"
    );
  }

  const token =
    inputPayload?.input?.captchaToken ||
    inputPayload?.input?.["g-recaptcha-response"] ||
    "";
  if (!token) {
    throw buildFailureError("Please complete the CAPTCHA.", 400, "validation");
  }

  const verifyBody = querystring.stringify({
    secret: CAPTCHA_SECRET_KEY,
    response: token,
    remoteip: getClientIp(event) || undefined
  });

  const response = await httpsRequest(
    {
      hostname: "www.google.com",
      path: "/recaptcha/api/siteverify",
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Content-Length": Buffer.byteLength(verifyBody)
      }
    },
    verifyBody
  );

  if (response.statusCode !== 200) {
    throw buildFailureError(
      `CAPTCHA verification failed. Status: ${response.statusCode}.`,
      502,
      "system",
      {
        responseBody: response.body
      }
    );
  }

  const result = JSON.parse(response.body || "{}");
  if (result.success !== true) {
    const codes = Array.isArray(result["error-codes"]) ? result["error-codes"].join(", ") : "";
    throw buildFailureError(
      codes ? `CAPTCHA verification failed: ${codes}` : "CAPTCHA verification failed.",
      400,
      "validation",
      {
        responseBody: response.body
      }
    );
  }
}

async function createSalesforceRecord(instanceUrl, accessToken, objectApiName, fields) {
  const payload = JSON.stringify(fields);
  const url = new URL(instanceUrl);

  const response = await httpsRequest(
    {
      hostname: url.hostname,
      path: `/services/data/${SALESFORCE_API_VERSION}/sobjects/${encodeURIComponent(objectApiName)}`,
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(payload)
      }
    },
    payload
  );

  if (response.statusCode !== 201) {
    throw buildFailureError(
      `Create failed. Status: ${response.statusCode}. Body: ${response.body}`,
      response.statusCode >= 500 ? 502 : 400,
      "salesforce",
      {
        responseBody: response.body
      }
    );
  }

  return JSON.parse(response.body);
}

async function updateSalesforceRecord(instanceUrl, accessToken, objectApiName, id, fields) {
  const payload = JSON.stringify(fields);
  const url = new URL(instanceUrl);

  const response = await httpsRequest(
    {
      hostname: url.hostname,
      path: `/services/data/${SALESFORCE_API_VERSION}/sobjects/${encodeURIComponent(objectApiName)}/${encodeURIComponent(id)}`,
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(payload)
      }
    },
    payload
  );

  if (response.statusCode !== 204) {
    throw buildFailureError(
      `Update failed. Status: ${response.statusCode}. Body: ${response.body}`,
      response.statusCode >= 500 ? 502 : 400,
      "salesforce",
      {
        responseBody: response.body
      }
    );
  }

  return { id, success: true };
}

async function deleteSalesforceRecord(instanceUrl, accessToken, objectApiName, id) {
  const url = new URL(instanceUrl);

  const response = await httpsRequest({
    hostname: url.hostname,
    path: `/services/data/${SALESFORCE_API_VERSION}/sobjects/${encodeURIComponent(objectApiName)}/${encodeURIComponent(id)}`,
    method: "DELETE",
    headers: {
      Authorization: `Bearer ${accessToken}`
    }
  });

  if (response.statusCode !== 204) {
    throw buildFailureError(
      `Delete failed. Status: ${response.statusCode}. Body: ${response.body}`,
      response.statusCode >= 500 ? 502 : 400,
      "salesforce",
      {
        responseBody: response.body
      }
    );
  }

  return { id, success: true };
}

async function createSalesforceFileVersion(instanceUrl, accessToken, fields) {
  return createSalesforceRecord(instanceUrl, accessToken, "ContentVersion", fields);
}

async function finalizeUploadedFiles({
  tenantRecord,
  formSecurity,
  inputPayload,
  results,
  sf
}) {
  const fileUploadSessionId = String(inputPayload?.input?.fileUploadSessionId || "").trim();
  const submittedUploadMap = normalizeSubmittedUploadMap(inputPayload?.input?.fileUploads);
  const fieldKeys = Object.keys(submittedUploadMap);
  if (!fieldKeys.length) {
    return [];
  }

  const planDefinition = await getPlanDefinition(tenantRecord?.planCode);
  const effectiveFeatureFlags = getEffectiveFeatureFlagsForTenant(tenantRecord, planDefinition);
  if (effectiveFeatureFlags.enableProLoadFile !== true) {
    throw buildFailureError("File Uploads are not available for this tenant.", 403, "validation");
  }

  const finalizedFiles = [];
  for (const fieldKey of fieldKeys) {
    const uploadField = getUploadFieldDefinition(formSecurity, fieldKey);
    if (!uploadField) {
      throw buildFailureError(`File Upload is not configured for field '${fieldKey}'.`, 400, "mapping");
    }

    const targetRecordId = resolveUploadTargetRecordId(uploadField.targetSubmitActionKey, results);
    if (!targetRecordId) {
      throw buildFailureError(
        `No saved record was available for file upload field '${fieldKey}'.`,
        400,
        "mapping"
      );
    }

    const uploadRefs = Array.isArray(submittedUploadMap[fieldKey]) ? submittedUploadMap[fieldKey] : [];
    for (const uploadRef of uploadRefs) {
      const uploadToken = String(uploadRef?.uploadToken || "").trim();
      const uploadTokenPayload = verifySignedUploadToken(tenantRecord, uploadToken);
      if (!uploadTokenPayload) {
        throw buildFailureError("One of the uploaded files has an invalid upload token.", 400, "validation");
      }

      const nowSeconds = Math.floor(Date.now() / 1000);
      if (Number(uploadTokenPayload.exp || 0) <= nowSeconds) {
        throw buildFailureError("One of the uploaded files has expired. Please upload it again.", 400, "validation");
      }

      if (
        uploadTokenPayload.kind !== "fileUpload" ||
        uploadTokenPayload.orgId !== formSecurity.orgId ||
        uploadTokenPayload.formId !== formSecurity.formId ||
        String(uploadTokenPayload.publishedVersionId || "") !== String(formSecurity.publishedVersionId || "") ||
        String(uploadTokenPayload.fieldKey || "") !== String(fieldKey) ||
        String(uploadTokenPayload.sessionId || "") !== fileUploadSessionId
      ) {
        throw buildFailureError("One of the uploaded files does not belong to this form submission.", 400, "validation");
      }

      const objectKey = String(uploadTokenPayload.objectKey || "").trim();
      if (!objectKey) {
        throw buildFailureError("One of the uploaded files is missing its staged object reference.", 400, "validation");
      }

      const s3Object = await s3Client.send(new GetObjectCommand({
        Bucket: PUBLISH_BUCKET,
        Key: objectKey
      }));
      const fileBuffer = await streamToBuffer(s3Object.Body);
      if (!fileBuffer.length) {
        throw buildFailureError("One of the uploaded files is empty.", 400, "validation");
      }

      const fileName = String(uploadTokenPayload.fileName || uploadRef?.fileName || "upload.bin");
      const dotIndex = fileName.lastIndexOf(".");
      const title = dotIndex > 0 ? fileName.slice(0, dotIndex) : fileName;
      const versionResult = await createSalesforceFileVersion(
        sf.instanceUrl,
        sf.accessToken,
        {
          Title: title,
          PathOnClient: fileName,
          VersionData: fileBuffer.toString("base64"),
          FirstPublishLocationId: targetRecordId
        }
      );

      finalizedFiles.push({
        fieldKey,
        fileName,
        targetRecordId,
        contentVersionId: versionResult.id
      });

      try {
        await s3Client.send(new DeleteObjectCommand({
          Bucket: PUBLISH_BUCKET,
          Key: objectKey
        }));
      } catch (error) {
        console.warn("Failed to delete staged upload after Salesforce finalization:", objectKey, error);
      }
    }
  }

  return finalizedFiles;
}

async function executeUpsertManyCommand(command, context, sf) {
  const { instanceUrl, accessToken } = sf;

  if (!command.objectApiName || !command.rows || !command.fields) {
    throw new Error(`upsertMany command '${command.commandKey || "unknown"}' is missing objectApiName, rows, or fields`);
  }

  const rows = resolveRowsSource(command.rows, context);
  const idField = command.idField || "Id";
  const relationshipValue = command.relationshipValue
    ? resolveValue(command.relationshipValue, context)
    : undefined;
  const deletedIds = command.deleteIds ? resolveValue(command.deleteIds, context) : [];

  const createdIds = [];
  const updatedIds = [];

  for (let rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
    const row = rows[rowIndex] || {};
    const rowContext = buildRowContext(context, row, rowIndex);
    const resolvedFields = await coerceFieldsForSalesforce(
      instanceUrl,
      accessToken,
      command.objectApiName,
      resolveValue(command.fields, rowContext)
    );

    if (command.relationshipField && relationshipValue !== undefined) {
      resolvedFields[command.relationshipField] = relationshipValue;
    }

    const rowId = getByPath(row, idField);

    if (rowId) {
      const updateResult = await updateSalesforceRecord(
        instanceUrl,
        accessToken,
        command.objectApiName,
        rowId,
        resolvedFields
      );
      updatedIds.push(updateResult.id);
      continue;
    }

    const createResult = await createSalesforceRecord(
      instanceUrl,
      accessToken,
      command.objectApiName,
      resolvedFields
    );
    createdIds.push(createResult.id);
  }

  const deleted = [];
  if (command.allowDelete && Array.isArray(deletedIds)) {
    for (const id of deletedIds) {
      if (!id) continue;
      const deleteResult = await deleteSalesforceRecord(
        instanceUrl,
        accessToken,
        command.objectApiName,
        id
      );
      deleted.push(deleteResult.id);
    }
  }

  return {
    success: true,
    type: command.type,
    objectApiName: command.objectApiName,
    processedCount: rows.length,
    createdIds,
    updatedIds,
    deletedIds: deleted
  };
}

function buildFindOneSoql(command, resolvedWhere) {
  const objectApiName = command.objectApiName;
  const fieldsToReturn = Array.isArray(command.fieldsToReturn) && command.fieldsToReturn.length > 0
    ? command.fieldsToReturn
    : ["Id"];

  const whereClause = command.whereClause
    ? interpolateWhereClause(command.whereClause, resolvedWhere)
    : Object.entries(resolvedWhere || {})
      .map(([fieldName, value]) => {
        if (value === null) return `${fieldName} = null`;
        if (typeof value === "number" || typeof value === "boolean") return `${fieldName} = ${value}`;
        return `${fieldName} = '${escapeSoqlValue(value)}'`;
      })
      .join(" AND ");

  if (!whereClause) {
    throw new Error(`findOne command '${command.commandKey || "unknown"}' requires a non-empty where object`);
  }
  return `SELECT ${fieldsToReturn.join(", ")} FROM ${objectApiName} WHERE ${whereClause} ORDER BY CreatedDate DESC LIMIT 1`;
}

async function executeCommand(command, context, sf) {
  const { instanceUrl, accessToken } = sf;
  const type = command.type;

  if (type === "findOne") {
    if (!command.objectApiName || (!command.where && !command.whereClause)) {
      throw new Error(`findOne command '${command.commandKey || "unknown"}' is missing objectApiName or where`);
    }

    const resolvedWhere = command.whereClause ? context : resolveValue(command.where, context);
    const soql = buildFindOneSoql(command, resolvedWhere);
    const queryResult = await querySalesforce(instanceUrl, accessToken, soql);
    const record = queryResult.records && queryResult.records.length > 0 ? queryResult.records[0] : null;

    return {
      success: true,
      type,
      objectApiName: command.objectApiName,
      record
    };
  }

  if (type === "create") {
    if (!command.objectApiName || !command.fields) {
      throw new Error(`create command '${command.commandKey || "unknown"}' is missing objectApiName or fields`);
    }

    const resolvedFields = await coerceFieldsForSalesforce(
      instanceUrl,
      accessToken,
      command.objectApiName,
      resolveValue(command.fields, context)
    );
    const createResult = await createSalesforceRecord(instanceUrl, accessToken, command.objectApiName, resolvedFields);

    return {
      success: true,
      type,
      objectApiName: command.objectApiName,
      id: createResult.id
    };
  }

  if (type === "update") {
    if (!command.objectApiName || !command.fields) {
      throw new Error(`update command '${command.commandKey || "unknown"}' is missing objectApiName or fields`);
    }

    const resolvedFields = await coerceFieldsForSalesforce(
      instanceUrl,
      accessToken,
      command.objectApiName,
      resolveValue(command.fields, context)
    );
    const id = command.id ? resolveValue(command.id, context) : resolvedFields.Id;
    const shouldCreateOnMissing = command.onNotFound === "create";

    if (!id) {
      if (shouldCreateOnMissing) {
        const createResult = await createSalesforceRecord(instanceUrl, accessToken, command.objectApiName, resolvedFields);
        return {
          success: true,
          type: "create",
          objectApiName: command.objectApiName,
          id: createResult.id
        };
      }
      throw new Error(`update command '${command.commandKey || "unknown"}' requires id or fields.Id`);
    }

    const fieldsToUpdate = { ...resolvedFields };
    delete fieldsToUpdate.Id;

    let updateResult;
    try {
      updateResult = await updateSalesforceRecord(instanceUrl, accessToken, command.objectApiName, id, fieldsToUpdate);
    } catch (error) {
      if (shouldCreateOnMissing && String(error?.message || "").includes("Status: 404")) {
        const createResult = await createSalesforceRecord(instanceUrl, accessToken, command.objectApiName, resolvedFields);
        return {
          success: true,
          type: "create",
          objectApiName: command.objectApiName,
          id: createResult.id
        };
      }
      throw error;
    }

    return {
      success: true,
      type,
      objectApiName: command.objectApiName,
      id: updateResult.id
    };
  }

  if (type === "delete") {
    if (!command.objectApiName || !command.id) {
      throw new Error(`delete command '${command.commandKey || "unknown"}' is missing objectApiName or id`);
    }

    const resolvedId = resolveValue(command.id, context);
    if (!resolvedId) {
      throw new Error(`delete command '${command.commandKey || "unknown"}' resolved to blank id`);
    }

    const deleteResult = await deleteSalesforceRecord(
      instanceUrl,
      accessToken,
      command.objectApiName,
      resolvedId
    );

    return {
      success: true,
      type,
      objectApiName: command.objectApiName,
      id: deleteResult.id
    };
  }

  if (type === "upsertMany") {
    return executeUpsertManyCommand(command, context, sf);
  }

  throw new Error(`Unsupported command type: ${type}`);
}

function interpolateWhereClause(template, context) {
  if (!template) {
    return "";
  }
  return String(template).replace(/\{([^}]+)\}/g, (_, expression) => {
    const resolved = resolveExpression(expression, context);
    if (resolved === undefined || resolved === null) {
      return "";
    }
    return escapeSoqlValue(resolved);
  });
}

export const handler = async (event) => {
  const startedAtMs = Date.now();
  const submittedAt = new Date(startedAtMs).toISOString();
  const submissionId = generateSubmissionId(submittedAt);
  const submissionRef = generateSubmissionRef();
  let inputPayload = {};
  let formSecurity = null;
  let tenantRecord = null;
  const results = [];
  const commandTrace = [];

  try {
    const isDirectPayload =
      !!event &&
      typeof event === "object" &&
      !event?.requestContext &&
      !event?.httpMethod &&
      (event?.input || event?.publishToken || event?.formId);

    const method =
      event?.requestContext?.http?.method ||
      event?.httpMethod ||
      (isDirectPayload ? "POST" : (event?.body ? "POST" : "GET"));

    if (method === "OPTIONS") {
      return jsonResponse(200, { success: true });
    }

    if (method === "GET") {
      return jsonResponse(200, {
        success: true,
        message: "NativeForms endpoint is alive"
      });
    }

    if (method !== "POST") {
      return jsonResponse(405, {
        success: false,
        error: `Method ${method} not allowed`
      });
    }

    inputPayload = isDirectPayload
      ? event
      : event.body
        ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
        : {};

    if (!inputPayload.formId) {
      return jsonResponse(400, {
        success: false,
        submissionRef,
        error: "Missing required field: formId"
      });
    }

    const requestedSecretAction = normalizeSecretCodeAction(inputPayload.action);
    formSecurity = await getFormSecurityRecord(inputPayload.formId);
    ensureFormToken(formSecurity, inputPayload.publishToken, {
      requireSubmitDefinition: !requestedSecretAction
    });
    tenantRecord = await getTenantRecord(formSecurity.orgId);
    const runtimeStatus = deriveTenantRuntimeStatus(tenantRecord);
    if (runtimeStatus.status === "blocked") {
      throw buildFailureError(
        runtimeStatus.reason || "Data could not be updated in Salesforce because this customer is blocked.",
        403,
        "system"
      );
    }

    const secret = await getSecret(getSalesforceConnectionSecretName(formSecurity.orgId));
    assertSecret(secret);
    const loginBaseUrl = tenantRecord.loginBaseUrl || secret.loginBaseUrl || "https://login.salesforce.com";
    const accessToken = await refreshAccessToken(secret, loginBaseUrl);

    if (requestedSecretAction) {
      const secretCodeConfig = ensureSecretVerificationAllowed(formSecurity);
      const apexPayload = {
        action: requestedSecretAction,
        publishedVersionId: inputPayload.publishedVersionId || formSecurity.publishedVersionId,
        email: inputPayload.email || inputPayload?.input?.email || "",
        code: inputPayload.code || inputPayload?.input?.code || "",
        expiryMinutes: secretCodeConfig.expiryMinutes,
        maxAttempts: secretCodeConfig.maxAttempts
      };
      const apexResult = await callSalesforceApex(
        secret.instance_url,
        accessToken,
        `/services/apexrest/nativeforms/secret-code`,
        apexPayload
      );

      if (requestedSecretAction === "verifyCode" && apexResult.approved === true) {
        const normalizedEmail = String(apexResult.normalizedEmail || apexPayload.email || "").trim().toLowerCase();
        const sessionId =
          inputPayload.sessionId ||
          inputPayload.secretVerificationSessionId ||
          crypto.randomUUID();
        const verificationToken = createSecretVerificationToken(
          formSecurity,
          normalizedEmail,
          sessionId,
          secret
        );

        return jsonResponse(200, {
          success: true,
          approved: true,
          normalizedEmail,
          message: apexResult.message || "Code verified successfully.",
          verificationToken,
          sessionId
        });
      }

      return jsonResponse(200, {
        success: true,
        approved: apexResult.approved === true,
        emailSent: apexResult.emailSent === true,
        normalizedEmail: apexResult.normalizedEmail || apexPayload.email || "",
        lockedOut: apexResult.lockedOut === true,
        expired: apexResult.expired === true,
        message: apexResult.message || (requestedSecretAction === "sendCode"
          ? "If we found a matching contact, a code was sent."
          : "The verification code is invalid.")
      });
    }

    await verifyCaptcha(formSecurity, inputPayload, event);
    const submitCommands = formSecurity.submitDefinition.commands;
    const secretCodeConfig = normalizeSecretCodeConfig(formSecurity);
    if (secretCodeConfig.enabled) {
      const verifiedEmail =
        inputPayload?.input?.secretVerificationEmail ||
        inputPayload?.secretVerificationEmail ||
        "";
      const sessionId =
        inputPayload?.input?.secretVerificationSessionId ||
        inputPayload?.secretVerificationSessionId ||
        "";
      const verificationToken =
        inputPayload?.input?.secretVerificationToken ||
        inputPayload?.secretVerificationToken ||
        "";
      if (!verifySecretVerificationToken(formSecurity, verificationToken, sessionId, secret, verifiedEmail)) {
        throw buildFailureError(
          secretCodeConfig.invalidMessage || "Verify the secret code before continuing.",
          403,
          "validation"
        );
      }
    }

    const context = {
      input: inputPayload.input || {}
    };

    for (const command of submitCommands) {
      let traceEntry = null;
      try {
        if (!command.type) {
          throw buildFailureError("Each command must include 'type'", 400, "mapping");
        }

        try {
          validateSubmitCommandAgainstPolicy(command, formSecurity);
        } catch (error) {
          throw buildFailureError(error.message, 400, "mapping");
        }

        traceEntry = buildCommandTraceSnapshot(command, context);

        if (!shouldRunCommand(command.runIf, context)) {
          commandTrace.push({
            ...traceEntry,
            skipped: true
          });
          results.push({
            commandKey: command.commandKey || null,
            type: command.type,
            skipped: true,
            success: true
          });
          continue;
        }

        const result = await executeCommand(
          command,
          context,
          {
            instanceUrl: secret.instance_url,
            accessToken
          }
        );
    
        if (command.storeResultAs) {
          if (result.type === "findOne") {
            context[command.storeResultAs] = result.record;
          } else {
            const storedResult = { ...result };
            if (storedResult.id != null && storedResult.Id == null) {
              storedResult.Id = storedResult.id;
            }
            context[command.storeResultAs] = storedResult;
          }
        }

        commandTrace.push({
          ...traceEntry,
          skipped: false,
          result
        });
        results.push({
          commandKey: command.commandKey || null,
          type: command.type,
          objectApiName: result.objectApiName || null,
          id: result.id || null,
          found: result.type === "findOne" ? !!result.record : undefined,
          processedCount: result.processedCount,
          createdIds: result.createdIds,
          updatedIds: result.updatedIds,
          deletedIds: result.deletedIds,
          skipped: false,
          success: true
        });
      } catch (err) {
        err.commandKey = command?.commandKey || null;
        err.commandType = command?.type || null;
        err.objectApiName = command?.objectApiName || null;

        commandTrace.push({
          ...(traceEntry || buildCommandTraceSnapshot(command || {}, context)),
          skipped: false,
          error: buildErrorDetail(err)
        });

        const failureStage = getFailureStage(err, "mapping");
        await writeSubmissionLogSafely({
          tenantRecord,
          formSecurity,
          inputPayload,
          event,
          submissionId,
          submissionRef,
          submittedAt,
          startedAtMs,
          outcome: "failed",
          failureStage,
          results,
          commandTrace,
          error: err
        });

        return jsonResponse(err.statusCode || 400, {
          success: false,
          submissionRef,
          error: {
            message: err.message,
            commandKey: command.commandKey || null,
            commandType: command.type || null,
            objectApiName: command.objectApiName || null
          },
          partialResults: results
        });
      }
    }

    const finalizedFiles = await finalizeUploadedFiles({
      tenantRecord,
      formSecurity,
      inputPayload,
      results,
      sf: {
        instanceUrl: secret.instance_url,
        accessToken
      }
    });
    if (finalizedFiles.length) {
      results.push({
        commandKey: "__fileUploads__",
        type: "fileUploadFinalize",
        processedCount: finalizedFiles.length,
        files: finalizedFiles,
        skipped: false,
        success: true
      });
    }

    await writeSubmissionLogSafely({
      tenantRecord,
      formSecurity,
      inputPayload,
      event,
      submissionId,
      submissionRef,
      submittedAt,
      startedAtMs,
      outcome: "success",
      failureStage: "none",
      results,
      commandTrace,
      error: null
    });

    return jsonResponse(200, {
      success: true,
      submissionRef,
      results
    });
  } catch (error) {
    if (formSecurity?.orgId) {
      await writeSubmissionLogSafely({
        tenantRecord,
        formSecurity,
        inputPayload,
        event,
        submissionId,
        submissionRef,
        submittedAt,
        startedAtMs,
        outcome: "failed",
        failureStage: getFailureStage(error, "system"),
        results,
        commandTrace,
        error
      });
    }

    return jsonResponse(error?.statusCode || 500, {
      success: false,
      submissionRef,
      error: error.message
    });
  }
};
