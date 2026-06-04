import {
  SecretsManagerClient,
  CreateSecretCommand,
  PutSecretValueCommand,
  GetSecretValueCommand,
  RestoreSecretCommand
} from "@aws-sdk/client-secrets-manager";
import {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand,
  QueryCommand,
  ScanCommand
} from "@aws-sdk/client-dynamodb";
import { S3Client, DeleteObjectCommand, GetObjectTaggingCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import { SESClient, SendEmailCommand } from "@aws-sdk/client-ses";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import crypto from "crypto";
import https from "https";
import querystring from "querystring";
import { verifyBootstrapV2SignedPayload } from "./bootstrap-v2-hmac.mjs";
import {
  buildBootstrapV2ConnectionFields,
  buildBootstrapV2UnavailableConnectionFields,
  fetchBootstrapV2SigningSecret
} from "./bootstrap-v2-salesforce.mjs";

const secretsClient = new SecretsManagerClient({});
const dynamoClient = new DynamoDBClient({});
const s3Client = new S3Client({});
const sesClient = new SESClient({ region: process.env.SES_REGION || process.env.AWS_REGION || "eu-north-1" });
const FORM_SECURITY_TABLE = process.env.FORM_SECURITY_TABLE || "NativeFormsFormSecurity";
const TENANT_TABLE = process.env.TENANT_TABLE || "NativeFormsTenants";
const PLAN_TABLE = process.env.PLAN_TABLE || "NativeFormsPlans";
const GEO_LOCATION_TABLE = process.env.GEO_LOCATION_TABLE || "NativeFormsGeoLocations";
const SUBMISSION_LOG_TABLE = process.env.SUBMISSION_LOG_TABLE || "NativeFormsSubmissionLogs";
const SETTINGS_TABLE = process.env.SETTINGS_TABLE || "NativeFormsAdminSettings";
const BOOTSTRAP_V2_NONCE_TABLE = process.env.BOOTSTRAP_V2_NONCE_TABLE || "NativeFormsBootstrapV2Nonces";
const BOOTSTRAP_V2_NONCE_KEY_ATTRIBUTE = process.env.BOOTSTRAP_V2_NONCE_KEY_ATTRIBUTE || "nonceKey";
const SALESFORCE_CONNECTION_SECRET_PREFIX = "NativeForms/SalesforceConnection";
const SALESFORCE_OAUTH_CLIENT_SECRET_NAME = process.env.SALESFORCE_OAUTH_CLIENT_SECRET_NAME || "";
const SALESFORCE_OAUTH_CLIENT_ID = process.env.SALESFORCE_OAUTH_CLIENT_ID || "";
const SALESFORCE_OAUTH_CLIENT_SECRET = process.env.SALESFORCE_OAUTH_CLIENT_SECRET || "";
const SALESFORCE_API_VERSION = "v60.0";
const SES_FROM = process.env.SES_FROM || "";
const DEV_MODE = String(process.env.DEV_MODE || "").toLowerCase() === "true";
const PUBLISH_BUCKET = process.env.PUBLISH_BUCKET || "";
const UPLOAD_STAGING_BUCKET = process.env.UPLOAD_STAGING_BUCKET || "";
const PUBLIC_BASE_URL = (process.env.PUBLIC_BASE_URL || "").replace(/\/+$/, "");
const PRICING_BASE_URL = (process.env.PRICING_BASE_URL || "https://twinaforms.com").replace(/\/+$/, "");
const BOOTSTRAP_V2_SPIKE_SECRET_B64 = process.env.BOOTSTRAP_V2_SPIKE_SECRET_B64 || "";
const MALWARE_SCAN_STATUS_TAG_KEY = "GuardDutyMalwareScanStatus";
const FEATURE_FLAG_METADATA = {
  enableProConditionLogic: {
    label: "Conditional Logic",
    description: "Show, hide, or control behavior based on multiple form conditions and grouped logic."
  },
  enableProRepeatGroups: {
    label: "Repeated Records Table",
    description: "Collect and submit multiple rows of related records, like products, household members, or case items, in one form."
  },
  enableProPrefillAliasReferences: {
    label: "Prefill Result References",
    description: "Reuse prefill results across new Prefill actions."
  },
  enableProAdvancedSubmitModes: {
    label: "Advanced Submit Actions",
    description: "Use richer submit flows like find-and-update or update-by-id for more advanced Salesforce writeback behavior."
  },
  enableProPageLayoutClone: {
    label: "Page Layout Clone",
    description: "Create a draft TwinaForms form from supported Salesforce page-layout fields."
  },
  enableProFormulaFields: {
    label: "Calculated Fields",
    description: "Generate values automatically inside the form instead of asking users to enter them manually."
  },
  enableProPostSubmitAutoLink: {
    label: "Post Submit Auto Link",
    description: "Automatically link related Salesforce records after submission based on configured matching rules."
  },
  enableProSfSecretCodeAuth: {
    label: "Secret Code Verification",
    description: "Add an extra verification step with a secret code for more sensitive workflows."
  },
  enableProUserVerification: {
    label: "User Verification",
    description: "Compatibility flag for 0.9 packages that use the original User Verification entitlement name."
  },
  enableProLoadFile: {
    label: "File Uploads",
    description: "Allow Pro forms to upload files as part of the form experience and submission flow."
  },
  enableProElectronicSignature: {
    label: "Electronic Signature",
    description: "Capture drawn signatures and attach them to submitted Salesforce records."
  },
  enableProSubmissionPdf: {
    label: "Submission PDF",
    description: "Generate a readable PDF copy of submitted responses and attach it to Salesforce records."
  },
  enableProMergedDocument: {
    label: "Merged Document",
    description: "Create document-style rich text that inserts prefilled Salesforce values such as contact names or agreement details."
  },
  enableProSurveyFields: {
    label: "Survey Fields",
    description: "Add rating, NPS, Likert, ranking, and satisfaction fields to Pro forms."
  },
  enableProLocationFields: {
    label: "Country / State / City",
    description: "Add AWS-backed country, state/region, and city autocomplete fields to Pro forms."
  },
  enableProCustomJs: {
    label: "Custom JavaScript",
    description: "Run supported TwinaForms custom JavaScript in published forms for advanced behavior."
  },
  enableDetailedSubmissionLogs: {
    label: "Detailed Submission Logs",
    description: "See richer troubleshooting detail for submissions, runtime behavior, and processing outcomes."
  }
};

let cachedSalesforceOAuthClientCredentials = null;

const DEFAULT_PLANS = [
  {
    planCode: "free",
    label: "Free",
    description: "Permanent low-volume entry plan.",
    featureLabels: Object.fromEntries(Object.entries(FEATURE_FLAG_METADATA).map(([key, value]) => [key, value.label])),
    limits: {
      maxSfUsers: 1,
      maxForms: 1,
      maxSubmissionsPerMonth: 100,
      submissionLogRetentionDays: 30
    },
    featureFlags: {
      enableDetailedSubmissionLogs: false,
      enableProConditionLogic: false,
      enableProRepeatGroups: false,
      enableProPrefillAliasReferences: false,
      enableProAdvancedSubmitModes: false,
      enableProPageLayoutClone: false,
      enableProFormulaFields: false,
      enableProPostSubmitAutoLink: false,
      enableProSfSecretCodeAuth: false,
      enableProUserVerification: false,
      enableProLoadFile: false,
      enableProElectronicSignature: false,
      enableProSubmissionPdf: false,
      enableProMergedDocument: false,
      enableProSurveyFields: false,
      enableProLocationFields: false,
      enableProCustomJs: false
    }
  },
  {
    planCode: "trial",
    label: "Trial",
    description: "Time-limited evaluation with all Pro features.",
    featureLabels: Object.fromEntries(Object.entries(FEATURE_FLAG_METADATA).map(([key, value]) => [key, value.label])),
    limits: {
      maxSfUsers: 1,
      maxForms: 5,
      maxSubmissionsPerMonth: null,
      submissionLogRetentionDays: 30
    },
    featureFlags: {
      enableDetailedSubmissionLogs: true,
      enableProConditionLogic: true,
      enableProRepeatGroups: true,
      enableProPrefillAliasReferences: true,
      enableProAdvancedSubmitModes: true,
      enableProPageLayoutClone: true,
      enableProFormulaFields: true,
      enableProPostSubmitAutoLink: true,
      enableProSfSecretCodeAuth: true,
      enableProUserVerification: true,
      enableProLoadFile: true,
      enableProElectronicSignature: true,
      enableProSubmissionPdf: true,
      enableProMergedDocument: true,
      enableProSurveyFields: true,
      enableProLocationFields: true,
      enableProCustomJs: true
    }
  },
  {
    planCode: "starter",
    label: "Starter",
    description: "Paid production plan without Pro-only features.",
    featureLabels: Object.fromEntries(Object.entries(FEATURE_FLAG_METADATA).map(([key, value]) => [key, value.label])),
    limits: {
      maxSfUsers: 1,
      maxForms: 5,
      maxSubmissionsPerMonth: 1000,
      submissionLogRetentionDays: 90
    },
    featureFlags: {
      enableDetailedSubmissionLogs: true,
      enableProConditionLogic: false,
      enableProRepeatGroups: false,
      enableProPrefillAliasReferences: false,
      enableProAdvancedSubmitModes: false,
      enableProPageLayoutClone: false,
      enableProFormulaFields: false,
      enableProPostSubmitAutoLink: false,
      enableProSfSecretCodeAuth: false,
      enableProUserVerification: false,
      enableProLoadFile: false,
      enableProElectronicSignature: false,
      enableProSubmissionPdf: false,
      enableProMergedDocument: false,
      enableProSurveyFields: false,
      enableProLocationFields: false,
      enableProCustomJs: false
    }
  },
  {
    planCode: "pro",
    label: "Pro",
    description: "Full plan with no product limits.",
    featureLabels: Object.fromEntries(Object.entries(FEATURE_FLAG_METADATA).map(([key, value]) => [key, value.label])),
    limits: {
      maxSfUsers: null,
      maxForms: null,
      maxSubmissionsPerMonth: null,
      submissionLogRetentionDays: 365
    },
    featureFlags: {
      enableDetailedSubmissionLogs: true,
      enableProConditionLogic: true,
      enableProRepeatGroups: true,
      enableProPrefillAliasReferences: true,
      enableProAdvancedSubmitModes: true,
      enableProPageLayoutClone: true,
      enableProFormulaFields: true,
      enableProPostSubmitAutoLink: true,
      enableProSfSecretCodeAuth: true,
      enableProUserVerification: true,
      enableProLoadFile: true,
      enableProElectronicSignature: true,
      enableProSubmissionPdf: true,
      enableProMergedDocument: true,
      enableProSurveyFields: true,
      enableProLocationFields: true,
      enableProCustomJs: true
    }
  }
];

async function saveSalesforceConnection(secretName, payload) {
  const secretString = JSON.stringify(payload, null, 2);

  try {
    await secretsClient.send(
      new CreateSecretCommand({
        Name: secretName,
        SecretString: secretString
      })
    );

    return { created: true, updated: false };
  } catch (e) {
    if (e.name === "ResourceExistsException" || isSecretScheduledForDeletionError(e)) {
      if (isSecretScheduledForDeletionError(e)) {
        await restoreSalesforceConnectionSecret(secretName);
      }
      await secretsClient.send(
        new PutSecretValueCommand({
          SecretId: secretName,
          SecretString: secretString
        })
      );

      return { created: false, updated: true };
    }

    throw e;
  }
}

function isSecretScheduledForDeletionError(error) {
  const message = String(error?.message || "").toLowerCase();
  return error?.name === "InvalidRequestException" && message.includes("scheduled for deletion");
}

async function restoreSalesforceConnectionSecret(secretName) {
  try {
    await secretsClient.send(new RestoreSecretCommand({ SecretId: secretName }));
  } catch (error) {
    if (error?.name !== "ResourceNotFoundException" && !isSecretScheduledForDeletionError(error)) {
      throw error;
    }
  }
}

async function getSalesforceConnection(secretName) {
  try {
    const result = await secretsClient.send(
      new GetSecretValueCommand({
        SecretId: secretName
      })
    );

    return result?.SecretString ? JSON.parse(result.SecretString) : null;
  } catch (error) {
    if (error.name === "ResourceNotFoundException") {
      return null;
    }
    if (isSecretScheduledForDeletionError(error)) {
      await restoreSalesforceConnectionSecret(secretName);
      const restoredResult = await secretsClient.send(
        new GetSecretValueCommand({
          SecretId: secretName
        })
      );
      return restoredResult?.SecretString ? JSON.parse(restoredResult.SecretString) : null;
    }
    throw error;
  }
}

function getSalesforceConnectionSecretName(orgId) {
  return `${SALESFORCE_CONNECTION_SECRET_PREFIX}/${normalizeOrgId(orgId)}`;
}

function stripLegacySalesforceClientCredentials(connectionRecord) {
  if (!connectionRecord || typeof connectionRecord !== "object") {
    return {};
  }

  const { client_id, client_secret, ...safeConnectionRecord } = connectionRecord;
  return safeConnectionRecord;
}

async function getSalesforceOAuthClientCredentials() {
  if (cachedSalesforceOAuthClientCredentials) {
    return cachedSalesforceOAuthClientCredentials;
  }

  let clientId = String(SALESFORCE_OAUTH_CLIENT_ID || "").trim();
  let clientSecret = String(SALESFORCE_OAUTH_CLIENT_SECRET || "").trim();

  if ((!clientId || !clientSecret) && SALESFORCE_OAUTH_CLIENT_SECRET_NAME) {
    const secretValue = await getSalesforceConnection(SALESFORCE_OAUTH_CLIENT_SECRET_NAME);
    clientId = clientId || String(secretValue?.client_id || secretValue?.clientId || "").trim();
    clientSecret = clientSecret || String(secretValue?.client_secret || secretValue?.clientSecret || "").trim();
  }

  if (!clientId || !clientSecret) {
    throw new Error("TwinaForms Salesforce OAuth client credentials are not configured in AWS.");
  }

  cachedSalesforceOAuthClientCredentials = {
    clientId,
    clientSecret
  };
  return cachedSalesforceOAuthClientCredentials;
}

async function hasSalesforceOAuthClientCredentials() {
  try {
    await getSalesforceOAuthClientCredentials();
    return true;
  } catch (error) {
    console.warn("Salesforce OAuth client credentials are not configured:", error.message);
    return false;
  }
}

function jsonResponse(statusCode, payload) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type,Authorization"
    },
    body: JSON.stringify(payload)
  };
}

function parseRawEventBody(event) {
  if (!event || event.body == null) {
    return "";
  }
  if (event.isBase64Encoded) {
    return Buffer.from(String(event.body), "base64").toString("utf8");
  }
  return typeof event.body === "string" ? event.body : JSON.stringify(event.body);
}

function hashToken(token) {
  return crypto.createHash("sha256").update(String(token)).digest("hex");
}

function generateSecret() {
  return crypto.randomBytes(32).toString("base64url");
}

function normalizeOrgId(orgId) {
  if (typeof orgId !== "string") {
    return orgId;
  }

  const trimmed = orgId.trim();
  return trimmed.length >= 15 ? trimmed.substring(0, 15) : trimmed;
}

