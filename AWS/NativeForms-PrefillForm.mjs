/*
NativeForms Prefill Engine - V1 Protocol Spec

Purpose
-------
Generic read-only Lambda for prefilled forms.
This Lambda is separate from the Submit Lambda.

Recommended flow
----------------
User clicks link -> S3-hosted HTML loads -> page calls Prefill Lambda ->
Lambda reads Salesforce -> Lambda returns normalized JSON ->
page fills visible and hidden fields.

Top-level request
-----------------
{
  "publishToken": "abc123",
  "request": {
    "formId": "supportForm1",
    "params": {
      "email": "user@example.com"
    }
  }
}

Server-side execution definition
--------------------------------
Commands, response mapping, and onNotFound behavior are stored in DynamoDB
per form record and loaded by Lambda using request.formId.

Top-level response
------------------
{
  "success": true,
  "formId": "supportForm1",
  "input": {
    "email": "user@example.com",
    "lastName": "Cohen"
  },
  "hidden": {
    "contactId": "003xxxxxxxxxxxx"
  },
  "meta": {
    "foundContact": true
  },
  "results": [
    {
      "commandKey": "findContact",
      "type": "findOne",
      "objectApiName": "Contact",
      "found": true,
      "success": true
    }
  ]
}

Supported command types (V1)
----------------------------
1) findOne
   - Finds a single record using simple equality filters joined by AND.
   - Returns first matching record or null.
   Required:
   - type = "findOne"
   - objectApiName
   - where
   Optional:
   - fieldsToReturn
   - storeResultAs

2) getById
   - Fetches one record by Salesforce Id.
   Required:
   - type = "getById"
   - objectApiName
   - id
   Optional:
   - fieldsToReturn
   - storeResultAs

3) findMany
   - Returns multiple records using simple equality filters and a limit.
   Required:
   - type = "findMany"
   - objectApiName
   - where (may be empty object if desired)
   - limit
   Optional:
   - fieldsToReturn
   - orderBy
   - storeResultAs

Expression resolution
---------------------
Supported forms:
- {params.email}
- {foundContact.Id}
- {firstNotBlank(contact.Id, foundContact.Id)}

V1 rule:
- Only whole-string expressions are supported.
- Mixed embedded text is not supported.

responseMapping behavior
------------------------
- Maps values from params and command results into normalized output.
- Typical output sections:
  - input
  - hidden
  - meta
- If a mapped value resolves to undefined, Lambda should skip that field.
- Null may be returned if expression explicitly resolves to null.

Execution model
---------------
- Commands run sequentially.
- Commands are loaded from the stored server-side form definition, not from the browser.
- Later commands may reference earlier stored results.
- Results are stored under storeResultAs.
- Lambda returns both normalized mapped output and command result summaries.
- Commands may include optional `runIf` guards, matching the submit engine pattern.

V1 boundaries
-------------
- Read-only Lambda. No writes.
- findOne and findMany support simple equality filters only.
- findMany supports simple filters, limit, and basic orderBy. No pagination yet.
- No arbitrary SOQL from client.
- No business-specific HTML rendering in Lambda.
- No delete / update / create in Prefill Lambda.
*/
import https from "https";
import querystring from "querystring";
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";
import { DynamoDBClient, GetItemCommand } from "@aws-sdk/client-dynamodb";
import crypto from "crypto";

const FORM_SECURITY_TABLE = process.env.FORM_SECURITY_TABLE || "NativeFormsFormSecurity";
const TENANT_TABLE = process.env.TENANT_TABLE || "NativeFormsTenants";
const SALESFORCE_API_VERSION = "v60.0";
const SALESFORCE_CONNECTION_SECRET_PREFIX = "NativeForms/SalesforceConnection";

const secretsClient = new SecretsManagerClient({});
const dynamoClient = new DynamoDBClient({});

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
      reason: tenantRecord.statusReason || "Data could not be loaded from Salesforce because this customer is blocked."
    };
  }

  return {
    status: normalizedStatus || "active",
    reason: tenantRecord.statusReason || ""
  };
}

