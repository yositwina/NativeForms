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
  enableProRecordsListRowSignaturePdf: {
    label: "Records List Row Signature + PDF",
    description: "Require signatures on repeated rows and include them in the submitted PDF."
  },
  enableProSurveyFields: {
    label: "Survey Fields",
    description: "Add rating, NPS, Likert, ranking, and satisfaction fields to Pro forms."
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

function getFeatureMetadata(settings = state.settings) {
  const featureMetadata = { ...FEATURE_FLAG_METADATA };
  const incoming = settings?.featureMetadata || {};

  for (const key of Object.keys(featureMetadata)) {
    featureMetadata[key] = {
      label: incoming?.[key]?.label || featureMetadata[key].label,
      description: incoming?.[key]?.description || featureMetadata[key].description
    };
  }

  return featureMetadata;
}

function getFeatureFlagLabels(plan = null, settings = state.settings) {
  const metadata = getFeatureMetadata(settings);
  return Object.fromEntries(
    Object.entries(metadata).map(([key, value]) => [key, value.label])
  );
}

function buildFeatureFlags(enabledKeys) {
  return Object.fromEntries(
    Object.keys(FEATURE_FLAG_METADATA).map((key) => [key, enabledKeys.includes(key)])
  );
}

function getPlanSortOrder(planCode) {
  return {
    free: 1,
    trial: 2,
    starter: 3,
    pro: 4
  }[String(planCode || "").toLowerCase()] || 99;
}

function sortPlans(plans) {
  return [...plans].sort((a, b) => {
    const sortA = a?.sortOrder ?? getPlanSortOrder(a?.planCode);
    const sortB = b?.sortOrder ?? getPlanSortOrder(b?.planCode);

    if (sortA !== sortB) {
      return sortA - sortB;
    }

    return String(a?.label || "").localeCompare(String(b?.label || ""));
  });
}

const adminFeatureListPrimary = [
  {
    title: "Status alert recipient persistence",
    detail: "Finish saving the status-change alert email from Settings into a dedicated admin settings store instead of using only the default fallback.",
    phase: "Now"
  },
  {
    title: "Automatic Active / Alert recompute",
    detail: "Keep customer status updated from end-date and submission-limit rules in the Admin backend while preserving manual Blocked as the only service-deny state.",
    phase: "Now"
  },
  {
    title: "Status change notification email",
    detail: "Send an email with customer name, org id, admin email, previous status, new status, and reason whenever status changes.",
    phase: "Now"
  },
  {
    title: "Block and unblock audit hardening",
    detail: "Continue validating that every manual Block / Unblock action is captured cleanly in the audit trail with reason and actor.",
    phase: "Now"
  },
  {
    title: "Full enforcement testing",
    detail: "Test Active, Alert, and Blocked behavior end to end against Prefill, Submit, and the Admin Control screens.",
    phase: "Now"
  },
  {
    title: "Connection health actions",
    detail: "Finish the customer connection workflow items from the spec: refresh or recheck connection health, surface recent connection failures, and expose clearer resend setup actions from one operational view.",
    phase: "Now"
  },
  {
    title: "Support timeline hardening",
    detail: "Complete the dedicated support flow with cleaner note history, support-event visibility, and faster support triage around setup and connection issues.",
    phase: "Now"
  },
  {
    title: "Usage tab and daily usage feed",
    detail: "Add the documented usage view with recent usage trend, anomalies, and the usage-daily API data so customer limits can be understood without digging into raw records.",
    phase: "Now"
  }
];

const adminFeatureListSecondary = [
  {
    title: "Additional alert rules",
    detail: "Add optional alert types later for setup issues, OAuth disconnect, tenant auth health, and other non-blocking customer-risk signals."
  },
  {
    title: "Multiple notification recipients",
    detail: "Support more than one admin email recipient for status-change notifications and maybe per-environment recipients."
  },
  {
    title: "Customer history summary",
    detail: "Show a compact timeline of plan changes, alerts, blocks, and major support actions in one combined history view."
  },
  {
    title: "Usage counters and limit visuals",
    detail: "Make customer usage limits more visible with clearer warning thresholds and monthly trend summaries."
  },
  {
    title: "Operational dashboards",
    detail: "Expand overview cards and lists once the support, audit, and status data has been proven stable in testing."
  },
  {
    title: "Cognito login and protected admin access",
    detail: "Replace the current dev-style open access with the planned Cognito hosted login and protected AWS admin flow."
  },
  {
    title: "API Gateway and Cognito authorizer",
    detail: "Move the Admin Control API from the public Lambda URL pattern to the documented API Gateway plus Cognito authorizer setup."
  },
  {
    title: "Role-based admin groups",
    detail: "Introduce the planned admin roles so support, product, and read-only users do not all share the same powers inside the control console."
  },
  {
    title: "Commercial and lifecycle guardrails",
    detail: "Add stronger confirmation, reason capture, and action guardrails for plan changes, suspend or reactivate flows, and other high-impact customer operations."
  },
  {
    title: "Connection tab and setup diagnostics",
    detail: "Build the fuller connection screen from the plan with OAuth state, login base URL, last successful check, recent failures, and cleaner setup diagnostics."
  }
];

const state = {
  view: "overview",
  search: "",
  status: "",
  planCode: "",
  setupState: "",
  healthStatus: "",
  sortKey: "",
  sortDirection: "asc",
  selectedOrgId: null,
  selectedPlanCode: "free",
  tenants: [],
  tenantDetailsById: new Map(),
  plans: [],
  splitLeftWidth: null,
  planStorageMode: "fallback",
  overview: null,
  auditLog: [],
  supportByOrgId: new Map(),
  auditByOrgId: new Map(),
  settings: {
    statusAlertEmailRecipient: "yosi@harmony-it.co.il",
    statusRecomputeTimeUtc: "02:00",
    featureMetadata: getFeatureMetadata({ featureMetadata: FEATURE_FLAG_METADATA }),
    source: "default"
  },
  apiHealth: {
    status: "unknown",
    message: "Health check has not run yet."
  },
  isLoading: true,
  dataMode: "live",
  requestedDataMode: "live",
  isSavingPlan: false,
  isSavingTenant: false,
  busyActionKey: "",
  errorMessage: "",
  successMessage: ""
};

const config = window.NativeFormsAdminConfig || {};
const apiBaseUrl = String(config.apiBaseUrl || "").replace(/\/+$/, "");
const authConfig = config.auth || {};

const authState = {
  enabled: authConfig.enabled === true,
  accessToken: "",
  idToken: "",
  claims: null,
  email: ""
};

const refs = {
  tenantTableBody: document.getElementById("tenantTableBody"),
  tenantsLayout: document.getElementById("tenantsLayout"),
  tenantsSplitter: document.getElementById("tenantsSplitter"),
  tenantDetail: document.getElementById("tenantDetail"),
  emptyState: document.getElementById("emptyState"),
  tenantCount: document.getElementById("tenantCount"),
  attentionCount: document.getElementById("attentionCount"),
  trialCount: document.getElementById("trialCount"),
  heroCopy: document.querySelector(".hero__copy"),
  dataModeHelper: document.getElementById("dataModeHelper"),
  planNotice: document.getElementById("planNotice"),
  planList: document.getElementById("planList"),
  planEditor: document.getElementById("planEditor"),
  navButtons: Array.from(document.querySelectorAll(".nav__item[data-view]")),
  workspaceTitle: document.getElementById("workspaceTitle"),
  heroEyebrow: document.getElementById("heroEyebrow"),
  heroTitle: document.getElementById("heroTitle"),
  overviewSection: document.getElementById("overviewSection"),
  tenantsPanel: document.getElementById("tenantsPanel"),
  plansPanel: document.getElementById("plansPanel"),
  plansSection: document.getElementById("plansSection"),
  auditSection: document.getElementById("auditSection"),
  featureListSection: document.getElementById("featureListSection"),
  settingsSection: document.getElementById("settingsSection"),
  overviewSummary: document.getElementById("overviewSummary"),
  overviewSetupIssues: document.getElementById("overviewSetupIssues"),
  overviewExpiringTrials: document.getElementById("overviewExpiringTrials"),
  overviewSupportNotes: document.getElementById("overviewSupportNotes"),
  overviewAdminActions: document.getElementById("overviewAdminActions"),
  featureListPrimary: document.getElementById("featureListPrimary"),
  featureListSecondary: document.getElementById("featureListSecondary"),
  auditLogList: document.getElementById("auditLogList"),
  settingsApiUrl: document.getElementById("settingsApiUrl"),
  settingsActiveMode: document.getElementById("settingsActiveMode"),
  settingsPlanStorage: document.getElementById("settingsPlanStorage"),
  settingsStatusAlertEmail: document.getElementById("settingsStatusAlertEmail"),
  settingsRecomputeTime: document.getElementById("settingsRecomputeTime"),
  settingsSource: document.getElementById("settingsSource"),
  settingsFeatureMetadata: document.getElementById("settingsFeatureMetadata"),
  refreshDataButton: document.getElementById("refreshDataButton"),
  signedInUser: document.getElementById("signedInUser"),
  logoutButton: document.getElementById("logoutButton")
};

function getSavedSplitWidth() {
  try {
    const raw = window.localStorage.getItem("nativeforms-admin-split-left-width");
    const value = Number(raw);
    return Number.isFinite(value) ? value : null;
  } catch (error) {
    return null;
  }
}

function saveSplitWidth(value) {
  try {
    window.localStorage.setItem("nativeforms-admin-split-left-width", String(value));
  } catch (error) {
    // Best effort only.
  }
}

function encodeBase64Url(bytes) {
  const binary = Array.from(bytes, (byte) => String.fromCharCode(byte)).join("");
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function decodeJwtClaims(token) {
  try {
    const payload = String(token || "").split(".")[1];
    if (!payload) {
      return null;
    }

    const normalized = payload.replaceAll("-", "+").replaceAll("_", "/");
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
    return JSON.parse(atob(padded));
  } catch (error) {
    return null;
  }
}

async function sha256Base64Url(value) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return encodeBase64Url(new Uint8Array(digest));
}

function randomBase64Url(byteLength = 32) {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  return encodeBase64Url(bytes);
}

function authStorageKey(name) {
  return `twinaforms-admin-auth-${name}`;
}

function getAuthDomain() {
  return String(authConfig.domain || "").replace(/\/+$/, "");
}

function getRedirectUri() {
  return authConfig.redirectUri || window.location.origin + window.location.pathname;
}

function getLogoutUri() {
  return authConfig.logoutUri || getRedirectUri();
}

function getAuthScopes() {
  return Array.isArray(authConfig.scopes) && authConfig.scopes.length
    ? authConfig.scopes
    : ["openid", "email", "profile"];
}

function clearAuthTokens() {
  window.localStorage.removeItem(authStorageKey("access-token"));
  window.localStorage.removeItem(authStorageKey("id-token"));
  window.sessionStorage.removeItem(authStorageKey("code-verifier"));
  window.sessionStorage.removeItem(authStorageKey("state"));
}

async function redirectToLogin() {
  const domain = getAuthDomain();
  if (!domain || !authConfig.clientId) {
    state.errorMessage = "Admin login is enabled but Cognito is not configured.";
    render();
    return;
  }

  const verifier = randomBase64Url(48);
  const challenge = await sha256Base64Url(verifier);
  const stateValue = randomBase64Url(24);
  window.sessionStorage.setItem(authStorageKey("code-verifier"), verifier);
  window.sessionStorage.setItem(authStorageKey("state"), stateValue);

  const params = new URLSearchParams({
    client_id: authConfig.clientId,
    response_type: "code",
    scope: getAuthScopes().join(" "),
    redirect_uri: getRedirectUri(),
    code_challenge_method: "S256",
    code_challenge: challenge,
    state: stateValue
  });

  window.location.assign(`${domain}/oauth2/authorize?${params.toString()}`);
}

async function exchangeAuthCode(code) {
  const verifier = window.sessionStorage.getItem(authStorageKey("code-verifier"));
  if (!verifier) {
    throw new Error("The login session expired. Please sign in again.");
  }

  const response = await fetch(`${getAuthDomain()}/oauth2/token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      client_id: authConfig.clientId,
      redirect_uri: getRedirectUri(),
      code,
      code_verifier: verifier
    })
  });
  const payload = await response.json();

  if (!response.ok || !payload.access_token) {
    throw new Error(payload.error_description || payload.error || "Cognito login did not return an access token.");
  }

  window.localStorage.setItem(authStorageKey("access-token"), payload.access_token);
  if (payload.id_token) {
    window.localStorage.setItem(authStorageKey("id-token"), payload.id_token);
  }
  window.sessionStorage.removeItem(authStorageKey("code-verifier"));
  window.sessionStorage.removeItem(authStorageKey("state"));
}

async function initializeAuth() {
  if (!authState.enabled) {
    return true;
  }

  const url = new URL(window.location.href);
  const code = url.searchParams.get("code");
  const incomingState = url.searchParams.get("state");
  const expectedState = window.sessionStorage.getItem(authStorageKey("state"));
  const error = url.searchParams.get("error");

  if (error) {
    clearAuthTokens();
    state.errorMessage = `Admin login failed. ${url.searchParams.get("error_description") || error}`;
    window.history.replaceState({}, document.title, getRedirectUri());
    return false;
  }

  if (code) {
    if (!expectedState || incomingState !== expectedState) {
      clearAuthTokens();
      state.errorMessage = "Admin login could not be verified. Please sign in again.";
      window.history.replaceState({}, document.title, getRedirectUri());
      return false;
    }

    await exchangeAuthCode(code);
    window.history.replaceState({}, document.title, getRedirectUri());
  }

  authState.accessToken = window.localStorage.getItem(authStorageKey("access-token")) || "";
  authState.idToken = window.localStorage.getItem(authStorageKey("id-token")) || "";
  authState.claims = decodeJwtClaims(authState.idToken) || decodeJwtClaims(authState.accessToken);
  authState.email = authState.claims?.email || authState.claims?.username || authState.claims?.sub || "";

  if (!authState.accessToken) {
    await redirectToLogin();
    return false;
  }

  return true;
}

function logoutAdmin() {
  clearAuthTokens();
  const domain = getAuthDomain();
  if (!authState.enabled || !domain || !authConfig.clientId) {
    window.location.assign(getLogoutUri());
    return;
  }

  const params = new URLSearchParams({
    client_id: authConfig.clientId,
    logout_uri: getLogoutUri()
  });
  window.location.assign(`${domain}/logout?${params.toString()}`);
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll("\"", "&quot;")
    .replaceAll("'", "&#39;");
}

function parseNullableNumber(value) {
  const normalized = String(value ?? "").trim();
  if (!normalized) {
    return null;
  }

  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : null;
}

function labelize(value) {
  return String(value || "")
    .replaceAll("_", " ")
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

function formatLimit(value) {
  return value == null ? "Unlimited" : String(value);
}

function formatRelative(isoValue) {
  if (!isoValue) {
    return "No recent activity";
  }

  const date = new Date(isoValue);
  const diffMs = Date.now() - date.getTime();
  const diffHours = Math.max(0, Math.round(diffMs / (1000 * 60 * 60)));
  if (diffHours < 24) {
    return `${diffHours}h ago`;
  }

  return `${Math.round(diffHours / 24)}d ago`;
}

function formatDate(value) {
  if (!value) {
    return "Not set";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return String(value);
  }

  return date.toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric"
  });
}

function formatDateInput(value) {
  return value ? String(value).slice(0, 10) : "";
}

function countEnabledFeatures(featureFlags) {
  return Object.values(featureFlags || {}).filter(Boolean).length;
}

function getStatusChipClass(value) {
  return `status-chip status-chip--${String(value || "").toLowerCase()}`;
}

function formatAlertType(value) {
  if (!value) {
    return "No active alert";
  }

  return labelize(String(value).replaceAll("_", " "));
}

function getFilteredTenants() {
  const filtered = state.tenants.filter((tenant) => {
    const matchesSearch = !state.search || [
      tenant.companyName,
      tenant.adminEmail,
      tenant.orgId
    ].some((value) => String(value || "").toLowerCase().includes(state.search));

    return matchesSearch
      && (!state.status || tenant.status === state.status)
      && (!state.planCode || tenant.planCode === state.planCode)
      && (!state.setupState || tenant.setupState === state.setupState)
      && (!state.healthStatus || tenant.healthStatus === state.healthStatus);
  });

  return sortTenants(filtered);
}

function sortTenants(items) {
  if (!state.sortKey) {
    return items;
  }

  const direction = state.sortDirection === "desc" ? -1 : 1;
  const compare = (a, b) => {
    if (state.sortKey === "companyName") {
      const va = String(a.companyName || "").toLowerCase();
      const vb = String(b.companyName || "").toLowerCase();
      if (va === vb) return 0;
      return va < vb ? -1 * direction : 1 * direction;
    }
    if (state.sortKey === "lastActivityAt") {
      const ta = a.lastActivityAt ? Date.parse(a.lastActivityAt) : 0;
      const tb = b.lastActivityAt ? Date.parse(b.lastActivityAt) : 0;
      if (ta === tb) return 0;
      return ta < tb ? -1 * direction : 1 * direction;
    }
    if (state.sortKey === "startedAt") {
      const sa = a.planStartedAt || a.trialStartedAt;
      const sb = b.planStartedAt || b.trialStartedAt;
      const ta = sa ? Date.parse(sa) : 0;
      const tb = sb ? Date.parse(sb) : 0;
      if (ta === tb) return 0;
      return ta < tb ? -1 * direction : 1 * direction;
    }
    return 0;
  };

  return [...items].sort(compare);
}

function handleSortClick(sortKey) {
  if (state.sortKey === sortKey) {
    state.sortDirection = state.sortDirection === "asc" ? "desc" : "asc";
  } else {
    state.sortKey = sortKey;
    state.sortDirection = (sortKey === "lastActivityAt" || sortKey === "startedAt") ? "desc" : "asc";
  }
  render();
}

function updateSortIndicators() {
  const headers = document.querySelectorAll(".tenant-table th[data-sort-key]");
  headers.forEach((th) => {
    const key = th.dataset.sortKey;
    const indicator = th.querySelector(".sort-indicator");
    const isActive = state.sortKey === key;
    th.classList.toggle("is-sorted-active", isActive);
    if (indicator) {
      indicator.textContent = isActive
        ? (state.sortDirection === "desc" ? "▾" : "▴")
        : "▴▾";
    }
  });
}

function getSelectedPlan() {
  return state.plans.find((plan) => plan.planCode === state.selectedPlanCode) || state.plans[0] || null;
}

function getSelectedTenant(items = state.tenants) {
  const summary = items.find((tenant) => tenant.orgId === state.selectedOrgId) || items[0] || null;
  if (!summary) {
    return null;
  }

  state.selectedOrgId = summary.orgId;
  return state.tenantDetailsById.get(summary.orgId) || summary;
}

async function parseApiResponse(response, path) {
  const rawText = await response.text();
  let payload = null;

  if (rawText) {
    try {
      payload = JSON.parse(rawText);
    } catch (error) {
      const preview = rawText.replace(/\s+/g, " ").slice(0, 180);
      throw new Error(`The Admin API returned invalid JSON for ${path} (${response.status}). ${preview}`);
    }
  }

  if (!response.ok || payload?.success !== true) {
    throw new Error(payload?.error?.message || `The Admin API request failed for ${path} (${response.status}).`);
  }

  return payload.data;
}

async function fetchJson(path) {
  const headers = {
    "Content-Type": "application/json"
  };
  if (authState.accessToken) {
    headers.Authorization = `Bearer ${authState.accessToken}`;
  }

  const response = await fetch(`${apiBaseUrl}${path}`, {
    headers
  });
  return parseApiResponse(response, path);
}

async function postJson(path, body) {
  const headers = {
    "Content-Type": "application/json"
  };
  if (authState.accessToken) {
    headers.Authorization = `Bearer ${authState.accessToken}`;
  }

  const response = await fetch(`${apiBaseUrl}${path}`, {
    method: "POST",
    headers,
    body: JSON.stringify(body)
  });
  return parseApiResponse(response, path);
}

async function loadTenantsFromApi() {
  const data = await fetchJson("/admin/tenants");
  return data.items || [];
}

async function loadTenantDetailFromApi(orgId) {
  const data = await fetchJson(`/admin/tenants/${encodeURIComponent(orgId)}`);
  return data.tenant || null;
}

async function loadPlansFromApi() {
  const data = await fetchJson("/admin/plans");
  return {
    items: data.items || [],
    storageMode: data.storageMode || "fallback"
  };
}

async function loadOverviewFromApi() {
  return fetchJson("/admin/overview");
}

async function loadSettingsFromApi() {
  const data = await fetchJson("/admin/settings");
  return data.settings || null;
}

async function loadHealthFromApi() {
  return fetchJson("/admin/health");
}

async function loadAuditLogFromApi() {
  const data = await fetchJson("/admin/audit");
  return data.items || [];
}

async function loadTenantAuditFromApi(orgId) {
  const data = await fetchJson(`/admin/tenants/${encodeURIComponent(orgId)}/audit`);
  return data.items || [];
}

async function loadTenantSupportFromApi(orgId) {
  const data = await fetchJson(`/admin/tenants/${encodeURIComponent(orgId)}/support`);
  return data.items || [];
}

async function loadInitialData() {
  state.isLoading = true;
  state.errorMessage = "";
  state.successMessage = "";
  state.overview = null;
  state.auditLog = [];
  state.supportByOrgId.clear();
  state.auditByOrgId.clear();

  if (!apiBaseUrl) {
    state.tenants = [];
    state.plans = [];
    state.planStorageMode = "unavailable";
    state.dataMode = "live";
    state.overview = null;
    state.errorMessage = "The Admin API URL is not configured, so live admin data cannot be loaded.";
    state.isLoading = false;
    render();
    return;
  }

  try {
    const [tenants, plansPayload, overview, settings, health] = await Promise.all([
      loadTenantsFromApi(),
      loadPlansFromApi(),
      loadOverviewFromApi().catch(() => null),
      loadSettingsFromApi().catch(() => null),
      loadHealthFromApi().catch(() => null)
    ]);
    state.tenants = tenants;
    state.plans = sortPlans(plansPayload.items);
    state.planStorageMode = plansPayload.storageMode;
    state.overview = overview;
    state.settings = settings || state.settings;
    state.apiHealth = health || state.apiHealth;
    state.dataMode = "live";
  } catch (error) {
    state.tenants = [];
    state.plans = [];
    state.planStorageMode = "unavailable";
    state.overview = null;
    state.dataMode = "live";
    state.errorMessage = `The live Admin API could not be loaded. ${error.message}`;
  } finally {
    state.isLoading = false;
    state.selectedOrgId = state.selectedOrgId || state.tenants[0]?.orgId || null;
    state.selectedPlanCode = state.selectedPlanCode || state.plans[0]?.planCode || "free";
    render();
  }
}

async function ensureOverview() {
  if (!apiBaseUrl || state.overview) {
    return;
  }

  try {
    state.overview = await loadOverviewFromApi();
    render();
  } catch (error) {
    state.errorMessage = `Overview could not be loaded from the live API. ${error.message}`;
    render();
  }
}

async function ensureAuditLog() {
  if (!apiBaseUrl || state.auditLog.length) {
    return;
  }

  try {
    state.auditLog = await loadAuditLogFromApi();
    render();
  } catch (error) {
    state.errorMessage = `Audit log could not be loaded from the live API. ${error.message}`;
    render();
  }
}

async function ensureTenantData(orgId) {
  if (!orgId) {
    return;
  }

  if (!apiBaseUrl) {
    return;
  }

  try {
    const jobs = [];

    if (!state.tenantDetailsById.has(orgId)) {
      jobs.push(loadTenantDetailFromApi(orgId).then((tenant) => {
        if (tenant) {
          state.tenantDetailsById.set(orgId, tenant);
        }
      }));
    }

    if (!state.supportByOrgId.has(orgId)) {
      jobs.push(loadTenantSupportFromApi(orgId).then((items) => {
        state.supportByOrgId.set(orgId, items);
      }));
    }

    if (!state.auditByOrgId.has(orgId)) {
      jobs.push(loadTenantAuditFromApi(orgId).then((items) => {
        state.auditByOrgId.set(orgId, items);
      }));
    }

    if (jobs.length) {
      await Promise.all(jobs);
      render();
    }
  } catch (error) {
    state.errorMessage = `Customer activity could not be loaded from the live API. ${error.message}`;
    render();
  }
}

function updateTenantInState(tenant) {
  state.tenantDetailsById.set(tenant.orgId, tenant);
  state.tenants = state.tenants.map((item) => item.orgId === tenant.orgId ? {
    orgId: tenant.orgId,
    companyName: tenant.companyName,
    adminEmail: tenant.adminEmail,
    planCode: tenant.planCode,
    planLabel: tenant.planLabel,
    status: tenant.status,
    alertType: tenant.alertType,
    subscriptionStatus: tenant.subscriptionStatus,
    supportStatus: tenant.supportStatus,
    setupState: tenant.setupState,
    healthStatus: tenant.healthStatus,
    lastActivityAt: tenant.lastActivityAt,
    submissionsMonth: tenant.submissionsMonth,
    activeFormsCount: tenant.activeFormsCount
  } : item);
}

function prependAuditEntries(orgId, entries) {
  if (!entries?.length) {
    return;
  }

  const existingByTenant = state.auditByOrgId.get(orgId) || [];
  state.auditByOrgId.set(orgId, [...entries, ...existingByTenant]);
  state.auditLog = [...entries, ...state.auditLog];
}

function prependSupportEntries(orgId, entries) {
  if (!entries?.length) {
    return;
  }

  const existing = state.supportByOrgId.get(orgId) || [];
  state.supportByOrgId.set(orgId, [...entries, ...existing]);
}

function removeTenantFromState(orgId) {
  state.tenants = state.tenants.filter((tenant) => tenant.orgId !== orgId);
  state.tenantDetailsById.delete(orgId);
  state.supportByOrgId.delete(orgId);
  state.auditByOrgId.delete(orgId);
  state.selectedOrgId = state.tenants[0]?.orgId || null;
}

async function saveTenantProfile(form) {
  const formData = new FormData(form);
  const payload = {
    companyName: String(formData.get("companyName") || "").trim(),
    adminEmail: String(formData.get("adminEmail") || "").trim(),
    planCode: String(formData.get("planCode") || "trial"),
    subscriptionStatus: String(formData.get("subscriptionStatus") || "active"),
    planStartedAt: String(formData.get("planStartedAt") || "").trim() || null,
    planEndsAt: String(formData.get("planEndsAt") || "").trim() || null,
    trialStartedAt: String(formData.get("trialStartedAt") || "").trim() || null,
    trialEndsAt: String(formData.get("trialEndsAt") || "").trim() || null,
    supportStatus: String(formData.get("supportStatus") || "normal"),
    internalNotes: String(formData.get("internalNotes") || ""),
    supportFlags: {
      enableSalesforceAdminApp: formData.get("enableSalesforceAdminApp") === "on"
    }
  };

  state.isSavingTenant = true;
  render();

  try {
    const data = await postJson(`/admin/tenants/${encodeURIComponent(formData.get("orgId"))}/profile`, payload);
    updateTenantInState(data.tenant);
    prependAuditEntries(data.tenant.orgId, data.auditEntries || []);
    state.successMessage = `Saved customer ${data.tenant.companyName}.`;
    state.errorMessage = "";
    state.overview = null;
    await ensureOverview();
  } catch (error) {
    state.successMessage = "";
    state.errorMessage = `Customer save failed. ${error.message}`;
  } finally {
    state.isSavingTenant = false;
  }

  render();
}

async function savePlan(form) {
  const formData = new FormData(form);
  const selectedPlan = getSelectedPlan();
  const featureMetadata = getFeatureMetadata();
  const featureFlagLabels = getFeatureFlagLabels(selectedPlan);
  const payload = {
    label: String(formData.get("label") || "").trim(),
    description: String(formData.get("description") || "").trim(),
    isActive: formData.get("isActive") === "on",
    durationType: String(formData.get("durationType") || "forever"),
    durationDays: parseNullableNumber(formData.get("durationDays")),
    limits: {
      maxSfUsers: parseNullableNumber(formData.get("maxSfUsers")),
      maxForms: parseNullableNumber(formData.get("maxForms")),
      maxSubmissionsPerMonth: parseNullableNumber(formData.get("maxSubmissionsPerMonth")),
      submissionLogRetentionDays: parseNullableNumber(formData.get("submissionLogRetentionDays"))
    },
    featureLabels: Object.fromEntries(
      Object.entries(featureMetadata).map(([key, value]) => [key, value.label])
    ),
    featureFlags: Object.fromEntries(
      Object.keys(featureFlagLabels).map((key) => [key, formData.get(key) === "on"])
    )
  };

  state.isSavingPlan = true;
  render();

  try {
    const data = await postJson(`/admin/plans/${encodeURIComponent(formData.get("planCode"))}`, payload);
    state.successMessage = `Saved plan ${data.plan.label}.`;
    state.errorMessage = "";
    state.planStorageMode = data.storageMode || "dynamodb";
    prependAuditEntries("GLOBAL", data.auditEntries || []);
    const refreshed = await loadPlansFromApi();
    state.plans = sortPlans(refreshed.items);
    state.planStorageMode = refreshed.storageMode;
    state.overview = null;
    await ensureOverview();
  } catch (error) {
    state.successMessage = "";
    state.errorMessage = `Plan save failed. ${error.message}`;
  } finally {
    state.isSavingPlan = false;
  }

  render();
}

async function runTenantAction(orgId, action, body) {
  state.busyActionKey = `${orgId}:${action}`;
  state.successMessage = "";
  state.errorMessage = "";
  render();

  try {
    const data = await postJson(`/admin/tenants/${encodeURIComponent(orgId)}/${action}`, body);
    if (data.tenant) {
      updateTenantInState(data.tenant);
    }
    prependAuditEntries(orgId, data.auditEntries || []);
    prependSupportEntries(orgId, data.supportEntries || []);
    state.successMessage = data.message || `${labelize(action)} completed.`;
    state.overview = null;
    await Promise.all([ensureOverview(), ensureAuditLog()]);
  } catch (error) {
    state.errorMessage = `${labelize(action)} failed. ${error.message}`;
  } finally {
    state.busyActionKey = "";
  }

  render();
}

async function deleteTenantRecord(selectedTenant) {
  const orgId = selectedTenant?.orgId;
  if (!orgId) {
    return;
  }

  const firstConfirm = window.confirm(
    `Delete ${selectedTenant.companyName || orgId} from the tenant DynamoDB table?\n\nThis does not delete Secrets Manager.`
  );
  if (!firstConfirm) {
    return;
  }

  const typedOrgId = window.prompt(
    `This is destructive. Type the org id to delete this tenant record:\n${orgId}`
  );
  if (typedOrgId !== orgId) {
    state.errorMessage = "Delete canceled. The typed org id did not match.";
    state.successMessage = "";
    render();
    return;
  }

  state.busyActionKey = `${orgId}:delete-tenant`;
  state.successMessage = "";
  state.errorMessage = "";
  render();

  try {
    const data = await postJson(`/admin/tenants/${encodeURIComponent(orgId)}/delete-tenant`, {
      actorEmail: "admin@nativeforms.internal",
      reason: "Deleted tenant DynamoDB record from the Admin Console after double confirmation."
    });
    removeTenantFromState(orgId);
    prependAuditEntries(orgId, data.auditEntries || []);
    state.successMessage = data.message || "Tenant DynamoDB record deleted. Secrets Manager was not changed.";
    state.overview = null;
    await Promise.all([
      ensureOverview(),
      ensureAuditLog(),
      state.selectedOrgId ? ensureTenantData(state.selectedOrgId) : Promise.resolve()
    ]);
  } catch (error) {
    state.errorMessage = `Delete tenant failed. ${error.message}`;
  } finally {
    state.busyActionKey = "";
  }

  render();
}

async function saveSupportNote(form) {
  const formData = new FormData(form);
  const orgId = String(formData.get("orgId") || "");

  state.busyActionKey = `${orgId}:support-note`;
  render();

  try {
    const data = await postJson(`/admin/tenants/${encodeURIComponent(orgId)}/support-note`, {
      message: String(formData.get("message") || "").trim(),
      severity: String(formData.get("severity") || "normal"),
      createdBy: "admin@nativeforms.internal"
    });
    prependSupportEntries(orgId, data.supportEntries || []);
    prependAuditEntries(orgId, data.auditEntries || []);
    state.successMessage = "Support note saved.";
    state.overview = null;
    form.reset();
    await Promise.all([ensureOverview(), ensureAuditLog()]);
  } catch (error) {
    state.errorMessage = `Support note failed. ${error.message}`;
  } finally {
    state.busyActionKey = "";
  }

  render();
}

async function saveSettings(form) {
  const formData = new FormData(form);
  const featureMetadata = {};
  for (const key of Object.keys(FEATURE_FLAG_METADATA)) {
    featureMetadata[key] = {
      label: String(formData.get(`featureLabel__${key}`) || "").trim(),
      description: String(formData.get(`featureDescription__${key}`) || "").trim()
    };
  }
  const payload = {
    statusAlertEmailRecipient: String(formData.get("statusAlertEmailRecipient") || "").trim(),
    statusRecomputeTimeUtc: String(formData.get("statusRecomputeTimeUtc") || "").trim(),
    featureMetadata
  };

  state.busyActionKey = "settings:save";
  state.errorMessage = "";
  state.successMessage = "";
  render();

  try {
    const data = await postJson("/admin/settings", payload);
    state.settings = data.settings || state.settings;
    state.successMessage = "Settings saved.";
  } catch (error) {
    state.errorMessage = `Settings save failed. ${error.message}`;
  } finally {
    state.busyActionKey = "";
  }

  render();
}

async function refreshAdminData() {
  state.busyActionKey = "settings:refresh-data";
  state.errorMessage = "";
  state.successMessage = "";
  render();

  try {
    const data = await postJson("/admin/refresh-data", {});
    state.tenantDetailsById.clear();
    state.supportByOrgId.clear();
    state.auditByOrgId.clear();
    state.overview = null;
    state.auditLog = [];
    await loadInitialData();
    await ensureTenantData(state.selectedOrgId || state.tenants[0]?.orgId || null);
    state.successMessage = data?.reason || "Admin data was refreshed.";
  } catch (error) {
    state.errorMessage = `Refresh Data failed. ${error.message}`;
  } finally {
    state.busyActionKey = "";
  }

  render();
}

function renderTimeline(target, items, emptyTitle, type) {
  if (!target) {
    return;
  }

  if (!items?.length) {
    target.innerHTML = `
      <div class="timeline-empty">
        <strong>${escapeHtml(emptyTitle)}</strong>
        <span>No items to show right now.</span>
      </div>
    `;
    return;
  }

  target.innerHTML = items.map((item) => {
    const title = type === "support"
      ? labelize(item.severity || item.eventType || "note")
      : type === "tenant"
        ? escapeHtml(item.companyName || item.orgId || "Customer")
        : escapeHtml(item.actionLabel || labelize(item.actionType || "action"));
    const body = type === "support"
      ? escapeHtml(item.message || "")
      : type === "tenant"
        ? escapeHtml(`${labelize(item.setupState || "unknown")} / ${labelize(item.healthStatus || "unknown")} / ${item.adminEmail || item.orgId || ""}`)
        : escapeHtml(item.reason || item.summary || "Administrative action");
    const meta = type === "support"
      ? `${escapeHtml(item.createdBy || "Unknown")} / ${escapeHtml(formatRelative(item.createdAt))}`
      : type === "tenant"
        ? `${escapeHtml(item.planLabel || labelize(item.planCode || "plan"))}${item.trialEndsAt || item.planEndsAt ? ` / ${escapeHtml(formatDate(item.trialEndsAt || item.planEndsAt))}` : ""}`
        : `${escapeHtml(item.actorEmail || "Unknown")} / ${escapeHtml(formatRelative(item.createdAt))}`;

    return `
      <article class="timeline-item">
        <div class="timeline-item__row">
          <strong>${title}</strong>
          <span class="timeline-item__meta">${meta}</span>
        </div>
        <p>${body || "No additional detail was saved."}</p>
      </article>
    `;
  }).join("");
}

function renderOverview() {
  const overview = state.overview || {
    summary: {},
    lists: {
      setupIssues: [],
      expiringTrials: [],
      recentSupportNotes: [],
      recentAdminActions: []
    }
  };
  const summary = overview.summary || {};
  const cards = [
    ["Active Customers", summary.activeTenants ?? 0],
    ["Trials Running", summary.trialsInProgress ?? 0],
    ["Expiring Trials", summary.expiringTrials ?? 0],
    ["Needs Attention", summary.tenantsWithIssues ?? 0],
    ["Support Watch", summary.tenantsNeedingSupport ?? 0],
    ["Submissions Today", summary.submissionsToday ?? 0]
  ];

  refs.overviewSummary.innerHTML = cards.map(([label, value]) => `
    <article class="summary-card">
      <span class="summary-card__label">${escapeHtml(label)}</span>
      <strong class="summary-card__value">${escapeHtml(value)}</strong>
    </article>
  `).join("");

  renderTimeline(refs.overviewSetupIssues, overview.lists?.setupIssues || [], "Setup looks clean", "tenant");
  renderTimeline(refs.overviewExpiringTrials, overview.lists?.expiringTrials || [], "No trials are close to ending", "tenant");
  renderTimeline(refs.overviewSupportNotes, overview.lists?.recentSupportNotes || [], "No new support notes", "support");
  renderTimeline(refs.overviewAdminActions, overview.lists?.recentAdminActions || [], "No recent admin actions", "audit");
}

function renderStats(items) {
  refs.tenantCount.textContent = String(items.length);
  refs.attentionCount.textContent = String(items.filter((tenant) => tenant.healthStatus !== "healthy").length);
  refs.trialCount.textContent = String(items.filter((tenant) => tenant.planCode === "trial").length);
}

function renderBanner() {
  if (state.successMessage) {
    refs.heroCopy.textContent = state.successMessage;
    return;
  }

  if (state.errorMessage) {
    refs.heroCopy.textContent = state.errorMessage;
    return;
  }

  if (state.view === "overview") {
    refs.heroCopy.textContent = "This view is built for support and operations: setup blockers, expiring trials, recent notes, and recent admin actions in one place.";
    return;
  }

  if (state.view === "audit") {
    refs.heroCopy.textContent = "Every change should leave a trail. This screen helps you understand who changed what and why.";
    return;
  }

  if (state.view === "plans") {
    refs.heroCopy.textContent = state.planStorageMode === "dynamodb"
      ? "Plan changes save directly into the TwinaForms plan storage and can immediately influence customer limits."
      : "The live plan endpoint is reachable, but plan storage is currently unavailable or unhealthy.";
    return;
  }

  if (state.view === "settings") {
    refs.heroCopy.textContent = "Use this page to review live admin connection details and manage notification and recompute settings.";
    return;
  }

  refs.heroCopy.textContent = "This customer workspace is running on the live Admin API, including customer profile saves and real plan assignments.";
}

function renderModePanel() {
  refs.settingsApiUrl.textContent = apiBaseUrl || "Not configured";
  refs.settingsActiveMode.textContent = !apiBaseUrl
    ? "Live API Missing"
    : (state.errorMessage ? "Live API Error" : "Live API");
  refs.settingsPlanStorage.textContent = labelize(state.planStorageMode);
  refs.settingsStatusAlertEmail.textContent = state.settings?.statusAlertEmailRecipient || "Not configured";
  refs.settingsRecomputeTime.textContent = `${state.settings?.statusRecomputeTimeUtc || "02:00"} UTC`;
  refs.settingsSource.textContent = labelize(state.settings?.source || "default");
  if (refs.dataModeHelper) {
    refs.dataModeHelper.textContent = !apiBaseUrl
      ? "The Admin API URL is missing, so live data cannot be loaded."
      : (state.errorMessage
        ? "The app stays on the live path and shows backend errors directly until the Admin API is healthy again."
        : `The Admin API is active. Health: ${state.apiHealth?.status || "unknown"}. ${state.apiHealth?.message || ""}`.trim());
  }
  const settingsForm = document.getElementById("settingsForm");
  if (settingsForm) {
    const emailInput = settingsForm.querySelector('[name="statusAlertEmailRecipient"]');
    const timeInput = settingsForm.querySelector('[name="statusRecomputeTimeUtc"]');
    const submitButton = settingsForm.querySelector('button[type="submit"]');
    if (emailInput) {
      emailInput.value = state.settings?.statusAlertEmailRecipient || "";
      emailInput.disabled = !apiBaseUrl || state.busyActionKey === "settings:save";
    }
    if (timeInput) {
      timeInput.value = state.settings?.statusRecomputeTimeUtc || "02:00";
      timeInput.disabled = !apiBaseUrl || state.busyActionKey === "settings:save";
    }
    if (refs.settingsFeatureMetadata) {
      const featureMetadata = getFeatureMetadata();
      refs.settingsFeatureMetadata.innerHTML = Object.entries(featureMetadata).map(([key, value]) => `
        <article class="feature-settings-item">
          <p class="feature-settings-item__title">${escapeHtml(value.label)}</p>
          <div class="stack-form">
            <label class="field">
              <span class="field__label">Feature Name</span>
              <input class="field__control" name="featureLabel__${escapeHtml(key)}" type="text" value="${escapeHtml(value.label)}" ${(!apiBaseUrl || state.busyActionKey === "settings:save") ? "disabled" : ""}>
            </label>
            <label class="field">
              <span class="field__label">Feature Description</span>
              <textarea class="field__control field__control--textarea" name="featureDescription__${escapeHtml(key)}" ${(!apiBaseUrl || state.busyActionKey === "settings:save") ? "disabled" : ""}>${escapeHtml(value.description || "")}</textarea>
            </label>
          </div>
        </article>
      `).join("");
    }
    if (submitButton) {
      submitButton.disabled = !apiBaseUrl || state.busyActionKey === "settings:save";
      submitButton.textContent = state.busyActionKey === "settings:save" ? "Saving Settings..." : "Save Settings";
    }
    if (refs.refreshDataButton) {
      refs.refreshDataButton.disabled = !apiBaseUrl || state.busyActionKey === "settings:refresh-data";
      refs.refreshDataButton.textContent = state.busyActionKey === "settings:refresh-data" ? "Refreshing Data..." : "Refresh Data";
    }
  }
}

function applySplitLayout() {
  if (!refs.tenantsLayout) {
    return;
  }

  if (window.innerWidth <= 900) {
    refs.tenantsLayout.style.gridTemplateColumns = "";
    return;
  }

  const containerWidth = refs.tenantsLayout.clientWidth;
  if (!containerWidth) {
    return;
  }

  const minLeft = 620;
  const minRight = 360;
  const splitterWidth = 14;
  const maxLeft = Math.max(minLeft, containerWidth - minRight - splitterWidth);
  const desiredLeft = state.splitLeftWidth ?? Math.round(containerWidth * 0.68);
  const clampedLeft = Math.min(Math.max(desiredLeft, minLeft), maxLeft);
  state.splitLeftWidth = clampedLeft;
  refs.tenantsLayout.style.gridTemplateColumns = `${clampedLeft}px ${splitterWidth}px minmax(${minRight}px, 1fr)`;
}

function renderTable(items) {
  updateSortIndicators();
  refs.tenantTableBody.innerHTML = "";

  items.forEach((tenant) => {
    const row = document.createElement("tr");
    if (tenant.orgId === state.selectedOrgId) {
      row.classList.add("is-selected");
    }

    row.innerHTML = `
      <td>
        <div class="tenant-primary">
          <strong>${escapeHtml(tenant.companyName)}</strong>
          <span>${escapeHtml(tenant.adminEmail)}</span>
          <span>${escapeHtml(tenant.orgId)}</span>
        </div>
      </td>
      <td>
        ${(() => {
          const planDate = tenant.planStartedAt;
          const trialDate = tenant.trialStartedAt;
          const startedAt = planDate || trialDate;
          const sourceLabel = planDate ? "Plan" : (trialDate ? "Trial" : "");
          if (!startedAt) {
            return '<div class="metric-strong">—</div><div class="metric-soft">Not started</div>';
          }
          return `
            <div class="metric-strong">${escapeHtml(formatDate(startedAt))}</div>
            <div class="metric-soft">${escapeHtml(sourceLabel)}</div>
          `;
        })()}
      </td>
      <td><span class="${getStatusChipClass(tenant.planCode)}">${escapeHtml(tenant.planLabel || labelize(tenant.planCode))}</span></td>
      <td><span class="${getStatusChipClass(tenant.status)}">${escapeHtml(labelize(tenant.status))}</span></td>
      <td><span class="${getStatusChipClass(tenant.setupState)}">${escapeHtml(labelize(tenant.setupState))}</span></td>
      <td><span class="${getStatusChipClass(tenant.healthStatus)}">${escapeHtml(labelize(tenant.healthStatus))}</span></td>
      <td>
        <div class="metric-strong">${escapeHtml(formatRelative(tenant.lastActivityAt))}</div>
        <div class="metric-soft">${escapeHtml(tenant.alertType ? formatAlertType(tenant.alertType) : `Forms ${tenant.activeFormsCount ?? 0}`)}</div>
      </td>
      <td>
        <div class="metric-strong">${escapeHtml(tenant.submissionsMonth ?? 0)}</div>
        <div class="metric-soft">submissions</div>
      </td>
    `;

    row.addEventListener("click", () => {
      state.selectedOrgId = tenant.orgId;
      render();
      ensureTenantData(tenant.orgId);
    });

    refs.tenantTableBody.appendChild(row);
  });
}

function renderDetail(items) {
  const selectedTenant = getSelectedTenant(items);
  if (!selectedTenant) {
    refs.tenantDetail.innerHTML = `
      <div class="detail-card__placeholder">
        <p class="detail-card__eyebrow">Customer Detail</p>
        <h4>No customer selected</h4>
        <p>Adjust the filters or search, then choose a customer to inspect.</p>
      </div>
    `;
    return;
  }

  const tenantSupport = state.supportByOrgId.get(selectedTenant.orgId) || [];
  const tenantAudit = state.auditByOrgId.get(selectedTenant.orgId) || [];
  const planOptions = state.plans.map((plan) => `
    <option value="${escapeHtml(plan.planCode)}" ${plan.planCode === selectedTenant.planCode ? "selected" : ""}>${escapeHtml(plan.label)}</option>
  `).join("");
  const saveTenantButtonClass = state.isSavingTenant ? "action-button action-button--busy" : "action-button";
  const isBusy = (action) => state.busyActionKey === `${selectedTenant.orgId}:${action}`;

  refs.tenantDetail.innerHTML = `
    <div class="detail-header">
      <div>
        <p class="detail-card__eyebrow">Customer Detail</p>
        <h4>${escapeHtml(selectedTenant.companyName)}</h4>
        <p class="detail-subtitle">${escapeHtml(selectedTenant.adminEmail)}<br>${escapeHtml(selectedTenant.orgId)}</p>
      </div>
      <span class="${getStatusChipClass(selectedTenant.healthStatus)}">${escapeHtml(labelize(selectedTenant.healthStatus))}</span>
    </div>

    <div class="detail-grid">
      <div class="detail-block">
        <p class="detail-block__label">Current Plan</p>
        <p class="detail-block__value">${escapeHtml(selectedTenant.planLabel || labelize(selectedTenant.planCode))}</p>
      </div>
      <div class="detail-block">
        <p class="detail-block__label">Service Status</p>
        <p class="detail-block__value">${escapeHtml(labelize(selectedTenant.status))}</p>
      </div>
      <div class="detail-block">
        <p class="detail-block__label">Forms</p>
        <p class="detail-block__value">${escapeHtml(selectedTenant.activeFormsCount ?? 0)} / ${escapeHtml(formatLimit(selectedTenant.effectiveLimits?.maxForms))}</p>
      </div>
      <div class="detail-block">
        <p class="detail-block__label">Submissions This Month</p>
        <p class="detail-block__value">${escapeHtml(selectedTenant.submissionsMonth ?? 0)} / ${escapeHtml(formatLimit(selectedTenant.effectiveLimits?.maxSubmissionsPerMonth))}</p>
      </div>
      <div class="detail-block">
        <p class="detail-block__label">Alert Type</p>
        <p class="detail-block__value">${escapeHtml(formatAlertType(selectedTenant.alertType))}</p>
      </div>
      <div class="detail-block">
        <p class="detail-block__label">Status Reason</p>
        <p class="detail-block__value">${escapeHtml(selectedTenant.statusReason || "No current alert reason")}</p>
      </div>
      <div class="detail-block">
        <p class="detail-block__label">Trial Window</p>
        <p class="detail-block__value">${escapeHtml(formatDate(selectedTenant.trialStartedAt))} - ${escapeHtml(formatDate(selectedTenant.trialEndsAt))}</p>
      </div>
      <div class="detail-block">
        <p class="detail-block__label">Location</p>
        <p class="detail-block__value">${escapeHtml([
          selectedTenant.city,
          selectedTenant.state,
          selectedTenant.country
        ].filter(Boolean).join(", ") || "Not set")}</p>
      </div>
      <div class="detail-block">
        <p class="detail-block__label">Salesforce Admin App</p>
        <p class="detail-block__value">${selectedTenant.supportFlags?.enableSalesforceAdminApp ? "Open for support/debug" : "Closed by default"}</p>
      </div>
    </div>

    <section class="detail-section">
      <h5>Edit Customer</h5>
      <form id="tenantProfileForm" class="stack-form">
        <input type="hidden" name="orgId" value="${escapeHtml(selectedTenant.orgId)}">
        <label class="field">
          <span class="field__label">Company Name</span>
          <input class="field__control" name="companyName" type="text" value="${escapeHtml(selectedTenant.companyName)}">
        </label>
        <label class="field">
          <span class="field__label">Admin Email</span>
          <input class="field__control" name="adminEmail" type="email" value="${escapeHtml(selectedTenant.adminEmail)}">
        </label>
        <div class="inline-fields">
          <label class="field field--readonly">
            <span class="field__label">Current Status</span>
            <input class="field__control" type="text" value="${escapeHtml(labelize(selectedTenant.status))}" disabled>
          </label>
          <label class="field">
            <span class="field__label">Assigned Plan</span>
            <select class="field__control" name="planCode">${planOptions}</select>
          </label>
        </div>
        <div class="inline-fields">
          <label class="field">
            <span class="field__label">Subscription Status</span>
            <select class="field__control" name="subscriptionStatus">
              <option value="active" ${selectedTenant.subscriptionStatus === "active" ? "selected" : ""}>Active</option>
              <option value="trialing" ${selectedTenant.subscriptionStatus === "trialing" ? "selected" : ""}>Trialing</option>
              <option value="paused" ${selectedTenant.subscriptionStatus === "paused" ? "selected" : ""}>Paused</option>
              <option value="expired" ${selectedTenant.subscriptionStatus === "expired" ? "selected" : ""}>Expired</option>
            </select>
          </label>
          <label class="field">
            <span class="field__label">Support Status</span>
            <select class="field__control" name="supportStatus">
              <option value="normal" ${selectedTenant.supportStatus === "normal" ? "selected" : ""}>Normal</option>
              <option value="watch" ${selectedTenant.supportStatus === "watch" ? "selected" : ""}>Watch</option>
              <option value="priority" ${selectedTenant.supportStatus === "priority" ? "selected" : ""}>Priority</option>
            </select>
          </label>
        </div>
        <div class="field field--checkbox">
          <span class="field__label">Salesforce Admin App</span>
          <label class="checkbox-row">
            <input type="checkbox" name="enableSalesforceAdminApp" ${selectedTenant.supportFlags?.enableSalesforceAdminApp ? "checked" : ""}>
            <span>Open TwinaForms Admin in Salesforce for support/debug use</span>
          </label>
        </div>
        <div class="inline-fields">
          <label class="field">
            <span class="field__label">Plan Start Date</span>
            <input class="field__control" name="planStartedAt" type="date" value="${escapeHtml(formatDateInput(selectedTenant.planStartedAt))}">
          </label>
          <label class="field">
            <span class="field__label">Plan End Date</span>
            <input class="field__control" name="planEndsAt" type="date" value="${escapeHtml(formatDateInput(selectedTenant.planEndsAt))}">
          </label>
        </div>
        <div class="inline-fields">
          <label class="field">
            <span class="field__label">Trial Start Date</span>
            <input class="field__control" name="trialStartedAt" type="date" value="${escapeHtml(formatDateInput(selectedTenant.trialStartedAt))}">
          </label>
          <label class="field">
            <span class="field__label">Trial End Date</span>
            <input class="field__control" name="trialEndsAt" type="date" value="${escapeHtml(formatDateInput(selectedTenant.trialEndsAt))}">
          </label>
        </div>
        <label class="field">
          <span class="field__label">Internal Notes</span>
          <textarea class="field__control field__control--textarea" name="internalNotes">${escapeHtml(selectedTenant.internalNotes || "")}</textarea>
        </label>
        <label class="field field--readonly">
          <span class="field__label">Connected Username</span>
          <input class="field__control" type="text" value="${escapeHtml(selectedTenant.connectedUsername || "Not connected yet")}" disabled>
        </label>
        <div class="detail-actions">
          <button class="${saveTenantButtonClass}" type="submit" ${state.isSavingTenant ? "disabled" : ""}>${state.isSavingTenant ? "Saving Customer..." : "Save Customer"}</button>
        </div>
      </form>
    </section>

    <section class="detail-section">
      <h5>Safe Actions</h5>
      <form id="tenantActionsForm" class="stack-form">
        <input type="hidden" name="orgId" value="${escapeHtml(selectedTenant.orgId)}">
        <div class="inline-fields">
          <label class="field">
            <span class="field__label">Action Reason</span>
            <input class="field__control" name="reason" type="text" placeholder="Add a short reason for the audit log">
          </label>
          <label class="field">
            <span class="field__label">Extend Trial By Days</span>
            <input class="field__control" name="days" type="number" min="1" value="14">
          </label>
        </div>
        <div class="detail-actions detail-actions--split">
          <button class="action-button action-button--secondary" type="button" data-action="extend-trial" ${isBusy("extend-trial") ? "disabled" : ""}>${isBusy("extend-trial") ? "Extending..." : "Extend Trial"}</button>
          <button class="action-button action-button--secondary" type="button" data-action="${selectedTenant.status === "blocked" ? "unblock" : "block"}" ${(isBusy("block") || isBusy("unblock")) ? "disabled" : ""}>${selectedTenant.status === "blocked" ? (isBusy("unblock") ? "Unblocking..." : "Unblock Customer") : (isBusy("block") ? "Blocking..." : "Block Customer")}</button>
          <button class="action-button action-button--secondary" type="button" data-action="resend-setup" ${isBusy("resend-setup") ? "disabled" : ""}>${isBusy("resend-setup") ? "Sending..." : "Resend Setup"}</button>
          <button class="action-button action-button--secondary" type="button" data-action="regenerate-secret" ${isBusy("regenerate-secret") ? "disabled" : ""}>${isBusy("regenerate-secret") ? "Requesting..." : "Regenerate Secret"}</button>
        </div>
      </form>
    </section>

    <section class="detail-section">
      <h5>Support</h5>
      <form id="supportNoteForm" class="stack-form">
        <input type="hidden" name="orgId" value="${escapeHtml(selectedTenant.orgId)}">
        <div class="inline-fields">
          <label class="field">
            <span class="field__label">Severity</span>
            <select class="field__control" name="severity">
              <option value="normal">Normal</option>
              <option value="watch">Watch</option>
              <option value="priority">Priority</option>
            </select>
          </label>
        </div>
        <label class="field">
          <span class="field__label">New Support Note</span>
          <textarea class="field__control field__control--textarea" name="message" placeholder="Capture context for the next admin or support person." required></textarea>
        </label>
        <div class="detail-actions">
          <button class="${isBusy("support-note") ? "action-button action-button--busy" : "action-button"}" type="submit" ${isBusy("support-note") ? "disabled" : ""}>${isBusy("support-note") ? "Saving Note..." : "Save Support Note"}</button>
        </div>
      </form>
      <details class="collapsible">
        <summary>
          <span class="collapsible__title">Past notes</span>
          <span class="collapsible__count">${tenantSupport.length}</span>
        </summary>
        <div class="activity-stream">
          ${tenantSupport.length ? tenantSupport.map((item) => `
            <article class="timeline-item">
              <div class="timeline-item__row">
                <strong>${escapeHtml(labelize(item.severity || item.eventType || "support"))}</strong>
                <span class="timeline-item__meta">${escapeHtml(item.createdBy || "Unknown")} / ${escapeHtml(formatRelative(item.createdAt))}</span>
              </div>
              <p>${escapeHtml(item.message || "")}</p>
            </article>
          `).join("") : '<div class="timeline-empty"><strong>No support notes yet</strong><span>Add the first note from this customer panel.</span></div>'}
        </div>
      </details>
    </section>

    <section class="detail-section detail-section--danger">
      <h5>Danger Zone</h5>
      <div class="danger-panel">
        <div>
          <strong>Delete tenant DynamoDB record</strong>
          <p>This removes only the customer record from DynamoDB. Secrets Manager is intentionally left untouched.</p>
        </div>
        <button class="action-button action-button--danger" type="button" id="deleteTenantButton" ${isBusy("delete-tenant") ? "disabled" : ""}>${isBusy("delete-tenant") ? "Deleting..." : "Delete Tenant"}</button>
      </div>
    </section>

    <section class="detail-section detail-section--collapsible">
      <details class="collapsible">
        <summary>
          <h5>Audit Trail</h5>
          <span class="collapsible__count">${tenantAudit.length}</span>
        </summary>
        <div class="activity-stream">
          ${tenantAudit.length ? tenantAudit.map((item) => `
            <article class="timeline-item">
              <div class="timeline-item__row">
                <strong>${escapeHtml(item.actionLabel || labelize(item.actionType || "action"))}</strong>
                <span class="timeline-item__meta">${escapeHtml(item.actorEmail || "Unknown")} / ${escapeHtml(formatRelative(item.createdAt))}</span>
              </div>
              <p>${escapeHtml(item.reason || item.summary || "Administrative action")}</p>
            </article>
          `).join("") : '<div class="timeline-empty"><strong>No audit entries yet</strong><span>Administrative changes for this customer will appear here.</span></div>'}
        </div>
      </details>
    </section>
  `;

  document.getElementById("tenantProfileForm")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    await saveTenantProfile(event.currentTarget);
  });

  document.getElementById("supportNoteForm")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    await saveSupportNote(event.currentTarget);
  });

  document.querySelectorAll("#tenantActionsForm [data-action]").forEach((button) => {
    button.addEventListener("click", async () => {
      const form = document.getElementById("tenantActionsForm");
      const formData = new FormData(form);
      await runTenantAction(selectedTenant.orgId, button.dataset.action, {
        reason: String(formData.get("reason") || "").trim(),
        days: parseNullableNumber(formData.get("days")),
        actorEmail: "admin@nativeforms.internal"
      });
    });
  });

  document.getElementById("deleteTenantButton")?.addEventListener("click", async () => {
    await deleteTenantRecord(selectedTenant);
  });
}

function renderPlans() {
  const selectedPlan = getSelectedPlan();
  const planStorageReady = state.planStorageMode === "dynamodb";
  const savePlanButtonClass = state.isSavingPlan ? "action-button action-button--busy" : "action-button";

  refs.planNotice.hidden = false;
  refs.planNotice.className = `notice-banner ${planStorageReady ? "notice-banner--success" : "notice-banner--warning"}`;
  refs.planNotice.innerHTML = planStorageReady
    ? "<strong>Plan storage is live.</strong><span>Changes on this screen save into the TwinaForms plan storage.</span>"
    : "<strong>Plan storage is currently unavailable.</strong><span>The live API could not confirm DynamoDB-backed plan storage. Check the Admin API health and table access.</span>";

  refs.planList.innerHTML = `
    <p class="detail-card__eyebrow">Plans</p>
    <div class="plan-list">
      ${state.plans.map((plan) => `
        <button class="plan-list__item ${plan.planCode === state.selectedPlanCode ? "is-selected" : ""}" type="button" data-plan-code="${escapeHtml(plan.planCode)}">
          <strong>${escapeHtml(plan.label)}</strong>
          <span>${escapeHtml(plan.description || "No description yet.")}</span>
        </button>
      `).join("")}
    </div>
  `;

  const featureFlagLabels = getFeatureFlagLabels(selectedPlan);
  const featureMetadata = getFeatureMetadata();

  refs.planEditor.innerHTML = selectedPlan ? `
    <div class="detail-header">
      <div>
        <p class="detail-card__eyebrow">Plan Detail</p>
        <h4>${escapeHtml(selectedPlan.label)}</h4>
        <p class="detail-subtitle">${escapeHtml(selectedPlan.planCode)} plan definition and feature flags</p>
      </div>
      <span class="${getStatusChipClass(selectedPlan.planCode)}">${escapeHtml(selectedPlan.label)}</span>
    </div>
    <form id="planEditorForm" class="stack-form">
      <input type="hidden" name="planCode" value="${escapeHtml(selectedPlan.planCode)}">
      <label class="field">
        <span class="field__label">Label</span>
        <input class="field__control" name="label" type="text" value="${escapeHtml(selectedPlan.label)}">
      </label>
      <label class="field">
        <span class="field__label">Description</span>
        <textarea class="field__control field__control--textarea" name="description">${escapeHtml(selectedPlan.description || "")}</textarea>
      </label>
      <div class="inline-fields">
        <label class="field">
          <span class="field__label">Duration Type</span>
          <select class="field__control" name="durationType">
            <option value="forever" ${selectedPlan.durationType === "forever" ? "selected" : ""}>Forever</option>
            <option value="fixed_days" ${selectedPlan.durationType === "fixed_days" ? "selected" : ""}>Fixed Days</option>
          </select>
        </label>
        <label class="field">
          <span class="field__label">Duration Days</span>
          <input class="field__control" name="durationDays" type="number" min="0" value="${escapeHtml(selectedPlan.durationDays ?? "")}">
        </label>
      </div>
      <div class="inline-fields inline-fields--quad">
        <label class="field">
          <span class="field__label">Max SF Users</span>
          <input class="field__control" name="maxSfUsers" type="number" min="0" value="${escapeHtml(selectedPlan.limits?.maxSfUsers ?? "")}">
        </label>
        <label class="field">
          <span class="field__label">Max Forms</span>
          <input class="field__control" name="maxForms" type="number" min="0" value="${escapeHtml(selectedPlan.limits?.maxForms ?? "")}">
        </label>
        <label class="field">
          <span class="field__label">Monthly Submissions</span>
          <input class="field__control" name="maxSubmissionsPerMonth" type="number" min="0" value="${escapeHtml(selectedPlan.limits?.maxSubmissionsPerMonth ?? "")}">
        </label>
        <label class="field">
          <span class="field__label">Submission Log Retention (Days)</span>
          <input class="field__control" name="submissionLogRetentionDays" type="number" min="1" value="${escapeHtml(selectedPlan.limits?.submissionLogRetentionDays ?? "")}">
        </label>
      </div>
      <label class="toggle-field">
        <input type="checkbox" name="isActive" ${selectedPlan.isActive ? "checked" : ""}>
        <span>Plan is active and available for assignment</span>
      </label>
      <section class="detail-section detail-section--tight">
        <h5>Pro Feature Flags</h5>
        <div class="feature-grid">
          ${Object.entries(featureFlagLabels).map(([key, label]) => `
            <label class="toggle-card">
              <input type="checkbox" name="${escapeHtml(key)}" ${selectedPlan.featureFlags?.[key] ? "checked" : ""}>
              <span class="toggle-card__body">
                <strong>${escapeHtml(label)}</strong>
                <small>${escapeHtml(featureMetadata?.[key]?.description || "")}</small>
              </span>
            </label>
          `).join("")}
        </div>
      </section>
      <div class="detail-actions">
        <button class="${savePlanButtonClass}" type="submit" ${(!apiBaseUrl || !planStorageReady || state.isSavingPlan) ? "disabled" : ""}>${state.isSavingPlan ? "Saving Plan..." : "Save Plan"}</button>
      </div>
    </form>
  ` : `
    <div class="detail-card__placeholder">
      <p class="detail-card__eyebrow">Plan Detail</p>
      <h4>Select a plan</h4>
      <p>Choose one of the available plans to view or edit its limits and features.</p>
    </div>
  `;

  Array.from(document.querySelectorAll("[data-plan-code]")).forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedPlanCode = button.dataset.planCode;
      renderPlans();
    });
  });

  document.getElementById("planEditorForm")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    await savePlan(event.currentTarget);
  });
}

function renderAuditPage() {
  const items = state.auditLog;
  renderTimeline(refs.auditLogList, items, "No audit entries yet", "audit");
}

function renderFeatureList() {
  refs.featureListPrimary.innerHTML = adminFeatureListPrimary.map((item) => `
    <article class="timeline-item">
      <div class="timeline-item__row">
        <strong>${escapeHtml(item.title)}</strong>
        <span class="timeline-item__meta">${escapeHtml(item.phase)}</span>
      </div>
      <p>${escapeHtml(item.detail)}</p>
    </article>
  `).join("");

  refs.featureListSecondary.innerHTML = adminFeatureListSecondary.map((item) => `
    <article class="timeline-item">
      <div class="timeline-item__row">
        <strong>${escapeHtml(item.title)}</strong>
      </div>
      <p>${escapeHtml(item.detail)}</p>
    </article>
  `).join("");
}

function bindSettingsForm() {
  const form = document.getElementById("settingsForm");
  if (!form || form.dataset.bound === "true") {
    return;
  }

  form.dataset.bound = "true";
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    await saveSettings(event.currentTarget);
  });

  refs.refreshDataButton?.addEventListener("click", async () => {
    await refreshAdminData();
  });
}

function renderView() {
  const meta = {
    overview: {
      workspaceTitle: "Operational Overview",
      heroEyebrow: "Overview",
      heroTitle: "See customer health, setup blockers, expiring trials, and the latest admin activity at a glance."
    },
    tenants: {
      workspaceTitle: "Customer Operations Workspace",
      heroEyebrow: "Primary Screen",
      heroTitle: "Find any customer, understand plan and setup health quickly, then take the next safe action."
    },
    plans: {
      workspaceTitle: "Plan And Feature Control",
      heroEyebrow: "Plan Management",
      heroTitle: "Manage the four commercial plans and the Pro feature flags they unlock."
    },
    "feature-list": {
      workspaceTitle: "Admin Feature List",
      heroEyebrow: "Roadmap",
      heroTitle: "Track the open admin features we still plan to add after the current control workflow is stable."
    },
    audit: {
      workspaceTitle: "Administrative Audit Log",
      heroEyebrow: "Audit Trail",
      heroTitle: "Review the latest changes made across plans, customer records, and operational support actions."
    },
    settings: {
      workspaceTitle: "Admin Console Settings",
      heroEyebrow: "App setting",
      heroTitle: "App setting"
    }
  }[state.view];

  refs.workspaceTitle.textContent = meta.workspaceTitle;
  refs.heroEyebrow.textContent = meta.heroEyebrow;
  refs.heroTitle.textContent = meta.heroTitle;

  refs.overviewSection.hidden = state.view !== "overview";
  refs.tenantsPanel.hidden = state.view !== "tenants";
  refs.plansPanel.hidden = state.view !== "plans";
  refs.plansSection.hidden = state.view !== "plans";
  refs.featureListSection.hidden = state.view !== "feature-list";
  refs.auditSection.hidden = state.view !== "audit";
  refs.settingsSection.hidden = state.view !== "settings";

  refs.navButtons.forEach((button) => {
    button.classList.toggle("nav__item--active", button.dataset.view === state.view);
  });
}

function render() {
  const filteredTenants = getFilteredTenants();
  if (refs.signedInUser) {
    refs.signedInUser.textContent = authState.enabled
      ? (authState.email || "Authenticated")
      : "Local Preview";
  }
  if (refs.logoutButton) {
    refs.logoutButton.hidden = !authState.enabled || !authState.accessToken;
  }
  renderBanner();
  renderModePanel();
  renderView();
  applySplitLayout();
  renderStats(filteredTenants);
  renderOverview();
  renderTable(filteredTenants);
  renderDetail(filteredTenants);
  renderPlans();
  renderFeatureList();
  renderAuditPage();
  bindSettingsForm();
  refs.emptyState.hidden = filteredTenants.length > 0;
}

document.getElementById("searchInput").addEventListener("input", (event) => {
  state.search = event.target.value.trim().toLowerCase();
  render();
});

document.getElementById("statusFilter").addEventListener("change", (event) => {
  state.status = event.target.value;
  render();
});

document.getElementById("planFilter").addEventListener("change", (event) => {
  state.planCode = event.target.value;
  render();
});

document.getElementById("setupFilter").addEventListener("change", (event) => {
  state.setupState = event.target.value;
  render();
});

document.getElementById("healthFilter").addEventListener("change", (event) => {
  state.healthStatus = event.target.value;
  render();
});

document.querySelectorAll(".tenant-table th[data-sort-key]").forEach((th) => {
  th.addEventListener("click", () => {
    handleSortClick(th.dataset.sortKey);
  });
});

state.requestedDataMode = "live";
state.dataMode = "live";
state.splitLeftWidth = getSavedSplitWidth();

refs.navButtons.forEach((button) => {
  button.addEventListener("click", async () => {
    state.view = button.dataset.view;

    if (state.view === "overview") {
      await ensureOverview();
    }

    if (state.view === "audit") {
      await ensureAuditLog();
    }

    if (state.view === "tenants") {
      await ensureTenantData(state.selectedOrgId || state.tenants[0]?.orgId || null);
    }

    render();
  });
});

if (refs.tenantsSplitter && refs.tenantsLayout) {
  refs.tenantsSplitter.addEventListener("mousedown", (event) => {
    if (window.innerWidth <= 900) {
      return;
    }

    event.preventDefault();
    const rect = refs.tenantsLayout.getBoundingClientRect();

    const handleMove = (moveEvent) => {
      const nextWidth = moveEvent.clientX - rect.left;
      state.splitLeftWidth = nextWidth;
      applySplitLayout();
    };

    const handleUp = () => {
      saveSplitWidth(state.splitLeftWidth);
      window.removeEventListener("mousemove", handleMove);
      window.removeEventListener("mouseup", handleUp);
    };

    window.addEventListener("mousemove", handleMove);
    window.addEventListener("mouseup", handleUp);
  });
}

window.addEventListener("resize", () => {
  applySplitLayout();
});

refs.logoutButton?.addEventListener("click", () => {
  logoutAdmin();
});

initializeAuth()
  .then((ready) => {
    if (!ready) {
      render();
      return null;
    }
    return loadInitialData().then(() => ensureTenantData(state.selectedOrgId || state.tenants[0]?.orgId || null));
  })
  .catch((error) => {
    state.errorMessage = `Admin login could not start. ${error.message}`;
    state.isLoading = false;
    render();
  });