function toAttributeValue(value) {
  if (value === null) return { NULL: true };
  if (typeof value === "string") return { S: value };
  if (typeof value === "number") return { N: String(value) };
  if (typeof value === "boolean") return { BOOL: value };
  if (Array.isArray(value)) return { L: value.map(toAttributeValue) };
  if (value && typeof value === "object") {
    const map = {};
    for (const [key, nestedValue] of Object.entries(value)) {
      map[key] = toAttributeValue(nestedValue);
    }
    return { M: map };
  }
  return { S: String(value) };
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

function marshallItem(item) {
  const marshalled = {};
  for (const [key, value] of Object.entries(item)) {
    marshalled[key] = toAttributeValue(value);
  }
  return marshalled;
}

function unmarshallItem(item) {
  const unmarshalled = {};
  for (const [key, value] of Object.entries(item || {})) {
    unmarshalled[key] = fromAttributeValue(value);
  }
  return unmarshalled;
}

async function getItemByKey(tableName, keyName, keyValue) {
  const result = await dynamoClient.send(new GetItemCommand({
    TableName: tableName,
    Key: {
      [keyName]: { S: keyValue }
    }
  }));

  return result.Item ? unmarshallItem(result.Item) : null;
}

async function saveItem(tableName, record) {
  await dynamoClient.send(new PutItemCommand({
    TableName: tableName,
    Item: marshallItem(record)
  }));
}

async function scanAllItems(tableName) {
  const items = [];
  let exclusiveStartKey;

  do {
    const result = await dynamoClient.send(new ScanCommand({
      TableName: tableName,
      ExclusiveStartKey: exclusiveStartKey
    }));

    (result.Items || []).forEach((item) => {
      items.push(unmarshallItem(item));
    });

    exclusiveStartKey = result.LastEvaluatedKey;
  } while (exclusiveStartKey);

  return items;
}

function isMissingTableError(error) {
  return error?.name === "ResourceNotFoundException";
}

function isTableUnavailableError(error) {
  return isMissingTableError(error) || error?.name === "AccessDeniedException";
}

async function scanAllItemsSafe(tableName) {
  try {
    return await scanAllItems(tableName);
  } catch (error) {
    if (isTableUnavailableError(error)) {
      return [];
    }
    throw error;
  }
}

async function getFormSecurityRecord(formId) {
  return getItemByKey(FORM_SECURITY_TABLE, "formId", formId);
}

async function getTenantRecord(orgId) {
  return getItemByKey(TENANT_TABLE, "orgId", normalizeOrgId(orgId));
}

function validateOrgId(orgId) {
  return typeof orgId === "string" && /^00D[A-Za-z0-9]{12,15}$/.test(normalizeOrgId(orgId));
}

function sanitizeTenantRecord(record) {
  if (!record) return null;
  const { secret, ...safe } = record;
  return safe;
}

function sanitizeFormSecurityRecord(record) {
  if (!record) return null;
  const safe = { ...record };
  if (safe.captcha && typeof safe.captcha === "object") {
    safe.captcha = { ...safe.captcha };
    delete safe.captcha.secretKey;
  }
  return safe;
}

function ensurePublishedFormToken(formSecurity, publishToken) {
  if (!publishToken) {
    const error = new Error("Missing required field: publishToken");
    error.statusCode = 401;
    throw error;
  }

  if (!formSecurity || formSecurity.status !== "published") {
    const error = new Error("Form is not published");
    error.statusCode = 403;
    throw error;
  }

  if (formSecurity.tokenHash !== hashToken(publishToken)) {
    const error = new Error("Unauthorized: invalid publish token");
    error.statusCode = 401;
    throw error;
  }
}

function normalizeFileName(fileName) {
  return String(fileName || "")
    .replace(/[\\/:*?"<>|]/g, "_")
    .replace(/\s+/g, " ")
    .trim();
}

function getFileExtension(fileName) {
  const normalized = normalizeFileName(fileName);
  const dotIndex = normalized.lastIndexOf(".");
  if (dotIndex <= 0 || dotIndex === normalized.length - 1) {
    return "";
  }
  return normalized.slice(dotIndex + 1).toLowerCase();
}

function normalizeUploadFieldList(uploadFields) {
  return Array.isArray(uploadFields) ? uploadFields.filter((item) => item && typeof item === "object") : [];
}

function normalizeLookupDefinition(formSecurity) {
  const definition = formSecurity?.lookupDefinition;
  if (!definition || typeof definition !== "object" || Array.isArray(definition)) {
    return { fields: {} };
  }
  return {
    ...definition,
    fields: definition.fields && typeof definition.fields === "object" && !Array.isArray(definition.fields)
      ? definition.fields
      : {}
  };
}

function findLookupFieldDefinition(formSecurity, fieldKey) {
  const normalizedFieldKey = String(fieldKey || "").trim();
  if (!normalizedFieldKey) {
    return null;
  }
  const fields = normalizeLookupDefinition(formSecurity).fields;
  const definition = fields[normalizedFieldKey];
  return definition && typeof definition === "object" && !Array.isArray(definition) ? definition : null;
}

function normalizeLocationDefinition(formSecurity) {
  const definition = formSecurity?.locationDefinition;
  if (!definition || typeof definition !== "object" || Array.isArray(definition)) {
    return { fields: {} };
  }
  return {
    ...definition,
    fields: definition.fields && typeof definition.fields === "object" && !Array.isArray(definition.fields)
      ? definition.fields
      : {}
  };
}

function findLocationFieldDefinition(formSecurity, fieldKey) {
  const normalizedFieldKey = String(fieldKey || "").trim();
  if (!normalizedFieldKey) {
    return null;
  }
  const fields = normalizeLocationDefinition(formSecurity).fields;
  const definition = fields[normalizedFieldKey];
  return definition && typeof definition === "object" && !Array.isArray(definition) ? definition : null;
}

function findUploadFieldDefinition(formSecurity, fieldKey) {
  const normalizedFieldKey = String(fieldKey || "").trim();
  if (!normalizedFieldKey) {
    return null;
  }
  return normalizeUploadFieldList(formSecurity?.uploadFields).find((item) => String(item.fieldKey || "").trim() === normalizedFieldKey) || null;
}

function getUploadSigningSecret(tenantRecord) {
  const signingSecret = String(tenantRecord?.secret || "");
  if (!signingSecret) {
    const error = new Error("Owning tenant is missing an upload signing secret");
    error.statusCode = 500;
    throw error;
  }
  return signingSecret;
}

function base64UrlEncodeUtf8(value) {
  return Buffer.from(String(value), "utf8")
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function createUploadReferenceToken(payload, tenantRecord) {
  const encodedPayload = base64UrlEncodeUtf8(JSON.stringify(payload));
  const signature = crypto
    .createHmac("sha256", getUploadSigningSecret(tenantRecord))
    .update(encodedPayload)
    .digest("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
  return `${encodedPayload}.${signature}`;
}

function base64UrlDecodeUtf8(value) {
  const normalized = String(value || "").replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  return Buffer.from(padded, "base64").toString("utf8");
}

function verifyUploadReferenceToken(token, tenantRecord) {
  const parts = String(token || "").trim().split(".");
  if (parts.length !== 2) {
    return null;
  }
  const [encodedPayload, suppliedSignature] = parts;
  const expectedSignature = crypto
    .createHmac("sha256", getUploadSigningSecret(tenantRecord))
    .update(encodedPayload)
    .digest("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
  const expectedBuffer = Buffer.from(expectedSignature);
  const suppliedBuffer = Buffer.from(suppliedSignature);
  if (expectedBuffer.length !== suppliedBuffer.length || !crypto.timingSafeEqual(expectedBuffer, suppliedBuffer)) {
    return null;
  }
  try {
    return JSON.parse(base64UrlDecodeUtf8(encodedPayload));
  } catch (error) {
    return null;
  }
}

function validateBoundUploadReference(payload, formSecurity, tenantRecord) {
  const tokenPayload = verifyUploadReferenceToken(payload.uploadToken, tenantRecord);
  if (!tokenPayload) {
    const error = new Error("This file upload reference is invalid.");
    error.statusCode = 400;
    throw error;
  }
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (Number(tokenPayload.exp || 0) <= nowSeconds) {
    const error = new Error("This file upload has expired. Please upload it again.");
    error.statusCode = 400;
    throw error;
  }
  if (
    tokenPayload.kind !== "fileUpload" ||
    tokenPayload.orgId !== formSecurity.orgId ||
    tokenPayload.formId !== formSecurity.formId ||
    String(tokenPayload.publishedVersionId || "") !== String(formSecurity.publishedVersionId || "") ||
    String(tokenPayload.fieldKey || "") !== String(payload.fieldKey || "") ||
    String(tokenPayload.sessionId || "") !== String(payload.sessionId || "")
  ) {
    const error = new Error("This file upload does not belong to this form session.");
    error.statusCode = 400;
    throw error;
  }
  return tokenPayload;
}

async function getUploadScanStatus(objectKey) {
  if (!objectKey) {
    return { status: "unavailable" };
  }
  try {
    const result = await s3Client.send(new GetObjectTaggingCommand({
      Bucket: UPLOAD_STAGING_BUCKET,
      Key: objectKey
    }));
    const tag = (result.TagSet || []).find((item) => item.Key === MALWARE_SCAN_STATUS_TAG_KEY);
    const scanStatus = String(tag?.Value || "").trim();
    if (!scanStatus) {
      return { status: "pending" };
    }
    if (scanStatus === "NO_THREATS_FOUND") {
      return { status: "ready" };
    }
    if (scanStatus === "THREATS_FOUND") {
      return { status: "rejected" };
    }
    return { status: "unavailable" };
  } catch (error) {
    console.warn("Unable to retrieve upload scan status", { objectKey, message: error?.message });
    return { status: "unavailable" };
  }
}

async function removeRejectedStagedUpload(objectKey) {
  if (!objectKey) {
    return;
  }
  try {
    await s3Client.send(new DeleteObjectCommand({
      Bucket: UPLOAD_STAGING_BUCKET,
      Key: objectKey
    }));
  } catch (error) {
    console.warn("Unable to delete rejected staged upload", { objectKey, message: error?.message });
  }
}

function buildUploadObjectKey(formSecurity, fieldKey, sessionId, fileName) {
  const safeSessionId = String(sessionId || "").trim() || crypto.randomUUID();
  const safeFieldKey = String(fieldKey || "").trim() || "file";
  const normalizedFileName = normalizeFileName(fileName) || "upload.bin";
  const uniquePrefix = crypto.randomUUID();
  const companySlug = String(formSecurity?.companySlug || "org").trim();
  const formSlug = String(formSecurity?.formSlug || formSecurity?.formId || "form").trim();
  return `${companySlug}/${formSlug}/_uploads/${safeSessionId}/${safeFieldKey}/${uniquePrefix}-${normalizedFileName}`;
}

function validateUploadFieldRules(uploadField, payload) {
  const normalizedFileName = normalizeFileName(payload.fileName);
  if (!normalizedFileName) {
    const error = new Error("Missing required field: fileName");
    error.statusCode = 400;
    throw error;
  }

  const fileSize = Number(payload.fileSize);
  if (!Number.isFinite(fileSize) || fileSize <= 0) {
    const error = new Error("fileSize must be a positive number");
    error.statusCode = 400;
    throw error;
  }

  const maxFileSizeMb = Number(uploadField?.maxFileSizeMb);
  if (Number.isFinite(maxFileSizeMb) && maxFileSizeMb > 0) {
    const maxBytes = maxFileSizeMb * 1024 * 1024;
    if (fileSize > maxBytes) {
      const error = new Error(`This file is larger than the allowed size of ${maxFileSizeMb} MB.`);
      error.statusCode = 400;
      throw error;
    }
  }

  const allowedExtensions = Array.isArray(uploadField?.allowedExtensions)
    ? uploadField.allowedExtensions.map((value) => String(value || "").trim().toLowerCase().replace(/^\./, "")).filter(Boolean)
    : [];
  if (allowedExtensions.length > 0) {
    const extension = getFileExtension(normalizedFileName);
    if (!extension || !allowedExtensions.includes(extension)) {
      const error = new Error("This file type is not allowed.");
      error.statusCode = 400;
      throw error;
    }
  }
}

function normalizeSubscriptionState(payload, existing = null) {
  return {
    subscriptionState: payload.subscriptionState || existing?.subscriptionState || "trial",
    subscriptionStartDate: payload.subscriptionStartDate || existing?.subscriptionStartDate || null,
    subscriptionEndDate: payload.subscriptionEndDate || existing?.subscriptionEndDate || null,
    isActive: typeof payload.isActive === "boolean" ? payload.isActive : (existing?.isActive ?? true),
    status: payload.status || existing?.status || "active"
  };
}

function normalizePlanCode(planCode, tenantRecord = null) {
  const normalized = String(
    planCode
    || tenantRecord?.planCode
    || tenantRecord?.subscriptionState
    || ""
  ).trim().toLowerCase();

  return ["free", "trial", "starter", "pro"].includes(normalized)
    ? normalized
    : "trial";
}

async function loadPlanDefinitions() {
  try {
    const items = await scanAllItems(PLAN_TABLE);
    if (Array.isArray(items) && items.length > 0) {
      return {
        items,
        storageMode: "dynamodb"
      };
    }
  } catch (error) {
    if (!isMissingTableError(error)) {
      throw error;
    }
  }

  return {
    items: DEFAULT_PLANS,
    storageMode: "fallback"
  };
}

function getPlanByCode(planDefinitions, planCode) {
  const normalizedPlanCode = normalizePlanCode(planCode);
  const defaultPlan = DEFAULT_PLANS.find((item) => item.planCode === normalizedPlanCode)
    || DEFAULT_PLANS[1];
  const storedPlan = planDefinitions.find((item) => normalizePlanCode(item?.planCode) === normalizedPlanCode);

  if (!storedPlan) {
    return defaultPlan;
  }

  return {
    ...defaultPlan,
    ...storedPlan,
    featureLabels: Object.fromEntries(
      Object.entries(FEATURE_FLAG_METADATA).map(([key, value]) => [
        key,
        storedPlan?.featureLabels?.[key] || defaultPlan?.featureLabels?.[key] || value.label
      ])
    ),
    limits: {
      ...(defaultPlan?.limits || {}),
      ...(storedPlan?.limits || {})
    },
    featureFlags: Object.fromEntries(
      Object.keys(FEATURE_FLAG_METADATA).map((key) => [
        key,
        storedPlan?.featureFlags?.[key] ?? defaultPlan?.featureFlags?.[key] ?? false
      ])
    )
  };
}

function mergeDefinedObjects(...items) {
  const output = {};
  for (const item of items) {
    if (!item || typeof item !== "object") {
      continue;
    }
    for (const [key, value] of Object.entries(item)) {
      if (value !== undefined) {
        output[key] = value;
      }
    }
  }
  return output;
}

function getEffectivePlanLimits(tenantRecord, selectedPlan) {
  return mergeDefinedObjects(
    selectedPlan?.limits || {},
    tenantRecord?.planLimits || {},
    tenantRecord?.limits || {},
    tenantRecord?.planOverrides?.limits || {},
    tenantRecord?.effectiveLimits || {}
  );
}

function getEffectivePlanFeatures(tenantRecord, selectedPlan) {
  return mergeDefinedObjects(
    selectedPlan?.featureFlags || {},
    tenantRecord?.planFeatureFlags || {},
    tenantRecord?.featureFlags || {},
    tenantRecord?.planOverrides?.featureFlags || {},
    tenantRecord?.effectiveFeatureFlags || {}
  );
}

async function countPublishedForms(orgId) {
  const normalizedOrgId = normalizeOrgId(orgId);
  if (!normalizedOrgId) {
    return 0;
  }

  const formRecords = await scanAllItemsSafe(FORM_SECURITY_TABLE);
  return formRecords.filter((record) =>
    normalizeOrgId(record?.orgId) === normalizedOrgId
    && String(record?.status || "").toLowerCase() === "published"
  ).length;
}

function getCurrentMonthRangeUtc() {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = now.getUTCMonth();
  const start = new Date(Date.UTC(year, month, 1, 0, 0, 0, 0)).toISOString();
  const end = new Date(Date.UTC(year, month + 1, 0, 23, 59, 59, 999)).toISOString();
  return { start, end };
}

async function countTenantSubmissionsForCurrentMonth(orgId) {
  if (!orgId) {
    return 0;
  }

  const normalizedOrgId = normalizeOrgId(orgId);
  const { start, end } = getCurrentMonthRangeUtc();
  let count = 0;
  let exclusiveStartKey;

  do {
    const result = await dynamoClient.send(new QueryCommand({
      TableName: SUBMISSION_LOG_TABLE,
      KeyConditionExpression: "tenantId = :tenantId AND submittedAtSubmissionId BETWEEN :fromKey AND :toKey",
      ExpressionAttributeValues: {
        ":tenantId": { S: normalizedOrgId },
        ":fromKey": { S: `${start}#` },
        ":toKey": { S: `${end}#\uffff` }
      },
      Select: "COUNT",
      ExclusiveStartKey: exclusiveStartKey
    }));

    count += Number(result?.Count || 0);
    exclusiveStartKey = result?.LastEvaluatedKey;
  } while (exclusiveStartKey);

  return count;
}

function hasAdvancedProFeatures(featureFlags) {
  return [
    "enableProConditionLogic",
    "enableProRepeatGroups",
    "enableProPrefillAliasReferences",
    "enableProAdvancedSubmitModes",
    "enableProPageLayoutClone",
    "enableProFormulaFields",
    "enableProPostSubmitAutoLink",
    "enableProSfSecretCodeAuth",
    "enableProUserVerification",
    "enableProLoadFile",
    "enableProElectronicSignature",
    "enableProSubmissionPdf",
    "enableProMergedDocument",
    "enableProSurveyFields",
    "enableProLocationFields",
    "enableProCustomJs"
  ].some((key) => featureFlags?.[key] === true);
}

function getFeatureFlagLabels() {
  return Object.fromEntries(
    Object.entries(FEATURE_FLAG_METADATA).map(([key, value]) => [key, value.label])
  );
}

function normalizeFeatureMetadata(inputValue = null) {
  const output = {};

  for (const [key, defaults] of Object.entries(FEATURE_FLAG_METADATA)) {
    const incoming = inputValue && typeof inputValue === "object" ? inputValue[key] : null;
    output[key] = {
      label: String(incoming?.label || defaults.label),
      description: String(incoming?.description || defaults.description)
    };
  }

  return output;
}

function getFeatureMetadata(planDefinition = null, settingsMetadata = null) {
  const output = normalizeFeatureMetadata(settingsMetadata);
  const planLabels = getFeatureFlagLabels();

  for (const [key, label] of Object.entries(planLabels)) {
    if (!output[key]) {
      output[key] = {
        label: String(label || key),
        description: ""
      };
      continue;
    }
    output[key].label = String(label || output[key].label || key);
  }

  return output;
}

async function loadAdminSettings() {
  try {
    return await getItemByKey(SETTINGS_TABLE, "settingKey", "admin_notifications");
  } catch (error) {
    console.warn("Admin settings lookup failed for home summary; falling back to defaults.", error?.name || error?.message || error);
    return null;
  }
}

function normalizeOptionalString(value) {
  if (value == null) {
    return null;
  }

  const normalized = String(value).trim();
  return normalized ? normalized : null;
}

function getTodayIsoDate() {
  return new Date().toISOString().slice(0, 10);
}

function addDaysToIsoDate(isoDate, days) {
  const baseDate = new Date(`${isoDate}T00:00:00.000Z`);
  baseDate.setUTCDate(baseDate.getUTCDate() + days);
  return baseDate.toISOString().slice(0, 10);
}

function buildTrialLifecycleDates() {
  const startDate = getTodayIsoDate();
  const endDate = addDaysToIsoDate(startDate, 30);

  return {
    planCode: "trial",
    subscriptionState: "trial",
    subscriptionStartDate: startDate,
    subscriptionEndDate: endDate,
    trialStartedAt: startDate,
    trialEndsAt: endDate
  };
}

function buildIncludedFeatures(featureFlags) {
  const items = [
    {
      key: "builder",
      label: "Core Form Builder",
      detail: "Create and manage production forms from Salesforce.",
      status: "included"
    },
    {
      key: "themes",
      label: "Themes",
      detail: "Customize form branding and visual style.",
      status: "included"
    },
    {
      key: "prefill",
      label: "Prefill",
      detail: "Use Salesforce data to prefill form fields.",
      status: "included"
    },
    {
      key: "submit",
      label: "Submit Actions",
      detail: "Send submitted form data back into Salesforce.",
      status: "included"
    }
  ];

  if (featureFlags?.enableDetailedSubmissionLogs) {
    items.push({
      key: "detailedLogs",
      label: "Detailed Logs",
      detail: "Review richer submission activity and troubleshooting detail.",
      status: "included"
    });
  }

  if (hasAdvancedProFeatures(featureFlags)) {
    items.push({
      key: "advancedPro",
      label: "Advanced Pro Features",
      detail: "Use advanced form logic and richer runtime capabilities.",
      status: "included"
    });
  }

  return items;
}

function buildUpgradeFeatures(planCode, featureFlags, proPlan = null, featureMetadata = null) {
  const normalizedPlanCode = normalizePlanCode(planCode);
  if (["trial", "pro"].includes(normalizedPlanCode)) {
    return [];
  }

  const items = [];
  const proFeatures = proPlan?.featureFlags || {};
  const metadataByKey = getFeatureMetadata(proPlan, featureMetadata);

  for (const key of Object.keys(metadataByKey)) {
    if (proFeatures?.[key] !== true || featureFlags?.[key] === true) {
      continue;
    }

    items.push({
      key,
      label: metadataByKey[key]?.label || key,
      detail: metadataByKey[key]?.description || null,
      status: "upgrade"
    });
  }

  return items;
}

function buildFormsUsageMessage(activeFormsCount, maxForms) {
  if (maxForms == null) {
    return null;
  }

  if (activeFormsCount >= maxForms) {
    return "You have reached your current published-form limit.";
  }

  if (maxForms > 0 && activeFormsCount >= Math.max(1, maxForms - 1)) {
    return "You are close to your current published-form limit.";
  }

  return null;
}

function buildPlanUrls(planCode) {
  const normalizedPlanCode = normalizePlanCode(planCode);
  return {
    comparePlansUrl: `${PRICING_BASE_URL}/pricing?source=salesforce-home&plan=${encodeURIComponent(normalizedPlanCode)}`,
    upgradeUrl: `${PRICING_BASE_URL}/upgrade?source=salesforce-home&plan=${encodeURIComponent(normalizedPlanCode)}`
  };
}

function sortPlansForDisplay(plans = []) {
  const order = new Map([
    ["free", 1],
    ["trial", 2],
    ["starter", 3],
    ["pro", 4]
  ]);

  return [...plans].sort((left, right) => {
    const leftOrder = order.get(normalizePlanCode(left?.planCode)) || 99;
    const rightOrder = order.get(normalizePlanCode(right?.planCode)) || 99;
    return leftOrder - rightOrder;
  });
}

function formatLimitValue(value) {
  return value == null ? "Unlimited" : String(value);
}

function buildPlanFeatureList(planDefinition, featureMetadata = null) {
  const metadataByKey = getFeatureMetadata(planDefinition, featureMetadata);
  const featureFlags = planDefinition?.featureFlags || {};

  return Object.keys(metadataByKey)
    .filter((key) => featureFlags?.[key] === true)
    .map((key) => ({
      key,
      label: metadataByKey[key]?.label || key,
      description: metadataByKey[key]?.description || ""
    }));
}

function buildPublicPlansPayload(planDefinitions, featureMetadata = null) {
  const items = sortPlansForDisplay(planDefinitions)
    .filter((plan) => plan?.isActive !== false)
    .map((plan) => {
      const normalizedPlanCode = normalizePlanCode(plan?.planCode);
      const selectedPlan = getPlanByCode(planDefinitions, normalizedPlanCode);
      const limits = selectedPlan?.limits || {};

      return {
        planCode: normalizedPlanCode,
        label: selectedPlan?.label || normalizedPlanCode,
        description: selectedPlan?.description || "",
        durationType: selectedPlan?.durationType || "forever",
        durationDays: selectedPlan?.durationDays ?? null,
        limits: {
          maxSfUsers: limits?.maxSfUsers ?? null,
          maxForms: limits?.maxForms ?? null,
          maxSubmissionsPerMonth: limits?.maxSubmissionsPerMonth ?? null,
          submissionLogRetentionDays: limits?.submissionLogRetentionDays ?? null
        },
        limitSummary: [
          {
            key: "maxForms",
            label: "Forms",
            value: formatLimitValue(limits?.maxForms ?? null)
          },
          {
            key: "maxSubmissionsPerMonth",
            label: "Monthly submissions",
            value: formatLimitValue(limits?.maxSubmissionsPerMonth ?? null)
          },
          {
            key: "maxSfUsers",
            label: "Active users",
            value: formatLimitValue(limits?.maxSfUsers ?? null)
          }
        ],
        features: buildPlanFeatureList(selectedPlan, featureMetadata)
      };
    });

  return {
    success: true,
    storageMode: "dynamodb",
    items
  };
}

function buildTenantEntitlementsPayload(orgId, tenantRecord, planResult) {
  const planCode = normalizePlanCode(null, tenantRecord);
  const selectedPlan = getPlanByCode(planResult.items, planCode);
  const limits = getEffectivePlanLimits(tenantRecord, selectedPlan);
  const featureFlags = getEffectivePlanFeatures(tenantRecord, selectedPlan);

  return {
    success: true,
    orgId,
    planCode,
    planLabel: selectedPlan?.label || "Trial",
    effectiveFeatureFlags: featureFlags,
    effectiveLimits: limits
  };
}

function getEffectiveSubscriptionEndDate(tenantRecord) {
  if (!tenantRecord) {
    return null;
  }

  const subscriptionState = String(tenantRecord.subscriptionState || tenantRecord.planCode || "").toLowerCase();
  if (subscriptionState === "trial") {
    return tenantRecord.trialEndsAt || tenantRecord.planEndsAt || tenantRecord.subscriptionEndDate || null;
  }

  return tenantRecord.planEndsAt || tenantRecord.subscriptionEndDate || null;
}

function parseNullableNumber(value) {
  if (value == null || value === "") {
    return null;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function isSubscriptionEnded(subscriptionEndDate) {
  if (!subscriptionEndDate) {
    return false;
  }

  const end = new Date(`${subscriptionEndDate}T23:59:59.999Z`);
  return !Number.isNaN(end.getTime()) && end.getTime() < Date.now();
}

function deriveTenantRuntimeStatus(tenantRecord) {
  if (!tenantRecord) {
    return {
      status: "missing",
      reason: "Tenant not found"
    };
  }

  if (tenantRecord.status === "suspended" || tenantRecord.isActive === false) {
    return {
      status: "suspended",
      reason: tenantRecord.statusReason || "Subscription is not active for this Salesforce org"
    };
  }

  if (isSubscriptionEnded(getEffectiveSubscriptionEndDate(tenantRecord))) {
    return {
      status: "expired",
      reason: tenantRecord.statusReason || "Subscription has ended for this Salesforce org"
    };
  }

  const submissionLimit = parseNullableNumber(
    tenantRecord?.effectiveLimits?.maxSubmissionsPerMonth
    ?? tenantRecord?.planLimits?.maxSubmissionsPerMonth
    ?? tenantRecord?.limits?.maxSubmissionsPerMonth
  );
  const submissionsMonth = parseNullableNumber(tenantRecord?.submissionsMonth) ?? 0;

  if (submissionLimit != null && submissionsMonth > submissionLimit) {
    return {
      status: "over_limit",
      reason: tenantRecord.statusReason || "Monthly submission limit has been exceeded for this Salesforce org"
    };
  }

  return {
    status: tenantRecord.status === "trialing" ? "trialing" : "active",
    reason: tenantRecord.statusReason || ""
  };
}

function getTenantRuntimeAccessError(tenantRecord) {
  const runtimeStatus = deriveTenantRuntimeStatus(tenantRecord);
  if (["active", "trialing"].includes(runtimeStatus.status)) {
    return null;
  }

  return runtimeStatus.reason || "Subscription is not active for this Salesforce org";
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

function getBearerToken(headers) {
  const authorization = getHeaderValue(headers, "Authorization");
  if (!authorization) {
    return null;
  }

  const match = String(authorization).match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
}

function getRequestAuthContext(eventOrHeaders) {
  const looksLikeEvent = eventOrHeaders && (
    eventOrHeaders.headers ||
    eventOrHeaders.requestContext ||
    Object.prototype.hasOwnProperty.call(eventOrHeaders, "body")
  );
  if (!looksLikeEvent) {
    return {
      headers: eventOrHeaders || {},
      method: null,
      path: null,
      body: ""
    };
  }

  return {
    headers: eventOrHeaders?.headers || {},
    method: eventOrHeaders?.requestContext?.http?.method || eventOrHeaders?.httpMethod || null,
    path: eventOrHeaders?.requestContext?.http?.path || eventOrHeaders?.rawPath || null,
    body: parseRawEventBody(eventOrHeaders)
  };
}

function hasBootstrapV2SignatureHeaders(headers) {
  return !!(
    getHeaderValue(headers, "x-twinaforms-bootstrap-v2-signature") ||
    getHeaderValue(headers, "x-twinaforms-bootstrap-v2-algorithm")
  );
}

async function recordBootstrapV2Nonce(orgId, nonce, timestamp) {
  const normalizedOrgId = normalizeOrgId(orgId);
  const normalizedNonce = String(nonce || "").trim();
  if (!normalizedOrgId || !normalizedNonce) {
    const error = new Error("Bootstrap V2 signature nonce is missing.");
    error.statusCode = 401;
    throw error;
  }

  const parsedTimestamp = Date.parse(timestamp);
  const ttlSeconds = Math.floor(
    (Number.isFinite(parsedTimestamp) ? parsedTimestamp : Date.now()) / 1000
  ) + (10 * 60);

  try {
    const item = {
      [BOOTSTRAP_V2_NONCE_KEY_ATTRIBUTE]: { S: `${normalizedOrgId}#${normalizedNonce}` },
      orgId: { S: normalizedOrgId },
      nonce: { S: normalizedNonce },
      timestamp: { S: String(timestamp || "") },
      expiresAt: { N: String(ttlSeconds) },
      createdAt: { S: new Date().toISOString() },
      recordType: { S: "bootstrap-v2-nonce" }
    };

    await dynamoClient.send(new PutItemCommand({
      TableName: BOOTSTRAP_V2_NONCE_TABLE,
      Item: item,
      ConditionExpression: `attribute_not_exists(${BOOTSTRAP_V2_NONCE_KEY_ATTRIBUTE})`
    }));
  } catch (error) {
    if (error?.name === "ConditionalCheckFailedException") {
      const replayError = new Error("Unauthorized: Bootstrap V2 signature nonce was already used.");
      replayError.statusCode = 401;
      throw replayError;
    }
    throw error;
  }
}

async function verifyBootstrapV2TenantAuth(eventOrHeaders, orgId) {
  const authContext = getRequestAuthContext(eventOrHeaders);
  const connectionRecord = await getSalesforceConnection(getSalesforceConnectionSecretName(orgId));
  const signingSecretB64 = connectionRecord?.bootstrap_v2_signing_secret_b64;
  if (!signingSecretB64) {
    const error = new Error("Unauthorized: Bootstrap V2 signing secret is not available.");
    error.statusCode = 401;
    throw error;
  }

  const verification = verifyBootstrapV2SignedPayload({
    method: authContext.method,
    path: authContext.path,
    headers: authContext.headers,
    body: authContext.body,
    signingSecretB64
  });

  if (!verification.ok) {
    const error = new Error(`Unauthorized: ${verification.error || "invalid Bootstrap V2 signature"}`);
    error.statusCode = verification.statusCode || 401;
    throw error;
  }

  if (verification.orgId !== normalizeOrgId(orgId)) {
    const error = new Error("Unauthorized: Bootstrap V2 signature org mismatch.");
    error.statusCode = 401;
    throw error;
  }

  await recordBootstrapV2Nonce(verification.orgId, verification.nonce, verification.timestamp);
  return true;
}

function assertTenantIsActive(tenantRecord) {
  const tenantError = getTenantRuntimeAccessError(tenantRecord);
  if (tenantError) {
    const error = new Error(tenantError);
    error.statusCode = 403;
    throw error;
  }
}

async function sendTenantSecretEmail(toAddress, orgId, secret) {
  // SES production access is not available for the launch account. Keep tenant
  // secret delivery on the Connect page only until a new transactional email
  // provider is approved.
  console.log("Tenant secret email disabled for launch; secret is returned on the Connect page only");
  return false;

  // Email delivery disabled for now:
  // if (!SES_FROM) {
  //   console.log("SES_FROM not configured; tenant secret email skipped");
  //   return false;
  // }
  //
  // await sesClient.send(new SendEmailCommand({
  //   Source: SES_FROM,
  //   Destination: {
  //     ToAddresses: [toAddress]
  //   },
  //   Message: {
  //     Subject: {
  //       Data: "Your TwinaForms tenant secret"
  //     },
  //     Body: {
  //       Text: {
  //         Data: `Hello,
  //
  // Your TwinaForms tenant secret for Salesforce org ${orgId} is:
  //
  // ${secret}
  //
  // Paste this value into Salesforce External Credential setup.
  //
  // If you did not request this, you can safely ignore this email.
  //
  // TwinaForms`
  //       }
  //     }
  //   }
  // }));
  //
  // return true;
}

async function sendNewTrialAdminEmail(recipient, tenantRecord) {
  const normalizedRecipient = normalizeOptionalString(recipient);
  if (!normalizedRecipient || !SES_FROM) {
    return false;
  }

  const createdAtDisplay = tenantRecord.createdAt
    ? new Date(tenantRecord.createdAt).toLocaleString("en-US", {
        year: "numeric",
        month: "short",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
        hour12: false,
        timeZone: "UTC",
        timeZoneName: "short"
      })
    : "";
  const lines = [
    "Hi Yosi,",
    "",
    "A new NativeForms trial tenant was created.",
    "",
    `Company Name: ${tenantRecord.companyName || ""}`,
    `Org Id: ${tenantRecord.orgId || ""}`,
    `Admin Email: ${tenantRecord.adminEmail || ""}`,
    `Login Base URL: ${tenantRecord.loginBaseUrl || ""}`,
    `Plan Code: ${tenantRecord.planCode || ""}`,
    `Subscription State: ${tenantRecord.subscriptionState || ""}`,
    `Trial Start Date: ${tenantRecord.trialStartedAt || tenantRecord.subscriptionStartDate || ""}`,
    `Trial End Date: ${tenantRecord.trialEndsAt || tenantRecord.subscriptionEndDate || ""}`,
    `Country: ${tenantRecord.country || ""}`,
    `State: ${tenantRecord.state || ""}`,
    `City: ${tenantRecord.city || ""}`,
    `Created At: ${createdAtDisplay}`,
    "",
    "TwinaForms Automation"
  ];
  const htmlBody = `
    <html>
      <body style="font-family: Arial, sans-serif; color: #16325c; line-height: 1.6;">
        <p>Hi Yosi,</p>
        <p>A new <strong>NativeForms trial tenant</strong> was created.</p>
        <p>
          <strong>Company Name:</strong> ${tenantRecord.companyName || ""}<br>
          <strong>Org Id:</strong> ${tenantRecord.orgId || ""}<br>
          <strong>Admin Email:</strong> ${tenantRecord.adminEmail || ""}<br>
          <strong>Login Base URL:</strong> ${tenantRecord.loginBaseUrl || ""}<br>
          <strong>Plan Code:</strong> ${tenantRecord.planCode || ""}<br>
          <strong>Subscription State:</strong> ${tenantRecord.subscriptionState || ""}<br>
          <strong>Trial Start Date:</strong> ${tenantRecord.trialStartedAt || tenantRecord.subscriptionStartDate || ""}<br>
          <strong>Trial End Date:</strong> ${tenantRecord.trialEndsAt || tenantRecord.subscriptionEndDate || ""}<br>
          <strong>Country:</strong> ${tenantRecord.country || ""}<br>
          <strong>State:</strong> ${tenantRecord.state || ""}<br>
          <strong>City:</strong> ${tenantRecord.city || ""}<br>
          <strong>Created At:</strong> ${createdAtDisplay}
        </p>
        <p>TwinaForms Automation</p>
      </body>
    </html>
  `;

  await sesClient.send(new SendEmailCommand({
    Source: SES_FROM,
    Destination: {
      ToAddresses: [normalizedRecipient]
    },
    Message: {
      Subject: {
        Data: `New NativeForms trial tenant: ${tenantRecord.companyName || tenantRecord.orgId || "Unknown tenant"}`
      },
      Body: {
        Html: {
          Data: htmlBody
        },
        Text: {
          Data: lines.join("\n")
        }
      }
    }
  }));

  return true;
}

async function requireTenantAuth(eventOrHeaders, orgId) {
  const normalizedOrgId = normalizeOrgId(orgId);
  const authContext = getRequestAuthContext(eventOrHeaders);

  if (!orgId) {
    const error = new Error("Missing required field: orgId");
    error.statusCode = 400;
    throw error;
  }

  if (!validateOrgId(normalizedOrgId)) {
    const error = new Error("Invalid orgId");
    error.statusCode = 400;
    throw error;
  }

  const tenantRecord = await getTenantRecord(normalizedOrgId);
  if (!tenantRecord) {
    const error = new Error("Tenant not found");
    error.statusCode = 404;
    throw error;
  }

  const bearerToken = getBearerToken(authContext.headers);
  if (bearerToken && tenantRecord.secret === bearerToken) {
    assertTenantIsActive(tenantRecord);
    return tenantRecord;
  }

  if (hasBootstrapV2SignatureHeaders(authContext.headers)) {
    await verifyBootstrapV2TenantAuth(eventOrHeaders, normalizedOrgId);
    assertTenantIsActive(tenantRecord);
    return tenantRecord;
  }

  if (!bearerToken) {
    const error = new Error("Missing Authorization bearer token");
    error.statusCode = 401;
    throw error;
  }

  if (tenantRecord.secret !== bearerToken) {
    const error = new Error("Unauthorized: invalid tenant secret");
    error.statusCode = 401;
    throw error;
  }

  assertTenantIsActive(tenantRecord);
  return tenantRecord;
}

function validateTenantRegistrationPayload(payload) {
  if (!payload?.orgId) throw new Error("Missing required field: orgId");
  if (!validateOrgId(normalizeOrgId(payload.orgId))) throw new Error("Invalid orgId");
  if (!payload?.adminEmail) throw new Error("Missing required field: adminEmail");
  if (!payload?.companyName) throw new Error("Missing required field: companyName");
  if (!payload?.loginBaseUrl) throw new Error("Missing required field: loginBaseUrl");
}

function validateClientCredentialsPayload(payload) {
  if (!payload?.orgId) throw new Error("Missing required field: orgId");
  if (!validateOrgId(normalizeOrgId(payload.orgId))) throw new Error("Invalid orgId");
  if (!payload?.adminEmail) throw new Error("Missing required field: adminEmail");
  if (!payload?.companyName) throw new Error("Missing required field: companyName");
  if (!payload?.loginBaseUrl) throw new Error("Missing required field: loginBaseUrl");
}

function validateFormSecurityPayload(payload) {
  if (!payload?.orgId) throw new Error("Missing required field: orgId");
  if (!validateOrgId(normalizeOrgId(payload.orgId))) throw new Error("Invalid orgId");
  if (!payload?.formId) throw new Error("Missing required field: formId");
  if (!payload?.publishToken) throw new Error("Missing required field: publishToken");
  if (!payload?.publishedVersionId) throw new Error("Missing required field: publishedVersionId");
  if (!payload?.status) throw new Error("Missing required field: status");
  if (!payload?.securityMode) throw new Error("Missing required field: securityMode");
  if (!payload?.companySlug) throw new Error("Missing required field: companySlug");
  if (!payload?.formSlug) throw new Error("Missing required field: formSlug");
  if (!payload?.prefillPolicy || typeof payload.prefillPolicy !== "object") {
    throw new Error("Missing required field: prefillPolicy");
  }
  if (!payload?.submitPolicy || typeof payload.submitPolicy !== "object") {
    throw new Error("Missing required field: submitPolicy");
  }
  if (!payload?.prefillDefinition || typeof payload.prefillDefinition !== "object") {
    throw new Error("Missing required field: prefillDefinition");
  }
  if (!Array.isArray(payload.prefillDefinition.commands)) {
    throw new Error("Missing required field: prefillDefinition.commands");
  }
  if (!payload.prefillDefinition.responseMapping || typeof payload.prefillDefinition.responseMapping !== "object") {
    throw new Error("Missing required field: prefillDefinition.responseMapping");
  }
  if (!payload?.submitDefinition || typeof payload.submitDefinition !== "object") {
    throw new Error("Missing required field: submitDefinition");
  }
  if (!Array.isArray(payload.submitDefinition.commands)) {
    throw new Error("Missing required field: submitDefinition.commands");
  }
  if (payload.uploadFields != null && !Array.isArray(payload.uploadFields)) {
    throw new Error("uploadFields must be an array when provided");
  }
  if (payload.signatureFields != null && !Array.isArray(payload.signatureFields)) {
    throw new Error("signatureFields must be an array when provided");
  }
  if (payload.recordsListRowSignatures != null && !Array.isArray(payload.recordsListRowSignatures)) {
    throw new Error("recordsListRowSignatures must be an array when provided");
  }
  if (payload.lookupDefinition != null && (typeof payload.lookupDefinition !== "object" || Array.isArray(payload.lookupDefinition))) {
    throw new Error("lookupDefinition must be an object when provided");
  }
  if (payload.locationDefinition != null && (typeof payload.locationDefinition !== "object" || Array.isArray(payload.locationDefinition))) {
    throw new Error("locationDefinition must be an object when provided");
  }
  if (payload.submissionPdf != null && (typeof payload.submissionPdf !== "object" || Array.isArray(payload.submissionPdf))) {
    throw new Error("submissionPdf must be an object when provided");
  }
}

function validatePublishPresignPayload(payload) {
  if (!payload?.orgId) throw new Error("Missing required field: orgId");
  if (!validateOrgId(normalizeOrgId(payload.orgId))) throw new Error("Invalid orgId");
  if (!payload?.formId) throw new Error("Missing required field: formId");
  if (!payload?.formSlug) throw new Error("Missing required field: formSlug");
  if (!payload?.fileName) throw new Error("Missing required field: fileName");
}

function validateFormUnpublishPayload(payload) {
  if (!payload?.orgId) throw new Error("Missing required field: orgId");
  if (!validateOrgId(normalizeOrgId(payload.orgId))) throw new Error("Invalid orgId");
  if (!payload?.formId) throw new Error("Missing required field: formId");
}

function validateUploadInitPayload(payload) {
  if (!payload?.formId) throw new Error("Missing required field: formId");
  if (!payload?.publishToken) throw new Error("Missing required field: publishToken");
  if (!payload?.fieldKey) throw new Error("Missing required field: fieldKey");
  if (!payload?.fileName) throw new Error("Missing required field: fileName");
  if (!payload?.sessionId) throw new Error("Missing required field: sessionId");
}

function validateUploadStatusPayload(payload) {
  if (!payload?.formId) throw new Error("Missing required field: formId");
  if (!payload?.publishToken) throw new Error("Missing required field: publishToken");
  if (!payload?.fieldKey) throw new Error("Missing required field: fieldKey");
  if (!payload?.sessionId) throw new Error("Missing required field: sessionId");
  if (!payload?.uploadToken) throw new Error("Missing required field: uploadToken");
}

function validateLookupPayload(payload) {
  if (!payload?.formId) throw new Error("Missing required field: formId");
  if (!payload?.publishToken) throw new Error("Missing required field: publishToken");
  if (!payload?.fieldKey) throw new Error("Missing required field: fieldKey");
  if (!payload?.search && !payload?.recordId) throw new Error("Missing required field: search or recordId");
}

function validateLocationPayload(payload) {
  if (!payload?.formId) throw new Error("Missing required field: formId");
  if (!payload?.publishToken) throw new Error("Missing required field: publishToken");
  if (!payload?.fieldKey) throw new Error("Missing required field: fieldKey");
  if (!payload?.kind) throw new Error("Missing required field: kind");
  if (!payload?.search) throw new Error("Missing required field: search");
  if (!["country", "region", "city"].includes(String(payload.kind))) {
    throw new Error("Invalid location search kind");
  }
}

function validateSalesforceLayoutPayload(payload) {
  if (!payload?.orgId) throw new Error("Missing required field: orgId");
  if (!validateOrgId(normalizeOrgId(payload.orgId))) throw new Error("Invalid orgId");
  if (!payload?.objectApiName) throw new Error("Missing required field: objectApiName");
  if (!isSafeSalesforceIdentifier(payload.objectApiName)) throw new Error("Invalid objectApiName");
  if (payload?.languageCode) {
    const requestedLanguageCode = String(payload.languageCode || "").trim().toLowerCase();
    if (!["en", "he", "es", "de", "fr"].includes(requestedLanguageCode)) {
      throw new Error("Invalid languageCode");
    }
  }
  if (payload?.recordTypeId && !/^[A-Za-z0-9]{15,18}$/.test(String(payload.recordTypeId))) {
    throw new Error("Invalid recordTypeId");
  }
}

function httpsRequest(options, body = null) {
  return new Promise((resolve, reject) => {
    const request = https.request(options, (response) => {
      let data = "";
      response.on("data", (chunk) => {
        data += chunk;
      });
      response.on("end", () => {
        resolve({
          statusCode: response.statusCode,
          headers: response.headers,
          body: data
        });
      });
    });

    request.on("error", reject);
    if (body) {
      request.write(body);
    }
    request.end();
  });
}

async function refreshAccessToken(secret, loginUrl) {
  const credentials = await getSalesforceOAuthClientCredentials();
  const normalizedLoginUrl = String(loginUrl || "https://login.salesforce.com").replace(/\/+$/, "");
  const tokenBody = querystring.stringify({
    grant_type: "refresh_token",
    client_id: credentials.clientId,
    client_secret: credentials.clientSecret,
    refresh_token: secret.refresh_token
  });
  let tokenUrl = new URL("/services/oauth2/token", `${normalizedLoginUrl}/`);
  let response = null;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    response = await httpsRequest(
      {
        hostname: tokenUrl.hostname,
        path: `${tokenUrl.pathname}${tokenUrl.search || ""}`,
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Content-Length": Buffer.byteLength(tokenBody)
        }
      },
      tokenBody
    );
    if (![301, 302, 303, 307, 308].includes(response.statusCode) || !response.headers?.location) {
      break;
    }
    tokenUrl = new URL(response.headers.location, tokenUrl);
  }

  if (response.statusCode !== 200) {
    throw new Error(`Salesforce token refresh failed. Status: ${response.statusCode}. Body: ${response.body}`);
  }

  const tokenData = JSON.parse(response.body);
  if (tokenData.instance_url) {
    secret.instance_url = tokenData.instance_url;
  }
  return tokenData.access_token;
}

function normalizeSalesforceLanguageCode(value) {
  const normalized = String(value || "en").trim().toLowerCase();
  return ["en", "he", "es", "de", "fr"].includes(normalized) ? normalized : "en";
}

function isSafeSalesforceIdentifier(value) {
  return /^[A-Za-z][A-Za-z0-9_]*(?:__c)?$/.test(String(value || ""));
}

function escapeSoqlValue(value) {
  return String(value ?? "").replace(/\\/g, "\\\\").replace(/'/g, "\\'");
}

function normalizeLookupFields(fields) {
  const seen = new Set();
  return (Array.isArray(fields) ? fields : [])
    .map((value) => String(value || "").trim())
    .filter((value) => isSafeSalesforceIdentifier(value))
    .filter((value) => {
      const key = value.toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function normalizeLookupConfig(definition) {
  const targetObject = String(definition?.targetObject || "").trim();
  const searchFields = normalizeLookupFields(definition?.searchFields);
  let displayFields = normalizeLookupFields(definition?.displayFields);
  if (!targetObject || !isSafeSalesforceIdentifier(targetObject) || searchFields.length === 0) {
    const error = new Error("Lookup field is not configured correctly.");
    error.statusCode = 400;
    throw error;
  }
  if (!displayFields.length) {
    displayFields = [...searchFields];
  }
  if (!displayFields.some((field) => field.toLowerCase() === "id")) {
    displayFields.push("Id");
  }
  return {
    targetObject,
    searchFields,
    displayFields,
    minSearchLength: Math.max(1, Math.min(Number(definition?.minSearchLength) || 2, 10)),
    limit: Math.max(1, Math.min(Number(definition?.limit) || 10, 25))
  };
}

async function querySalesforce(instanceUrl, accessToken, soql) {
  const url = new URL(instanceUrl);
  const response = await httpsRequest({
    hostname: url.hostname,
    path: `/services/data/${SALESFORCE_API_VERSION}/query?q=${encodeURIComponent(soql)}`,
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`
    }
  });

  if (response.statusCode !== 200) {
    throw new Error(`Lookup query failed. Status: ${response.statusCode}. Body: ${response.body}`);
  }

  return JSON.parse(response.body);
}

async function salesforceGetJson(instanceUrl, accessToken, path, failureLabel, extraHeaders = {}) {
  const url = new URL(instanceUrl);
  const response = await httpsRequest({
    hostname: url.hostname,
    path,
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      ...extraHeaders
    }
  });

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw new Error(`${failureLabel} failed. Status: ${response.statusCode}. Body: ${response.body}`);
  }

  return JSON.parse(response.body);
}

function pickLayoutNode(layoutResponse, objectApiName) {
  if (Array.isArray(layoutResponse?.sections)) {
    return layoutResponse;
  }

  const layouts = layoutResponse?.layouts;
  if (layouts && typeof layouts === "object") {
    const objectLayout =
      layouts[objectApiName] ||
      layouts[String(objectApiName || "").toLowerCase()] ||
      Object.values(layouts).find((value) => value && typeof value === "object");
    const fullLayout = objectLayout?.Full || objectLayout?.FULL || objectLayout?.full;
    const editLayout = fullLayout?.Edit || fullLayout?.EDIT || fullLayout?.edit;
    if (Array.isArray(editLayout?.sections)) {
      return editLayout;
    }
  }

  const queue = [layoutResponse];
  while (queue.length) {
    const candidate = queue.shift();
    if (!candidate || typeof candidate !== "object") {
      continue;
    }
    if (Array.isArray(candidate.sections)) {
      return candidate;
    }
    Object.values(candidate).forEach((value) => {
      if (value && typeof value === "object") {
        queue.push(value);
      }
    });
  }

  return null;
}

function collectLayoutItemFields(layoutItem) {
  const components = Array.isArray(layoutItem?.layoutComponents) ? layoutItem.layoutComponents : [];
  return components
    .filter((component) => {
      const type = String(component?.componentType || component?.type || "").toLowerCase();
      return !type || type === "field";
    })
    .map((component) => String(component?.apiName || component?.value || "").trim())
    .filter((apiName) => isSafeSalesforceIdentifier(apiName));
}

function objectFieldInfo(fieldsInfo, apiName) {
  const normalizedKey = String(apiName || "").toLowerCase();
  return fieldsInfo?.[apiName] ||
    fieldsInfo?.[Object.keys(fieldsInfo || {}).find((key) => key.toLowerCase() === normalizedKey)] ||
    {};
}

function normalizePicklistValues(values) {
  if (!Array.isArray(values)) {
    return [];
  }
  return values
    .filter((entry) => entry && typeof entry === "object")
    .filter((entry) => entry.active !== false)
    .map((entry) => ({
      label: String(entry.label ?? entry.value ?? "").trim(),
      value: String(entry.value ?? "").trim()
    }))
    .filter((entry) => entry.value);
}

function fieldInfoIsPicklist(fieldInfo) {
  const dataType = String(fieldInfo?.dataType || fieldInfo?.type || "")
    .toLowerCase()
    .replace(/[^a-z]/g, "");
  return dataType === "picklist" ||
    dataType === "multipicklist" ||
    dataType === "multiselectpicklist";
}

function normalizeUiApiLayout(layoutResponse, objectInfo, objectApiName, recordTypeId) {
  const layoutNode = pickLayoutNode(layoutResponse, objectApiName);
  if (!layoutNode) {
    throw new Error("Salesforce layout metadata response did not include sections.");
  }

  const fieldsInfo = objectInfo?.fields || {};
  const seenFields = new Set();
  const sections = [];
  let skippedLayoutItems = 0;

  (Array.isArray(layoutNode.sections) ? layoutNode.sections : []).forEach((section, sectionIndex) => {
    const fields = [];
    const rows = Array.isArray(section?.layoutRows) ? section.layoutRows : [];
    rows.forEach((row) => {
      const items = Array.isArray(row?.layoutItems) ? row.layoutItems : [];
      items.forEach((item) => {
        const apiNames = collectLayoutItemFields(item);
        if (!apiNames.length) {
          skippedLayoutItems += 1;
          return;
        }
        apiNames.forEach((apiName) => {
          const normalizedKey = apiName.toLowerCase();
          if (seenFields.has(normalizedKey)) {
            return;
          }
          seenFields.add(normalizedKey);
          const fieldInfo = objectFieldInfo(fieldsInfo, apiName);
          const normalizedField = {
            apiName,
            label: item?.label || fieldInfo?.label || apiName,
            required: item?.required === true || fieldInfo?.required === true,
            editableForNew: item?.editableForNew !== false,
            editableForUpdate: item?.editableForUpdate !== false
          };
          if (fieldInfoIsPicklist(fieldInfo)) {
            normalizedField.dataType = fieldInfo.dataType || fieldInfo.type || "";
            const inlineValues = normalizePicklistValues(fieldInfo.picklistValues || fieldInfo.values);
            if (inlineValues.length) {
              normalizedField.picklistValues = inlineValues;
            }
          }
          fields.push(normalizedField);
        });
      });
    });

    if (fields.length) {
      sections.push({
        heading: String(section?.heading || section?.label || `Section ${sectionIndex + 1}`).trim() || `Section ${sectionIndex + 1}`,
        fields
      });
    }
  });

  const objectLabel = objectInfo?.label || objectInfo?.labelPlural || objectApiName;
  const layoutKey = `assigned:${recordTypeId || objectInfo?.defaultRecordTypeId || "default"}`;
  const layoutLabel = `${objectLabel} assigned layout`;
  const warnings = [];
  if (skippedLayoutItems > 0) {
    warnings.push(`${skippedLayoutItems} non-field layout items were skipped.`);
  }

  return {
    layoutKey,
    layoutLabel,
    objectApiName,
    objectLabel,
    recordTypeId: recordTypeId || objectInfo?.defaultRecordTypeId || null,
    sections,
    warnings
  };
}

async function enrichLayoutPicklistValues(layout, objectInfo, instanceUrl, accessToken, objectApiName, recordTypeId, languageHeaders) {
  const fieldsInfo = objectInfo?.fields || {};
  const effectiveRecordTypeId = String(recordTypeId || objectInfo?.defaultRecordTypeId || layout?.recordTypeId || "").trim();
  if (!layout || !effectiveRecordTypeId) {
    return layout;
  }

  const picklistFields = [];
  (layout.sections || []).forEach((section) => {
    (section.fields || []).forEach((field) => {
      const fieldInfo = objectFieldInfo(fieldsInfo, field.apiName);
      if (fieldInfoIsPicklist(fieldInfo)) {
        picklistFields.push(field);
      }
    });
  });

  const warnings = layout.warnings || [];
  await Promise.all(picklistFields.map(async (field) => {
    try {
      const picklistResponse = await salesforceGetJson(
        instanceUrl,
        accessToken,
        `/services/data/${SALESFORCE_API_VERSION}/ui-api/object-info/${encodeURIComponent(objectApiName)}/picklist-values/${encodeURIComponent(effectiveRecordTypeId)}/${encodeURIComponent(field.apiName)}`,
        `Salesforce picklist values for ${field.apiName}`,
        languageHeaders
      );
      const values = normalizePicklistValues(picklistResponse?.values);
      if (values.length) {
        field.picklistValues = values;
      }
    } catch (error) {
      warnings.push(`Translated picklist values could not be loaded for ${field.apiName}.`);
    }
  }));
  layout.warnings = warnings;
  return layout;
}

async function getSalesforceAssignedLayout(instanceUrl, accessToken, objectApiName, requestedRecordTypeId, languageCode = "en") {
  const normalizedLanguageCode = normalizeSalesforceLanguageCode(languageCode);
  const languageHeaders = {
    "Accept-Language": normalizedLanguageCode
  };
  const objectInfo = await salesforceGetJson(
    instanceUrl,
    accessToken,
    `/services/data/${SALESFORCE_API_VERSION}/ui-api/object-info/${encodeURIComponent(objectApiName)}`,
    "Salesforce object metadata",
    languageHeaders
  );
  const recordTypeId = String(requestedRecordTypeId || objectInfo?.defaultRecordTypeId || "").trim();
  const params = new URLSearchParams({
    layoutType: "Full",
    mode: "Edit",
    formFactor: "Large"
  });
  if (recordTypeId) {
    params.set("recordTypeId", recordTypeId);
  }
  const layoutResponse = await salesforceGetJson(
    instanceUrl,
    accessToken,
    `/services/data/${SALESFORCE_API_VERSION}/ui-api/layout/${encodeURIComponent(objectApiName)}?${params.toString()}`,
    "Salesforce page layout metadata",
    languageHeaders
  );
  const layout = normalizeUiApiLayout(layoutResponse, objectInfo, objectApiName, recordTypeId);
  await enrichLayoutPicklistValues(layout, objectInfo, instanceUrl, accessToken, objectApiName, recordTypeId, languageHeaders);
  layout.languageCode = normalizedLanguageCode;
  return layout;
}

async function runSalesforceLayoutMetadata(payload, tenantRecord) {
  const orgId = normalizeOrgId(payload.orgId);
  const connection = await getSalesforceConnection(getSalesforceConnectionSecretName(orgId));
  if (!connection?.refresh_token || !connection?.instance_url) {
    const error = new Error("Salesforce connection is not ready for page-layout metadata.");
    error.statusCode = 409;
    throw error;
  }

  const accessToken = await refreshAccessToken(connection, connection.loginBaseUrl || tenantRecord?.loginBaseUrl);
  const layout = await getSalesforceAssignedLayout(
    connection.instance_url,
    accessToken,
    String(payload.objectApiName).trim(),
    payload.recordTypeId,
    payload.languageCode
  );

  return {
    success: true,
    orgId,
    objectApiName: layout.objectApiName,
    objectLabel: layout.objectLabel,
    languageCode: layout.languageCode,
    defaultLayoutKey: layout.layoutKey,
    layouts: [
      {
        label: layout.layoutLabel,
        value: layout.layoutKey
      }
    ],
    layout,
    warnings: layout.warnings || []
  };
}

async function getSalesforceRecordById(instanceUrl, accessToken, objectApiName, recordId, fields) {
  const url = new URL(instanceUrl);
  const response = await httpsRequest({
    hostname: url.hostname,
    path: `/services/data/${SALESFORCE_API_VERSION}/sobjects/${encodeURIComponent(objectApiName)}/${encodeURIComponent(recordId)}?fields=${encodeURIComponent(fields.join(","))}`,
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`
    }
  });

  if (response.statusCode === 404) {
    return null;
  }
  if (response.statusCode !== 200) {
    throw new Error(`Lookup resolve failed. Status: ${response.statusCode}. Body: ${response.body}`);
  }
  return JSON.parse(response.body);
}

function readSalesforceRecordField(record, fieldName) {
  if (!record || !fieldName) {
    return undefined;
  }
  if (Object.prototype.hasOwnProperty.call(record, fieldName)) {
    return record[fieldName];
  }
  const requested = String(fieldName).toLowerCase();
  const actualKey = Object.keys(record).find((key) => String(key).toLowerCase() === requested);
  return actualKey ? record[actualKey] : undefined;
}

function buildLookupLabel(record, displayFields) {
  const parts = displayFields
    .filter((field) => String(field).toLowerCase() !== "id")
    .map((field) => readSalesforceRecordField(record, field))
    .filter((value) => value !== null && value !== undefined && String(value).trim() !== "")
    .map((value) => String(value));
  return parts.length ? parts.join(" - ") : String(record?.Id || "");
}

function formatLookupRecord(record, displayFields) {
  if (!record?.Id) {
    return null;
  }
  return {
    id: record.Id,
    label: buildLookupLabel(record, displayFields),
    fields: Object.fromEntries(displayFields.filter((field) => field !== "attributes").map((field) => [field, readSalesforceRecordField(record, field) ?? null]))
  };
}

async function runLookup(payload, formSecurity) {
  const lookupDefinition = findLookupFieldDefinition(formSecurity, payload.fieldKey);
  if (!lookupDefinition) {
    const error = new Error("Lookup is not configured for this field.");
    error.statusCode = 400;
    throw error;
  }

  const config = normalizeLookupConfig(lookupDefinition);
  const tenantRecord = await getTenantRecord(formSecurity.orgId);
  assertTenantIsActive(tenantRecord);
  const secret = await getSalesforceConnection(getSalesforceConnectionSecretName(formSecurity.orgId));
  if (!secret?.refresh_token || !secret?.instance_url) {
    const error = new Error("Salesforce connection is not ready for lookup.");
    error.statusCode = 409;
    throw error;
  }
  const accessToken = await refreshAccessToken(secret, tenantRecord.loginBaseUrl || secret.loginBaseUrl || "https://login.salesforce.com");

  if (payload.recordId) {
    const record = await getSalesforceRecordById(secret.instance_url, accessToken, config.targetObject, String(payload.recordId), config.displayFields);
    return {
      success: true,
      mode: "resolve",
      record: formatLookupRecord(record, config.displayFields)
    };
  }

  const search = String(payload.search || "").trim();
  if (search.length < config.minSearchLength) {
    return {
      success: true,
      mode: "search",
      records: []
    };
  }

  const fieldsToSelect = Array.from(new Set(["Id", ...config.displayFields]));
  const searchTerm = `%${escapeSoqlValue(search)}%`;
  const whereClause = config.searchFields.map((field) => `${field} LIKE '${searchTerm}'`).join(" OR ");
  const soql = `SELECT ${fieldsToSelect.join(", ")} FROM ${config.targetObject} WHERE ${whereClause} ORDER BY LastModifiedDate DESC LIMIT ${config.limit}`;
  const result = await querySalesforce(secret.instance_url, accessToken, soql);
  const records = Array.isArray(result.records)
    ? result.records.map((record) => formatLookupRecord(record, config.displayFields)).filter(Boolean)
    : [];
  return {
    success: true,
    mode: "search",
    records
  };
}

function normalizeCountryCode(value) {
  const code = String(value || "").trim().toUpperCase();
  return /^[A-Z]{2}$/.test(code) ? code : "";
}

function normalizeSearchText(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function normalizeLocationConfig(definition) {
  const mode = ["country", "countryRegion", "countryCity", "countryRegionCity"].includes(String(definition?.mode || ""))
    ? String(definition.mode)
    : "countryRegionCity";
  const allowedCountries = Array.isArray(definition?.allowedCountries)
    ? definition.allowedCountries.map(normalizeCountryCode).filter(Boolean)
    : [];
  return {
    mode,
    allowedCountries,
    minSearchLength: Math.min(Math.max(Number(definition?.minSearchLength) || 2, 1), 10),
    limit: Math.min(Math.max(Number(definition?.limit) || 10, 1), 25)
  };
}

function locationPartitionForPayload(payload) {
  const kind = String(payload?.kind || "");
  if (kind === "country") return "country";
  const countryCode = normalizeCountryCode(payload?.countryCode);
  if (!countryCode) {
    const error = new Error("Country is required for this location search.");
    error.statusCode = 400;
    throw error;
  }
  if (kind === "region") return `region#${countryCode}`;
  const regionCode = String(payload?.regionCode || "").trim();
  return regionCode ? `city#${countryCode}#${regionCode}` : `city#${countryCode}`;
}

function formatLocationRecord(item) {
  return {
    kind: item.kind || item.type || "",
    label: item.label || item.displayLabel || item.name || item.cityName || item.countryName || "",
    countryCode: item.countryCode || item.code || "",
    countryName: item.countryName || "",
    regionCode: item.regionCode || "",
    regionName: item.regionName || "",
    cityName: item.cityName || item.name || "",
    geoNameId: item.geoNameId || "",
    latitude: item.latitude ?? null,
    longitude: item.longitude ?? null,
    displayLabel: item.displayLabel || item.label || ""
  };
}

async function queryGeoLocations(partition, search, limit) {
  const result = await dynamoClient.send(new QueryCommand({
    TableName: GEO_LOCATION_TABLE,
    KeyConditionExpression: "locationPartition = :partition AND begins_with(searchKey, :search)",
    ExpressionAttributeValues: {
      ":partition": { S: partition },
      ":search": { S: search }
    },
    Limit: Math.min(Math.max(limit * 5, limit), 100)
  }));
  return (result.Items || []).map(unmarshallItem);
}

async function runLocationSearch(payload, formSecurity) {
  const locationDefinition = findLocationFieldDefinition(formSecurity, payload.fieldKey);
  if (!locationDefinition) {
    const error = new Error("Location is not configured for this field.");
    error.statusCode = 400;
    throw error;
  }

  const config = normalizeLocationConfig(locationDefinition);
  const search = normalizeSearchText(payload.search);
  if (search.length < (payload.kind === "country" ? 1 : config.minSearchLength)) {
    return { success: true, mode: "search", records: [] };
  }
  if (payload.kind === "region" && !["countryRegion", "countryRegionCity"].includes(config.mode)) {
    const error = new Error("State/region search is not enabled for this location field.");
    error.statusCode = 400;
    throw error;
  }
  if (payload.kind === "city" && !["countryCity", "countryRegionCity"].includes(config.mode)) {
    const error = new Error("City search is not enabled for this location field.");
    error.statusCode = 400;
    throw error;
  }
  const countryCode = normalizeCountryCode(payload.countryCode);
  if (config.allowedCountries.length && payload.kind !== "country" && !config.allowedCountries.includes(countryCode)) {
    const error = new Error("This country is not enabled for this location field.");
    error.statusCode = 403;
    throw error;
  }

  const partition = locationPartitionForPayload(payload);
  let records = await queryGeoLocations(partition, search, config.limit);
  if (payload.kind === "country" && config.allowedCountries.length) {
    records = records.filter((item) => config.allowedCountries.includes(normalizeCountryCode(item.countryCode || item.code)));
  }
  records = records.sort((a, b) => {
    const populationDelta = Number(b.population || 0) - Number(a.population || 0);
    if (populationDelta) return populationDelta;
    return String(a.label || a.displayLabel || a.name || "").localeCompare(String(b.label || b.displayLabel || b.name || ""));
  });
  return {
    success: true,
    mode: "search",
    records: records.map(formatLocationRecord).filter((item) => item.label || item.displayLabel).slice(0, config.limit)
  };
}

function buildTenantSetupState(tenantRecord, connectionRecord) {
  if (!tenantRecord) {
    return "not_registered";
  }

  const hasRefreshToken = !!connectionRecord?.refresh_token;
  const hasInstanceUrl = !!connectionRecord?.instance_url;
  const isConnected = tenantRecord.salesforceConnectionStatus === "connected" && hasRefreshToken && hasInstanceUrl;

  return isConnected ? "connected" : "registered_pending_connection";
}

function sanitizeKeyPart(value) {
  return String(value || "")
    .trim()
    .replace(/[^A-Za-z0-9._-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "") || "nativeforms";
}

function slugifyPublicSegment(value, fallbackValue) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "") || fallbackValue;
}

function last4OrgId(orgId) {
  const normalized = normalizeOrgId(orgId);
  return normalized ? normalized.slice(-4).toLowerCase() : "org";
}

function buildPublishKey(companySlug, formSlug) {
  const safeCompanySlug = slugifyPublicSegment(companySlug, "company");
  const safeFormSlug = slugifyPublicSegment(formSlug, "form");
  return `${safeCompanySlug}/${safeFormSlug}`;
}

function extractPublishedKey(generatedHtmlRef) {
  const rawValue = String(generatedHtmlRef || "").trim();
  if (!rawValue) return null;

  if (PUBLIC_BASE_URL && rawValue.startsWith(`${PUBLIC_BASE_URL}/`)) {
    return decodeURIComponent(rawValue.substring(PUBLIC_BASE_URL.length + 1));
  }

  if (/^https?:\/\//i.test(rawValue)) {
    try {
      return decodeURIComponent(new URL(rawValue).pathname.replace(/^\/+/, ""));
    } catch (error) {
      return null;
    }
  }

  return rawValue.replace(/^\/+/, "");
}

function buildUnavailableFormHtml() {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Form unavailable</title>
  <style>
    body { margin: 0; font-family: Arial, sans-serif; background: #f7fbff; color: #10233f; }
    main { min-height: 100vh; display: grid; place-items: center; padding: 2rem; }
    section { max-width: 32rem; border: 1px solid #d8e5f4; border-radius: 1rem; background: #fff; padding: 2rem; box-shadow: 0 18px 60px rgba(16, 35, 63, 0.08); }
    h1 { margin: 0 0 0.75rem; font-size: 1.5rem; }
    p { margin: 0; line-height: 1.5; color: #526582; }
  </style>
</head>
<body>
  <main>
    <section>
      <h1>This form is no longer available</h1>
      <p>The TwinaForms form you opened has been unpublished or deleted by the form owner.</p>
    </section>
  </main>
</body>
</html>`;
}

async function replacePublishedFormWithUnavailablePage(generatedHtmlRef) {
  const key = extractPublishedKey(generatedHtmlRef);
  if (!PUBLISH_BUCKET || !key) {
    return false;
  }

  await s3Client.send(new PutObjectCommand({
    Bucket: PUBLISH_BUCKET,
    Key: key,
    ContentType: "text/html; charset=utf-8",
    Body: buildUnavailableFormHtml()
  }));

  return true;
}

async function ensureTenantCompanySlug(orgId, tenantRecord) {
  if (!tenantRecord) {
    throw new Error("Tenant not found");
  }

  if (tenantRecord.companySlug) {
    return {
      companySlug: tenantRecord.companySlug,
      tenantRecord
    };
  }

  const baseCompanySlug = slugifyPublicSegment(tenantRecord.companyName, "company");
  const tenants = await scanAllItems(TENANT_TABLE);
  const collision = tenants.find((tenant) =>
    tenant?.orgId !== orgId &&
    slugifyPublicSegment(tenant?.companySlug || tenant?.companyName, "company") === baseCompanySlug
  );

  let companySlug = baseCompanySlug;
  if (collision) {
    companySlug = `${baseCompanySlug}-${last4OrgId(orgId)}`;
  }

  const updatedTenantRecord = {
    ...tenantRecord,
    companySlug,
    updatedAt: new Date().toISOString()
  };
  await saveItem(TENANT_TABLE, updatedTenantRecord);

  return {
    companySlug,
    tenantRecord: updatedTenantRecord
  };
}

export const handler = async (event) => {
  const path = event?.requestContext?.http?.path || event?.rawPath || "/";
  const method = event?.requestContext?.http?.method || event?.httpMethod || "GET";
  const host = getHeaderValue(event?.headers, "host");
  const protocol = getHeaderValue(event?.headers, "x-forwarded-proto") || "https";
  const baseUrl = host ? `${protocol}://${host}` : null;

  if (method === "OPTIONS") {
    return jsonResponse(200, { success: true });
  }

  if (path === "/tenant/bootstrap-v2/verify-signed-call" && method === "POST") {
    try {
      const rawBody = parseRawEventBody(event);
      const verification = verifyBootstrapV2SignedPayload({
        method,
        path,
        headers: event?.headers || {},
        body: rawBody,
        signingSecretB64: BOOTSTRAP_V2_SPIKE_SECRET_B64
      });

      if (!verification.ok) {
        return jsonResponse(verification.statusCode || 401, {
          success: false,
          experimental: true,
          error: verification.error
        });
      }

      return jsonResponse(200, {
        success: true,
        experimental: true,
        verified: true,
        orgId: verification.orgId,
        bodyHash: verification.bodyHash,
        timestamp: verification.timestamp
      });
    } catch (e) {
      return jsonResponse(e.statusCode || 500, {
        success: false,
        experimental: true,
        error: e.message
      });
    }
  }

  if (path === "/connect") {
    const orgId = normalizeOrgId(event?.queryStringParameters?.orgId);
    if (!orgId || !validateOrgId(orgId)) {
      return {
        statusCode: 400,
        headers: { "Content-Type": "text/html" },
        body: `
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <h2>Missing orgId</h2>
              <p>Call /connect with a valid orgId query parameter.</p>
            </body>
          </html>
        `
      };
    }

    const query = event?.queryStringParameters || {};
    let tenantRecord = await getTenantRecord(orgId);
    if (!tenantRecord) {
      if (!query.loginBaseUrl) {
        return {
          statusCode: 400,
          headers: { "Content-Type": "text/html" },
          body: `
            <html>
              <body style="font-family: Arial, sans-serif; padding: 20px;">
                <h2>Missing Login Base URL</h2>
                <p>Call /connect with loginBaseUrl the first time this org connects.</p>
              </body>
            </html>
          `
        };
      }

      const now = new Date().toISOString();
      const trialLifecycle = buildTrialLifecycleDates();
      tenantRecord = {
        orgId,
        adminEmail: normalizeOptionalString(query.adminEmail) || "",
        companyName: normalizeOptionalString(query.companyName) || "TwinaForms Tenant",
        loginBaseUrl: query.loginBaseUrl,
        country: normalizeOptionalString(query.country),
        state: normalizeOptionalString(query.state),
        city: normalizeOptionalString(query.city),
        secret: generateSecret(),
        planCode: trialLifecycle.planCode,
        status: "active",
        subscriptionState: trialLifecycle.subscriptionState,
        subscriptionStartDate: trialLifecycle.subscriptionStartDate,
        subscriptionEndDate: trialLifecycle.subscriptionEndDate,
        trialStartedAt: trialLifecycle.trialStartedAt,
        trialEndsAt: trialLifecycle.trialEndsAt,
        isActive: true,
        salesforceConnectionStatus: "not-connected",
        salesforceConnectionUpdatedAt: null,
        connectedUsername: null,
        createdAt: now,
        updatedAt: now
      };
      await saveItem(TENANT_TABLE, tenantRecord);
    } else if (query.loginBaseUrl || query.adminEmail || query.companyName) {
      tenantRecord = {
        ...tenantRecord,
        adminEmail: normalizeOptionalString(query.adminEmail) || tenantRecord.adminEmail,
        companyName: normalizeOptionalString(query.companyName) || tenantRecord.companyName,
        loginBaseUrl: query.loginBaseUrl || tenantRecord.loginBaseUrl,
        country: normalizeOptionalString(query.country) ?? tenantRecord.country,
        state: normalizeOptionalString(query.state) ?? tenantRecord.state,
        city: normalizeOptionalString(query.city) ?? tenantRecord.city,
        updatedAt: new Date().toISOString()
      };
      await saveItem(TENANT_TABLE, tenantRecord);
    }

    assertTenantIsActive(tenantRecord);
    if (!tenantRecord.loginBaseUrl) {
      return {
        statusCode: 400,
        headers: { "Content-Type": "text/html" },
        body: `
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <h2>Missing Login Base URL</h2>
              <p>Tenant ${orgId} does not have a stored Salesforce login base URL.</p>
            </body>
          </html>
        `
      };
    }

    const redirectUri = process.env.SF_REDIRECT_URI;
    const loginUrl = tenantRecord.loginBaseUrl;
    let clientId;

    try {
      ({ clientId } = await getSalesforceOAuthClientCredentials());
    } catch (error) {
      return {
        statusCode: 500,
        headers: { "Content-Type": "text/html" },
        body: `
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <h2>TwinaForms OAuth Client Is Not Configured</h2>
              <p>${error.message}</p>
            </body>
          </html>
        `
      };
    }

    const authUrl =
      `${loginUrl}/services/oauth2/authorize` +
      `?response_type=code` +
      `&client_id=${encodeURIComponent(clientId)}` +
      `&redirect_uri=${encodeURIComponent(redirectUri)}` +
      `&state=${encodeURIComponent(orgId)}`;

    return {
      statusCode: 302,
      headers: {
        Location: authUrl
      },
      body: ""
    };
  }

  if (path === "/tenant/status" && method === "GET") {
    try {
      const orgId = normalizeOrgId(event?.queryStringParameters?.orgId);
      if (!orgId) {
        throw new Error("Missing required field: orgId");
      }
      if (!validateOrgId(orgId)) {
        throw new Error("Invalid orgId");
      }

      const tenantRecord = await getTenantRecord(orgId);
      const connectionRecord = tenantRecord
        ? await getSalesforceConnection(getSalesforceConnectionSecretName(orgId))
        : null;
      const setupState = buildTenantSetupState(tenantRecord, connectionRecord);
      const oauthClientConfigured = await hasSalesforceOAuthClientCredentials();

      return jsonResponse(200, {
        success: true,
        registered: !!tenantRecord,
        connected: setupState === "connected",
        setupState,
        connectUrl: tenantRecord && baseUrl ? `${baseUrl}/connect?orgId=${encodeURIComponent(orgId)}` : null,
        tenant: sanitizeTenantRecord(tenantRecord),
        hasClientCredentials: oauthClientConfigured,
        oauthClientConfigured,
        hasRefreshToken: !!connectionRecord?.refresh_token,
        hasInstanceUrl: !!connectionRecord?.instance_url
      });
    } catch (e) {
      return jsonResponse(400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path === "/tenant/home-summary" && method === "GET") {
    try {
      const orgId = normalizeOrgId(event?.queryStringParameters?.orgId);
      if (!orgId) {
        throw new Error("Missing required field: orgId");
      }
      if (!validateOrgId(orgId)) {
        throw new Error("Invalid orgId");
      }

      const [tenantRecord, connectionRecord, planResult, activeFormsCount, adminSettings] = await Promise.all([
        getTenantRecord(orgId),
        getSalesforceConnection(getSalesforceConnectionSecretName(orgId)),
        loadPlanDefinitions(),
        countPublishedForms(orgId),
        loadAdminSettings()
      ]);

      const planCode = normalizePlanCode(null, tenantRecord);
      const selectedPlan = getPlanByCode(planResult.items, planCode);
      const proPlan = getPlanByCode(planResult.items, "pro");
      const limits = getEffectivePlanLimits(tenantRecord, selectedPlan);
      const featureFlags = getEffectivePlanFeatures(tenantRecord, selectedPlan);
      const urls = buildPlanUrls(planCode);
      const setupState = buildTenantSetupState(tenantRecord, connectionRecord);
      let submissionsMonth = 0;

      try {
        submissionsMonth = await countTenantSubmissionsForCurrentMonth(orgId);
      } catch (error) {
        if (!isTableUnavailableError(error)) {
          throw error;
        }
      }

      return jsonResponse(200, {
        success: true,
        orgId,
        registered: !!tenantRecord,
        setupState,
        supportFlags: {
          enableSalesforceAdminApp: tenantRecord?.supportFlags?.enableSalesforceAdminApp === true
        },
        plan: {
          code: planCode,
          label: selectedPlan?.label || "Trial",
          description: selectedPlan?.description || "",
          storageMode: planResult.storageMode,
          retentionDays: limits?.submissionLogRetentionDays ?? null,
          detailedLogsIncluded: featureFlags?.enableDetailedSubmissionLogs === true,
          advancedSecurityIncluded: featureFlags?.enableProSfSecretCodeAuth === true || featureFlags?.enableProUserVerification === true,
          limits,
          featureFlags
        },
        usage: {
          activeFormsCount,
          submissionsMonth,
          maxSubmissionsPerMonth: limits?.maxSubmissionsPerMonth ?? null,
          activeUsersCount: 1,
          maxSfUsers: limits?.maxSfUsers ?? null,
          maxForms: limits?.maxForms ?? null,
          formsUsageMessage: buildFormsUsageMessage(activeFormsCount, limits?.maxForms ?? null)
        },
        includedFeatures: buildIncludedFeatures(featureFlags),
        upgradeFeatures: buildUpgradeFeatures(planCode, featureFlags, proPlan, adminSettings?.featureMetadata || null),
        comparePlansUrl: urls.comparePlansUrl,
        upgradeUrl: urls.upgradeUrl
      });
    } catch (e) {
      return jsonResponse(400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path === "/public/plans" && method === "GET") {
    try {
      const [planResult, adminSettings] = await Promise.all([
        loadPlanDefinitions(),
        loadAdminSettings()
      ]);

      return jsonResponse(200, {
        ...buildPublicPlansPayload(planResult.items, adminSettings?.featureMetadata || null),
        storageMode: planResult.storageMode
      });
    } catch (e) {
      return jsonResponse(400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path === "/tenant/auth-health" && method === "GET") {
    try {
      const orgId = normalizeOrgId(event?.queryStringParameters?.orgId);
      const tenantRecord = await requireTenantAuth(event, orgId);

      return jsonResponse(200, {
        success: true,
        authenticated: true,
        orgId: tenantRecord.orgId
      });
    } catch (e) {
      return jsonResponse(e.statusCode || 400, {
        success: false,
        authenticated: false,
        error: e.message
      });
    }
  }

  if (path === "/tenant/entitlements" && method === "GET") {
    try {
      const orgId = normalizeOrgId(event?.queryStringParameters?.orgId);
      if (!orgId) {
        throw new Error("Missing required field: orgId");
      }
      if (!validateOrgId(orgId)) {
        throw new Error("Invalid orgId");
      }

      const tenantRecord = await requireTenantAuth(event, orgId);
      const planResult = await loadPlanDefinitions();

      return jsonResponse(200, buildTenantEntitlementsPayload(orgId, tenantRecord, planResult));
    } catch (e) {
      return jsonResponse(e.statusCode || 400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path === "/tenant/disconnect" && method === "POST") {
    try {
      const payload = event?.body
        ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
        : {};

      const orgId = normalizeOrgId(payload?.orgId);
      if (!orgId) {
        throw new Error("Missing required field: orgId");
      }
      if (!validateOrgId(orgId)) {
        throw new Error("Invalid orgId");
      }

      const tenantRecord = await requireTenantAuth(event, orgId);

      const now = new Date().toISOString();
      const existingConnection = await getSalesforceConnection(getSalesforceConnectionSecretName(orgId));
      if (existingConnection) {
        await saveSalesforceConnection(getSalesforceConnectionSecretName(orgId), {
          ...stripLegacySalesforceClientCredentials(existingConnection),
          orgId,
          loginBaseUrl: existingConnection.loginBaseUrl || tenantRecord.loginBaseUrl || null,
          refresh_token: null,
          instance_url: null,
          id_url: null,
          token_issued_at: null,
          updated_at: now
        });
      }

      const updatedTenantRecord = {
        ...tenantRecord,
        salesforceConnectionStatus: "not-connected",
        salesforceConnectionUpdatedAt: now,
        connectedUsername: null,
        updatedAt: now
      };
      await saveItem(TENANT_TABLE, updatedTenantRecord);

      return jsonResponse(200, {
        success: true,
        disconnected: true,
        connectUrl: baseUrl ? `${baseUrl}/connect?orgId=${encodeURIComponent(orgId)}` : null,
        tenant: sanitizeTenantRecord(updatedTenantRecord)
      });
    } catch (e) {
      return jsonResponse(e.statusCode || 400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path === "/oauth/callback") {
    const code = event?.queryStringParameters?.code;
    const error = event?.queryStringParameters?.error;
    const errorDescription = event?.queryStringParameters?.error_description;
    const orgId = normalizeOrgId(event?.queryStringParameters?.state || event?.queryStringParameters?.orgId);

    if (error) {
      return {
        statusCode: 200,
        headers: { "Content-Type": "text/html" },
        body: `
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <h2>OAuth Callback Error</h2>
              <p><b>Error:</b> ${error}</p>
              <p><b>Description:</b> ${errorDescription || ""}</p>
            </body>
          </html>
        `
      };
    }

    if (!code) {
      return {
        statusCode: 200,
        headers: { "Content-Type": "text/html" },
        body: `
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <h2>OAuth Callback</h2>
              <p>No authorization code received.</p>
            </body>
          </html>
        `
      };
    }

    if (!orgId || !validateOrgId(orgId)) {
      return {
        statusCode: 200,
        headers: { "Content-Type": "text/html" },
        body: `
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <h2>OAuth Callback Error</h2>
              <p>Missing or invalid orgId/state.</p>
            </body>
          </html>
        `
      };
    }

    const tenantRecord = await getTenantRecord(orgId);
    try {
      assertTenantIsActive(tenantRecord);
    } catch (tenantError) {
      return {
        statusCode: tenantError.statusCode || 403,
        headers: { "Content-Type": "text/html" },
        body: `
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <h2>Tenant Error</h2>
              <pre>${tenantError.message}</pre>
            </body>
          </html>
        `
      };
    }

    const redirectUri = process.env.SF_REDIRECT_URI;
    const loginUrl = tenantRecord.loginBaseUrl;
    const existingConnection = await getSalesforceConnection(getSalesforceConnectionSecretName(orgId));
    let clientId;
    let clientSecret;

    try {
      ({ clientId, clientSecret } = await getSalesforceOAuthClientCredentials());
    } catch (error) {
      return {
        statusCode: 500,
        headers: { "Content-Type": "text/html" },
        body: `
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <h2>TwinaForms OAuth Client Is Not Configured</h2>
              <p>${error.message}</p>
            </body>
          </html>
        `
      };
    }

    try {
      const tokenUrl = `${loginUrl}/services/oauth2/token`;

      const params = new URLSearchParams();
      params.append("grant_type", "authorization_code");
      params.append("client_id", clientId);
      params.append("client_secret", clientSecret);
      params.append("redirect_uri", redirectUri);
      params.append("code", code);

      const tokenResponse = await fetch(tokenUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: params.toString()
      });

      const tokenData = await tokenResponse.json();

      if (!tokenResponse.ok) {
        return {
          statusCode: 200,
          headers: { "Content-Type": "text/html" },
          body: `
            <html>
              <body style="font-family: Arial, sans-serif; padding: 20px;">
                <h2>Token Exchange Failed</h2>
                <p><b>Status:</b> ${tokenResponse.status}</p>
                <pre>${JSON.stringify(tokenData, null, 2)}</pre>
              </body>
            </html>
          `
        };
      }

      const tokenOrgId = normalizeOrgId(String(tokenData.id || "").split("/id/")[1]?.split("/")[0] || "");
      if (!tokenOrgId || tokenOrgId !== orgId) {
        return {
          statusCode: 403,
          headers: { "Content-Type": "text/html" },
          body: `
            <html>
              <body style="font-family: Arial, sans-serif; padding: 20px;">
                <h2>OAuth Org Mismatch</h2>
                <p>The Salesforce org returned by OAuth does not match the requested TwinaForms org.</p>
              </body>
            </html>
          `
        };
      }

      let bootstrapV2ConnectionFields = {};
      if (tokenData.access_token && tokenData.instance_url) {
        try {
          const bootstrapV2Result = await fetchBootstrapV2SigningSecret({
            instanceUrl: tokenData.instance_url,
            accessToken: tokenData.access_token,
            orgId
          });
          bootstrapV2ConnectionFields = buildBootstrapV2ConnectionFields(bootstrapV2Result);
        } catch (bootstrapV2Error) {
          console.warn("Bootstrap V2 experimental secret retrieval failed:", bootstrapV2Error.message);
          bootstrapV2ConnectionFields = buildBootstrapV2UnavailableConnectionFields(bootstrapV2Error);
        }
      } else {
        bootstrapV2ConnectionFields = buildBootstrapV2UnavailableConnectionFields(
          new Error("OAuth token response did not include an access token and instance URL for Bootstrap V2.")
        );
      }

      const secretName = getSalesforceConnectionSecretName(orgId);
      const saveResult = await saveSalesforceConnection(secretName, {
        ...stripLegacySalesforceClientCredentials(existingConnection),
        orgId,
        loginBaseUrl: loginUrl,
        oauth_client_source: "twinaforms-global",
        oauth_client_id_last4: clientId.slice(-4),
        refresh_token: tokenData.refresh_token || existingConnection?.refresh_token || null,
        instance_url: tokenData.instance_url || null,
        id_url: tokenData.id || null,
        token_issued_at: tokenData.issued_at || null,
        updated_at: new Date().toISOString(),
        ...bootstrapV2ConnectionFields
      });

      const updatedTenantRecord = {
        ...tenantRecord,
        salesforceConnectionStatus: "connected",
        salesforceConnectionUpdatedAt: new Date().toISOString(),
        connectedUsername: tokenData.id || tenantRecord.connectedUsername || null,
        updatedAt: new Date().toISOString()
      };
      await saveItem(TENANT_TABLE, updatedTenantRecord);

      return {
        statusCode: 200,
        headers: { "Content-Type": "text/html" },
        body: DEV_MODE
          ? `
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <h2>Salesforce Connected Successfully</h2>
              <p><b>Access token received:</b> ${tokenData.access_token ? "Yes" : "No"}</p>
              <p><b>Refresh token received:</b> ${tokenData.refresh_token ? "Yes" : "No"}</p>
              <p><b>Instance URL:</b> ${tokenData.instance_url || "(none)"}</p>
              <p><b>ID URL:</b> ${tokenData.id || "(none)"}</p>
              <p><b>Secret saved:</b> Yes</p>
              <p><b>Org Id:</b> ${orgId}</p>
              <p><b>Secret name:</b> ${secretName}</p>
              <p><b>Created new secret:</b> ${saveResult.created ? "Yes" : "No"}</p>
              <p><b>Updated existing secret:</b> ${saveResult.updated ? "Yes" : "No"}</p>
            </body>
          </html>
        `
          : `
          <html>
            <body style="font-family: Arial, sans-serif; padding: 24px; max-width: 640px; margin: 0 auto; color: #16325c;">
              <h2>NativeForms Is Connected</h2>
              <p>You can return to Salesforce now and finish setup.</p>
              <p>The org-specific Salesforce connection was saved successfully.</p>
              <p style="margin-top: 16px;"><a href="#" onclick="window.close(); return false;">Close this tab</a></p>
            </body>
          </html>
        `
      };
    } catch (e) {
      return {
        statusCode: 500,
        headers: { "Content-Type": "text/html" },
        body: `
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <h2>Server Error During Token Exchange</h2>
              <pre>${e.message}</pre>
            </body>
          </html>
        `
      };
    }
  }

  if (path === "/tenant/register" && method === "POST") {
    try {
      const payload = event?.body
        ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
        : {};

      validateTenantRegistrationPayload(payload);
      const orgId = normalizeOrgId(payload.orgId);

      const now = new Date().toISOString();
      const existing = await getTenantRecord(orgId);
      const existingConnection = await getSalesforceConnection(getSalesforceConnectionSecretName(orgId));
      const tenantSecret = existing?.secret || generateSecret();
      const trialLifecycle = !existing ? buildTrialLifecycleDates() : null;
      const subscription = existing
        ? normalizeSubscriptionState(payload, existing)
        : {
            subscriptionState: trialLifecycle.subscriptionState,
            subscriptionStartDate: trialLifecycle.subscriptionStartDate,
            subscriptionEndDate: trialLifecycle.subscriptionEndDate,
            isActive: true,
            status: payload.status || "active"
          };
      const tenantRecord = {
        orgId,
        adminEmail: payload.adminEmail,
        companyName: payload.companyName,
        loginBaseUrl: payload.loginBaseUrl,
        country: normalizeOptionalString(payload.country) ?? normalizeOptionalString(existing?.country),
        state: normalizeOptionalString(payload.state) ?? normalizeOptionalString(existing?.state),
        city: normalizeOptionalString(payload.city) ?? normalizeOptionalString(existing?.city),
        secret: tenantSecret,
        planCode: existing?.planCode || trialLifecycle?.planCode || normalizePlanCode(payload.subscriptionState, existing),
        status: subscription.status,
        subscriptionState: subscription.subscriptionState,
        subscriptionStartDate: subscription.subscriptionStartDate,
        subscriptionEndDate: subscription.subscriptionEndDate,
        trialStartedAt: existing?.trialStartedAt || trialLifecycle?.trialStartedAt || null,
        trialEndsAt: existing?.trialEndsAt || trialLifecycle?.trialEndsAt || null,
        isActive: subscription.isActive,
        salesforceConnectionStatus: existing?.salesforceConnectionStatus || "not-connected",
        salesforceConnectionUpdatedAt: existing?.salesforceConnectionUpdatedAt || null,
        connectedUsername: existing?.connectedUsername || null,
        createdAt: existing?.createdAt || now,
        updatedAt: now
      };

      await saveItem(TENANT_TABLE, tenantRecord);
      if (existingConnection?.client_id || existingConnection?.client_secret) {
        await saveSalesforceConnection(getSalesforceConnectionSecretName(orgId), {
          ...stripLegacySalesforceClientCredentials(existingConnection),
          orgId,
          loginBaseUrl: payload.loginBaseUrl,
          updated_at: now
        });
      }
      const emailSent = await sendTenantSecretEmail(payload.adminEmail, orgId, tenantSecret)
        .catch((error) => {
          console.error("Failed to send tenant secret email:", error);
          return false;
        });
      const adminSettings = !existing ? await loadAdminSettings() : null;
      const adminTrialEmailSent = !existing
        ? await sendNewTrialAdminEmail(adminSettings?.statusAlertEmailRecipient, tenantRecord)
          .catch((error) => {
            console.error("Failed to send new trial admin email:", error);
            return false;
          })
        : false;

      return jsonResponse(200, {
        success: true,
        tableName: TENANT_TABLE,
        created: !existing,
        updated: !!existing,
        tenant: sanitizeTenantRecord(tenantRecord),
        tenantSecret,
        connectUrl: baseUrl ? `${baseUrl}/connect?orgId=${encodeURIComponent(orgId)}` : null,
        emailSent,
        adminTrialEmailSent
      });
    } catch (e) {
      return jsonResponse(400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path === "/tenant/client-credentials" && method === "POST") {
    try {
      const payload = event?.body
        ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
        : {};

      validateClientCredentialsPayload(payload);
      const orgId = normalizeOrgId(payload.orgId);
      const tenantRecord = await getTenantRecord(orgId);
      if (!tenantRecord) {
        throw new Error("Tenant not found");
      }

      assertTenantIsActive(tenantRecord);

      const now = new Date().toISOString();
      const existingConnection = await getSalesforceConnection(getSalesforceConnectionSecretName(orgId));
      await saveSalesforceConnection(getSalesforceConnectionSecretName(orgId), {
        ...stripLegacySalesforceClientCredentials(existingConnection),
        orgId,
        loginBaseUrl: payload.loginBaseUrl,
        refresh_token: existingConnection?.refresh_token || null,
        instance_url: existingConnection?.instance_url || null,
        id_url: existingConnection?.id_url || null,
        token_issued_at: existingConnection?.token_issued_at || null,
        updated_at: now
      });

      const updatedTenantRecord = {
        ...tenantRecord,
        adminEmail: payload.adminEmail,
        companyName: payload.companyName,
        loginBaseUrl: payload.loginBaseUrl,
        updatedAt: now
      };
      await saveItem(TENANT_TABLE, updatedTenantRecord);

      return jsonResponse(200, {
        success: true,
        connectUrl: baseUrl ? `${baseUrl}/connect?orgId=${encodeURIComponent(orgId)}` : null,
        tenant: sanitizeTenantRecord(updatedTenantRecord)
      });
    } catch (e) {
      return jsonResponse(e.statusCode || 400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path === "/forms/register" && method === "POST") {
    try {
      const payload = event?.body
        ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
        : {};

      validateFormSecurityPayload(payload);
      const orgId = normalizeOrgId(payload.orgId);
      await requireTenantAuth(event, orgId);

      const now = new Date().toISOString();
      const existing = await getFormSecurityRecord(payload.formId);
      const record = {
        formId: payload.formId,
        orgId,
        companySlug: payload.companySlug,
        formSlug: payload.formSlug,
        publishedVersionId: payload.publishedVersionId,
        status: payload.status,
        securityMode: payload.securityMode,
        rateLimitProfile: payload.rateLimitProfile || "standard",
        tokenHash: hashToken(payload.publishToken),
        generatedHtmlRef: payload.generatedHtmlRef || null,
        publicUrl: payload.publicUrl || null,
        captcha: payload.captcha || null,
        uploadFields: Array.isArray(payload.uploadFields) ? payload.uploadFields : [],
        signatureFields: Array.isArray(payload.signatureFields) ? payload.signatureFields : [],
        recordsListRowSignatures: Array.isArray(payload.recordsListRowSignatures) ? payload.recordsListRowSignatures : [],
        lookupDefinition: payload.lookupDefinition && typeof payload.lookupDefinition === "object" ? payload.lookupDefinition : { fields: {} },
        locationDefinition: payload.locationDefinition && typeof payload.locationDefinition === "object" ? payload.locationDefinition : { fields: {} },
        submissionPdf: payload.submissionPdf && typeof payload.submissionPdf === "object" ? payload.submissionPdf : null,
        secretCodeConfig: payload.secretCodeConfig || payload.userVerificationConfig || null,
        prefillPolicy: payload.prefillPolicy,
        submitPolicy: payload.submitPolicy,
        prefillDefinition: payload.prefillDefinition,
        submitDefinition: payload.submitDefinition,
        createdAt: existing?.createdAt || now,
        updatedAt: now
      };

      await saveItem(FORM_SECURITY_TABLE, record);

      return jsonResponse(200, {
        success: true,
        tableName: FORM_SECURITY_TABLE,
        created: !existing,
        updated: !!existing,
        record: sanitizeFormSecurityRecord(record)
      });
    } catch (e) {
      return jsonResponse(e.statusCode || 400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path === "/forms/unpublish" && method === "POST") {
    try {
      const payload = event?.body
        ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
        : {};

      validateFormUnpublishPayload(payload);
      const orgId = normalizeOrgId(payload.orgId);
      await requireTenantAuth(event, orgId);

      const existing = await getFormSecurityRecord(payload.formId);
      if (!existing) {
        return jsonResponse(200, {
          success: true,
          found: false,
          unpublished: false,
          replacedHtml: false
        });
      }

      if (normalizeOrgId(existing.orgId) !== orgId) {
        const error = new Error("Form does not belong to this tenant.");
        error.statusCode = 403;
        throw error;
      }

      const now = new Date().toISOString();
      const replacedHtml = await replacePublishedFormWithUnavailablePage(existing.generatedHtmlRef);
      const record = {
        ...existing,
        status: "unpublished",
        unpublishedAt: existing.unpublishedAt || now,
        updatedAt: now
      };
      await saveItem(FORM_SECURITY_TABLE, record);

      return jsonResponse(200, {
        success: true,
        found: true,
        unpublished: true,
        replacedHtml,
        record: sanitizeFormSecurityRecord(record)
      });
    } catch (e) {
      return jsonResponse(e.statusCode || 400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path === "/forms/publish/presign" && method === "POST") {
    try {
      const payload = event?.body
        ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
        : {};

      validatePublishPresignPayload(payload);
      const orgId = normalizeOrgId(payload.orgId);
      const tenantRecord = await requireTenantAuth(event, orgId);

      if (!PUBLISH_BUCKET || !PUBLIC_BASE_URL) {
        throw new Error("Server misconfigured: PUBLISH_BUCKET and PUBLIC_BASE_URL are required");
      }

      const { companySlug } = await ensureTenantCompanySlug(orgId, tenantRecord);
      const formSlug = slugifyPublicSegment(payload.formSlug, "form");
      const key = buildPublishKey(companySlug, formSlug);
      const contentType = payload.contentType || "text/html; charset=utf-8";
      const expiresIn = Number(payload.expires) > 0 ? Number(payload.expires) : 900;
      const putCommand = new PutObjectCommand({
        Bucket: PUBLISH_BUCKET,
        Key: key,
        ContentType: contentType
      });
      const putUrl = await getSignedUrl(s3Client, putCommand, { expiresIn });
      const publicUrl = `${PUBLIC_BASE_URL}/${key}`;

      return jsonResponse(200, {
        success: true,
        putUrl,
        publicUrl,
        key,
        companySlug,
        formSlug,
        expiresAt: Date.now() + expiresIn * 1000
      });
    } catch (e) {
      return jsonResponse(e.statusCode || 400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path === "/salesforce/layouts" && method === "POST") {
    try {
      const payload = event?.body
        ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
        : {};

      validateSalesforceLayoutPayload(payload);
      const orgId = normalizeOrgId(payload.orgId);
      const tenantRecord = await requireTenantAuth(event, orgId);
      const result = await runSalesforceLayoutMetadata(payload, tenantRecord);
      return jsonResponse(200, result);
    } catch (e) {
      return jsonResponse(e.statusCode || 400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path === "/forms/lookup" && method === "POST") {
    try {
      const payload = event?.body
        ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
        : {};

      validateLookupPayload(payload);
      const formSecurity = await getFormSecurityRecord(payload.formId);
      ensurePublishedFormToken(formSecurity, payload.publishToken);
      const result = await runLookup(payload, formSecurity);
      return jsonResponse(200, result);
    } catch (e) {
      return jsonResponse(e.statusCode || 400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path === "/forms/location/search" && method === "POST") {
    try {
      const payload = event?.body
        ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
        : {};

      validateLocationPayload(payload);
      const formSecurity = await getFormSecurityRecord(payload.formId);
      ensurePublishedFormToken(formSecurity, payload.publishToken);
      const tenantRecord = await getTenantRecord(formSecurity.orgId);
      assertTenantIsActive(tenantRecord);
      const planResult = await loadPlanDefinitions();
      const selectedPlan = getPlanByCode(planResult.items, normalizePlanCode(null, tenantRecord));
      const effectiveFeatureFlags = getEffectivePlanFeatures(tenantRecord, selectedPlan);
      if (effectiveFeatureFlags?.enableProLocationFields !== true) {
        const error = new Error("Country / State / City is not available for this tenant.");
        error.statusCode = 403;
        throw error;
      }
      const result = await runLocationSearch(payload, formSecurity);
      return jsonResponse(200, result);
    } catch (e) {
      return jsonResponse(e.statusCode || 400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path === "/forms/upload/init" && method === "POST") {
    try {
      const payload = event?.body
        ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
        : {};

      validateUploadInitPayload(payload);
      const formSecurity = await getFormSecurityRecord(payload.formId);
      ensurePublishedFormToken(formSecurity, payload.publishToken);

      const tenantRecord = await getTenantRecord(formSecurity.orgId);
      assertTenantIsActive(tenantRecord);
      const planResult = await loadPlanDefinitions();
      const selectedPlan = getPlanByCode(planResult.items, normalizePlanCode(null, tenantRecord));
      const effectiveFeatureFlags = getEffectivePlanFeatures(tenantRecord, selectedPlan);
      if (effectiveFeatureFlags?.enableProLoadFile !== true) {
        const error = new Error("File Uploads are not available for this tenant.");
        error.statusCode = 403;
        throw error;
      }

      const uploadField = findUploadFieldDefinition(formSecurity, payload.fieldKey);
      if (!uploadField) {
        const error = new Error("File Upload is not configured for this field.");
        error.statusCode = 400;
        throw error;
      }

      validateUploadFieldRules(uploadField, payload);

      if (!UPLOAD_STAGING_BUCKET) {
        throw new Error("Server misconfigured: UPLOAD_STAGING_BUCKET is required for File Uploads");
      }

      const normalizedFileName = normalizeFileName(payload.fileName);
      const objectKey = buildUploadObjectKey(formSecurity, payload.fieldKey, payload.sessionId, normalizedFileName);
      const contentType = String(payload.contentType || "application/octet-stream").trim() || "application/octet-stream";
      const expiresIn = 900;
      const putCommand = new PutObjectCommand({
        Bucket: UPLOAD_STAGING_BUCKET,
        Key: objectKey,
        ContentType: contentType
      });
      const uploadUrl = await getSignedUrl(s3Client, putCommand, { expiresIn });

      const uploadTokenPayload = {
        kind: "fileUpload",
        orgId: formSecurity.orgId,
        formId: formSecurity.formId,
        publishedVersionId: formSecurity.publishedVersionId || null,
        fieldKey: String(payload.fieldKey),
        sessionId: String(payload.sessionId),
        objectKey,
        fileName: normalizedFileName,
        contentType,
        fileSize: Number(payload.fileSize),
        exp: Math.floor(Date.now() / 1000) + expiresIn
      };

      return jsonResponse(200, {
        success: true,
        uploadUrl,
        uploadToken: createUploadReferenceToken(uploadTokenPayload, tenantRecord),
        expiresAt: Date.now() + (expiresIn * 1000),
        fileName: normalizedFileName,
        fieldKey: String(payload.fieldKey),
        contentType,
        fileSize: Number(payload.fileSize)
      });
    } catch (e) {
      return jsonResponse(e.statusCode || 400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path === "/forms/upload/status" && method === "POST") {
    try {
      const payload = event?.body
        ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
        : {};

      validateUploadStatusPayload(payload);
      const formSecurity = await getFormSecurityRecord(payload.formId);
      ensurePublishedFormToken(formSecurity, payload.publishToken);

      const tenantRecord = await getTenantRecord(formSecurity.orgId);
      assertTenantIsActive(tenantRecord);
      const planResult = await loadPlanDefinitions();
      const selectedPlan = getPlanByCode(planResult.items, normalizePlanCode(null, tenantRecord));
      const effectiveFeatureFlags = getEffectivePlanFeatures(tenantRecord, selectedPlan);
      if (effectiveFeatureFlags?.enableProLoadFile !== true) {
        const error = new Error("File Uploads are not available for this tenant.");
        error.statusCode = 403;
        throw error;
      }
      if (!UPLOAD_STAGING_BUCKET) {
        throw new Error("Server misconfigured: UPLOAD_STAGING_BUCKET is required for File Uploads");
      }

      const tokenPayload = validateBoundUploadReference(payload, formSecurity, tenantRecord);
      const objectKey = String(tokenPayload.objectKey || "").trim();
      const scanResult = await getUploadScanStatus(objectKey);
      if (scanResult.status === "rejected") {
        await removeRejectedStagedUpload(objectKey);
      }
      return jsonResponse(200, {
        success: true,
        status: scanResult.status
      });
    } catch (e) {
      return jsonResponse(e.statusCode || 400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path.startsWith("/forms/") && path.endsWith("/security") && method === "GET") {
    try {
      const formId = path.split("/")[2];
      if (!formId) {
        throw new Error("Missing formId in path");
      }

      const orgId = normalizeOrgId(event?.queryStringParameters?.orgId);
      const tenantRecord = await requireTenantAuth(event, orgId);
      const record = await getFormSecurityRecord(formId);
      if (!record) {
        const error = new Error("Form security record not found");
        error.statusCode = 404;
        throw error;
      }

      if (record.orgId !== tenantRecord.orgId) {
        const error = new Error("Form does not belong to the authenticated tenant");
        error.statusCode = 403;
        throw error;
      }

      return jsonResponse(200, {
        success: true,
        record
      });
    } catch (e) {
      return jsonResponse(e.statusCode || 404, {
        success: false,
        error: e.message
      });
    }
  }

  return {
    statusCode: 200,
    headers: {
      "Content-Type": "text/html"
    },
    body: `
      <html>
        <body style="font-family: Arial, sans-serif; padding: 20px;">
          <h2>NativeForms Backend</h2>
          <ul>
            <li><a href="/connect">/connect</a></li>
          </ul>
        </body>
      </html>
    `
  };
};
