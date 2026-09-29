# AGENTS.md

Static bilingual (EN/ES) portfolio for Carlos Bustamante at https://carlosbustamante.dev.
Plain HTML + SCSS + vanilla JS on S3/CloudFront. The contact form is a Python Lambda
behind API Gateway, with Google reCAPTCHA Enterprise. All infrastructure is in Terraform.
There's no framework, no bundler, no package.json, and no test suite.

## Layout

```
sites/root/                 # Deployed as-is to S3 (the site root)
  index.html                # English page (all sections in one file)
  es/index.html             # Spanish page (mirror of index.html)
  assets/js/script.js       # English JS
  assets/js/script_es.js    # Spanish JS (same logic, translated strings)
  assets/scss/              # SCSS source: main.scss imports partials _*.scss
  assets/css/main.css       # Compiled CSS (committed; this is what the browser loads)
  assets/images/            # certs/, works/, tech/, flags/, misc images
  assets/files/CV.pdf       # Resume PDFs (CV.pdf = EN, CV_ES.pdf = ES)
  sitemap.xml, robots.txt
  googlee0a7ad9869d1b1e8.html   # Google Search Console verification. Don't delete it.
functions/send_email/
  lambda_function.py        # Contact form handler (python3.12, stdlib + boto3 only)
infra/                      # Terraform: AWS (us-east-1) + Google provider
  s3.tf  cloudfront.tf  route53.tf  contact.tf  recaptcha.tf
  backend.tf                # Remote state: s3://carlosbustamante-ops-terraform-state
  terraform.tfvars          # Gitignored. Holds real values; don't commit it
deploy.sh                   # Syncs sites/root to S3 and invalidates CloudFront
```

## How the pieces connect

- Browser → CloudFront → private S3 bucket through OAC. A CloudFront Function rewrites
  `/path/` and `/path` to `/path/index.html`, which is how `/es/` resolves.
- `www.` → S3 website redirect bucket → 301 to the apex domain.
- Contact form: `onSubmit()` in `script*.js` gets a reCAPTCHA Enterprise token (action
  `submit`) and POSTs JSON to API Gateway `/prod/sendemail`. The Lambda then verifies the
  token with Google (min score 0.5) and sends the message through SES.
- Hardcoded frontend values. If Terraform ever recreates these resources, update them in
  both HTML files and both JS files:
  - API Gateway URL: `https://w8e7rbc1of.execute-api.us-east-1.amazonaws.com/prod/sendemail`
  - reCAPTCHA site key `6LdBoB8q...`: the `enterprise.js?render=` script tag and `execute()`
- The CORS origin `https://carlosbustamante.dev` is hardcoded in `contact.tf` (OPTIONS mock
  response) and set in the Lambda `ALLOWED_ORIGIN` env var.

## Frontend conventions

- Single-page layout. Sections are `<section id="home|about_me|my_resume|my_work|contact_me">`
  inside `<main>`. Nav links (`a.inner-link`) switch the `.active` section.
- Portfolio items are `.item` elements with a `data-groups='["ds-ml","cloud","education"]'`
  attribute, filtered by Shuffle.js. The modal content comes from `data-title`, `data-image`,
  `data-description`, `data-type`, `data-completed`, `data-skills`, and `data-project-link`
  on `.wrap`.
- Libraries load from CDNs. Pinned versions: Bootstrap 5.3.3, Typed.js 2.1.0, Shuffle 6.1.0,
  and Line Awesome 1.3.0 (icons). Bootstrap tags have SRI `integrity` hashes, so update those
  if you bump the version. Fonts (Inter, Montserrat, Fira Code) come from Google Fonts through
  an `@import` in `_fonts.scss`.
- Colors are variables in `_colors.scss`. Use them instead of adding new hex values.
- Keep the accessibility work that's already there: focus-visible styles, modal focus trap,
  and keyboard-openable work items.

## Rules for changes

1. **Keep EN and ES in sync.** Apply every content or markup change to both
   `index.html` and `es/index.html`, and every JS change to both `script.js` and
   `script_es.js`. The ES page uses `../assets/...` paths.
2. **Edit SCSS, then recompile the CSS.** Never hand-edit `main.css`. Sass isn't installed
   globally, so use npx:
   ```bash
   npx sass sites/root/assets/scss/main.scss sites/root/assets/css/main.css
   ```
   Commit the SCSS and the regenerated CSS/map together.
3. **Bump the cache-buster** (`script.js?v=YYYYMMDD-tag`) in both HTML files when you change JS.
4. When page content changes, update `<lastmod>` in `sitemap.xml`. When metadata changes,
   update the JSON-LD block and `<meta>` tags in both HTML files.
5. The Lambda has no dependencies. Terraform `archive_file` zips just the one `.py` file.
   Adding a third-party package would mean changing the packaging in `contact.tf`.
6. `aws_api_gateway_deployment` has no `triggers`. If you change API methods or
   integrations, a new deployment may not be created, so verify the `prod` stage.

## Verify before finishing

```bash
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate
python3 -m py_compile functions/send_email/lambda_function.py
python3 -m http.server 8000 --directory sites/root   # preview at http://localhost:8000 and /es/
```

The contact form won't work from localhost because CORS only allows the production origin.

## High-risk actions (ask the user first)

- `./deploy.sh root` pushes to **production**. It runs `aws s3 sync --delete` against the live
  bucket and invalidates CloudFront distribution `E6VISQC42W7BR`. It skips `assets/scss/`
  and `*.map`.
- `terraform apply` changes live resources and the shared remote state (DNS, CDN, SES, Lambda,
  reCAPTCHA). Run `plan` and show the output first.
- Terraform state and the Lambda env contain the GCP API key. Don't print
  `terraform show`, `terraform state pull`, or Lambda configuration in output.

## Git

- Remote: `github.com/charlybgai/carlosbustamante.dev`. Default branch: `main`.
- Work on feature branches (`feat/...`, `fix/...`) and merge through PRs.
- Commit style: Conventional Commits with a scope, e.g. `feat(site): ...` or `fix(infra): ...`.
