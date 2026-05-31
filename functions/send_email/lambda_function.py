import json
import os
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

    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return response(400, {"message": "Invalid JSON body."})

    name = body.get("name", "").strip()
    email = body.get("email", "").strip()
    subject = body.get("subject", "").strip()
    message = body.get("message", "").strip()
    recaptcha_token = body.get("g-recaptcha-response", "").strip()

    if not all([name, email, subject, message, recaptcha_token]):
        return response(400, {"message": "Invalid input data."})

    is_valid, score = verify_recaptcha(recaptcha_token, "submit")
    if not is_valid:
        return response(400, {"message": "Invalid reCAPTCHA. Please try again."})

    ses_client = boto3.client("ses", region_name="us-east-1")
    email_subject = f"New contact message: {subject}"
    email_body = (
        "You have received a new contact message:\n\n"
        f"Name: {name}\n"
        f"Email: {email}\n"
        f"Subject: {subject}\n"
        f"Message: {message}\n"
        "\n---\n"
        f"reCAPTCHA Score: {score}"
    )

    try:
        ses_client.send_email(
            Source=CONTACT_SENDER,
            Destination={"ToAddresses": [CONTACT_RECIPIENT]},
            ReplyToAddresses=[email],
            Message={
                "Subject": {"Data": email_subject},
                "Body": {"Text": {"Data": email_body}},
            },
        )
    except ClientError as error:
        print(f"SES error: {error.response['Error'].get('Code', 'UNKNOWN')}")
        return response(500, {"message": "Error sending email."})

    return response(200, {"message": "Email sent successfully."})
