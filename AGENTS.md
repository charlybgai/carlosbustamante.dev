# AGENTS.md

Static bilingual (EN/ES) portfolio for Carlos Bustamante at https://carlosbustamante.dev.
Plain HTML + SCSS + vanilla JS on S3/CloudFront. The contact form is a Python Lambda
behind API Gateway, with Google reCAPTCHA Enterprise. All infrastructure is in Terraform.
There's no framework, no bundler and no package.json. Automated tests cover the Lambda,
offline cache-buster checks, and the CloudTrail sign-in event contract.

## Layout

```
sites/root/                 # Deployed as-is to S3 (the site root)
  index.html                # English page (all sections in one file)
  es/index.html             # Spanish page (mirror of index.html)
  404.html                  # Bilingual not-found page (CloudFront serves it for any missing path)
  assets/js/script.js       # Shared JS for both pages. UI strings are in its STRINGS table
  assets/scss/              # SCSS source: main.scss @use's the partials _*.scss
  assets/css/main.css       # Compiled CSS (committed; this is what the browser loads)
  assets/css/bootstrap.css  # Bootstrap 5.3.3 subset, built by tools/build-bootstrap.sh (don't edit)
  assets/fonts/             # Self-hosted Inter, Montserrat, Fira Code (Latin woff2) + OFL licenses
  assets/images/icons.svg   # SVG icon sprite (Line Awesome glyphs), built by tools/build-icons.py
  assets/images/icon.svg, logo.svg, apple-touch-icon.png, and /favicon.ico at the root:
                            #   favicon set and sidebar logo, all built by tools/build-favicons.py (don't edit)
  assets/images/            # WebP images: certs/ (official badges), works/, photos, avatar;
                            #   og-card.jpg = social card, built by tools/build-og-card.py from tools/og-card.html
                            #   hero-aurora.webp = desktop-only home background (set in _home.scss)
                            #   works/*.webp = card thumbnails built by tools/build-thumbnails.py (don't edit)
  assets/files/CV.pdf       # Resume PDFs (CV.pdf = EN, CV_ES.pdf = ES). Source of truth for career facts
  sitemap.xml, robots.txt
  googlee0a7ad9869d1b1e8.html   # Google Search Console verification. Don't delete it.
functions/send_email/
  lambda_function.py        # Contact form handler (python3.12, stdlib + boto3 only)
  test_lambda_function.py   # Unit tests (stdlib only; boto3 and network are faked)
infra/                      # Terraform: AWS (us-east-1) + Google provider (+ google-beta for one quota)
  s3.tf  cloudfront.tf  route53.tf  contact.tf  recaptcha.tf
                            #   (content bucket is versioned; old versions expire after 30 days)
  monitoring.tf             # SNS email topic + alarms on contact API 5XX, Lambda errors, site down
  deploy.tf                 # GitHub OIDC provider + deploy-only role for the CI deploy job
  certificates.tf           # Daily ACM expiry alarms for the exact CloudFront certificates
  csp.tf, csp-policy.txt     # CSP report-only header and shared policy template
  backend.tf                # Remote state: s3://carlosbustamante-ops-terraform-state
  security.tf               # External Access Analyzer + management-event CloudTrail (90-day logs)
  signin.tf, signin-regions.tf # Root/Charly console sign-in alerts in every enabled region
  bootstrap/                # State bucket policy/lifecycle; separate local state, no bucket import
  terraform.tfvars          # Gitignored. Holds real values; don't commit it
deploy.sh                   # Uploads sites/root to S3 (with Cache-Control), deletes extras, invalidates CloudFront
cv/                         # CV sources: CV.tex (EN), CV_ES.tex (ES), shared style.tex, build.sh
tools/                      # Asset builders and offline cache-buster checker/tests
.github/workflows/ci.yml     # PR/main checks (no cloud credentials), then deploy on main via OIDC;
                            #   actions pinned by SHA
```

## How the pieces connect

- Browser → CloudFront → private S3 bucket through OAC. A CloudFront Function rewrites
  `/path/` and `/path` to `/path/index.html`, which is how `/es/` resolves.
- `www.` → CloudFront → private S3 website bucket whose only job is a 301 to the apex domain
  (path and query string are kept).
