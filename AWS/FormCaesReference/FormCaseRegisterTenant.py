import os
import json
import secrets
import re
import boto3
import base64
from datetime import datetime, timezone

SES_REGION = os.environ.get("SES_REGION", "eu-north-1")
SES_FROM   = os.environ.get("SES_FROM")  # e.g. noreply@formcase.io

ses = boto3.client("ses", region_name=SES_REGION)

def send_secret_email(to_address, org_id, secret):
    if not SES_FROM:
        print("SES_FROM not configured; email skipped")
        return

    ses.send_email(
        Source=SES_FROM,
        Destination={"ToAddresses": [to_address]},
        Message={
            "Subject": {"Data": "Your FormCase secret"},
            "Body": {
                "Text": {
                    "Data": f"""Hello,

Your FormCase secret for Salesforce org {org_id} is:

{secret}

Paste this value into Salesforce → External Credential.

If you did not request this, you can safely ignore this email.

— FormCase
"""
                }
            }
        }
    )


# Explicitly define the DynamoDB region ---
# Your Lambda is in 'eu-north-1' but your table is in 'us-east-1'
dynamodb = boto3.resource(
    "dynamodb",
    region_name=os.environ.get("DDB_REGION", os.environ.get("AWS_REGION"))
)

# Ensure "TENANT_TABLE" is set in Configuration > Environment Variables
TENANT_TABLE = os.environ["TENANT_TABLE"]


def _cors():
    return {
        "Access-Control-Allow-Origin": os.environ.get("ALLOW_ORIGIN", "https://www.harmony-it.co.il"),
        "Access-Control-Allow-Headers": "content-type",
        "Access-Control-Allow-Methods": "OPTIONS,POST",
        # Security headers (fix ZAP findings)
        "X-Content-Type-Options": "nosniff",
        "Strict-Transport-Security": "max-age=63072000; includeSubDomains",
    }

def _resp(code, obj):
    """Builds a complete HTTP response with CORS headers."""
    return {
        "statusCode": code,
        "headers": _cors(),
        "body": json.dumps(obj),
    }


def lambda_handler(event, context):
    # --- Handle CORS preflight "OPTIONS" request ---
    method = (
        event.get("requestContext", {}).get("http", {}).get("method")
        or event.get("httpMethod", "")
    ).upper()
    path = (
        event.get("rawPath")
        or event.get("requestContext", {}).get("http", {}).get("path")
        or ""
    )

    if method == "OPTIONS":
        return {"statusCode": 204, "headers": _cors(), "body": ""}
    if path and path != "/register":
        return _resp(404, {"ok": False, "error": "not_found", "message": f"Unknown path: {path}"})

    #  Top-level try/except ---
    # Catches all crashes (like IAM errors) and returns a valid
    # JSON response with CORS headers, preventing fake "CORS" errors.
    try:
        # --- Parse JSON body ---
        raw = event.get("body") or "{}"
        if event.get("isBase64Encoded"):
            raw = base64.b64decode(raw).decode("utf-8")

        try:
            data = json.loads(raw)
        except Exception as e:
            return _resp(400, {"error": "invalid_json", "message": str(e)})

        # --- FIX 3: GUARANTEED PARSING ---
        # This code correctly looks for the "orgId" key
        # (with a capital 'I') that the client is sending.
        org_id = (data.get("orgId") or "").strip()
        email = (data.get("email") or "").strip()
        company_name = (data.get("companyName") or "").strip()

        # --- Basic validation ---
        if not org_id:
            # This is the error you were seeing.
            # It was triggered because the deployed code
            # was looking for the wrong key (e.g., "org_id").
            return _resp(400, {"ok": False, "error": "missing_orgId", "message": "orgId is required"})
        
        if not re.match(r"^00D[A-Za-z0-9]{12,15}$", org_id):
            return _resp(400, {"error": "invalid_orgId", "message": "Must be 12-15 char Org ID starting with 00D"})
        
        if not email or "@" not in email:
            return _resp(400, {"error": "invalid_email"})

        table = dynamodb.Table(TENANT_TABLE)
        # --- Check if org already exists ---
        existing = table.get_item(Key={"orgId": org_id}).get("Item")
        
        if existing:
            # Add Company name to older records 
            if company_name and not (existing.get("companyName") or "").strip():
                table.update_item(
                    Key={"orgId": org_id},
                    UpdateExpression="SET companyName = :c",
                    ExpressionAttributeValues={":c": company_name},
                )
            stored_email = (existing.get("email") or "").strip().lower()
            provided_email = email.strip().lower()
            if not stored_email:
                return _resp(409, {"error": "already_registered", "message": "Org already registered."})

            # If someone tries a different email, don't leak info
            if provided_email != stored_email:
                return _resp(200, {"ok": True, "message": "If this org is registered, the secret was sent to the admin email on file."})

            #print("Exsiting ORG", org_id)
            secret = existing.get("secret")
            if secret:
                send_secret_email(to_address=stored_email, org_id=org_id, secret=secret)  # implement with SES/SendGrid
                return _resp(200, {"ok": True, "alreadyRegistered": True, "message": "Secret sent to the admin email on file."})

        # --- Org does not exist, create new entry ---
        secret = secrets.token_urlsafe(32)
        now_iso = datetime.now(timezone.utc).isoformat()

        table.put_item(
            Item={
                "companyName": company_name,
                "orgId": org_id,
                "email": email,
                "secret": secret,
                "createdAt": now_iso,
            }
        )
        send_secret_email(
            to_address=email,
            org_id=org_id,
            secret=secret
        )

        return _resp(200, {"ok": True, "message": "Secret generated and sent to your email."})

    except Exception as e:
        # This block catches all other crashes
        print(f"UNHANDLED EXCEPTION: {str(e)}")
        return _resp(500, {"error": "internal_server_error"})