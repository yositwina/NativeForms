/*
NativeForms Submit Engine - V1 Command Spec

Purpose
-------
Generic Lambda execution engine for Salesforce-backed forms.
The HTML/JS payload does not send business-specific instructions hardcoded in Lambda.
Instead, it sends:
1) input      -> raw user-entered values
2) commands   -> ordered generic actions for Lambda to execute

Top-level payload
-----------------
{
  "formToken": "abc123",
  "input": {
    "email": "user@example.com",
    "problem": "Something is wrong"
  },
  "commands": [
    {
      "type": "findOne",
      "commandKey": "findContact",
      "objectApiName": "Contact",
      "where": {
        "Email": "{input.email}"
      },
      "storeResultAs": "foundContact"
    },
    {
      "type": "create",
      "commandKey": "createContact",
      "runIf": {
        "var": "foundContact.Id",
        "isBlank": true
      },
      "objectApiName": "Contact",
      "fields": {
        "LastName": "{input.email}",
        "Email": "{input.email}"
      },
      "storeResultAs": "createdContact"
    },
    {
      "type": "create",
      "commandKey": "createCase",
      "objectApiName": "Case",
      "fields": {
        "Subject": "Problem Report",
        "Description": "{input.problem}",
        "Origin": "Web",
        "ContactId": "{firstNotBlank(foundContact.Id, createdContact.id)}"
      },
      "storeResultAs": "createdCase"
    }
  ]
}

Execution model
---------------
- Commands run in array order.
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

const EXPECTED_FORM_TOKEN = "abc123";
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
  return path.split(".").reduce((acc, key) => (acc == null ? undefined : acc[key]), obj);
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

  throw new Error(`Unsupported command type: ${type}`);
}

export const handler = async (event) => {
  try {
    const isDirectPayload =
    !!event &&
    typeof event === "object" &&
    !event?.requestContext &&
    !event?.httpMethod &&
    (event?.commands || event?.input || event?.formToken);
  
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
      
    if (inputPayload.formToken !== EXPECTED_FORM_TOKEN) {
      return jsonResponse(401, {
        success: false,
        error: "Unauthorized: invalid form token"
      });
    }

    if (!Array.isArray(inputPayload.commands)) {
      return jsonResponse(400, {
        success: false,
        error: "Missing or invalid 'commands' array"
      });
    }

    const secret = await getSecret(SECRET_NAME);
    assertSecret(secret);

    const accessToken = await refreshAccessToken(secret);

    const context = {
      input: inputPayload.input || {}
    };

    const results = [];

    for (const command of inputPayload.commands) {
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