import {
  SecretsManagerClient,
  CreateSecretCommand,
  PutSecretValueCommand,
  GetSecretValueCommand
} from "@aws-sdk/client-secrets-manager";
import {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand,
  QueryCommand,
  ScanCommand
} from "@aws-sdk/client-dynamodb";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { SESClient, SendEmailCommand } from "@aws-sdk/client-ses";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import crypto from "crypto";

const secretsClient = new SecretsManagerClient({});
const dynamoClient = new DynamoDBClient({});
const s3Client = new S3Client({});
const sesClient = new SESClient({ region: process.env.SES_REGION || process.env.AWS_REGION || "eu-north-1" });
const FORM_SECURITY_TABLE = process.env.FORM_SECURITY_TABLE || "NativeFormsFormSecurity";
const TENANT_TABLE = process.env.TENANT_TABLE || "NativeFormsTenants";
const PLAN_TABLE = process.env.PLAN_TABLE || "NativeFormsPlans";
const SUBMISSION_LOG_TABLE = process.env.SUBMISSION_LOG_TABLE || "NativeFormsSubmissionLogs";
const SETTINGS_TABLE = process.env.SETTINGS_TABLE || "NativeFormsAdminSettings";
const SALESFORCE_CONNECTION_SECRET_PREFIX = "NativeForms/SalesforceConnection";
const SES_FROM = process.env.SES_FROM || "";
const DEV_MODE = String(process.env.DEV_MODE || "").toLowerCase() === "true";
const PUBLISH_BUCKET = process.env.PUBLISH_BUCKET || "";
const PUBLIC_BASE_URL = (process.env.PUBLIC_BASE_URL || "").replace(/\/+$/, "");
const PRICING_BASE_URL = (process.env.PRICING_BASE_URL || "https://twinaforms.com").replace(/\/+$/, "");
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
  enableProLoadFile: {
    label: "File Load Support",
    description: "Support advanced file-loading behavior as part of the form experience and submission flow."
  },
  enableDetailedSubmissionLogs: {
    label: "Detailed Submission Logs",
    description: "See richer troubleshooting detail for submissions, runtime behavior, and processing outcomes."
  }
};

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
      enableProFormulaFields: false,
      enableProPostSubmitAutoLink: false,
      enableProSfSecretCodeAuth: false,
      enableProLoadFile: false
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
      enableProFormulaFields: true,
      enableProPostSubmitAutoLink: true,
      enableProSfSecretCodeAuth: true,
      enableProLoadFile: true
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
      enableProFormulaFields: false,
      enableProPostSubmitAutoLink: false,
      enableProSfSecretCodeAuth: false,
      enableProLoadFile: false
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
      enableProFormulaFields: true,
      enableProPostSubmitAutoLink: true,
      enableProSfSecretCodeAuth: true,
      enableProLoadFile: true
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
    if (e.name === "ResourceExistsException") {
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
    throw error;
  }
}