- CloudFront uses the managed `CachingOptimized` cache policy (Gzip/Brotli, query strings are
  not part of the cache key). `deploy.sh` sets `Cache-Control` on every object: pages, XML and
  TXT revalidate in the browser on each visit (CloudFront keeps them a day, and every deploy
  invalidates `/*`); `main.css`/`script.js` are cached for a year because their `?v=` tag changes
  with every edit; images and PDFs for a day. Missing paths (S3 returns 403 or 404) get `/404.html` with status 404. Every URL
  in `404.html` must be root-absolute, because it's served at the missing path.
- Contact form: `script.js` loads Google's `enterprise.js` only on the first focus/input in the
  form (about 2.6 MB uncompressed that most visitors never need), and on submit if it isn't
  loaded yet. The `submit` handler runs after native HTML validation, gets a
  reCAPTCHA Enterprise token (action `submit`), and POSTs JSON to API Gateway
  `/prod/sendemail`. The Lambda verifies the token with Google (min score 0.5, action `submit`,
  hostname = the production domain) and sends the message through SES. The UI shows status
  inline and keeps the form on errors.
- Lambda status codes: 400/413 = the request was refused (bad input or reCAPTCHA said no),
  503 = a dependency failed (Google or SES; logged as `UPSTREAM_ERROR`), 500 = a bug (logged as
  `UNHANDLED_ERROR` with a traceback). API Gateway adds 429 (throttling) and 502/504 (Lambda
  crash/timeout), and its error responses carry the CORS header too. Any 5XX emails the alert
  address through the `contact-api-5xx` alarm (the SNS subscription must be confirmed once).
- reCAPTCHA assessments are capped at 300/day on the GCP side (`recaptcha.tf`), so junk traffic
  can't exhaust the 10,000 free assessments per month. Past the cap the Lambda returns 503.
- Hardcoded frontend values live only in the two HTML files (`script.js` reads them from the
  form). If Terraform ever recreates these resources, update both HTML files:
  - API Gateway URL: the contact form's `action` attribute
  - reCAPTCHA site key `6LdBoB8q...`: the form's `data-recaptcha-key` (script.js builds the
    `enterprise.js?render=` URL from it; don't add a script tag to the pages)
- The CORS origin comes from `local.allowed_origin` in `contact.tf` (`https://${var.root_domain}`):
  the Lambda `ALLOWED_ORIGIN` env var, the OPTIONS mock response and the gateway responses.

## Frontend conventions

- Single-page layout. Sections are `<section id="home|about_me|my_resume|my_work|contact_me">`
  inside `<main>`. Only `.active` is shown (CSS keys off the `js` class set in `<head>`, so
  without JS every section is visible). Any same-page link to a section id (nav, logo,
  buttons) is routed by `script.js`, which updates the URL hash, supports back/forward and
  deep links, and carries the hash over to the other language's link.
- Portfolio card thumbnails are generated: each project is a `<template>` in `tools/thumbnails.html`
  (shared background + one bold SVG illustration). Add it to `THUMBNAILS` in
  `tools/build-thumbnails.py`, run
  `uvx --from playwright==1.58.0 --with pillow==11.3.0 python tools/build-thumbnails.py <name>`,
  and use `assets/images/works/<name>.webp` (1200×750) in the card and its `data-image`.
- Portfolio cards: `.item` with `data-groups='["ds-ml","cloud","education"]'` (Shuffle.js
  filters), containing `<article class="wrap">`. The modal reads `data-title`, `data-image`,
  `data-description`, `data-type`, `data-completed`, `data-skills` (comma-separated → chips),
  `data-project-link` (empty = no link button), and optional `data-link-label` and
  `data-image-position` (CSS `object-position` for the wide popup header, e.g. `center 42%`) on `.wrap`.
  The visible card title is a `<button class="card-open">`, which makes the whole card clickable.
  Each card with a link also has a real `<a class="card-link">` in its footer: CSS hides it when
  JS runs, so it only shows without JS. If Bootstrap's JS never loads, clicking a card opens
  its link directly. Keep `data-project-link` and the `card-link` href in sync.
- Everything the first paint needs is served from this domain: `bootstrap.css` (subset),
  `main.css`, the fonts (preloaded in `<head>`) and the icon sprite. No third-party stylesheet
  is allowed in `<head>`, because a stalled CDN would block rendering.
  - To use another Bootstrap class or component, add its module to
    `assets/scss/vendor/bootstrap-subset.scss`, run `./tools/build-bootstrap.sh` and bump the
    `bootstrap.css?v=` tag.
  - Icons are `<svg class="ico" aria-hidden="true" focusable="false"><use href="…/icons.svg?v=TAG#name"></use></svg>`.
    To add one, add its Line Awesome name to `tools/build-icons.py`, run
    `uvx --from 'fonttools[woff]==4.60.1' python tools/build-icons.py`, and bump `icons.svg?v=`
    in every page. Style icons through `.ico`, not `i`.
