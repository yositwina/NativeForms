import {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand,
  ScanCommand
} from "@aws-sdk/client-dynamodb";
import { SESClient, SendEmailCommand } from "@aws-sdk/client-ses";
import { randomUUID } from "node:crypto";

const dynamoClient = new DynamoDBClient({});
const sesClient = new SESClient({ region: process.env.SES_REGION || process.env.AWS_REGION || "eu-north-1" });

const TENANT_TABLE = process.env.TENANT_TABLE || "NativeFormsTenants";
const PLAN_TABLE = process.env.PLAN_TABLE || "NativeFormsPlans";
const AUDIT_TABLE = process.env.AUDIT_TABLE || "NativeFormsAdminAudit";
const SUPPORT_TABLE = process.env.SUPPORT_TABLE || "NativeFormsSupportEvents";
const SETTINGS_TABLE = process.env.SETTINGS_TABLE || "NativeFormsAdminSettings";
const REQUIRE_ADMIN_AUTH = String(process.env.REQUIRE_ADMIN_AUTH || "").toLowerCase() === "true";
const EDITABLE_PLAN_CODES = new Set(["free", "trial", "starter", "pro"]);
const DEFAULT_STATUS_ALERT_EMAIL = process.env.DEFAULT_STATUS_ALERT_EMAIL || "yosi@harmony-it.co.il";
const SES_FROM = process.env.SES_FROM || "yosi@harmony-it.co.il";
const DEFAULT_STATUS_RECOMPUTE_TIME_UTC = process.env.DEFAULT_STATUS_RECOMPUTE_TIME_UTC || "02:00";

