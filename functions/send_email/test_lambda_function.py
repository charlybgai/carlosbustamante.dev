"""Unit tests for the contact form Lambda. Standard library only (no boto3, no network).

Run from the repo root:
    python3 -m unittest discover -s functions/send_email -v
"""
import importlib
import io
import json
import os
import sys
import types
import unittest
import urllib.error
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))

ENV = {
    "ALLOWED_ORIGIN": "https://carlosbustamante.dev",
    "CONTACT_RECIPIENT": "to@example.com",
    "CONTACT_SENDER": "from@example.com",
    "GCP_API_KEY": "test-key",
    "GCP_PROJECT_ID": "test-project",
    "RECAPTCHA_SITE_KEY": "test-site-key",
}


class FakeClientError(Exception):
    def __init__(self, code):
        super().__init__(code)
        self.response = {"Error": {"Code": code}}


def load_module():
    """Import lambda_function with stand-in boto3/botocore modules."""
    fake_boto3 = types.ModuleType("boto3")
    fake_boto3.client = mock.MagicMock(name="boto3.client")
    fake_botocore = types.ModuleType("botocore")
    fake_exceptions = types.ModuleType("botocore.exceptions")
    fake_exceptions.ClientError = FakeClientError
    fake_botocore.exceptions = fake_exceptions
    modules = {"boto3": fake_boto3, "botocore": fake_botocore, "botocore.exceptions": fake_exceptions}
    with mock.patch.dict(sys.modules, modules), mock.patch.dict(os.environ, ENV):
        sys.path.insert(0, HERE)
        try:
            sys.modules.pop("lambda_function", None)
            module = importlib.import_module("lambda_function")
        finally:
            sys.path.remove(HERE)
    return module, fake_boto3


def valid_body(**overrides):
    body = {
        "name": "Ada Lovelace",
        "email": "ada@example.com",
        "subject": "Hello",
        "message": "I'd like to talk about a role.",
        "g-recaptcha-response": "token-123",
    }
    body.update(overrides)
    return body


def event(body):
    raw = body if isinstance(body, str) else json.dumps(body)
    return {"httpMethod": "POST", "body": raw}


def recaptcha_reply(valid=True, action="submit", score=0.9):
    payload = {"tokenProperties": {"valid": valid, "action": action}, "riskAnalysis": {"score": score}}
    reply = mock.MagicMock()
    reply.__enter__.return_value.read.return_value = json.dumps(payload).encode()
    return reply


