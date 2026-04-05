import {
  SecretsManagerClient,
  CreateSecretCommand,
  PutSecretValueCommand,
  GetSecretValueCommand
} from "@aws-sdk/client-secrets-manager";
import {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand
} from "@aws-sdk/client-dynamodb";
import { SESClient, SendEmailCommand } from "@aws-sdk/client-ses";
import crypto from "crypto";

const secretsClient = new SecretsManagerClient({});
const dynamoClient = new DynamoDBClient({});
const sesClient = new SESClient({ region: process.env.SES_REGION || process.env.AWS_REGION || "eu-north-1" });
const FORM_SECURITY_TABLE = process.env.FORM_SECURITY_TABLE || "NativeFormsFormSecurity";
const TENANT_TABLE = process.env.TENANT_TABLE || "NativeFormsTenants";
const SALESFORCE_CONNECTION_SECRET_PREFIX = "NativeForms/SalesforceConnection";
const SES_FROM = process.env.SES_FROM || "";
const DEV_MODE = String(process.env.DEV_MODE || "").toLowerCase() === "true";

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
  return `${SALESFORCE_CONNECTION_SECRET_PREFIX}/${orgId}`;
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

async function getFormSecurityRecord(formId) {
  return getItemByKey(FORM_SECURITY_TABLE, "formId", formId);
}

async function getTenantRecord(orgId) {
  return getItemByKey(TENANT_TABLE, "orgId", orgId);
}

function validateOrgId(orgId) {
  return typeof orgId === "string" && /^00D[A-Za-z0-9]{12,15}$/.test(orgId);
}

function sanitizeTenantRecord(record) {
  if (!record) return null;
  const { secret, ...safe } = record;
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

function isSubscriptionEnded(subscriptionEndDate) {
  if (!subscriptionEndDate) {
    return false;
  }

  const end = new Date(`${subscriptionEndDate}T23:59:59.999Z`);
  return !Number.isNaN(end.getTime()) && end.getTime() < Date.now();
}

function getTenantRuntimeAccessError(tenantRecord) {
  if (!tenantRecord) {
    return "Tenant not found";
  }

  if (tenantRecord.status !== "active" || tenantRecord.isActive === false) {
    return "Subscription is not active for this Salesforce org";
  }

  if (isSubscriptionEnded(tenantRecord.subscriptionEndDate)) {
    return "Subscription has ended for this Salesforce org";
  }

  return null;
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
  if (!orgId) {
    const error = new Error("Missing required field: orgId");
    error.statusCode = 400;
    throw error;
  }

  if (!validateOrgId(orgId)) {
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

  const tenantRecord = await getTenantRecord(orgId);
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
  if (!validateOrgId(payload.orgId)) throw new Error("Invalid orgId");
  if (!payload?.adminEmail) throw new Error("Missing required field: adminEmail");
  if (!payload?.companyName) throw new Error("Missing required field: companyName");
  if (!payload?.loginBaseUrl) throw new Error("Missing required field: loginBaseUrl");
  if (!payload?.salesforceClientId) throw new Error("Missing required field: salesforceClientId");
  if (!payload?.salesforceClientSecret) throw new Error("Missing required field: salesforceClientSecret");
}

function validateFormSecurityPayload(payload) {
  if (!payload?.orgId) throw new Error("Missing required field: orgId");
  if (!validateOrgId(payload.orgId)) throw new Error("Invalid orgId");
  if (!payload?.formId) throw new Error("Missing required field: formId");
  if (!payload?.publishToken) throw new Error("Missing required field: publishToken");
  if (!payload?.publishedVersionId) throw new Error("Missing required field: publishedVersionId");
  if (!payload?.status) throw new Error("Missing required field: status");
  if (!payload?.securityMode) throw new Error("Missing required field: securityMode");
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
    const orgId = event?.queryStringParameters?.orgId;
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

  if (path === "/oauth/callback") {
    const code = event?.queryStringParameters?.code;
    const error = event?.queryStringParameters?.error;
    const errorDescription = event?.queryStringParameters?.error_description;
    const orgId = event?.queryStringParameters?.state || event?.queryStringParameters?.orgId;

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

      const now = new Date().toISOString();
      const existing = await getTenantRecord(payload.orgId);
      const existingConnection = await getSalesforceConnection(getSalesforceConnectionSecretName(payload.orgId));
      const tenantSecret = existing?.secret || generateSecret();
      const subscription = normalizeSubscriptionState(payload, existing);
      const tenantRecord = {
        orgId: payload.orgId,
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
      await saveSalesforceConnection(getSalesforceConnectionSecretName(payload.orgId), {
        ...(existingConnection || {}),
        orgId: payload.orgId,
        loginBaseUrl: payload.loginBaseUrl,
        client_id: payload.salesforceClientId,
        client_secret: payload.salesforceClientSecret,
        refresh_token: existingConnection?.refresh_token || null,
        instance_url: existingConnection?.instance_url || null,
        id_url: existingConnection?.id_url || null,
        token_issued_at: existingConnection?.token_issued_at || null,
        updated_at: now
      });
      const emailSent = await sendTenantSecretEmail(payload.adminEmail, payload.orgId, tenantSecret)
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
        connectUrl: baseUrl ? `${baseUrl}/connect?orgId=${encodeURIComponent(payload.orgId)}` : null,
        emailSent
      });
    } catch (e) {
      return jsonResponse(400, {
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
      await requireTenantAuth(event?.headers, payload.orgId);

      const now = new Date().toISOString();
      const existing = await getFormSecurityRecord(payload.formId);
      const record = {
        formId: payload.formId,
        orgId: payload.orgId,
        publishedVersionId: payload.publishedVersionId,
        status: payload.status,
        securityMode: payload.securityMode,
        rateLimitProfile: payload.rateLimitProfile || "standard",
        tokenHash: hashToken(payload.publishToken),
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
        record
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

      const orgId = event?.queryStringParameters?.orgId;
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
