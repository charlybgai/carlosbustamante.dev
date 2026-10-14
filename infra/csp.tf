# Enforced since 2026-10 after a clean report-only period (Chromium and Firefox checked live).
# Keep the readable template shared with tools/check_csp.py and the browser check.
locals {
  content_security_policy = join(" ", split("\n", trimspace(templatefile("${path.module}/csp-policy.txt", {
    contact_api_origin = "https://${split("/", aws_api_gateway_stage.prod.invoke_url)[2]}"
    contact_form_url   = "${aws_api_gateway_stage.prod.invoke_url}/sendemail"
  }))))
}
