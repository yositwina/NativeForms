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
  "prefillToken": "abc123",
  "request": {
    "formId": "supportForm1",
    "params": {
      "email": "user@example.com"
    },
    "commands": [
      {
        "type": "findOne",
        "commandKey": "findContact",
        "objectApiName": "Contact",
        "where": {
          "Email": "{params.email}"
        },
        "fieldsToReturn": ["Id", "Email", "LastName"],
        "storeResultAs": "foundContact"
      }
    ],
    "responseMapping": {
      "input.email": "{foundContact.Email}",
      "input.lastName": "{foundContact.LastName}",
      "hidden.contactId": "{foundContact.Id}",
      "meta.foundContact": "{foundContact.Id}"
    }
  }
}

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
- Later commands may reference earlier stored results.
- Results are stored under storeResultAs.
- Lambda returns both normalized mapped output and command result summaries.

V1 boundaries
-------------
- Read-only Lambda. No writes.
- findOne and findMany support simple equality filters only.
- findMany supports limit only. No sorting and no pagination yet.
- No arbitrary SOQL from client.
- No business-specific HTML rendering in Lambda.
- No delete / update / create in Prefill Lambda.
*/
import https from "https";
import querystring from "querystring";
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

const EXPECTED_PREFILL_TOKEN = "abc123";
const SECRET_NAME = "NativeForms/SalesforceConnection";
const SALESFORCE_API_VERSION = "v60.0";

const secretsClient = new SecretsManagerClient({});

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

function assertSecret(secret) {
  if (!secret.client_id || !secret.client_secret || !secret.refresh_token || !secret.instance_url) {
    throw new Error("Secret is missing required fields");
  }
}

async function refreshAccessToken(secret) {
  const tokenBody = querystring.stringify({
    grant_type: "refresh_token",
    client_id: secret.client_id,
    client_secret: secret.client_secret,
    refresh_token: secret.refresh_token
  });

  const response = await httpsRequest(
    {
      hostname: "login.salesforce.com",
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

  const normalized = path.replace(/\[(\d+)\]/g, ".$1");
  return normalized.split(".").reduce((acc, key) => {
    if (acc == null) return undefined;
    return acc[key];
  }, obj);
}

function setByPath(obj, path, value) {
  const parts = path.split(".");
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

function parseExpression(expr) {
  const trimmed = expr.trim();

  if (trimmed.startsWith("firstNotBlank(") && trimmed.endsWith(")")) {
    const inner = trimmed.slice("firstNotBlank(".length, -1);
    const args = inner.split(",").map((s) => s.trim()).filter(Boolean);
    return { type: "firstNotBlank", args };
  }

  return { type: "path", path: trimmed };
}

function resolveExpression(expr, context) {
  const parsed = parseExpression(expr);

  if (parsed.type === "path") {
    return getByPath(context, parsed.path);
  }

  if (parsed.type === "firstNotBlank") {
    for (const arg of parsed.args) {
      const value = getByPath(context, arg);
      if (value !== undefined && value !== null && value !== "") {
        return value;
      }
    }
    return null;
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
    for (const [k, v] of Object.entries(value)) {
      out[k] = resolveValue(v, context);
    }
    return out;
  }

  return value;
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

function buildFindOneSoql(command, resolvedWhere) {
  const fieldsToReturn = normalizeFieldsToReturn(command.fieldsToReturn);
  const whereClause = buildWhereClause(resolvedWhere);

  if (!whereClause) {
    throw new Error(`findOne command '${command.commandKey || "unknown"}' requires a non-empty where object`);
  }

  return `SELECT ${fieldsToReturn.join(", ")} FROM ${command.objectApiName} WHERE ${whereClause} ORDER BY CreatedDate DESC LIMIT 1`;
}

function buildFindManySoql(command, resolvedWhere) {
  const fieldsToReturn = normalizeFieldsToReturn(command.fieldsToReturn);
  const whereClause = buildWhereClause(resolvedWhere);
  const limit = Number.isInteger(command.limit) && command.limit > 0 ? command.limit : 50;

  let soql = `SELECT ${fieldsToReturn.join(", ")} FROM ${command.objectApiName}`;
  if (whereClause) {
    soql += ` WHERE ${whereClause}`;
  }
  soql += ` LIMIT ${limit}`;

  return soql;
}

async function executePrefillCommand(command, context, sf) {
  const { instanceUrl, accessToken } = sf;
  const type = command.type;

  if (type === "findOne") {
    if (!command.objectApiName || !command.where) {
      throw new Error(`findOne command '${command.commandKey || "unknown"}' is missing objectApiName or where`);
    }

    const resolvedWhere = resolveValue(command.where, context);
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

    const resolvedWhere = resolveValue(command.where || {}, context);
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

    if (payload.prefillToken !== EXPECTED_PREFILL_TOKEN) {
      return jsonResponse(401, {
        success: false,
        error: "Unauthorized: invalid prefill token"
      });
    }

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

    if (!Array.isArray(request.commands)) {
      return jsonResponse(400, {
        success: false,
        error: "Missing or invalid 'request.commands' array"
      });
    }

    if (!request.responseMapping || typeof request.responseMapping !== "object") {
      return jsonResponse(400, {
        success: false,
        error: "Missing or invalid 'request.responseMapping'"
      });
    }

    const secret = await getSecret(SECRET_NAME);
    assertSecret(secret);

    const accessToken = await refreshAccessToken(secret);

    const context = {
      params: request.params || {}
    };

    const results = [];

    for (const command of request.commands) {
      try {
        if (!command.type) {
          throw new Error("Each command must include 'type'");
        }

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

    const mapped = applyResponseMapping(request.responseMapping, context);
    console.log("Mapped output:", JSON.stringify(mapped));
    
    return jsonResponse(200, {
      success: true,
      formId: request.formId,
      input: mapped.input || {},
      hidden: mapped.hidden || {},
      meta: mapped.meta || {},
      results
    });

  } catch (error) {
    return jsonResponse(500, {
      success: false,
      error: error.message
    });
  }
};