- The JS libraries load from CDNs with SRI hashes: Bootstrap 5.3.3 (JS bundle), Typed.js 2.1.0,
  Shuffle 6.1.0. Update the `integrity` hash if you bump a version.
- The three JS libraries load with `async`, and `script.js` must never assume they're there:
  use `whenLibraryLoads()` to start a feature when its library arrives, and keep a working
  fallback (static role text, plain show/hide filters, no modal). This is what keeps navigation
  working when a CDN stalls. `main.css` also defines `.visually-hidden` and hides
  `.modal:not(.show)` so the page stays clean if Bootstrap's CSS fails.
- SCSS uses modules (`@use`, not `@import`). Tokens are in `_colors.scss` (palette plus
  derived tokens like `$surface`, `$border`, `$on_primary`) and `_mixins.scss` (breakpoints,
  `surface`, `label-caps`). Use them instead of adding new hex values. Text on emerald uses
  `$on_primary` (dark). White on emerald fails contrast.
- Images are WebP with explicit `width`/`height` and `loading="lazy"` below the fold.
- Accessibility to keep: focus-visible ring, skip link, nav labels that stay in the
  accessibility tree (tooltips use opacity, not `visibility`), modal focus trap + focus return,
  `aria-pressed` filters, `aria-live` form status, `prefers-reduced-motion` support, the hero's
  pause/play button for looping motion (WCAG 2.2.2), a visually hidden "(opens in a new tab)"
  on every `target="_blank"` link, and the `<noscript>` note above the contact form.
