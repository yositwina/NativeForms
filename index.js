
import {
  SecretsManagerClient,
  CreateSecretCommand,
  PutSecretValueCommand
} from '@aws-sdk/client-secrets-manager';
const secretsClient = new SecretsManagerClient({});

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
export const handler = async (event) => {
  const path = event?.requestContext?.http?.path || event?.rawPath || '/';

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