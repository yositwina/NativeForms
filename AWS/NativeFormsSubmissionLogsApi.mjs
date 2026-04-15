import {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand,
  QueryCommand,
  ScanCommand,
} from "@aws-sdk/client-dynamodb";
import crypto from "node:crypto";

const TENANT_TABLE = process.env.TENANT_TABLE || "NativeFormsTenants";
const PLAN_TABLE = process.env.PLAN_TABLE || "NativeFormsPlans";
const SUBMISSION_LOG_TABLE = process.env.SUBMISSION_LOG_TABLE || "NativeFormsSubmissionLogs";

const dynamoClient = new DynamoDBClient({});

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

function getHeaderValue(headers, name) {
  const target = String(name || "").toLowerCase();
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

function validateOrgId(orgId) {
  return /^[a-zA-Z0-9]{15,18}$/.test(String(orgId || ""));
}

function normalizeOrgId(orgId) {
  return String(orgId || "").trim().substring(0, 18);
}

function fromAttributeValue(attributeValue) {
  if (attributeValue == null) return undefined;
  if (attributeValue.S != null) return attributeValue.S;
  if (attributeValue.N != null) return Number(attributeValue.N);
  if (attributeValue.BOOL != null) return attributeValue.BOOL;
  if (attributeValue.NULL) return null;
  if (attributeValue.L) return attributeValue.L.map(fromAttributeValue);
  if (attributeValue.M) {
    const output = {};
    for (const [key, value] of Object.entries(attributeValue.M)) {
      output[key] = fromAttributeValue(value);
    }
    return output;
  }
  return undefined;
}

function unmarshallItem(item) {
  const output = {};
  for (const [key, value] of Object.entries(item || {})) {
    output[key] = fromAttributeValue(value);
  }
  return output;
}

function toAttributeValue(value) {
  if (value === undefined) {
    return undefined;
  }
  if (value === null) {
    return { NULL: true };
  }
  if (typeof value === "string") {
    return { S: value };
  }
  if (typeof value === "number") {
    return { N: String(value) };
  }
  if (typeof value === "boolean") {
    return { BOOL: value };
  }
  if (Array.isArray(value)) {
    return { L: value.map((item) => toAttributeValue(item)).filter(Boolean) };
  }
  if (typeof value === "object") {
    const mapped = {};
    for (const [key, nested] of Object.entries(value)) {
      const converted = toAttributeValue(nested);
      if (converted !== undefined) {
        mapped[key] = converted;
      }
    }
    return { M: mapped };
  }
  return { S: String(value) };
}

function marshallKey(key) {
  const output = {};
  for (const [entryKey, entryValue] of Object.entries(key || {})) {
    const converted = toAttributeValue(entryValue);
    if (converted !== undefined) {
      output[entryKey] = converted;
    }
  }
  return output;
}

function marshallItem(item) {
  const output = {};
  for (const [key, value] of Object.entries(item || {})) {
    const converted = toAttributeValue(value);
    if (converted !== undefined) {
      output[key] = converted;
    }
  }
  return output;
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

function getDefaultPlanLoggingPolicy(planCode) {
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

function buildEffectiveConfig(tenantRecord, planDefinition) {
  const defaultPolicy = getDefaultPlanLoggingPolicy(tenantRecord?.planCode);
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
  const hasValidPublicKey = !!parseSubmissionLogPublicKey(tenantRecord?.submissionLogPublicKey);
  const detailMode =
    detailedLogsIncludedByPlan &&
    hasValidPublicKey
      ? "encrypted_detail"
      : "metadata_only";
  const encryptionStatus = !detailedLogsIncludedByPlan
    ? "not_included_by_plan"
    : hasValidPublicKey
      ? "ready"
      : "missing_public_key";

  return {
    retentionDays,
    planCode: defaultPolicy.planCode,
    detailedLogsIncludedByPlan,
    detailMode,
    keyVersion: tenantRecord?.submissionLogKeyVersion || "v2",
    publicKeyConfigured: hasValidPublicKey,
    encryptionStatus,
    publicKeySyncedAt: tenantRecord?.submissionLogPublicKeySyncedAt || null
  };
}

function encodeNextToken(lastEvaluatedKey) {
  if (!lastEvaluatedKey) {
    return null;
  }
  return Buffer.from(JSON.stringify(unmarshallItem(lastEvaluatedKey)), "utf8").toString("base64");
}

function decodeNextToken(nextToken) {
  if (!nextToken) {
    return undefined;
  }
  try {
    const decoded = JSON.parse(Buffer.from(String(nextToken), "base64").toString("utf8"));
    return marshallKey(decoded);
  } catch (error) {
    const invalidTokenError = new Error("Invalid nextToken");
    invalidTokenError.statusCode = 400;
    throw invalidTokenError;
  }
}

function normalizeDateBoundary(value, boundaryType) {
  if (!value) {
    return null;
  }

  const raw = String(value).trim();
  if (!raw) {
    return null;
  }

  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    return boundaryType === "from"
      ? `${raw}T00:00:00.000Z`
      : `${raw}T23:59:59.999Z`;
  }

  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) {
    const invalidDateError = new Error(`Invalid ${boundaryType === "from" ? "dateFrom" : "dateTo"} value`);
    invalidDateError.statusCode = 400;
    throw invalidDateError;
  }
  return parsed.toISOString();
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

async function requireTenantSecret(headers, orgId) {
  const normalizedOrgId = normalizeOrgId(orgId);
  if (!normalizedOrgId) {
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

  return tenantRecord;
}

async function getSubmissionLogConfigStatus(headers, queryStringParameters) {
  const normalizedOrgId = normalizeOrgId(queryStringParameters?.orgId);
  const tenantRecord = await requireTenantSecret(headers, normalizedOrgId);
  const planDefinition = await getPlanDefinition(tenantRecord?.planCode);
  const effectiveConfig = buildEffectiveConfig(tenantRecord, planDefinition);

  return jsonResponse(200, {
    success: true,
    orgId: normalizedOrgId,
    planCode: effectiveConfig.planCode,
    retentionDays: effectiveConfig.retentionDays,
    detailedLogsIncludedByPlan: effectiveConfig.detailedLogsIncludedByPlan,
    effectiveDetailMode: effectiveConfig.detailMode,
    encryptionStatus: effectiveConfig.encryptionStatus,
    keyVersion: effectiveConfig.keyVersion,
    publicKeyConfigured: effectiveConfig.publicKeyConfigured,
    publicKeySyncedAt: effectiveConfig.publicKeySyncedAt
  });
}

async function syncSubmissionLogConfig(headers, body) {
  const normalizedOrgId = normalizeOrgId(body?.orgId);
  const tenantRecord = await requireTenantSecret(headers, normalizedOrgId);
  const publicKeyValue = String(body?.submissionLogPublicKey || "").trim();
  const keyVersion = String(body?.submissionLogKeyVersion || "v2").trim() || "v2";

  if (publicKeyValue && !parseSubmissionLogPublicKey(publicKeyValue)) {
    const error = new Error("submissionLogPublicKey must be a base64-encoded SPKI public key");
    error.statusCode = 400;
    throw error;
  }

  const updatedAt = new Date().toISOString();
  const freshTenantRecord = {
    ...tenantRecord,
    submissionLogPublicKey: publicKeyValue || null,
    submissionLogKeyVersion: keyVersion,
    submissionLogPublicKeySyncedAt: updatedAt
  };
  await dynamoClient.send(new PutItemCommand({
    TableName: TENANT_TABLE,
    Item: marshallItem(freshTenantRecord)
  }));

  const planDefinition = await getPlanDefinition(freshTenantRecord?.planCode);
  const effectiveConfig = buildEffectiveConfig(freshTenantRecord, planDefinition);

  return jsonResponse(200, {
    success: true,
    orgId: normalizedOrgId,
    planCode: effectiveConfig.planCode,
    retentionDays: effectiveConfig.retentionDays,
    detailedLogsIncludedByPlan: effectiveConfig.detailedLogsIncludedByPlan,
    effectiveDetailMode: effectiveConfig.detailMode,
    encryptionStatus: effectiveConfig.encryptionStatus,
    keyVersion: effectiveConfig.keyVersion,
    publicKeyConfigured: effectiveConfig.publicKeyConfigured,
    publicKeySyncedAt: effectiveConfig.publicKeySyncedAt
  });
}

function buildListQuery(tenantRecord, queryStringParameters) {
  const normalizedOrgId = normalizeOrgId(tenantRecord?.orgId);
  const formId = String(queryStringParameters?.formId || "").trim();
  const outcome = String(queryStringParameters?.outcome || "").trim().toLowerCase();
  const submissionRef = String(queryStringParameters?.submissionRef || "").trim();
  const dateFrom = normalizeDateBoundary(queryStringParameters?.dateFrom, "from");
  const dateTo = normalizeDateBoundary(queryStringParameters?.dateTo, "to");
  const pageSizeRaw = Number(queryStringParameters?.pageSize || 25);
  const pageSize = Number.isFinite(pageSizeRaw)
    ? Math.min(Math.max(Math.trunc(pageSizeRaw), 1), 100)
    : 25;

  if (submissionRef) {
    return {
      mode: "scan",
      pageSize,
      input: {
        TableName: SUBMISSION_LOG_TABLE,
        FilterExpression: "tenantId = :tenantId AND submissionRef = :submissionRef",
        ExpressionAttributeValues: {
          ":tenantId": { S: normalizedOrgId },
          ":submissionRef": { S: submissionRef }
        }
      }
    };
  }

  const queryInput = {
    TableName: SUBMISSION_LOG_TABLE,
    Limit: pageSize,
    ScanIndexForward: false,
    ExclusiveStartKey: decodeNextToken(queryStringParameters?.nextToken)
  };

  if (formId) {
    queryInput.IndexName = "tenantFormSubmittedAt";
    queryInput.KeyConditionExpression = "tenantFormKey = :tenantFormKey";
    queryInput.ExpressionAttributeValues = {
      ":tenantFormKey": { S: `${normalizedOrgId}#${formId}` }
    };
  } else if (outcome) {
    queryInput.IndexName = "tenantOutcomeSubmittedAt";
    queryInput.KeyConditionExpression = "tenantOutcomeKey = :tenantOutcomeKey";
    queryInput.ExpressionAttributeValues = {
      ":tenantOutcomeKey": { S: `${normalizedOrgId}#${outcome}` }
    };
  } else {
    queryInput.KeyConditionExpression = "tenantId = :tenantId";
    queryInput.ExpressionAttributeValues = {
      ":tenantId": { S: normalizedOrgId }
    };
  }

  if (dateFrom && dateTo) {
    queryInput.KeyConditionExpression += " AND submittedAtSubmissionId BETWEEN :dateFromKey AND :dateToKey";
    queryInput.ExpressionAttributeValues[":dateFromKey"] = { S: `${dateFrom}#` };
    queryInput.ExpressionAttributeValues[":dateToKey"] = { S: `${dateTo}#\uffff` };
  } else if (dateFrom) {
    queryInput.KeyConditionExpression += " AND submittedAtSubmissionId >= :dateFromKey";
    queryInput.ExpressionAttributeValues[":dateFromKey"] = { S: `${dateFrom}#` };
  } else if (dateTo) {
    queryInput.KeyConditionExpression += " AND submittedAtSubmissionId <= :dateToKey";
    queryInput.ExpressionAttributeValues[":dateToKey"] = { S: `${dateTo}#\uffff` };
  }

  if (formId && outcome) {
    queryInput.FilterExpression = "outcome = :outcomeValue";
    queryInput.ExpressionAttributeValues[":outcomeValue"] = { S: outcome };
  }

  return {
    mode: "query",
    pageSize,
    input: queryInput
  };
}

function mapLogListItem(item) {
  return {
    tenantId: item.tenantId,
    submissionId: item.submissionId,
    submissionRef: item.submissionRef,
    formId: item.formId,
    formVersionId: item.formVersionId,
    submittedAt: item.submittedAt,
    outcome: item.outcome,
    failureStage: item.failureStage,
    detailMode: item.detailMode,
    recordId: item.recordId || null,
    expiresAt: item.expiresAt || null
  };
}

async function listSubmissionLogs(headers, queryStringParameters) {
  const normalizedOrgId = normalizeOrgId(queryStringParameters?.orgId);
  const tenantRecord = await requireTenantSecret(headers, normalizedOrgId);
  const requestConfig = buildListQuery(tenantRecord, queryStringParameters);
  let items = [];
  let nextToken = null;

  if (requestConfig.mode === "scan") {
    const result = await dynamoClient.send(new ScanCommand(requestConfig.input));
    items = (result.Items || [])
      .map((item) => unmarshallItem(item))
      .sort((left, right) => String(right.submittedAtSubmissionId || "").localeCompare(String(left.submittedAtSubmissionId || "")))
      .slice(0, requestConfig.pageSize)
      .map(mapLogListItem);
  } else {
    const result = await dynamoClient.send(new QueryCommand(requestConfig.input));
    items = (result.Items || []).map((item) => mapLogListItem(unmarshallItem(item)));
    nextToken = encodeNextToken(result.LastEvaluatedKey);
  }

  return jsonResponse(200, {
    success: true,
    orgId: normalizedOrgId,
    logs: items,
    nextToken
  });
}

async function getSubmissionLogDetail(headers, pathId, queryStringParameters) {
  const normalizedOrgId = normalizeOrgId(queryStringParameters?.orgId);
  await requireTenantSecret(headers, normalizedOrgId);
  const submissionId = decodeURIComponent(String(pathId || "").trim());
  if (!submissionId) {
    const error = new Error("Missing required path parameter: submissionId");
    error.statusCode = 400;
    throw error;
  }

  const result = await dynamoClient.send(new GetItemCommand({
    TableName: SUBMISSION_LOG_TABLE,
    Key: {
      tenantId: { S: normalizedOrgId },
      submittedAtSubmissionId: { S: submissionId }
    }
  }));

  if (!result.Item) {
    const error = new Error("Submission log not found");
    error.statusCode = 404;
    throw error;
  }

  const item = unmarshallItem(result.Item);
  return jsonResponse(200, {
    success: true,
    log: {
      ...mapLogListItem(item),
      encryptedDetail: item.detailMode === "encrypted_detail"
        ? {
            detailCiphertextB64: item.detailCiphertextB64 || null,
            detailIvB64: item.detailIvB64 || null,
            detailEncryptedKeyB64: item.detailEncryptedKeyB64 || null,
            detailKeyVersion: item.detailKeyVersion || null,
            detailSchemaVersion: item.detailSchemaVersion || null
          }
        : null
    }
  });
}

export const handler = async (event) => {
  try {
    const method = event?.requestContext?.http?.method || event?.httpMethod || "GET";
    const routePath = event?.rawPath || event?.path || "/";
    const headers = event?.headers || {};
    const queryStringParameters = event?.queryStringParameters || {};

    if (method === "OPTIONS") {
      return jsonResponse(200, { success: true });
    }

    if (method === "POST" && routePath.endsWith("/submission-log-config/sync")) {
      const body = event?.body
        ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
        : {};
      return await syncSubmissionLogConfig(headers, body);
    }

    if (method === "GET" && routePath.endsWith("/submission-log-config/status")) {
      return await getSubmissionLogConfigStatus(headers, queryStringParameters);
    }

    if (method === "GET" && /\/submission-logs\/[^/]+$/.test(routePath)) {
      const pathId = routePath.split("/").pop();
      return await getSubmissionLogDetail(headers, pathId, queryStringParameters);
    }

    if (method === "GET" && routePath.endsWith("/submission-logs")) {
      return await listSubmissionLogs(headers, queryStringParameters);
    }

    return jsonResponse(404, {
      success: false,
      error: "Route not found"
    });
  } catch (error) {
    return jsonResponse(error?.statusCode || 500, {
      success: false,
      error: error?.message || "Unexpected submission log error"
    });
  }
};
