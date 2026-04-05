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

function isSubscriptionEnded(subscriptionEndDate) {
  if (!subscriptionEndDate) {
    return false;
  }

  const end = new Date(`${subscriptionEndDate}T23:59:59.999Z`);
  return !Number.isNaN(end.getTime()) && end.getTime() < Date.now();
}

function ensureFormToken(formSecurity, publishToken) {
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

  if (!formSecurity.submitPolicy) {
    const error = new Error("Submit policy is not configured for this form");
    error.statusCode = 403;
    throw error;
  }

  if (!formSecurity.submitDefinition || !Array.isArray(formSecurity.submitDefinition.commands)) {
    const error = new Error("Submit definition is not configured for this form");
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
  if (!tenantRecord) {
    const error = new Error("Owning tenant was not found");
    error.statusCode = 403;
    throw error;
  }

  if (tenantRecord.status !== "active" || tenantRecord.isActive === false) {
    const error = new Error("Data could not be updated in Salesforce because the subscription is not active.");
    error.statusCode = 403;
    throw error;
  }

  if (isSubscriptionEnded(tenantRecord.subscriptionEndDate)) {
    const error = new Error("Data could not be updated in Salesforce because the subscription has ended.");
    error.statusCode = 403;
    throw error;
  }

  return tenantRecord;
}

function isRiskySubmitCommand(commandType) {
  return ["update", "delete", "upsertMany"].includes(commandType);
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

  if (isRiskySubmitCommand(command.type) && formSecurity.securityMode !== "secure-edit") {
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
    throw new Error(`Token refresh failed. Status: ${response.statusCode}. Body: ${response.body}`);
  }

  return JSON.parse(response.body).access_token;
}

function assertSecret(secret) {
  if (!secret.client_id || !secret.client_secret || !secret.refresh_token || !secret.instance_url) {
    throw new Error("Secret is missing required fields");
  }
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
    throw new Error(`Create failed. Status: ${response.statusCode}. Body: ${response.body}`);
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
    throw new Error(`Update failed. Status: ${response.statusCode}. Body: ${response.body}`);
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
    throw new Error(`Delete failed. Status: ${response.statusCode}. Body: ${response.body}`);
  }

  return { id, success: true };
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
    const resolvedFields = resolveValue(command.fields, rowContext);

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

  const filters = Object.entries(resolvedWhere || {});

  if (filters.length === 0) {
    throw new Error(`findOne command '${command.commandKey || "unknown"}' requires a non-empty where object`);
  }

  const whereClause = filters
    .map(([fieldName, value]) => {
      if (value === null) return `${fieldName} = null`;
      if (typeof value === "number" || typeof value === "boolean") return `${fieldName} = ${value}`;
      return `${fieldName} = '${escapeSoqlValue(value)}'`;
    })
    .join(" AND ");

  return `SELECT ${fieldsToReturn.join(", ")} FROM ${objectApiName} WHERE ${whereClause} ORDER BY CreatedDate DESC LIMIT 1`;
}

async function executeCommand(command, context, sf) {
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

  if (type === "create") {
    if (!command.objectApiName || !command.fields) {
      throw new Error(`create command '${command.commandKey || "unknown"}' is missing objectApiName or fields`);
    }

    const resolvedFields = resolveValue(command.fields, context);
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

    const resolvedFields = resolveValue(command.fields, context);
    const id = command.id ? resolveValue(command.id, context) : resolvedFields.Id;

    if (!id) {
      throw new Error(`update command '${command.commandKey || "unknown"}' requires id or fields.Id`);
    }

    const fieldsToUpdate = { ...resolvedFields };
    delete fieldsToUpdate.Id;

    const updateResult = await updateSalesforceRecord(instanceUrl, accessToken, command.objectApiName, id, fieldsToUpdate);

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

export const handler = async (event) => {
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
  
  const inputPayload = isDirectPayload
    ? event
    : event.body
      ? (typeof event.body === "string" ? JSON.parse(event.body) : event.body)
      : {};
      
    if (!inputPayload.formId) {
      return jsonResponse(400, {
        success: false,
        error: "Missing required field: formId"
      });
    }

    const formSecurity = await getFormSecurityRecord(inputPayload.formId);
    ensureFormToken(formSecurity, inputPayload.publishToken);
    const tenantRecord = await ensureActiveTenantForForm(formSecurity);
    const submitCommands = formSecurity.submitDefinition.commands;

    const secret = await getSecret(getSalesforceConnectionSecretName(formSecurity.orgId));
    assertSecret(secret);

    const accessToken = await refreshAccessToken(secret, tenantRecord.loginBaseUrl || secret.loginBaseUrl || "https://login.salesforce.com");

    const context = {
      input: inputPayload.input || {}
    };

    const results = [];

    for (const command of submitCommands) {
      try {
    
        if (!command.type) {
          throw new Error("Each command must include 'type'");
        }

        validateSubmitCommandAgainstPolicy(command, formSecurity);
    
        if (!shouldRunCommand(command.runIf, context)) {
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
            context[command.storeResultAs] = result;
          }
        }
    
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

    return jsonResponse(200, {
      success: true,
      results
    });
  } catch (error) {
    return jsonResponse(500, {
      success: false,
      error: error.message
    });
  }
};
