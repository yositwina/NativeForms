import os, json, base64, urllib.parse, boto3
import re
from datetime import datetime, timezone  # (optional; only if you log)
TENANT_TABLE = os.environ.get("TENANT_TABLE")

#os.environ.get("ALLOW_ORIGIN"),

def _cors():
    return {
        "Access-Control-Allow-Origin":  "*",
        "Access-Control-Allow-Headers": "content-type, authorization",
        "Access-Control-Allow-Methods": "OPTIONS,POST",
    }
def _cors():
    return {
        # Restrict origin (not needed for Apex, but avoids wildcard finding)
        "Access-Control-Allow-Origin": os.environ.get("ALLOW_ORIGIN", "https://www.harmony-it.co.il" ),

        # Only what you actually need
        "Access-Control-Allow-Headers": "content-type, authorization",
        "Access-Control-Allow-Methods": "OPTIONS,POST",

        # Security headers 
        "X-Content-Type-Options": "nosniff",
        "Strict-Transport-Security": "max-age=63072000; includeSubDomains",
    }

def _resp(code, obj):
    return {"statusCode": code, "headers": _cors(), "body": json.dumps(obj)}

def lambda_handler(event, context):
    # --- Load env vars safely at runtime ---
    S3_BUCKET   = os.environ.get("BUCKET_NAME")
    PUBLIC_BASE = os.environ.get("CLOUDFRONT_BASE")  # e.g. https://d2x...cloudfront.net
    #BEARER      = os.environ.get("SHARED_SECRET")

    # Basic config validation
    #if not S3_BUCKET or not PUBLIC_BASE or not BEARER:
    #    missing = [k for k,v in {"BUCKET":S3_BUCKET, "PUBLIC_BASE":PUBLIC_BASE, "SHARED_SECRET":BEARER}.items() if not v]
    #    return _resp(500, {"error": "server_misconfigured", "missing": missing})
    if not S3_BUCKET or not PUBLIC_BASE or not TENANT_TABLE:
        missing = [k for k,v in {"BUCKET":S3_BUCKET, "PUBLIC_BASE":PUBLIC_BASE, "TENANT_TABLE":TENANT_TABLE}.items() if not v]
        return _resp(500, {"error": "server_misconfigured", "missing": missing})

    # if method != "POST":
    #     return _resp(405, {"error": "method_not_allowed"})

    # Auth
    auth = (event.get("headers") or {}).get("authorization") or ""
    if not auth.startswith("Bearer "):
        return _resp(401, {"error": "missing_bearer"})

    #I changed this for testing, check about the 403 problem...
    # if auth.split(" ", 1)[1].strip() != BEARER:
    #     return _resp(403, {"error": "invalid_bearer"})

    # Parse body (JSON only)
    raw = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw).decode("utf-8")
    try:
        data = json.loads(raw)
    except Exception as e:
        return _resp(400, {"error": "invalid_json"})

    # Inputs from Apex
    org_id      = (data.get("orgId") or "").strip()
    site_Name   = (data.get("site_Name") or data.get("siteName") or "").strip()
    file_name   = (data.get("file") or data.get("fileName") or "").strip()
    contentType = (data.get("contentType") or "text/html; charset=utf-8").strip()
    try:
        expires = int(data.get("expires") or 900)
    except Exception:
        expires = 900

    if not org_id:    return _resp(400, {"error": "missing orgId"})
    if not re.match(r"^00D[A-Za-z0-9]{12,15}$", org_id):
        return _resp(400, {"error": "invalid_orgId"})
    if not site_Name: return _resp(400, {"error": "missing site_Name"})
    if not file_name: return _resp(400, {"error": "missing file"})
    # Auth: validate bearer token against DynamoDB secret for this orgId
    dynamodb = boto3.resource(
        "dynamodb",
        region_name=os.environ.get("DDB_REGION", os.environ.get("AWS_REGION"))
    )
    
    token = auth.split(" ", 1)[1].strip()

    table = dynamodb.Table(TENANT_TABLE)
    tenant = table.get_item(Key={"orgId": org_id}).get("Item")
    if not tenant:
        print("AUTH_FAIL unknown_org", {"orgId": org_id})
        return _resp(403, {"error": "unknown_org"})
    if tenant.get("secret") != token:
       print("AUTH_FAIL invalid_secret", {
            "orgId": org_id,
            "token": token[:12] + "...",
            "storedSecret": tenant.get("secret")[:12] + "..."
        })
       return _resp(403, {"error": "invalid_secret"})

    # Build S3 key
    safe_org  = "".join(c for c in org_id if c.isalnum() or c in "-_")
    # canonical folder name comes from DynamoDB
    canonical_company = (tenant.get("companyName") or "").strip()
    # if missing, initialize it once from site_Name (first publish wins)
    if not canonical_company and site_Name:
        canonical_company = site_Name
        table.update_item(
            Key={"orgId": org_id},
            UpdateExpression="SET companyName = :c",
            ExpressionAttributeValues={":c": canonical_company},
        )
    safe_company = "".join(c for c in canonical_company if c.isalnum() or c in "-_")
    key = f"{safe_company}/{file_name}"
    #safe_site = "".join(c for c in site_Name if c.isalnum() or c in "-_")
    #key       = f"{safe_org}/site/{safe_site}/{file_name}"
    #key       = f"org/{safe_site}/{file_name}"
    #key       = f"{safe_site}/{file_name}"
    # Presign PUT
    s3 = boto3.client("s3")
    try:
        putUrl = s3.generate_presigned_url(
            ClientMethod="put_object",
            Params={"Bucket": S3_BUCKET, "Key": key, "ContentType": contentType},
            ExpiresIn=expires,
            HttpMethod="PUT",
        )
    except Exception as e:
        return _resp(500, {"error": "presign_failed"})

    publicUrl = f"{PUBLIC_BASE}/{key}"
    return _resp(200, {"putUrl": putUrl, "publicUrl": publicUrl, "key": key})