class ContactLambdaTests(unittest.TestCase):
    def setUp(self):
        self.lf, self.boto3 = load_module()
        self.ses = mock.MagicMock(name="ses")
        self.boto3.client.return_value = self.ses
        self.urlopen = mock.patch.object(self.lf.urllib.request, "urlopen", return_value=recaptcha_reply()).start()
        self.addCleanup(mock.patch.stopall)
        # Keep the test output clean (the handler logs errors with print)
        mock.patch("builtins.print").start()

    def call(self, body):
        result = self.lf.lambda_handler(event(body), None)
        return result["statusCode"], json.loads(result["body"])

    # --- happy path -------------------------------------------------------------------
    def test_valid_submission_sends_email(self):
        status, body = self.call(valid_body())
        self.assertEqual(status, 200)
        self.assertEqual(body["message"], "Email sent successfully.")
        kwargs = self.ses.send_email.call_args.kwargs
        self.assertEqual(kwargs["Source"], ENV["CONTACT_SENDER"])
        self.assertEqual(kwargs["Destination"], {"ToAddresses": [ENV["CONTACT_RECIPIENT"]]})
        self.assertEqual(kwargs["ReplyToAddresses"], ["ada@example.com"])
        self.assertEqual(kwargs["Message"]["Subject"]["Data"], "New contact message: Hello")

    def test_values_are_trimmed(self):
        status, _ = self.call(valid_body(name="  Ada  ", email=" ada@example.com "))
        self.assertEqual(status, 200)
        self.assertEqual(self.ses.send_email.call_args.kwargs["ReplyToAddresses"], ["ada@example.com"])

    def test_multiline_message_is_allowed(self):
        status, _ = self.call(valid_body(message="Line one\nLine two"))
        self.assertEqual(status, 200)

    def test_values_at_the_maximum_length_are_accepted(self):
        long_email = "a" * 240 + "@example.com"  # 252 chars
        status, _ = self.call(valid_body(name="n" * 100, subject="s" * 150, message="m" * 5000, email=long_email))
        self.assertEqual(status, 200)

    def test_cors_headers_on_every_response(self):
        for body in (valid_body(), valid_body(email="bad")):
            result = self.lf.lambda_handler(event(body), None)
            self.assertEqual(result["headers"]["Access-Control-Allow-Origin"], ENV["ALLOWED_ORIGIN"])

    def test_options_preflight(self):
        result = self.lf.lambda_handler({"httpMethod": "OPTIONS"}, None)
        self.assertEqual(result["statusCode"], 200)
        self.urlopen.assert_not_called()

    # --- rejected input (never reaches reCAPTCHA or SES) ------------------------------
    def assert_rejected(self, body, status=400):
        got, _ = self.call(body)
        self.assertEqual(got, status)
        self.urlopen.assert_not_called()
        self.ses.send_email.assert_not_called()

    def test_missing_or_blank_fields(self):
        for field in ("name", "email", "subject", "message", "g-recaptcha-response"):
            with self.subTest(field=field, case="missing"):
                body = valid_body(); body.pop(field)
                self.assert_rejected(body)
            with self.subTest(field=field, case="blank"):
                self.assert_rejected(valid_body(**{field: "   "}))

    def test_too_long_fields(self):
        cases = {"name": "n" * 101, "subject": "s" * 151, "message": "m" * 5001,
                 "email": "a" * 250 + "@example.com", "g-recaptcha-response": "t" * 4097}
        for field, value in cases.items():
            with self.subTest(field=field):
                self.assert_rejected(valid_body(**{field: value}))

    def test_non_string_fields(self):
        for field, value in (("name", 123), ("email", ["a@b.co"]), ("message", {"x": 1}), ("g-recaptcha-response", None)):
            with self.subTest(field=field):
                self.assert_rejected(valid_body(**{field: value}))

    def test_invalid_email_addresses(self):
        for email in ("plainaddress", "no-at.example.com", "a@b", "a b@example.com", "a@@example.com", "@example.com"):
            with self.subTest(email=email):
                self.assert_rejected(valid_body(email=email))

    def test_header_injection_is_blocked(self):
        for field, value in (("subject", "Hi\r\nBcc: victim@example.com"), ("name", "Ada\nBcc: x@example.com"),
                             ("email", "ada@example.com\nBcc: x@example.com"), ("subject", "Hi\x00there")):
            with self.subTest(field=field, value=value):
                self.assert_rejected(valid_body(**{field: value}))

    def test_body_that_is_not_an_object(self):
        for raw in ('["a", "b"]', '"just a string"', "42", "null"):
            with self.subTest(raw=raw):
                self.assert_rejected(raw)

    def test_invalid_json(self):
        self.assert_rejected("{not json")

    def test_oversized_body(self):
        self.assert_rejected(json.dumps(valid_body(message="m" * 20000)), status=413)

    # --- reCAPTCHA and SES outcomes ---------------------------------------------------
    def test_low_score_is_rejected(self):
        self.urlopen.return_value = recaptcha_reply(score=0.1)
        status, body = self.call(valid_body())
        self.assertEqual(status, 400)
        self.assertIn("reCAPTCHA", body["message"])
        self.ses.send_email.assert_not_called()

    def test_invalid_token_or_wrong_action_is_rejected(self):
        for reply in (recaptcha_reply(valid=False), recaptcha_reply(action="login")):
            with self.subTest(reply=reply):
                self.urlopen.return_value = reply
                status, _ = self.call(valid_body())
                self.assertEqual(status, 400)
        self.ses.send_email.assert_not_called()

    def test_recaptcha_api_failure_is_rejected(self):
        self.urlopen.side_effect = urllib.error.HTTPError("url", 403, "Forbidden", {}, io.BytesIO(b"{}"))
        status, _ = self.call(valid_body())
        self.assertEqual(status, 400)
        self.ses.send_email.assert_not_called()

    def test_ses_error_returns_500(self):
        self.ses.send_email.side_effect = FakeClientError("MessageRejected")
        status, body = self.call(valid_body())
        self.assertEqual(status, 500)
        self.assertEqual(body["message"], "Error sending email.")


if __name__ == "__main__":
    unittest.main()
