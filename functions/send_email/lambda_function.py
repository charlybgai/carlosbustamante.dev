import json
import os
import re
import urllib.error
import urllib.request

import boto3
from botocore.exceptions import ClientError


ALLOWED_ORIGIN = os.environ["ALLOWED_ORIGIN"]
CONTACT_RECIPIENT = os.environ["CONTACT_RECIPIENT"]
CONTACT_SENDER = os.environ["CONTACT_SENDER"]
GCP_API_KEY = os.environ["GCP_API_KEY"]
GCP_PROJECT_ID = os.environ["GCP_PROJECT_ID"]
RECAPTCHA_SITE_KEY = os.environ["RECAPTCHA_SITE_KEY"]
RECAPTCHA_MIN_SCORE = float(os.environ.get("RECAPTCHA_MIN_SCORE", "0.5"))

# Same limits as the maxlength attributes on the contact form (sites/root/index.html)
MAX_LENGTHS = {"name": 100, "email": 254, "subject": 150, "message": 5000}
# reCAPTCHA tokens are about 2 KB; anything far larger isn't a real token
MAX_TOKEN_LENGTH = 4096
# API Gateway rejects nothing by size here, so cap the raw body before parsing it
MAX_BODY_BYTES = 16 * 1024

# Pragmatic address check (the browser already validates type="email"): one @, no spaces,
# a dot in the domain. It's not RFC 5322, it just keeps garbage out of Reply-To.
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
# Characters that could split an email header (Subject / Reply-To)
HEADER_BREAKS = re.compile(r"[\r\n\x00]")


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Allow-Methods": "OPTIONS,POST",
            "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
            "Content-Type": "application/json",
        },
        "body": json.dumps(body),
    }


def validate_input(body):
    """Return (fields, error). fields holds the cleaned values when error is None."""
    if not isinstance(body, dict):
        return None, "Invalid input data."

    fields = {}
    for name, max_length in MAX_LENGTHS.items():
        value = body.get(name, "")
        if not isinstance(value, str):
            return None, "Invalid input data."
        value = value.strip()
        if not value or len(value) > max_length:
            return None, "Invalid input data."
        fields[name] = value

    token = body.get("g-recaptcha-response", "")
    if not isinstance(token, str) or not token.strip() or len(token) > MAX_TOKEN_LENGTH:
        return None, "Invalid input data."
    fields["token"] = token.strip()

    # These end up in email headers, so they must be a single line
    for name in ("name", "email", "subject"):
        if HEADER_BREAKS.search(fields[name]):
            return None, "Invalid input data."

    if not EMAIL_RE.match(fields["email"]):
        return None, "Invalid email address."

    return fields, None


def verify_recaptcha(token, action):
    url = (
        "https://recaptchaenterprise.googleapis.com/v1/"
        f"projects/{GCP_PROJECT_ID}/assessments?key={GCP_API_KEY}"
    )
    payload = {
        "event": {
            "token": token,
            "siteKey": RECAPTCHA_SITE_KEY,
            "expectedAction": action,
        }
    }

    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )

    try:
        with urllib.request.urlopen(request, timeout=5) as result:
            assessment = json.loads(result.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        error_body = error.read().decode("utf-8", errors="replace")
        print(f"reCAPTCHA API HTTP {error.code}: {error_body}")
        return False, 0.0
    except urllib.error.URLError as error:
        print(f"reCAPTCHA API error: {error}")
        return False, 0.0

    token_properties = assessment.get("tokenProperties", {})
    if not token_properties.get("valid", False):
        print(f"Token invalid: {token_properties.get('invalidReason', 'UNKNOWN')}")
        return False, 0.0

    if token_properties.get("action") != action:
        print(f"Action mismatch: expected {action}, got {token_properties.get('action')}")
        return False, 0.0

    score = assessment.get("riskAnalysis", {}).get("score", 0.0)
    return score >= RECAPTCHA_MIN_SCORE, score


def lambda_handler(event, context):
    if event.get("httpMethod") == "OPTIONS":
        return response(200, {"message": "OK"})

    raw_body = event.get("body") or "{}"
    if len(raw_body.encode("utf-8")) > MAX_BODY_BYTES:
        return response(413, {"message": "Request too large."})

    try:
        body = json.loads(raw_body)
    except json.JSONDecodeError:
        return response(400, {"message": "Invalid JSON body."})

    fields, error = validate_input(body)
    if error:
        return response(400, {"message": error})

    is_valid, score = verify_recaptcha(fields["token"], "submit")
    if not is_valid:
        return response(400, {"message": "Invalid reCAPTCHA. Please try again."})

    ses_client = boto3.client("ses", region_name="us-east-1")
    email_subject = f"New contact message: {fields['subject']}"
    email_body = (
        "You have received a new contact message:\n\n"
        f"Name: {fields['name']}\n"
        f"Email: {fields['email']}\n"
        f"Subject: {fields['subject']}\n"
        f"Message: {fields['message']}\n"
        "\n---\n"
        f"reCAPTCHA Score: {score}"
    )

    try:
        ses_client.send_email(
            Source=CONTACT_SENDER,
            Destination={"ToAddresses": [CONTACT_RECIPIENT]},
            ReplyToAddresses=[fields["email"]],
            Message={
                "Subject": {"Data": email_subject},
                "Body": {"Text": {"Data": email_body}},
            },
        )
    except ClientError as error:
        print(f"SES error: {error.response['Error'].get('Code', 'UNKNOWN')}")
        return response(500, {"message": "Error sending email."})

    return response(200, {"message": "Email sent successfully."})
