
import {
  SecretsManagerClient,
  CreateSecretCommand,
  PutSecretValueCommand,
  GetSecretValueCommand
} from '@aws-sdk/client-secrets-manager';
import {
  DynamoDBClient,
  GetItemCommand,
  PutItemCommand
} from '@aws-sdk/client-dynamodb';
import crypto from 'crypto';
const secretsClient = new SecretsManagerClient({});
const dynamoClient = new DynamoDBClient({});
const FORM_SECURITY_TABLE = process.env.FORM_SECURITY_TABLE || 'NativeFormsFormSecurity';

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
    if (e.name === 'ResourceExistsException') {
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

function jsonResponse(statusCode, payload) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    },
    body: JSON.stringify(payload)
  };
}

function hashToken(token) {
  return crypto.createHash('sha256').update(String(token)).digest('hex');
}

function toAttributeValue(value) {
  if (value === null) return { NULL: true };
  if (typeof value === 'string') return { S: value };
  if (typeof value === 'number') return { N: String(value) };
  if (typeof value === 'boolean') return { BOOL: value };
  if (Array.isArray(value)) return { L: value.map(toAttributeValue) };
  if (value && typeof value === 'object') {
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

async function getFormSecurityRecord(formId) {
  const result = await dynamoClient.send(new GetItemCommand({
    TableName: FORM_SECURITY_TABLE,
    Key: {
      formId: { S: formId }
    }
  }));

  return result.Item ? unmarshallItem(result.Item) : null;
}

async function saveFormSecurityRecord(record) {
  await dynamoClient.send(new PutItemCommand({
    TableName: FORM_SECURITY_TABLE,
    Item: marshallItem(record)
  }));
}

function validateFormSecurityPayload(payload) {
  if (!payload?.formId) throw new Error('Missing required field: formId');
  if (!payload?.publishToken) throw new Error('Missing required field: publishToken');
  if (!payload?.publishedVersionId) throw new Error('Missing required field: publishedVersionId');
  if (!payload?.status) throw new Error('Missing required field: status');
  if (!payload?.securityMode) throw new Error('Missing required field: securityMode');
  if (!payload?.prefillPolicy || typeof payload.prefillPolicy !== 'object') {
    throw new Error('Missing required field: prefillPolicy');
  }
  if (!payload?.submitPolicy || typeof payload.submitPolicy !== 'object') {
    throw new Error('Missing required field: submitPolicy');
  }
  if (!payload?.prefillDefinition || typeof payload.prefillDefinition !== 'object') {
    throw new Error('Missing required field: prefillDefinition');
  }
  if (!Array.isArray(payload.prefillDefinition.commands)) {
    throw new Error('Missing required field: prefillDefinition.commands');
  }
  if (!payload.prefillDefinition.responseMapping || typeof payload.prefillDefinition.responseMapping !== 'object') {
    throw new Error('Missing required field: prefillDefinition.responseMapping');
  }
  if (!payload?.submitDefinition || typeof payload.submitDefinition !== 'object') {
    throw new Error('Missing required field: submitDefinition');
  }
  if (!Array.isArray(payload.submitDefinition.commands)) {
    throw new Error('Missing required field: submitDefinition.commands');
  }
}
export const handler = async (event) => {
  const path = event?.requestContext?.http?.path || event?.rawPath || '/';
  const method = event?.requestContext?.http?.method || event?.httpMethod || 'GET';

  if (method === 'OPTIONS') {
    return jsonResponse(200, { success: true });
  }

  if (path === '/connect') {
    const clientId = process.env.SF_CLIENT_ID;
    const redirectUri = process.env.SF_REDIRECT_URI;
    const loginUrl = process.env.SF_LOGIN_URL || 'https://login.salesforce.com';

    const authUrl =
      `${loginUrl}/services/oauth2/authorize` +
      `?response_type=code` +
      `&client_id=${encodeURIComponent(clientId)}` +
      `&redirect_uri=${encodeURIComponent(redirectUri)}`;

    return {
      statusCode: 302,
      headers: {
        Location: authUrl
      },
      body: ''
    };
  }

  if (path === '/oauth/callback') {
    const code = event?.queryStringParameters?.code;
    const error = event?.queryStringParameters?.error;
    const errorDescription = event?.queryStringParameters?.error_description;

    if (error) {
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'text/html' },
        body: `
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <h2>OAuth Callback Error</h2>
              <p><b>Error:</b> ${error}</p>
              <p><b>Description:</b> ${errorDescription || ''}</p>
            </body>
          </html>
        `
      };
    }

    if (!code) {
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'text/html' },
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

    const clientId = process.env.SF_CLIENT_ID;
    const clientSecret = process.env.SF_CLIENT_SECRET;
    const redirectUri = process.env.SF_REDIRECT_URI;
    const loginUrl = process.env.SF_LOGIN_URL || 'https://login.salesforce.com';

    try {
      const tokenUrl = `${loginUrl}/services/oauth2/token`;

      const params = new URLSearchParams();
      params.append('grant_type', 'authorization_code');
      params.append('client_id', clientId);
      params.append('client_secret', clientSecret);
      params.append('redirect_uri', redirectUri);
      params.append('code', code);

      const tokenResponse = await fetch(tokenUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: params.toString()
      });

      const tokenData = await tokenResponse.json();

      console.log('Token response status:', tokenResponse.status);
      console.log('Token response body:', JSON.stringify(tokenData));

      if (!tokenResponse.ok) {
        return {
          statusCode: 200,
          headers: { 'Content-Type': 'text/html' },
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
      const secretName = 'NativeForms/SalesforceConnection';

      const saveResult = await saveSalesforceConnection(secretName, {
        client_id: clientId,
        client_secret: clientSecret,
        refresh_token: tokenData.refresh_token || null,
        instance_url: tokenData.instance_url || null,
        id_url: tokenData.id || null,
        token_issued_at: tokenData.issued_at || null,
        updated_at: new Date().toISOString()
      });

      return {
        statusCode: 200,
        headers: { 'Content-Type': 'text/html' },
        body: `
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
              <h2>Salesforce Connected Successfully</h2>
              <p><b>Access token received:</b> ${tokenData.access_token ? 'Yes' : 'No'}</p>
              <p><b>Refresh token received:</b> ${tokenData.refresh_token ? 'Yes' : 'No'}</p>
              <p><b>Instance URL:</b> ${tokenData.instance_url || '(none)'}</p>
              <p><b>ID URL:</b> ${tokenData.id || '(none)'}</p>
              <p><b>Secret saved:</b> Yes</p>
              <p><b>Secret name:</b> ${secretName}</p>
              <p><b>Created new secret:</b> ${saveResult.created ? 'Yes' : 'No'}</p>
              <p><b>Updated existing secret:</b> ${saveResult.updated ? 'Yes' : 'No'}</p>
            </body>
          </html>
        `
      };
    } catch (e) {
      console.error('OAuth callback exception:', e);

      return {
        statusCode: 500,
        headers: { 'Content-Type': 'text/html' },
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

  if (path === '/forms/register' && method === 'POST') {
    try {
      const payload = event?.body
        ? (typeof event.body === 'string' ? JSON.parse(event.body) : event.body)
        : {};

      validateFormSecurityPayload(payload);

      const now = new Date().toISOString();
      let createdAt = now;
      const existing = await getFormSecurityRecord(payload.formId);
      if (existing) {
        createdAt = existing.createdAt || now;
      }

      const record = {
        formId: payload.formId,
        publishedVersionId: payload.publishedVersionId,
        status: payload.status,
        securityMode: payload.securityMode,
        rateLimitProfile: payload.rateLimitProfile || 'standard',
        tokenHash: hashToken(payload.publishToken),
        prefillPolicy: payload.prefillPolicy,
        submitPolicy: payload.submitPolicy,
        prefillDefinition: payload.prefillDefinition,
        submitDefinition: payload.submitDefinition,
        createdAt,
        updatedAt: now
      };

      await saveFormSecurityRecord(record);

      return jsonResponse(200, {
        success: true,
        tableName: FORM_SECURITY_TABLE,
        created: !existing,
        updated: !!existing,
        record
      });
    } catch (e) {
      return jsonResponse(400, {
        success: false,
        error: e.message
      });
    }
  }

  if (path.startsWith('/forms/') && path.endsWith('/security') && method === 'GET') {
    try {
      const formId = path.split('/')[2];
      if (!formId) {
        throw new Error('Missing formId in path');
      }

      const record = await getFormSecurityRecord(formId);
      if (!record) {
        throw new Error('Form security record not found');
      }
      return jsonResponse(200, {
        success: true,
        record
      });
    } catch (e) {
      return jsonResponse(404, {
        success: false,
        error: e.message
      });
    }
  }

  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'text/html'
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