function getSalesforceConnectionSecretName(orgId) {
  return `${SALESFORCE_CONNECTION_SECRET_PREFIX}/${normalizeOrgId(orgId)}`;
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
    featureLabels: {
      ...Object.fromEntries(Object.entries(FEATURE_FLAG_METADATA).map(([key, value]) => [key, value.label])),
      ...(defaultPlan?.featureLabels || {}),
      ...(storedPlan?.featureLabels || {})
    },
    limits: {
      ...(defaultPlan?.limits || {}),
      ...(storedPlan?.limits || {})
    },
    featureFlags: {
      ...(defaultPlan?.featureFlags || {}),
      ...(storedPlan?.featureFlags || {})
    }
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
    "enableProFormulaFields",
    "enableProPostSubmitAutoLink",
    "enableProSfSecretCodeAuth",
    "enableProLoadFile"
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

function assertTenantIsActive(tenantRecord) {
  const tenantError = getTenantRuntimeAccessError(tenantRecord);
  if (tenantError) {
    const error = new Error(tenantError);
    error.statusCode = 403;
    throw error;
  }
}

async function sendTenantSecretEmail(toAddress, orgId, secret) {
  if (!SES_FROM) {
    console.log("SES_FROM not configured; tenant secret email skipped");
    return false;
  }

  await sesClient.send(new SendEmailCommand({
    Source: SES_FROM,
    Destination: {
      ToAddresses: [toAddress]
    },
    Message: {
      Subject: {
        Data: "Your NativeForms tenant secret"
      },
      Body: {
        Text: {
          Data: `Hello,

Your NativeForms tenant secret for Salesforce org ${orgId} is:

${secret}

Paste this value into Salesforce External Credential setup.

If you did not request this, you can safely ignore this email.

NativeForms`
        }
      }
    }
  }));

  return true;
}

async function requireTenantAuth(headers, orgId) {
  const normalizedOrgId = normalizeOrgId(orgId);

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

  const bearerToken = getBearerToken(headers);
  if (!bearerToken) {
    const error = new Error("Missing Authorization bearer token");
    error.statusCode = 401;
    throw error;
  }

  const tenantRecord = await getTenantRecord(normalizedOrgId);
  if (!tenantRecord) {
    const error = new Error("Tenant not found");
    error.statusCode = 404;
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
  if (!payload?.salesforceClientId) throw new Error("Missing required field: salesforceClientId");
  if (!payload?.salesforceClientSecret) throw new Error("Missing required field: salesforceClientSecret");
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
}

function validatePublishPresignPayload(payload) {
  if (!payload?.orgId) throw new Error("Missing required field: orgId");
  if (!validateOrgId(normalizeOrgId(payload.orgId))) throw new Error("Invalid orgId");
  if (!payload?.formId) throw new Error("Missing required field: formId");
  if (!payload?.formSlug) throw new Error("Missing required field: formSlug");
  if (!payload?.fileName) throw new Error("Missing required field: fileName");
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

function hasStoredClientCredentials(connectionRecord) {
  return !!connectionRecord?.client_id && !!connectionRecord?.client_secret;
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

    const tenantRecord = await getTenantRecord(orgId);
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

    const tenantConnection = await getSalesforceConnection(getSalesforceConnectionSecretName(orgId));
    const clientId = tenantConnection?.client_id;
    const redirectUri = process.env.SF_REDIRECT_URI;
    const loginUrl = tenantRecord.loginBaseUrl;

    if (!clientId) {
      return {
        statusCode: 400,
        headers: { "Content-Type": "text/html" },
        body: `
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <h2>Missing Salesforce Client Id</h2>
              <p>Register the tenant with salesforceClientId and salesforceClientSecret before connecting.</p>
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
      const connectionRecord = await getSalesforceConnection(getSalesforceConnectionSecretName(orgId));
      const setupState = buildTenantSetupState(tenantRecord, connectionRecord);

      return jsonResponse(200, {
        success: true,
        registered: !!tenantRecord,
        connected: setupState === "connected",
        setupState,
        connectUrl: tenantRecord && baseUrl ? `${baseUrl}/connect?orgId=${encodeURIComponent(orgId)}` : null,
        tenant: sanitizeTenantRecord(tenantRecord),
        hasClientCredentials: hasStoredClientCredentials(connectionRecord),
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
        plan: {
          code: planCode,
          label: selectedPlan?.label || "Trial",
          description: selectedPlan?.description || "",
          storageMode: planResult.storageMode,
          retentionDays: limits?.submissionLogRetentionDays ?? null,
          detailedLogsIncluded: featureFlags?.enableDetailedSubmissionLogs === true,
          advancedSecurityIncluded: featureFlags?.enableProSfSecretCodeAuth === true,
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

  if (path === "/tenant/auth-health" && method === "GET") {
    try {
      const orgId = normalizeOrgId(event?.queryStringParameters?.orgId);
      const tenantRecord = await requireTenantAuth(event?.headers, orgId);

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

      const tenantRecord = await requireTenantAuth(event?.headers, orgId);
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

      const tenantRecord = await getTenantRecord(orgId);
      if (!tenantRecord) {
        throw new Error("Tenant not found");
      }

      const now = new Date().toISOString();
      const existingConnection = await getSalesforceConnection(getSalesforceConnectionSecretName(orgId));
      if (existingConnection) {
        await saveSalesforceConnection(getSalesforceConnectionSecretName(orgId), {
          ...existingConnection,
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
      return jsonResponse(400, {
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
    const clientId = existingConnection?.client_id;
    const clientSecret = existingConnection?.client_secret;

    if (!clientId || !clientSecret) {
      return {
        statusCode: 200,
        headers: { "Content-Type": "text/html" },
        body: `
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <h2>Missing Salesforce Client Credentials</h2>
              <p>Tenant ${orgId} does not have a stored Salesforce client id and secret yet.</p>
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

      const secretName = getSalesforceConnectionSecretName(orgId);
      const saveResult = await saveSalesforceConnection(secretName, {
        ...(existingConnection || {}),
        orgId,
        loginBaseUrl: loginUrl,
        client_id: clientId,
        client_secret: clientSecret,
        refresh_token: tokenData.refresh_token || existingConnection?.refresh_token || null,
        instance_url: tokenData.instance_url || null,
        id_url: tokenData.id || null,
        token_issued_at: tokenData.issued_at || null,
        updated_at: new Date().toISOString()
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
      const subscription = normalizeSubscriptionState(payload, existing);
      const tenantRecord = {
        orgId,
        adminEmail: payload.adminEmail,
        companyName: payload.companyName,
        loginBaseUrl: payload.loginBaseUrl,
        secret: tenantSecret,
        status: subscription.status,
        subscriptionState: subscription.subscriptionState,
        subscriptionStartDate: subscription.subscriptionStartDate,
        subscriptionEndDate: subscription.subscriptionEndDate,
        isActive: subscription.isActive,
        salesforceConnectionStatus: existing?.salesforceConnectionStatus || "not-connected",
        salesforceConnectionUpdatedAt: existing?.salesforceConnectionUpdatedAt || null,
        connectedUsername: existing?.connectedUsername || null,
        createdAt: existing?.createdAt || now,
        updatedAt: now
      };

      await saveItem(TENANT_TABLE, tenantRecord);
      if (payload.salesforceClientId && payload.salesforceClientSecret) {
        await saveSalesforceConnection(getSalesforceConnectionSecretName(orgId), {
          ...(existingConnection || {}),
          orgId,
          loginBaseUrl: payload.loginBaseUrl,
          client_id: payload.salesforceClientId,
          client_secret: payload.salesforceClientSecret,
          refresh_token: existingConnection?.refresh_token || null,
          instance_url: existingConnection?.instance_url || null,
          id_url: existingConnection?.id_url || null,
          token_issued_at: existingConnection?.token_issued_at || null,
          updated_at: now
        });
      }
      const emailSent = await sendTenantSecretEmail(payload.adminEmail, orgId, tenantSecret)
        .catch((error) => {
          console.error("Failed to send tenant secret email:", error);
          return false;
        });

      return jsonResponse(200, {
        success: true,
        tableName: TENANT_TABLE,
        created: !existing,
        updated: !!existing,
        tenant: sanitizeTenantRecord(tenantRecord),
        tenantSecret,
        connectUrl: baseUrl ? `${baseUrl}/connect?orgId=${encodeURIComponent(orgId)}` : null,
        emailSent
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
        ...(existingConnection || {}),
        orgId,
        loginBaseUrl: payload.loginBaseUrl,
        client_id: payload.salesforceClientId,
        client_secret: payload.salesforceClientSecret,
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
      await requireTenantAuth(event?.headers, orgId);

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

  if (path === "/forms/publish/presign" && method === "POST") {
    try {
      const payload = event?.body
        ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
        : {};

      validatePublishPresignPayload(payload);
      const orgId = normalizeOrgId(payload.orgId);
      const tenantRecord = await requireTenantAuth(event?.headers, orgId);

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

  if (path.startsWith("/forms/") && path.endsWith("/security") && method === "GET") {
    try {
      const formId = path.split("/")[2];
      if (!formId) {
        throw new Error("Missing formId in path");
      }

      const orgId = normalizeOrgId(event?.queryStringParameters?.orgId);
      const tenantRecord = await requireTenantAuth(event?.headers, orgId);
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