- The hero portrait is a `<picture>` whose `<source media="(min-width: 992px)">` is the only
  real image, so phones and tablets (where it's hidden) don't download it.
- The reCAPTCHA badge is hidden with `visibility: hidden`. That's only allowed because the
  attribution text is shown next to the form, so keep that text.
- CSP is initially **report-only**, defined in `infra/csp-policy.txt` and attached through
  CloudFront's custom response headers. A new library/host needs a policy review; changing an
  executable inline script needs its SHA-256 hash updated. `tools/check_csp.py` checks all pages.
  Typed.js must keep `autoInsertCss: false`; cursor CSS belongs in SCSS. No reporting endpoint
  is configured: inspect browser violations with `tools/check_csp_browser.py`. Move to enforcing
  CSP only in a separate approved change after a clean live report-only period (about a week).

## Rules for changes

1. **Keep EN and ES in sync.** Apply every content or markup change to both
   `index.html` and `es/index.html`. The ES page uses `../assets/...` paths. New UI strings in
   JS go in both the `en` and `es` entries of `STRINGS` in `script.js`.
2. **Edit SCSS, then recompile the CSS.** Never hand-edit `main.css`. Sass isn't installed
   globally, so use npx:
   ```bash
   npx sass@1.105.0 sites/root/assets/scss/main.scss sites/root/assets/css/main.css
   ```
   Commit the SCSS and the regenerated CSS/map together.
3. **Bump the cache-busters** (`?v=` on `main.css`, `bootstrap.css`, `script.js` and
   `icons.svg`) in every page that loads the file when you change it. `404.html` links
   `main.css` too. Browsers cache CSS/JS for a year, so this is required: `deploy.sh` refuses to
   deploy a changed file whose tag wasn't bumped, pages that disagree on a tag, or a CSS/JS file
   that no page loads with `?v=`.
4. When page content changes, update `<lastmod>` in `sitemap.xml`. When metadata changes,
   update the JSON-LD block and `<meta>` tags in both HTML files. If the title, current role or
   hero chips change, update `tools/og-card.html` and re-run `tools/build-og-card.py`.
5. Career facts (roles, dates, certifications) must match the CV PDFs. Don't invent metrics.
6. The Lambda has no dependencies. Terraform `archive_file` zips just the one `.py` file.
   Adding a third-party package would mean changing the packaging in `contact.tf`.
   Field length limits in the Lambda (`MAX_LENGTHS`) match the form's `maxlength` attributes;
   change both together.
7. `aws_api_gateway_deployment` redeploys through `triggers`, a hash of the API resources.
   If you add an API resource, method, integration or gateway response, add it to that list too.
   The `prod` stage is throttled (2 req/s, burst 5) via `aws_api_gateway_method_settings`.

## CV (resume PDFs)

- Source of truth: `cv/CV.tex` (English) and `cv/CV_ES.tex` (Spanish). Both `\input{style}`, so
  layout changes go in `cv/style.tex` once. Keep both languages in sync.
- Build: `./cv/build.sh` compiles both with pdfLaTeX in a pinned TeX Live 2025 Docker image (the
  TeX Live year Overleaf used) and copies them to `sites/root/assets/files/`. Use
  `./cv/build.sh --check` to build into `cv/build/` (gitignored) without publishing. The only
  requirement is Docker. The first run downloads the image (about 2.6 GB).
- Each CV must stay exactly one US Letter page. The script fails if a CV spills onto a second
  page and warns about lines that overflow the margin.
- Builds are reproducible: PDF dates come from the last commit that touched `cv/`, so the same
  sources give byte-identical PDFs. Title/author metadata is set in `style.tex` from each CV's
  `\cvtitle`/`\cvsubject`. The site's download links save them as `Carlos_Bustamante_CV(_ES).pdf`.
- Commit the `.tex` changes and the regenerated PDFs together. If the career facts change, update
  the site too (rule 5).
- The GlobalLogic role is client work for Ring (an Amazon company). Don't mention internal
  Ring/Amazon specifics (internal tools, document types, projects, apps) on the CV or the site.

## Verify before finishing

```bash
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate
terraform -chdir=infra test # offline regression tests, all providers mocked
terraform -chdir=infra/bootstrap validate
python3 -m py_compile functions/send_email/lambda_function.py
python3 -m unittest discover -s functions/send_email
node --check sites/root/assets/js/script.js
./deploy.sh root --dryrun   # deploy checks + list of changed files (read-only)
./deploy.sh root --check-only # offline cache-buster checks, no credentials
python3 -m unittest discover -s tools -p 'test_*.py'
python3 tools/check_csp.py
# Requires playwright==1.58.0 and Chromium (see README): API/Google mocked, real CDN libraries
python3 tools/check_csp_browser.py
python3 -m http.server 8000 --directory sites/root   # preview at http://localhost:8000 and /es/
```

The contact form won't work from localhost because CORS only allows the production origin
(and reCAPTCHA only allows `localhost`, not `127.0.0.1`). To test the form flow, mock the API
and `grecaptcha` in a headless browser.

## High-risk actions (ask the user first)

- **Merging to `main` deploys.** When every CI job passes on `main`, the `deploy` job (GitHub
  environment `production`) assumes `portfolio-github-deploy` through OIDC and runs
  `./deploy.sh root`. It is skipped while the repo variable `AWS_DEPLOY_ROLE_ARN` is unset.
  Treat a merge like a deploy and ask first.
- `./deploy.sh root` pushes to **production**: it re-uploads every file, deletes bucket files
  that don't exist locally, and invalidates CloudFront distribution `E6VISQC42W7BR`. It skips
  `assets/scss/` and `*.map`. It only runs from a clean `main` that matches `origin/main`, so
  merge first. `./deploy.sh root --dryrun` shows the checks and the changed files without
  touching anything (works on any branch). The script defaults to the `portfolio-deploy` SSO
  profile (or environment credentials in CI) and checks that the caller is one of the two
  deploy-only roles. Use `portfolio-admin` for Terraform. Roll back a bad file from its previous
  S3 version, or revert the commit and let CI redeploy.
- `terraform apply` changes live resources and the shared remote state (DNS, CDN, SES, Lambda,
  reCAPTCHA). Run `plan` and show the output first.
- Terraform state and the Lambda env contain the GCP API key. Don't print
  `terraform show`, `terraform state pull`, or Lambda configuration in output.
- The bootstrap state-bucket lifecycle permanently deletes eligible historical state versions;
  show its separate plan and obtain approval before applying. Never expire current state or
  remove `prevent_destroy` without explicit authorization. Keep bootstrap local state backed up.
- When enabling another AWS region, extend `signin-regions.tf` and the trust-policy region list
  in `signin.tf` so regional break-glass sign-ins still generate email alerts.
- ACM emits `DaysToExpiry` only twice daily. Keep expiry alarms on a daily window with
  `treat_missing_data = "ignore"` so sparse samples and expiration don't clear an existing alert.

## Git

- Remote: `github.com/charlybgai/carlosbustamante.dev`. Default branch: `main`.
- Work on feature branches (`feat/...`, `fix/...`) and merge through PRs.
- Commit style: Conventional Commits with a scope, e.g. `feat(site): ...` or `fix(infra): ...`.