const DEFAULT_PLANS = [
  {
    planCode: "free",
    label: "Free",
    description: "Permanent low-volume entry plan.",
    isActive: true,
    durationType: "forever",
    durationDays: null,
    limits: {
      maxSfUsers: 1,
      maxForms: 1,
      maxSubmissionsPerMonth: 100
    },
    featureFlags: {
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
    isActive: true,
    durationType: "fixed_days",
    durationDays: 30,
    limits: {
      maxSfUsers: 1,
      maxForms: 5,
      maxSubmissionsPerMonth: null
    },
    featureFlags: {
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
    isActive: true,
    durationType: "forever",
    durationDays: null,
    limits: {
      maxSfUsers: 1,
      maxForms: 5,
      maxSubmissionsPerMonth: 1000
    },
    featureFlags: {
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
    isActive: true,
    durationType: "forever",
    durationDays: null,
    limits: {
      maxSfUsers: null,
      maxForms: null,
      maxSubmissionsPerMonth: null
    },
    featureFlags: {
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

function jsonResponse(statusCode, payload) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  };
}

function success(data) {
  return { success: true, data };
}

function failure(code, message, statusCode = 400) {
  return jsonResponse(statusCode, {
    success: false,
    error: {
      code,
      message
    }
  });
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

function assertAdminAccess(headers) {
  if (!REQUIRE_ADMIN_AUTH) {
    return;
  }

  const token = getBearerToken(headers);
  if (!token) {
    const error = new Error("Missing or invalid admin token.");
    error.statusCode = 401;
    error.code = "UNAUTHORIZED";
    throw error;
  }
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
    return {
      L: value
        .map(toAttributeValue)
        .filter(Boolean)
    };
  }

  if (typeof value === "object") {
    const mapped = {};
    for (const [key, nestedValue] of Object.entries(value)) {
      const attributeValue = toAttributeValue(nestedValue);
      if (attributeValue !== undefined) {
        mapped[key] = attributeValue;
      }
    }
    return { M: mapped };
  }

  return { S: String(value) };
}

function marshallItem(item) {
  const marshalled = {};
  for (const [key, value] of Object.entries(item || {})) {
    const attributeValue = toAttributeValue(value);
    if (attributeValue !== undefined) {
      marshalled[key] = attributeValue;
    }
  }
  return marshalled;
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

async function putItem(tableName, item) {
  await dynamoClient.send(new PutItemCommand({
    TableName: tableName,
    Item: marshallItem(item)
  }));
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

async function putItemIfTableExists(tableName, item) {
  try {
    await putItem(tableName, item);
    return true;
  } catch (error) {
    if (isTableUnavailableError(error)) {
      return false;
    }
    throw error;
  }
}

async function getAdminSettings() {
  const stored = await getItemByKey(SETTINGS_TABLE, "settingKey", "admin_notifications").catch((error) => {
    if (isTableUnavailableError(error)) {
      return null;
    }
    throw error;
  });

  return {
    statusAlertEmailRecipient: normalizeOptionalString(stored?.statusAlertEmailRecipient) || DEFAULT_STATUS_ALERT_EMAIL,
    statusRecomputeTimeUtc: normalizeTimeOfDay(stored?.statusRecomputeTimeUtc) || DEFAULT_STATUS_RECOMPUTE_TIME_UTC,
    updatedAt: stored?.updatedAt || null,
    source: stored ? "dynamodb" : "default"
  };
}

async function saveAdminSettings(settings) {
  const existing = await getItemByKey(SETTINGS_TABLE, "settingKey", "admin_notifications").catch((error) => {
    if (isTableUnavailableError(error)) {
      return null;
    }
    throw error;
  });

  const record = {
    ...(existing || {}),
    settingKey: "admin_notifications",
    statusAlertEmailRecipient: normalizeOptionalString(settings?.statusAlertEmailRecipient) || DEFAULT_STATUS_ALERT_EMAIL,
    statusRecomputeTimeUtc: normalizeTimeOfDay(settings?.statusRecomputeTimeUtc) || DEFAULT_STATUS_RECOMPUTE_TIME_UTC,
    updatedAt: getNowIso()
  };

  await putItem(SETTINGS_TABLE, record);

  return {
    statusAlertEmailRecipient: record.statusAlertEmailRecipient,
    statusRecomputeTimeUtc: record.statusRecomputeTimeUtc,
    updatedAt: record.updatedAt,
    source: "dynamodb"
  };
}

function normalizeTimeOfDay(value) {
  const normalized = String(value || "").trim();
  const match = /^(\d{2}):(\d{2})$/.exec(normalized);
  if (!match) {
    return null;
  }

  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  if (!Number.isInteger(hours) || !Number.isInteger(minutes) || hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
    return null;
  }

  return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}`;
}

async function sendStatusChangeEmail(recipient, beforeTenant, afterTenant) {
  const normalizedRecipient = normalizeOptionalString(recipient);
  if (!normalizedRecipient || !SES_FROM) {
    return false;
  }

  const beforeStatus = beforeTenant?.status || "unknown";
  const afterStatus = afterTenant?.status || "unknown";
  const beforeAlert = beforeTenant?.alertType || "none";
  const afterAlert = afterTenant?.alertType || "none";

  await sesClient.send(new SendEmailCommand({
    Source: SES_FROM,
    Destination: {
      ToAddresses: [normalizedRecipient]
    },
    Message: {
      Subject: {
        Data: `NativeForms customer status changed: ${afterTenant?.companyName || afterTenant?.orgId || "Unknown customer"}`
      },
      Body: {
        Text: {
          Data: [
            "A NativeForms customer status changed.",
            "",
            `Customer: ${afterTenant?.companyName || ""}`,
            `Org Id: ${afterTenant?.orgId || ""}`,
            `Admin Email: ${afterTenant?.adminEmail || ""}`,
            `Previous Status: ${beforeStatus}`,
            `New Status: ${afterStatus}`,
            `Previous Alert Type: ${beforeAlert}`,
            `New Alert Type: ${afterAlert}`,
            `Reason: ${afterTenant?.statusReason || "No reason saved."}`,
            `Changed At: ${afterTenant?.statusComputedAt || getNowIso()}`
          ].join("\n")
        }
      }
    }
  }));

  return true;
}

function normalizeOrgId(orgId) {
  if (typeof orgId !== "string") {
    return orgId;
  }

  const trimmed = orgId.trim();
  return trimmed.length >= 15 ? trimmed.substring(0, 15) : trimmed;
}

function normalizePlanCode(planCode, tenant) {
  if (planCode) {
    return String(planCode).toLowerCase();
  }

  const state = String(tenant?.subscriptionState || "").toLowerCase();
  if (["free", "trial", "starter", "pro"].includes(state)) {
    return state;
  }

  return "trial";
}

function normalizePlanDefinition(plan, existingPlan = {}) {
  const planCode = normalizePlanCode(plan.planCode || existingPlan.planCode);
  if (!EDITABLE_PLAN_CODES.has(planCode)) {
    const error = new Error("Plan code must be one of free, trial, starter, or pro.");
    error.code = "INVALID_PLAN_CODE";
    error.statusCode = 400;
    throw error;
  }

  const limits = {
    maxSfUsers: plan?.limits?.maxSfUsers ?? existingPlan?.limits?.maxSfUsers ?? null,
    maxForms: plan?.limits?.maxForms ?? existingPlan?.limits?.maxForms ?? null,
    maxSubmissionsPerMonth: plan?.limits?.maxSubmissionsPerMonth ?? existingPlan?.limits?.maxSubmissionsPerMonth ?? null
  };

  const featureFlags = {
    ...existingPlan?.featureFlags,
    ...plan?.featureFlags
  };

  return {
    planCode,
    label: plan.label || existingPlan.label || labelizePlanCode(planCode),
    description: plan.description || existingPlan.description || "",
    isActive: plan.isActive ?? existingPlan.isActive ?? true,
    durationType: plan.durationType || existingPlan.durationType || "forever",
    durationDays: plan.durationDays ?? existingPlan.durationDays ?? null,
    sortOrder: plan.sortOrder ?? existingPlan.sortOrder ?? getDefaultPlanSortOrder(planCode),
    limits,
    featureFlags,
    updatedAt: new Date().toISOString()
  };
}

function labelizePlanCode(planCode) {
  return String(planCode || "")
    .replaceAll("_", " ")
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

function getDefaultPlanSortOrder(planCode) {
  return {
    free: 1,
    trial: 2,
    starter: 3,
    pro: 4
  }[planCode] || 99;
}

function sortPlans(plans) {
  return [...plans].sort((a, b) => {
    const sortA = a?.sortOrder ?? getDefaultPlanSortOrder(a?.planCode);
    const sortB = b?.sortOrder ?? getDefaultPlanSortOrder(b?.planCode);

    if (sortA !== sortB) {
      return sortA - sortB;
    }

    return String(a?.label || "").localeCompare(String(b?.label || ""));
  });
}

function parseJsonBody(body) {
  if (!body) {
    return {};
  }

  if (typeof body === "string") {
    try {
      return JSON.parse(body);
    } catch (error) {
      const parseError = new Error("Request body must be valid JSON.");
      parseError.code = "INVALID_JSON";
      parseError.statusCode = 400;
      throw parseError;
    }
  }

  return body;
}

function normalizeOptionalString(value) {
  if (value == null) {
    return null;
  }

  const trimmed = String(value).trim();
  return trimmed ? trimmed : null;
}

function normalizeOptionalDate(value) {
  const normalized = normalizeOptionalString(value);
  if (!normalized) {
    return null;
  }

  return normalized;
}

function parseDateEnd(value) {
  const normalized = normalizeOptionalDate(value);
  if (!normalized) {
    return null;
  }

  const parsed = new Date(`${normalized}T23:59:59.999Z`);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function isSameValue(left, right) {
  return JSON.stringify(left ?? null) === JSON.stringify(right ?? null);
}

function parseNumberOrNull(value) {
  if (value == null || value === "") {
    return null;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function getEffectiveAccessEndDate(tenant, planCode = normalizePlanCode(tenant?.planCode, tenant)) {
  const normalizedPlanCode = normalizePlanCode(planCode, tenant);
  if (normalizedPlanCode === "trial") {
    return tenant?.trialEndsAt || tenant?.planEndsAt || tenant?.subscriptionEndDate || null;
  }

  return tenant?.planEndsAt || tenant?.subscriptionEndDate || null;
}

function isTenantDateExpired(tenant, planCode = normalizePlanCode(tenant?.planCode, tenant)) {
  const endValue = getEffectiveAccessEndDate(tenant, planCode);
  const parsed = parseDateEnd(endValue);
  return parsed ? parsed.getTime() < Date.now() : false;
}

function deriveTenantAccessState(tenant, selectedPlan) {
  const planCode = normalizePlanCode(tenant?.planCode, tenant);
  const plan = selectedPlan || DEFAULT_PLANS.find((item) => item.planCode === planCode) || DEFAULT_PLANS[1];
  const effectiveLimits = tenant?.effectiveLimits || mergeLimits(plan?.limits || {}, tenant?.planOverrides?.limits || {});
  const manualStatus = normalizeOptionalString(tenant?.status);
  const maxSubmissionsPerMonth = parseNumberOrNull(effectiveLimits?.maxSubmissionsPerMonth);
  const submissionsMonth = parseNumberOrNull(tenant?.submissionsMonth) ?? 0;

  if (["blocked", "suspended"].includes(String(manualStatus || "").toLowerCase()) || tenant?.isActive === false) {
    return {
      status: "blocked",
      isActive: false,
      subscriptionStatus: planCode === "trial" ? "trialing" : "active",
      alertType: null,
      statusSource: "manual_admin",
      reason: "Customer was blocked manually."
    };
  }

  if (isTenantDateExpired(tenant, planCode)) {
    return {
      status: "alert",
      isActive: true,
      subscriptionStatus: planCode === "trial" ? "trialing" : "active",
      alertType: "end_date_passed",
      statusSource: "auto_rule",
      reason: "Customer passed the configured access end date."
    };
  }

  if (maxSubmissionsPerMonth != null && submissionsMonth > maxSubmissionsPerMonth) {
    return {
      status: "alert",
      isActive: true,
      subscriptionStatus: planCode === "trial" ? "trialing" : "active",
      alertType: "submission_limit_exceeded",
      statusSource: "auto_rule",
      reason: "Customer exceeded the monthly submission limit."
    };
  }

  return {
    status: "active",
    isActive: true,
    subscriptionStatus: planCode === "trial" ? "trialing" : "active",
    alertType: null,
    statusSource: "auto_rule",
    reason: planCode === "trial" ? "Trial is active." : "Customer is active."
  };
}

function normalizeTenantLifecycle(tenant, selectedPlan) {
  const planCode = normalizePlanCode(tenant?.planCode, tenant);
  const planStartedAt = tenant?.planStartedAt || tenant?.subscriptionStartDate || tenant?.createdAt || null;
  const trialStartedAt = planCode === "trial"
    ? (tenant?.trialStartedAt || tenant?.planStartedAt || tenant?.subscriptionStartDate || null)
    : (tenant?.trialStartedAt || null);
  const trialEndsAt = planCode === "trial"
    ? (tenant?.trialEndsAt || tenant?.planEndsAt || tenant?.subscriptionEndDate || null)
    : (tenant?.trialEndsAt || null);
  const planEndsAt = tenant?.planEndsAt || (planCode === "trial" ? trialEndsAt : tenant?.subscriptionEndDate || null);
  const effectiveEndDate = getEffectiveAccessEndDate({
    ...tenant,
    planCode,
    planEndsAt,
    trialEndsAt
  }, planCode);
  const accessState = deriveTenantAccessState({
    ...tenant,
    planCode,
    planEndsAt,
    trialEndsAt,
    effectiveLimits: tenant?.effectiveLimits || mergeLimits(selectedPlan?.limits || {}, tenant?.planOverrides?.limits || {})
  }, selectedPlan);

  return {
    ...tenant,
    planCode,
    planLabel: tenant?.planLabel || selectedPlan?.label || labelizePlanCode(planCode),
    status: accessState.status,
    isActive: accessState.isActive,
    planStartedAt,
    planEndsAt,
    trialStartedAt,
    trialEndsAt,
    subscriptionStartDate: tenant?.subscriptionStartDate || planStartedAt,
    subscriptionEndDate: effectiveEndDate,
    planStatus: accessState.subscriptionStatus,
    subscriptionStatus: accessState.subscriptionStatus,
    alertType: accessState.alertType,
    statusReason: accessState.reason,
    statusSource: accessState.statusSource,
    statusComputedAt: getNowIso(),
    effectiveAccessEndDate: effectiveEndDate
  };
}

function getNowIso() {
  return new Date().toISOString();
}

function addDays(baseValue, days) {
  const base = baseValue ? new Date(baseValue) : new Date();
  if (Number.isNaN(base.getTime())) {
    return null;
  }
  base.setUTCDate(base.getUTCDate() + days);
  return base.toISOString().slice(0, 10);
}

function sortByCreatedAtDesc(items) {
  return [...items].sort((a, b) => String(b?.createdAt || "").localeCompare(String(a?.createdAt || "")));
}

function buildAuditEntry({ orgId = "GLOBAL", actionType, actionLabel, actorEmail, reason, summary, before = null, after = null }) {
  return {
    auditId: randomUUID(),
    orgId,
    actionType,
    actionLabel,
    actorEmail: actorEmail || "admin@nativeforms.internal",
    reason: normalizeOptionalString(reason) || summary || actionLabel,
    summary: summary || actionLabel,
    before,
    after,
    createdAt: getNowIso()
  };
}

function buildSupportEntry({ orgId, eventType = "support_note", severity, message, createdBy }) {
  return {
    eventId: randomUUID(),
    orgId,
    eventType,
    severity: severity || "normal",
    message: message || "",
    createdBy: createdBy || "admin@nativeforms.internal",
    createdAt: getNowIso()
  };
}

function getPlanMap(plans) {
  return new Map(plans.map((plan) => [plan.planCode, plan]));
}

function mergeFlags(planFlags = {}, overrideFlags = {}) {
  return {
    ...planFlags,
    ...overrideFlags
  };
}

function mergeLimits(planLimits = {}, overrideLimits = {}) {
  return {
    ...planLimits,
    ...overrideLimits
  };
}

function deriveSetupState(tenant) {
  if (tenant?.setupState) {
    return tenant.setupState;
  }

  const connection = String(tenant?.salesforceConnectionStatus || "").toLowerCase();
  const oauth = String(tenant?.oauthStatus || "").toLowerCase();
  const secretStatus = String(tenant?.tenantSecretStatus || "").toLowerCase();

  if (connection === "connected" || oauth === "connected") {
    return "connected";
  }
  if (oauth === "pending") {
    return "oauth_pending";
  }
  if (secretStatus === "verified") {
    return "tenant_secret_verified";
  }
  if (connection === "failed") {
    return "setup_failed";
  }

  return "not_registered";
}

function deriveHealthStatus(tenant) {
  if (tenant?.healthStatus) {
    return tenant.healthStatus;
  }

  if (tenant?.status === "blocked") {
    return "critical";
  }

  if (tenant?.status === "alert") {
    return "warning";
  }

  const setupState = deriveSetupState(tenant);
  if (setupState === "connected") {
    return tenant?.status === "blocked" ? "critical" : "healthy";
  }
  if (setupState === "setup_failed") {
    return "critical";
  }
  return "warning";
}

function buildTenantDetail(tenant, plansByCode) {
  const planCode = normalizePlanCode(tenant.planCode, tenant);
  const plan = plansByCode.get(planCode) || plansByCode.get("trial") || DEFAULT_PLANS[1];
  const normalizedTenant = normalizeTenantLifecycle(tenant, plan);
  const overrideFlags = tenant?.planOverrides?.featureFlags || {};
  const overrideLimits = tenant?.planOverrides?.limits || {};
  const effectiveFeatureFlags = tenant?.effectiveFeatureFlags || mergeFlags(plan.featureFlags, overrideFlags);
  const effectiveLimits = tenant?.effectiveLimits || mergeLimits(plan.limits, overrideLimits);

  return {
    orgId: normalizeOrgId(normalizedTenant.orgId),
    companyName: normalizedTenant.companyName || "Unknown Tenant",
    adminEmail: normalizedTenant.adminEmail || "",
    loginBaseUrl: normalizedTenant.loginBaseUrl || "",
    status: normalizedTenant.status,
    isActive: normalizedTenant.isActive,
    planCode,
    planLabel: normalizedTenant.planLabel || plan.label,
    planStatus: normalizedTenant.planStatus || "active",
    subscriptionStatus: normalizedTenant.subscriptionStatus || normalizedTenant.planStatus || "active",
    planStartedAt: normalizedTenant.planStartedAt || null,
    planEndsAt: normalizedTenant.planEndsAt || null,
    trialStartedAt: normalizedTenant.trialStartedAt || null,
    trialEndsAt: normalizedTenant.trialEndsAt || null,
    effectiveAccessEndDate: normalizedTenant.effectiveAccessEndDate || null,
    alertType: normalizedTenant.alertType || null,
    statusReason: normalizedTenant.statusReason || "",
    statusSource: normalizedTenant.statusSource || "auto_rule",
    statusComputedAt: normalizedTenant.statusComputedAt || null,
    effectiveLimits,
    effectiveFeatureFlags,
    planOverrides: normalizedTenant.planOverrides || {
      limits: {},
      featureFlags: {}
    },
    setupState: deriveSetupState(normalizedTenant),
    tenantSecretStatus: normalizedTenant.tenantSecretStatus || "unknown",
    oauthStatus: normalizedTenant.oauthStatus || (normalizedTenant.salesforceConnectionStatus === "connected" ? "connected" : "not_started"),
    healthStatus: deriveHealthStatus(normalizedTenant),
    supportStatus: normalizedTenant.supportStatus || "normal",
    internalNotes: normalizedTenant.internalNotes || normalizedTenant.notes || "",
    activeFormsCount: normalizedTenant.activeFormsCount ?? 0,
    submissionsToday: normalizedTenant.submissionsToday ?? 0,
    submissionsMonth: normalizedTenant.submissionsMonth ?? 0,
    lastSubmissionAt: normalizedTenant.lastSubmissionAt || null,
    lastActivityAt: normalizedTenant.lastActivityAt || normalizedTenant.updatedAt || normalizedTenant.createdAt || null,
    salesforceConnectionStatus: normalizedTenant.salesforceConnectionStatus || "not-connected",
    salesforceConnectionUpdatedAt: normalizedTenant.salesforceConnectionUpdatedAt || null,
    connectedUsername: normalizedTenant.connectedUsername || null,
    createdAt: normalizedTenant.createdAt || null,
    updatedAt: normalizedTenant.updatedAt || null
  };
}

function buildTenantSummary(tenantDetail) {
  return {
    orgId: tenantDetail.orgId,
    companyName: tenantDetail.companyName,
    adminEmail: tenantDetail.adminEmail,
    planCode: tenantDetail.planCode,
    planLabel: tenantDetail.planLabel,
    status: tenantDetail.status,
    setupState: tenantDetail.setupState,
    healthStatus: tenantDetail.healthStatus,
    supportStatus: tenantDetail.supportStatus,
    alertType: tenantDetail.alertType,
    planEndsAt: tenantDetail.planEndsAt,
    trialEndsAt: tenantDetail.trialEndsAt,
    lastActivityAt: tenantDetail.lastActivityAt,
    submissionsMonth: tenantDetail.submissionsMonth,
    activeFormsCount: tenantDetail.activeFormsCount
  };
}

async function loadPlans() {
  try {
    const plans = sortPlans(await scanAllItems(PLAN_TABLE));
    if (!plans.length) {
      return {
        items: sortPlans(DEFAULT_PLANS),
        isFallback: true
      };
    }
    return {
      items: plans,
      isFallback: false
    };
  } catch (error) {
    return {
      items: sortPlans(DEFAULT_PLANS),
      isFallback: true
    };
  }
}

async function syncTenantStatuses(tenants, plansByCode) {
  const details = [];
  let updatedCount = 0;

  for (const tenant of tenants) {
    const detail = buildTenantDetail(tenant, plansByCode);
    details.push(detail);

    const needsStatusSync = tenant.status !== detail.status
      || !isSameValue(tenant.alertType, detail.alertType)
      || tenant.statusReason !== detail.statusReason
      || tenant.statusSource !== detail.statusSource;

    if (needsStatusSync) {
      const syncedTenant = {
        ...tenant,
        status: detail.status,
        isActive: detail.isActive,
        alertType: detail.alertType,
        statusReason: detail.statusReason,
        statusSource: detail.statusSource,
        statusComputedAt: detail.statusComputedAt,
        subscriptionStatus: detail.subscriptionStatus,
        planStatus: detail.planStatus,
        subscriptionEndDate: detail.effectiveAccessEndDate || tenant.subscriptionEndDate || null,
        updatedAt: tenant.updatedAt || detail.updatedAt || getNowIso()
      };

      await putItem(TENANT_TABLE, syncedTenant);
      await notifyStatusChangeIfNeeded(buildTenantDetail(tenant, plansByCode), detail);
      updatedCount += 1;
    }
  }

  return {
    details,
    updatedCount
  };
}

async function loadTenantDetails(plansByCode) {
  const tenants = await scanAllItems(TENANT_TABLE);
  const result = await syncTenantStatuses(tenants, plansByCode);
  return result.details;
}

function getCurrentUtcTimeOfDay() {
  return getNowIso().slice(11, 16);
}

async function runScheduledStatusRefresh() {
  const settings = await getAdminSettings();
  const recomputeTime = normalizeTimeOfDay(settings.statusRecomputeTimeUtc) || DEFAULT_STATUS_RECOMPUTE_TIME_UTC;
  const currentTime = getCurrentUtcTimeOfDay();

  if (currentTime !== recomputeTime) {
    return {
      ran: false,
      reason: `Current UTC time ${currentTime} does not match configured recompute time ${recomputeTime}.`,
      configuredTimeUtc: recomputeTime,
      updatedCount: 0,
      totalCustomers: 0
    };
  }

  const plansResult = await loadPlans();
  const plansByCode = getPlanMap(plansResult.items);
  const tenants = await scanAllItems(TENANT_TABLE);
  const result = await syncTenantStatuses(tenants, plansByCode);

  return {
    ran: true,
    reason: `Daily customer status recompute executed at ${currentTime} UTC.`,
    configuredTimeUtc: recomputeTime,
    updatedCount: result.updatedCount,
    totalCustomers: result.details.length
  };
}

async function loadAuditEntries(orgId = null) {
  const items = await scanAllItemsSafe(AUDIT_TABLE);
  const filtered = orgId ? items.filter((item) => normalizeOrgId(item.orgId) === normalizeOrgId(orgId)) : items;
  return sortByCreatedAtDesc(filtered);
}

async function loadSupportEntries(orgId = null) {
  const items = await scanAllItemsSafe(SUPPORT_TABLE);
  const filtered = orgId ? items.filter((item) => normalizeOrgId(item.orgId) === normalizeOrgId(orgId)) : items;
  return sortByCreatedAtDesc(filtered);
}

function applyTenantFilters(items, query) {
  const q = String(query?.q || "").trim().toLowerCase();
  const status = String(query?.status || "").trim().toLowerCase();
  const planCode = String(query?.planCode || "").trim().toLowerCase();
  const setupState = String(query?.setupState || "").trim().toLowerCase();
  const healthStatus = String(query?.healthStatus || "").trim().toLowerCase();

  return items.filter((item) => {
    const matchesSearch = !q || [
      item.companyName,
      item.adminEmail,
      item.orgId
    ].some((value) => String(value || "").toLowerCase().includes(q));

    const matchesStatus = !status || String(item.status).toLowerCase() === status;
    const matchesPlan = !planCode || String(item.planCode).toLowerCase() === planCode;
    const matchesSetup = !setupState || String(item.setupState).toLowerCase() === setupState;
    const matchesHealth = !healthStatus || String(item.healthStatus).toLowerCase() === healthStatus;

    return matchesSearch && matchesStatus && matchesPlan && matchesSetup && matchesHealth;
  });
}

async function recordAuditEntries(entries) {
  const stored = [];
  for (const entry of entries) {
    const saved = await putItemIfTableExists(AUDIT_TABLE, entry);
    if (saved) {
      stored.push(entry);
    }
  }
  return stored;
}

async function recordSupportEntries(entries) {
  const stored = [];
  for (const entry of entries) {
    const saved = await putItemIfTableExists(SUPPORT_TABLE, entry);
    if (saved) {
      stored.push(entry);
    }
  }
  return stored;
}

async function saveTenantWithAudit(tenant, plansByCode, auditEntries = [], supportEntries = []) {
  await putItem(TENANT_TABLE, tenant);
  const storedAuditEntries = await recordAuditEntries(auditEntries);
  const storedSupportEntries = await recordSupportEntries(supportEntries);

  return {
    tenant: buildTenantDetail(tenant, plansByCode),
    auditEntries: storedAuditEntries,
    supportEntries: storedSupportEntries
  };
}

async function notifyStatusChangeIfNeeded(beforeTenant, afterTenant) {
  if (!beforeTenant || !afterTenant) {
    return false;
  }

  if (beforeTenant.status === afterTenant.status) {
    return false;
  }

  const settings = await getAdminSettings();
  try {
    return await sendStatusChangeEmail(settings.statusAlertEmailRecipient, beforeTenant, afterTenant);
  } catch (error) {
    console.error("Failed to send status change email:", error);
    return false;
  }
}

function buildOverview(tenantSummaries, auditEntries = [], supportEntries = []) {
  const activeTenants = tenantSummaries.filter((tenant) => tenant.status === "active").length;
  const trialsInProgress = tenantSummaries.filter((tenant) => tenant.planCode === "trial").length;
  const expiringTrialsList = tenantSummaries.filter((tenant) => {
    if (!tenant.trialEndsAt && !tenant.planEndsAt) {
      return false;
    }

    const compareValue = tenant.trialEndsAt || tenant.planEndsAt;
    const compareDate = new Date(compareValue);
    if (Number.isNaN(compareDate.getTime())) {
      return false;
    }

    const diffDays = Math.ceil((compareDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24));
    return diffDays >= 0 && diffDays <= 14;
  });
  const tenantsWithIssues = tenantSummaries.filter((tenant) => tenant.healthStatus !== "healthy").length;
  const submissionsToday = 0;
  const tenantsNeedingSupport = tenantSummaries.filter((tenant) => tenant.healthStatus === "critical" || tenant.supportStatus === "priority").length;
  const setupIssues = tenantSummaries.filter((tenant) => tenant.setupState !== "connected" || tenant.healthStatus === "critical");

  return {
    summary: {
      activeTenants,
      trialsInProgress,
      expiringTrials: expiringTrialsList.length,
      tenantsWithIssues,
      submissionsToday,
      tenantsNeedingSupport
    },
    lists: {
      setupIssues: setupIssues.slice(0, 8),
      expiringTrials: expiringTrialsList.slice(0, 8),
      recentSupportNotes: supportEntries.slice(0, 8),
      recentAdminActions: auditEntries.slice(0, 8)
    }
  };
}

function routeMatch(path) {
  const normalized = String(path || "/").replace(/\/+$/, "") || "/";
  const parts = normalized.split("/").filter(Boolean);
  return parts;
}

export const handler = async (event) => {
  const path = event?.requestContext?.http?.path || event?.rawPath || "/";
  const method = event?.requestContext?.http?.method || event?.httpMethod || "GET";

  if (event?.source === "aws.events" || event?.["detail-type"] === "Scheduled Event") {
    try {
      return {
        statusCode: 200,
        body: JSON.stringify(await runScheduledStatusRefresh())
      };
    } catch (error) {
      console.error("Scheduled status refresh failed:", error);
      return {
        statusCode: 500,
        body: JSON.stringify({
          ran: false,
          reason: error?.message || "Scheduled status refresh failed."
        })
      };
    }
  }

  if (method === "OPTIONS") {
    return jsonResponse(200, success({}));
  }

  try {
    assertAdminAccess(event?.headers);

    const plansResult = await loadPlans();
    const plans = plansResult.items;
    const plansByCode = getPlanMap(plans);
    const parts = routeMatch(path);

    if (method === "GET" && parts.length === 2 && parts[0] === "admin" && parts[1] === "overview") {
      const tenantDetails = await loadTenantDetails(plansByCode);
      const tenantSummaries = tenantDetails.map(buildTenantSummary);
      const [auditEntries, supportEntries] = await Promise.all([
        loadAuditEntries(),
        loadSupportEntries()
      ]);
      return jsonResponse(200, success(buildOverview(tenantSummaries, auditEntries, supportEntries)));
    }

    if (method === "GET" && parts.length === 2 && parts[0] === "admin" && parts[1] === "plans") {
      return jsonResponse(200, success({
        items: plans,
        storageMode: plansResult.isFallback ? "fallback" : "dynamodb"
      }));
    }

    if (method === "GET" && parts.length === 2 && parts[0] === "admin" && parts[1] === "audit") {
      return jsonResponse(200, success({
        items: await loadAuditEntries()
      }));
    }

    if (method === "GET" && parts.length === 2 && parts[0] === "admin" && parts[1] === "settings") {
      return jsonResponse(200, success({
        settings: await getAdminSettings()
      }));
    }

    if (method === "GET" && parts.length === 2 && parts[0] === "admin" && parts[1] === "tenants") {
      const tenantDetails = await loadTenantDetails(plansByCode);
      const tenantSummaries = tenantDetails.map(buildTenantSummary);
      const filtered = applyTenantFilters(tenantSummaries, event?.queryStringParameters || {});

      return jsonResponse(200, success({
        items: filtered,
        page: {
          limit: Number(event?.queryStringParameters?.limit || 25),
          nextCursor: null
        }
      }));
    }

    if (method === "GET" && parts.length === 3 && parts[0] === "admin" && parts[1] === "tenants") {
      const orgId = normalizeOrgId(parts[2]);
      const tenant = await getItemByKey(TENANT_TABLE, "orgId", orgId);

      if (!tenant) {
        return failure("TENANT_NOT_FOUND", "Tenant was not found.", 404);
      }

      const detail = buildTenantDetail(tenant, plansByCode);
      const needsStatusSync = tenant.status !== detail.status
        || !isSameValue(tenant.alertType, detail.alertType)
        || tenant.statusReason !== detail.statusReason
        || tenant.statusSource !== detail.statusSource;

      if (needsStatusSync) {
        await putItem(TENANT_TABLE, {
          ...tenant,
          status: detail.status,
          isActive: detail.isActive,
          alertType: detail.alertType,
          statusReason: detail.statusReason,
          statusSource: detail.statusSource,
          statusComputedAt: detail.statusComputedAt,
          subscriptionStatus: detail.subscriptionStatus,
          planStatus: detail.planStatus,
          subscriptionEndDate: detail.effectiveAccessEndDate || tenant.subscriptionEndDate || null
        });
        await notifyStatusChangeIfNeeded(buildTenantDetail(tenant, plansByCode), detail);
      }

      return jsonResponse(200, success({
        tenant: detail
      }));
    }

    if (method === "GET" && parts.length === 4 && parts[0] === "admin" && parts[1] === "tenants" && parts[3] === "audit") {
      return jsonResponse(200, success({
        items: await loadAuditEntries(parts[2])
      }));
    }

    if (method === "GET" && parts.length === 4 && parts[0] === "admin" && parts[1] === "tenants" && parts[3] === "support") {
      return jsonResponse(200, success({
        items: await loadSupportEntries(parts[2])
      }));
    }

    if (method === "POST" && parts.length === 3 && parts[0] === "admin" && parts[1] === "plans") {
      if (plansResult.isFallback) {
        return failure("PLAN_TABLE_NOT_READY", "NativeFormsPlans table does not exist yet. Create that table before saving plan changes.", 409);
      }

      const planCode = normalizePlanCode(parts[2]);
      const body = parseJsonBody(event?.body);
      const existingPlan = plansByCode.get(planCode) || DEFAULT_PLANS.find((plan) => plan.planCode === planCode) || {};
      const normalizedPlan = normalizePlanDefinition({
        ...body,
        planCode
      }, existingPlan);

      await putItem(PLAN_TABLE, normalizedPlan);
      const auditEntries = await recordAuditEntries([
        buildAuditEntry({
          actionType: "change_plan",
          actionLabel: "Changed plan definition",
          actorEmail: body.actorEmail,
          reason: body.reason,
          summary: `Updated ${normalizedPlan.label} plan definition.`,
          before: existingPlan,
          after: normalizedPlan
        })
      ]);

      return jsonResponse(200, success({
        plan: normalizedPlan,
        storageMode: "dynamodb",
        auditEntries
      }));
    }

    if (method === "POST" && parts.length === 2 && parts[0] === "admin" && parts[1] === "settings") {
      const body = parseJsonBody(event?.body);
      const settings = await saveAdminSettings({
        statusAlertEmailRecipient: body.statusAlertEmailRecipient,
        statusRecomputeTimeUtc: body.statusRecomputeTimeUtc
      });

      return jsonResponse(200, success({
        settings
      }));
    }

    if (method === "POST" && parts.length === 4 && parts[0] === "admin" && parts[1] === "tenants" && parts[3] === "profile") {
      const orgId = normalizeOrgId(parts[2]);
      const tenant = await getItemByKey(TENANT_TABLE, "orgId", orgId);

      if (!tenant) {
        return failure("TENANT_NOT_FOUND", "Tenant was not found.", 404);
      }

      const body = parseJsonBody(event?.body);
      const planCode = normalizePlanCode(body.planCode || tenant.planCode, tenant);
      const selectedPlan = plansByCode.get(planCode) || DEFAULT_PLANS.find((plan) => plan.planCode === planCode) || DEFAULT_PLANS[1];
      const mergedTenant = normalizeTenantLifecycle({
        ...tenant,
        orgId,
        companyName: body.companyName?.trim?.() || tenant.companyName || "",
        adminEmail: body.adminEmail?.trim?.() || tenant.adminEmail || "",
        status: tenant.status || "active",
        planCode,
        planLabel: selectedPlan.label,
        planStatus: normalizeOptionalString(body.subscriptionStatus) || tenant.planStatus || "active",
        subscriptionStatus: normalizeOptionalString(body.subscriptionStatus) || tenant.subscriptionStatus || tenant.planStatus || "active",
        planStartedAt: normalizeOptionalDate(body.planStartedAt) ?? tenant.planStartedAt ?? tenant.subscriptionStartDate ?? null,
        planEndsAt: normalizeOptionalDate(body.planEndsAt) ?? tenant.planEndsAt ?? null,
        trialStartedAt: normalizeOptionalDate(body.trialStartedAt) ?? tenant.trialStartedAt ?? null,
        trialEndsAt: normalizeOptionalDate(body.trialEndsAt) ?? tenant.trialEndsAt ?? null,
        supportStatus: normalizeOptionalString(body.supportStatus) || tenant.supportStatus || "normal",
        internalNotes: body.internalNotes != null ? String(body.internalNotes) : (tenant.internalNotes || tenant.notes || ""),
        notes: body.internalNotes != null ? String(body.internalNotes) : (tenant.notes || tenant.internalNotes || ""),
        updatedAt: new Date().toISOString(),
        effectiveLimits: mergeLimits(selectedPlan.limits, tenant?.planOverrides?.limits || {}),
        effectiveFeatureFlags: mergeFlags(selectedPlan.featureFlags, tenant?.planOverrides?.featureFlags || {})
      }, selectedPlan);

      const result = await saveTenantWithAudit(
        mergedTenant,
        plansByCode,
        [
          buildAuditEntry({
            orgId,
            actionType: "update_tenant_profile",
            actionLabel: "Updated tenant profile",
            actorEmail: body.actorEmail,
            reason: body.reason || "Tenant profile was updated from the Admin Control App.",
            summary: `Updated tenant profile for ${mergedTenant.companyName}.`,
            before: buildTenantDetail(tenant, plansByCode),
            after: buildTenantDetail(mergedTenant, plansByCode)
          })
        ]
      );

      await notifyStatusChangeIfNeeded(buildTenantDetail(tenant, plansByCode), result.tenant);

      return jsonResponse(200, success({
        tenant: result.tenant,
        auditEntries: result.auditEntries
      }));
    }

    if (method === "POST" && parts.length === 4 && parts[0] === "admin" && parts[1] === "tenants" && parts[3] === "extend-trial") {
      const orgId = normalizeOrgId(parts[2]);
      const tenant = await getItemByKey(TENANT_TABLE, "orgId", orgId);
      if (!tenant) {
        return failure("TENANT_NOT_FOUND", "Tenant was not found.", 404);
      }

      const body = parseJsonBody(event?.body);
      const days = Number(body.days || 14);
      const currentEnd = tenant.trialEndsAt || tenant.planEndsAt || tenant.subscriptionEndDate || getNowIso().slice(0, 10);
      const nextEnd = addDays(currentEnd, Number.isFinite(days) && days > 0 ? days : 14);
      const selectedPlan = plansByCode.get("trial") || DEFAULT_PLANS.find((plan) => plan.planCode === "trial") || DEFAULT_PLANS[1];
      const updatedTenant = normalizeTenantLifecycle({
        ...tenant,
        planCode: "trial",
        planLabel: selectedPlan.label,
        subscriptionStatus: "trialing",
        planStatus: "trialing",
        trialStartedAt: tenant.trialStartedAt || tenant.planStartedAt || tenant.subscriptionStartDate || getNowIso().slice(0, 10),
        trialEndsAt: nextEnd,
        planEndsAt: nextEnd,
        updatedAt: getNowIso()
      }, selectedPlan);

      const result = await saveTenantWithAudit(
        updatedTenant,
        plansByCode,
        [
          buildAuditEntry({
            orgId,
            actionType: "extend_trial",
            actionLabel: "Extended trial",
            actorEmail: body.actorEmail,
            reason: body.reason || `Extended trial by ${days || 14} days.`,
            summary: `Extended trial until ${nextEnd}.`,
            before: buildTenantDetail(tenant, plansByCode),
            after: buildTenantDetail(updatedTenant, plansByCode)
          })
        ]
      );

      await notifyStatusChangeIfNeeded(buildTenantDetail(tenant, plansByCode), result.tenant);

      return jsonResponse(200, success({
        ...result,
        message: `Trial extended to ${nextEnd}.`
      }));
    }

    if (method === "POST" && parts.length === 4 && parts[0] === "admin" && parts[1] === "tenants" && (parts[3] === "block" || parts[3] === "unblock" || parts[3] === "suspend" || parts[3] === "reactivate")) {
      const orgId = normalizeOrgId(parts[2]);
      const tenant = await getItemByKey(TENANT_TABLE, "orgId", orgId);
      if (!tenant) {
        return failure("TENANT_NOT_FOUND", "Tenant was not found.", 404);
      }

      const body = parseJsonBody(event?.body);
      const isBlockAction = ["block", "suspend"].includes(parts[3]);
      const nextStatus = isBlockAction ? "blocked" : "active";
      const selectedPlan = plansByCode.get(normalizePlanCode(tenant.planCode, tenant)) || DEFAULT_PLANS[1];
      const updatedTenant = normalizeTenantLifecycle({
        ...tenant,
        status: nextStatus,
        alertType: null,
        isActive: nextStatus !== "blocked",
        updatedAt: getNowIso()
      }, selectedPlan);

      const result = await saveTenantWithAudit(
        updatedTenant,
        plansByCode,
        [
          buildAuditEntry({
            orgId,
            actionType: isBlockAction ? "block_customer" : "unblock_customer",
            actionLabel: isBlockAction ? "Blocked customer" : "Unblocked customer",
            actorEmail: body.actorEmail,
            reason: body.reason || `${isBlockAction ? "Block" : "Unblock"} was triggered from the Admin Control App.`,
            summary: `${isBlockAction ? "Blocked" : "Unblocked"} ${tenant.companyName}.`,
            before: buildTenantDetail(tenant, plansByCode),
            after: buildTenantDetail(updatedTenant, plansByCode)
          })
        ]
      );

      await notifyStatusChangeIfNeeded(buildTenantDetail(tenant, plansByCode), result.tenant);

      return jsonResponse(200, success({
        ...result,
        message: isBlockAction ? "Customer blocked." : "Customer unblocked."
      }));
    }

    if (method === "POST" && parts.length === 4 && parts[0] === "admin" && parts[1] === "tenants" && parts[3] === "resend-setup") {
      const orgId = normalizeOrgId(parts[2]);
      const tenant = await getItemByKey(TENANT_TABLE, "orgId", orgId);
      if (!tenant) {
        return failure("TENANT_NOT_FOUND", "Tenant was not found.", 404);
      }

      const body = parseJsonBody(event?.body);
      const auditEntries = await recordAuditEntries([
        buildAuditEntry({
          orgId,
          actionType: "resend_setup",
          actionLabel: "Resent setup instructions",
          actorEmail: body.actorEmail,
          reason: body.reason || "Setup instructions were resent from the Admin Control App.",
          summary: `Resent setup instructions to ${tenant.adminEmail || tenant.companyName}.`
        })
      ]);

      return jsonResponse(200, success({
        tenant: buildTenantDetail(tenant, plansByCode),
        auditEntries,
        message: "Setup instructions were logged as resent."
      }));
    }

    if (method === "POST" && parts.length === 4 && parts[0] === "admin" && parts[1] === "tenants" && parts[3] === "regenerate-secret") {
      const orgId = normalizeOrgId(parts[2]);
      const tenant = await getItemByKey(TENANT_TABLE, "orgId", orgId);
      if (!tenant) {
        return failure("TENANT_NOT_FOUND", "Tenant was not found.", 404);
      }

      const body = parseJsonBody(event?.body);
      const updatedTenant = {
        ...tenant,
        tenantSecretStatus: "rotation_requested",
        updatedAt: getNowIso()
      };

      const result = await saveTenantWithAudit(
        updatedTenant,
        plansByCode,
        [
          buildAuditEntry({
            orgId,
            actionType: "regenerate_secret",
            actionLabel: "Requested tenant secret regeneration",
            actorEmail: body.actorEmail,
            reason: body.reason || "Requested a new tenant secret from the Admin Control App.",
            summary: `Secret rotation requested for ${tenant.companyName}.`,
            before: buildTenantDetail(tenant, plansByCode),
            after: buildTenantDetail(updatedTenant, plansByCode)
          })
        ],
        [
          buildSupportEntry({
            orgId,
            severity: "watch",
            message: "Tenant secret regeneration was requested. Follow up with delivery and verification steps.",
            createdBy: body.actorEmail
          })
        ]
      );

      return jsonResponse(200, success({
        ...result,
        message: "Tenant secret regeneration request was recorded."
      }));
    }

    if (method === "POST" && parts.length === 4 && parts[0] === "admin" && parts[1] === "tenants" && parts[3] === "support-note") {
      const orgId = normalizeOrgId(parts[2]);
      const tenant = await getItemByKey(TENANT_TABLE, "orgId", orgId);
      if (!tenant) {
        return failure("TENANT_NOT_FOUND", "Tenant was not found.", 404);
      }

      const body = parseJsonBody(event?.body);
      const supportEntry = buildSupportEntry({
        orgId,
        severity: body.severity,
        message: normalizeOptionalString(body.message) || "",
        createdBy: body.createdBy || body.actorEmail
      });
      const supportEntries = await recordSupportEntries([supportEntry]);
      const auditEntries = await recordAuditEntries([
        buildAuditEntry({
          orgId,
          actionType: "support_note",
          actionLabel: "Added support note",
          actorEmail: body.createdBy || body.actorEmail,
          reason: supportEntry.message,
          summary: `Added a ${supportEntry.severity} support note for ${tenant.companyName}.`
        })
      ]);

      return jsonResponse(200, success({
        supportEntries,
        auditEntries,
        tenant: buildTenantDetail(tenant, plansByCode),
        message: "Support note saved."
      }));
    }

    return failure("NOT_FOUND", "Route was not found.", 404);
  } catch (error) {
    return failure(
      error.code || (error.statusCode === 401 ? "UNAUTHORIZED" : "INTERNAL_ERROR"),
      error.message || "Unexpected admin API error.",
      error.statusCode || 500
    );
  }
};