function ensureFormToken(formSecurity, publishToken, mode) {
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

  if (!formSecurity.prefillPolicy || mode !== "prefill") {
    const error = new Error("Prefill policy is not configured for this form");
    error.statusCode = 403;
    throw error;
  }

  if (
    !formSecurity.prefillDefinition ||
    !Array.isArray(formSecurity.prefillDefinition.commands) ||
    !formSecurity.prefillDefinition.responseMapping
  ) {
    const error = new Error("Prefill definition is not configured for this form");
    error.statusCode = 403;
    throw error;
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

function validatePrefillCommandAgainstPolicy(command, formSecurity) {
  const allowedCommands = formSecurity.prefillPolicy?.allowedCommands || [];
  const allowedObjects = formSecurity.prefillPolicy?.allowedObjects || [];

  if (!allowedCommands.includes(command.type)) {
    throw new Error(`Command type '${command.type}' is not allowed for prefill on form '${formSecurity.formId}'`);
  }

  if (command.objectApiName && !allowedObjects.includes(command.objectApiName)) {
    throw new Error(`Object '${command.objectApiName}' is not allowed for prefill on form '${formSecurity.formId}'`);
  }
}

function assertSecret(secret) {
  if (!secret.client_id || !secret.client_secret || !secret.refresh_token || !secret.instance_url) {
    throw new Error("Secret is missing required fields");
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
    throw new Error(`Token refresh failed. Status: ${response.statusCode}. Body: ${response.body}`);
  }

  return JSON.parse(response.body).access_token;
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

function setByPath(obj, path, value) {
  const parts = String(path).split(".");
  let current = obj;

  for (let i = 0; i < parts.length - 1; i += 1) {
    const key = parts[i];

    if (
      !Object.prototype.hasOwnProperty.call(current, key) ||
      current[key] === null ||
      typeof current[key] !== "object" ||
      Array.isArray(current[key])
    ) {
      current[key] = {};
    }

    current = current[key];
  }

  current[parts[parts.length - 1]] = value;
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

function applyResponseMapping(responseMapping, context) {
  const output = {};

  for (const [targetPath, sourceExpression] of Object.entries(responseMapping || {})) {
    const value = resolveValue(sourceExpression, context);
    if (value !== undefined) {
      setByPath(output, targetPath, value);
    }
  }

  return output;
}

function buildPrefillAliases(commands, context) {
  const aliases = {};

  for (const command of commands || []) {
    const alias = command?.storeResultAs;
    if (!alias) {
      continue;
    }
    if (Object.prototype.hasOwnProperty.call(context || {}, alias)) {
      aliases[alias] = context[alias];
    }
  }

  return aliases;
}

function buildPrefillResponse({ formId, mapped, results, aliases }) {
  return {
    success: true,
    formId,
    input: mapped.input || {},
    hidden: mapped.hidden || {},
    meta: mapped.meta || {},
    repeatGroups: mapped.repeatGroups || {},
    aliases: aliases || {},
    output: mapped,
    results
  };
}

function normalizeNotFoundConfig(command = {}, request = {}) {
  const configured = command.onNotFound ?? request.onNotFound ?? "ignore";

  if (typeof configured === "string") {
    return {
      action: configured,
      message: null
    };
  }

  if (configured && typeof configured === "object") {
    return {
      action: configured.action || "ignore",
      message: configured.message || null
    };
  }

  return {
    action: "ignore",
    message: null
  };
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
    throw new Error(`Query failed. Status: ${response.statusCode}. Body: ${response.body}`);
  }

  return JSON.parse(response.body);
}

async function getSalesforceRecordById(instanceUrl, accessToken, objectApiName, id, fieldsToReturn) {
  const url = new URL(instanceUrl);
  const fields = Array.isArray(fieldsToReturn) && fieldsToReturn.length > 0
    ? fieldsToReturn.join(",")
    : "Id";

  const path =
    `/services/data/${SALESFORCE_API_VERSION}/sobjects/` +
    `${encodeURIComponent(objectApiName)}/${encodeURIComponent(id)}?fields=${encodeURIComponent(fields)}`;

  const response = await httpsRequest({
    hostname: url.hostname,
    path,
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`
    }
  });

  if (response.statusCode === 404) {
    return null;
  }

  if (response.statusCode !== 200) {
    throw new Error(`getById failed. Status: ${response.statusCode}. Body: ${response.body}`);
  }

  return JSON.parse(response.body);
}

function buildWhereClause(whereObj) {
  const filters = Object.entries(whereObj || {});

  if (filters.length === 0) {
    return "";
  }

  return filters.map(([fieldName, value]) => {
    if (value === null) return `${fieldName} = null`;
    if (typeof value === "number" || typeof value === "boolean") return `${fieldName} = ${value}`;
    return `${fieldName} = '${escapeSoqlValue(value)}'`;
  }).join(" AND ");
}

function normalizeFieldsToReturn(fieldsToReturn) {
  return Array.isArray(fieldsToReturn) && fieldsToReturn.length > 0
    ? fieldsToReturn
    : ["Id"];
}

function buildOrderByClause(orderBy) {
  if (!orderBy) {
    return "";
  }

  const entries = Array.isArray(orderBy) ? orderBy : [orderBy];
  const normalized = entries
    .filter((entry) => entry && typeof entry === "object" && entry.field)
    .map((entry) => {
      const direction = String(entry.direction || "ASC").toUpperCase() === "DESC" ? "DESC" : "ASC";
      return `${entry.field} ${direction}`;
    });

  return normalized.length > 0 ? ` ORDER BY ${normalized.join(", ")}` : "";
}

function buildFindOneSoql(command, resolvedWhere) {
  const fieldsToReturn = normalizeFieldsToReturn(command.fieldsToReturn);
  const whereClause = command.whereClause
    ? interpolateWhereClause(command.whereClause, resolvedWhere)
    : buildWhereClause(resolvedWhere);

  if (!whereClause) {
    throw new Error(`findOne command '${command.commandKey || "unknown"}' requires a non-empty where object`);
  }

  return `SELECT ${fieldsToReturn.join(", ")} FROM ${command.objectApiName} WHERE ${whereClause} ORDER BY CreatedDate DESC LIMIT 1`;
}

function buildFindManySoql(command, resolvedWhere) {
  const fieldsToReturn = normalizeFieldsToReturn(command.fieldsToReturn);
  const whereClause = command.whereClause
    ? interpolateWhereClause(command.whereClause, resolvedWhere)
    : buildWhereClause(resolvedWhere);
  const limit = Number.isInteger(command.limit) && command.limit > 0 ? command.limit : 50;
  const orderByClause = buildOrderByClause(command.orderBy);

  let soql = `SELECT ${fieldsToReturn.join(", ")} FROM ${command.objectApiName}`;
  if (whereClause) {
    soql += ` WHERE ${whereClause}`;
  }
  soql += orderByClause;
  soql += ` LIMIT ${limit}`;

  return soql;
}

async function executePrefillCommand(command, context, sf) {
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
    const notFoundConfig = normalizeNotFoundConfig(command, context.request || {});

    if (!record && notFoundConfig.action === "error") {
      const message =
        notFoundConfig.message ||
        `No ${command.objectApiName} record found for command '${command.commandKey || "unknown"}'`;
      const error = new Error(message);
      error.code = "NOT_FOUND";
      error.statusCode = 404;
      throw error;
    }

    return {
      success: true,
      type,
      objectApiName: command.objectApiName,
      record
    };
  }

  if (type === "getById") {
    if (!command.objectApiName || !command.id) {
      throw new Error(`getById command '${command.commandKey || "unknown"}' is missing objectApiName or id`);
    }

    const resolvedId = resolveValue(command.id, context);
    if (!resolvedId) {
      throw new Error(`getById command '${command.commandKey || "unknown"}' resolved to blank id`);
    }

    const record = await getSalesforceRecordById(
      instanceUrl,
      accessToken,
      command.objectApiName,
      resolvedId,
      command.fieldsToReturn
    );
    const notFoundConfig = normalizeNotFoundConfig(command, context.request || {});

    if (!record && notFoundConfig.action === "error") {
      const message =
        notFoundConfig.message ||
        `No ${command.objectApiName} record found for command '${command.commandKey || "unknown"}'`;
      const error = new Error(message);
      error.code = "NOT_FOUND";
      error.statusCode = 404;
      throw error;
    }

    return {
      success: true,
      type,
      objectApiName: command.objectApiName,
      record
    };
  }

  if (type === "findMany") {
    if (!command.objectApiName || command.limit == null) {
      throw new Error(`findMany command '${command.commandKey || "unknown"}' is missing objectApiName or limit`);
    }

    const resolvedWhere = command.whereClause ? context : resolveValue(command.where || {}, context);
    const soql = buildFindManySoql(command, resolvedWhere);
    const queryResult = await querySalesforce(instanceUrl, accessToken, soql);
    const records = Array.isArray(queryResult.records) ? queryResult.records : [];

    return {
      success: true,
      type,
      objectApiName: command.objectApiName,
      count: records.length,
      records
    };
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

function storeCommandResult(command, result, context) {
  if (!command.storeResultAs) {
    return;
  }

  if (result.type === "findOne" || result.type === "getById") {
    context[command.storeResultAs] = result.record;
    return;
  }

  if (result.type === "findMany") {
    context[command.storeResultAs] = result.records;
    return;
  }

  context[command.storeResultAs] = result;
}

export const handler = async (event) => {
  try {
    const isDirectPayload =
      !!event &&
      typeof event === "object" &&
      !event?.requestContext &&
      !event?.httpMethod &&
      (event?.request || event?.prefillToken);

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
        message: "NativeForms prefill endpoint is alive"
      });
    }

    if (method !== "POST") {
      return jsonResponse(405, {
        success: false,
        error: `Method ${method} not allowed`
      });
    }

    const payload = isDirectPayload
      ? event
      : event.body
        ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
        : {};

    if (!payload.request || typeof payload.request !== "object") {
      return jsonResponse(400, {
        success: false,
        error: "Missing or invalid 'request' object"
      });
    }

    const request = payload.request;

    if (!request.formId) {
      return jsonResponse(400, {
        success: false,
        error: "Missing required field: request.formId"
      });
    }

    const formSecurity = await getFormSecurityRecord(request.formId);
    ensureFormToken(formSecurity, payload.publishToken, "prefill");
    const prefillDefinition = formSecurity.prefillDefinition;

    const tenantRecord = await ensureActiveTenantForForm(formSecurity);
    const secret = await getSecret(getSalesforceConnectionSecretName(formSecurity.orgId));
    assertSecret(secret);

    const accessToken = await refreshAccessToken(secret, tenantRecord.loginBaseUrl || secret.loginBaseUrl || "https://login.salesforce.com");

    const context = {
      params: request.params || {},
      request: {
        onNotFound: prefillDefinition.onNotFound || "ignore"
      }
    };

    const results = [];

    for (const command of prefillDefinition.commands) {
      try {
        if (!command.type) {
          throw new Error("Each command must include 'type'");
        }

        if (!shouldRunCommand(command.runIf, context)) {
          results.push({
            commandKey: command.commandKey || null,
            type: command.type,
            skipped: true,
            success: true
          });
          continue;
        }

        validatePrefillCommandAgainstPolicy(command, formSecurity);

        const result = await executePrefillCommand(
          command,
          context,
          {
            instanceUrl: secret.instance_url,
            accessToken
          }
        );

        storeCommandResult(command, result, context);

        results.push({
          commandKey: command.commandKey || null,
          type: result.type,
          objectApiName: result.objectApiName || null,
          found: (result.type === "findOne" || result.type === "getById") ? !!result.record : undefined,
          count: result.type === "findMany" ? result.count : undefined,
          records: result.type === "findMany" ? result.records : undefined,
          success: true
        });

      } catch (err) {
        return jsonResponse(400, {
          success: false,
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

    console.log("Context after commands:", JSON.stringify(context));

    const mapped = applyResponseMapping(prefillDefinition.responseMapping, context);
    console.log("Mapped output:", JSON.stringify(mapped));
    
    return jsonResponse(200, buildPrefillResponse({
      formId: request.formId,
      mapped,
      results,
      aliases: buildPrefillAliases(prefillDefinition.commands, context)
    }));

  } catch (error) {
    return jsonResponse(error.statusCode || 500, {
      success: false,
      error: error.message
    });
  }
};
