# Carlos Bustamante - Cloud & MLOps Engineer Portfolio

Personal portfolio website for **Carlos Bustamante**, Cloud & MLOps Engineer, hosted at
[carlosbustamante.dev](https://carlosbustamante.dev) (English) and
[carlosbustamante.dev/es/](https://carlosbustamante.dev/es/) (Spanish).

## Project Structure

```
carlosbustamante.dev/
├── sites/root/          # Static site deployed to S3 (EN at /, ES at /es/, 404.html)
├── functions/send_email # Python Lambda behind the contact form, with its unit tests
├── infra/               # Terraform (AWS + Google reCAPTCHA Enterprise)
├── cv/                  # LaTeX sources of the CVs and their build script
├── tools/               # Build scripts for the Bootstrap subset and the icon sprite
└── deploy.sh            # Uploads the site to S3 and invalidates CloudFront
```

## Technologies

### Frontend
- **HTML5**: semantic, accessible markup (one page per language)
- **SCSS**: design tokens and partials, compiled to `assets/css/main.css`
- **JavaScript**: vanilla, one shared script (section routing, filters, modal, contact form)
- **Bootstrap 5** grid and modal, **Shuffle.js** filters, **Typed.js** hero animation
- CSS, fonts (Inter, Montserrat, Fira Code) and icons (Line Awesome as an SVG sprite) are served
  from the site itself, so a slow CDN can't block the page

### Infrastructure
- **Terraform**: all infrastructure as code, remote state in S3
- **AWS S3 + CloudFront**: private buckets behind CloudFront, compression and security headers at the edge
- **AWS Route 53**: IPv4/IPv6 DNS, plus a `www` → apex redirect
- **API Gateway + Lambda + SES**: serverless contact form, with CloudWatch alarms on failures
- **Google reCAPTCHA Enterprise**: spam protection for the form, with a daily assessment cap

## Local development

```bash
# Rebuild CSS after editing SCSS
npx sass@1.105.0 sites/root/assets/scss/main.scss sites/root/assets/css/main.css

# Preview
python3 -m http.server 8000 --directory sites/root

# Lambda unit tests (no dependencies needed)
python3 -m unittest discover -s functions/send_email

# Rebuild the CV PDFs (needs Docker)
./cv/build.sh
```

`tools/build-bootstrap.sh`, `tools/build-icons.py` and `tools/build-favicons.py` regenerate
`assets/css/bootstrap.css`, the `assets/images/icons.svg` sprite, and the favicons plus sidebar
logo; you only need them when changing those. See [AGENTS.md](AGENTS.md) for conventions and checks.

## Deployment

Merging to `main` deploys automatically: after every CI job passes, the `deploy` job assumes the
deploy-only `portfolio-github-deploy` role through GitHub OIDC (no stored AWS keys) and runs
`./deploy.sh root`. One-time setup after `terraform apply` creates the role:

1. In the repo settings, create the environment `production` and limit its deployment branches
   to `main` (optionally add yourself as a required reviewer for a manual gate).
2. Save `terraform -chdir=infra output -raw github_deploy_role_arn` as the repository variable
   `AWS_DEPLOY_ROLE_ARN`. The deploy job is skipped until it exists.

The content bucket is versioned (old versions are kept 30 days), so a bad file can be restored
from S3; usually reverting the commit is simpler, since CI redeploys it.

To deploy by hand, sign in with the limited portfolio deploy role. `deploy.sh` selects this
profile by default and checks the active role before accessing production.

```bash
aws sso login --profile portfolio-deploy
./deploy.sh root --dryrun   # checks + list of changed files, changes nothing
./deploy.sh root            # from a clean main that matches origin/main
```

## Infrastructure

Use the administrative SSO profile for Terraform. The AWS CLI will prompt for a new browser
sign-in when the SSO session expires.

```bash
export AWS_PROFILE=portfolio-admin
aws sso login --profile "$AWS_PROFILE"
cd infra
terraform init
terraform plan
terraform apply
```

### CI checks

Every pull request and push to `main` runs Terraform formatting/validation and offline regression tests, Lambda unit tests,
JavaScript syntax and HTML validation, SCSS compilation comparison, ShellCheck, and offline
cache-buster checks. Jobs use pinned actions, read-only repository permissions, and no cloud
credentials. Standard GitHub runners are free for this public repository.

```bash
./deploy.sh root --check-only   # offline; checks EN, ES and 404 asset tags
python3 -m unittest discover -s tools -p 'test_*.py'
```

The offline check verifies tag consistency and missing tags. The deployment dry run also
compares assets with S3 to detect a changed file whose tag was not bumped.

### CSP and certificate monitoring

`infra/csp-policy.txt` is the source for the **report-only** CloudFront CSP header. It allows
the pinned CDN library paths, Google's reCAPTCHA sources and the contact API. The frontend
keeps inline JavaScript limited to the hashed first-paint helper; Typed.js cursor styles are
compiled from SCSS. CI checks the hashes and exercises EN, ES and 404 in Chromium, including
navigation, filters, modal focus, motion pause and a contact submission intercepted before AWS.

```bash
python3 tools/check_csp.py
python3 -m pip install playwright==1.58.0
python3 -m playwright install chromium
python3 tools/check_csp_browser.py
# Localhost is allowed by the real reCAPTCHA key; the API is still intercepted:
python3 tools/check_csp_browser.py --real-recaptcha
# After the approved production apply/deploy, verify the actual report-only header:
python3 tools/check_csp_browser.py --live --real-recaptcha
```

Browser checks use real CDN libraries with the page's SRI checks. Google is mocked by default;
`--real-recaptcha` loads Google's real script and requests a token but never sends an email.
No public CSP report receiver is created. Inspect violation events locally and on production,
then repeat after about a week before proposing enforcement in a separate PR.

`infra/certificates.tf` alarms on fewer than 30 days remaining for the exact ACM certificates
configured on CloudFront. A daily window matches ACM's twice-daily metrics; missing samples
preserve the previous state, including after expiration. Alerts and recovery use the existing
confirmed SNS topic. ACM certificates remain externally managed. This does not monitor domain
registration expiry; keep auto-renew enabled at the registrar.

Incremental cost: no fee for CSP headers or additional IPv6 alias records; two standard
CloudWatch alarms add at most about **$0.20/month** before shared allowances and occasional
notification charges. There is no paid uptime health check in this batch.

### Account security baseline

`infra/security.tf` defines a free external-access IAM Access Analyzer and one multi-region
CloudTrail trail with management events, log validation, and 90-day retention in a private
SSE-S3 bucket. CloudTrail's first management-event copy is free; S3 storage and requests are
billed by usage. Paid data-event analysis, Insights and CloudWatch log delivery are disabled.
Review Access Analyzer findings before archiving any of them.

`infra/signin.tf` sends recognized root and `Charly` console sign-in attempts to the existing
`contact-form-alerts` email subscription. Regional EventBridge rules forward matching events
to `us-east-1`; IAM roles allow only that event bus and SNS topic. `infra/signin-regions.tf`
covers all 17 regions enabled during setup. When enabling another region, add its provider,
forwarding module, and trust-policy ARN list entry. CloudTrail still records activity in all
enabled regions. Failed sign-ins that AWS reports with a hidden identity cannot be matched
to a specific user. EventBridge cross-region delivery and SNS requests incur usage charges;
these should be negligible for occasional sign-ins.

These resources become active after the reviewed Terraform plan is applied. Verify trail
logging and delivery, validate its first log files, review analyzer findings, and test a
`Charly` sign-in to confirm the notification arrives. Do not sign in as root just to test.

### Terraform state bucket protections

`infra/bootstrap/` is a separate configuration with local state. It manages only the existing
state bucket's TLS-only policy and lifecycle, without importing the bucket or the site's
state. Keep its local state in a secure backup; it is gitignored and must not be committed.

```bash
export AWS_PROFILE=portfolio-admin
terraform -chdir=infra/bootstrap init
terraform -chdir=infra/bootstrap plan
# After reviewing and approving the plan:
terraform -chdir=infra/bootstrap apply
terraform -chdir=infra plan   # immediately verify state access still works
```

The lifecycle keeps the newest 10 noncurrent versions per object under `portfolio/`, expires
older noncurrent versions after 90 days, removes expired delete markers, and aborts incomplete
uploads after 7 days. Current state is never expired. Removing historical versions is permanent
once S3 executes the lifecycle. TLS-only access and shorter retention add no recurring fees.
`prevent_destroy` guards both settings and the audit bucket against accidental Terraform removal.
For emergency recovery from an incorrect bucket policy, an administrator can delete the policy
with `aws s3api delete-bucket-policy --bucket carlosbustamante-ops-terraform-state`, then correct
and reapply it from the bootstrap configuration.

## Acknowledgements

The original layout of the portfolio was based on the course offered by **Cheetah Academy** on Udemy:

[Responsive Portfolio Website using HTML5, CSS3, JavaScript & Bootstrap5](https://www.udemy.com/course/responsive-portfolio-website-using-html5-css3-javascript-bootstrap5/)
