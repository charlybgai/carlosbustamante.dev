# AGENTS.md

Static bilingual (EN/ES) portfolio for Carlos Bustamante at https://carlosbustamante.dev.
Plain HTML + SCSS + vanilla JS on S3/CloudFront. The contact form is a Python Lambda
behind API Gateway, with Google reCAPTCHA Enterprise. All infrastructure is in Terraform.
There's no framework, no bundler and no package.json. The only automated tests are the Lambda's
unit tests.

## Layout

```
sites/root/                 # Deployed as-is to S3 (the site root)
  index.html                # English page (all sections in one file)
  es/index.html             # Spanish page (mirror of index.html)
  404.html                  # Bilingual not-found page (CloudFront serves it for any missing path)
  assets/js/script.js       # Shared JS for both pages. UI strings are in its STRINGS table
  assets/scss/              # SCSS source: main.scss @use's the partials _*.scss
  assets/css/main.css       # Compiled CSS (committed; this is what the browser loads)
  assets/images/            # WebP images: certs/, works/, photos, avatar; og-card.jpg (social card);
                            #   hero-aurora.webp = desktop-only home background (set in _home.scss)
  assets/files/CV.pdf       # Resume PDFs (CV.pdf = EN, CV_ES.pdf = ES). Source of truth for career facts
  sitemap.xml, robots.txt
  googlee0a7ad9869d1b1e8.html   # Google Search Console verification. Don't delete it.
functions/send_email/
  lambda_function.py        # Contact form handler (python3.12, stdlib + boto3 only)
  test_lambda_function.py   # Unit tests (stdlib only; boto3 and network are faked)
infra/                      # Terraform: AWS (us-east-1) + Google provider (+ google-beta for one quota)
  s3.tf  cloudfront.tf  route53.tf  contact.tf  recaptcha.tf
  monitoring.tf             # SNS email topic + alarms on contact API 5XX and Lambda errors
  backend.tf                # Remote state: s3://carlosbustamante-ops-terraform-state
  terraform.tfvars          # Gitignored. Holds real values; don't commit it
deploy.sh                   # Uploads sites/root to S3 (with Cache-Control), deletes extras, invalidates CloudFront
cv/                         # CV sources: CV.tex (EN), CV_ES.tex (ES), shared style.tex, build.sh
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
- Contact form: the `submit` handler in `script.js` runs after native HTML validation, gets a
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
  - reCAPTCHA site key `6LdBoB8q...`: the form's `data-recaptcha-key` and the
    `enterprise.js?render=` script tag
- The CORS origin comes from `local.allowed_origin` in `contact.tf` (`https://${var.root_domain}`):
  the Lambda `ALLOWED_ORIGIN` env var, the OPTIONS mock response and the gateway responses.

## Frontend conventions

- Single-page layout. Sections are `<section id="home|about_me|my_resume|my_work|contact_me">`
  inside `<main>`. Only `.active` is shown (CSS keys off the `js` class set in `<head>`, so
  without JS every section is visible). Any same-page link to a section id (nav, logo,
  buttons) is routed by `script.js`, which updates the URL hash, supports back/forward and
  deep links, and carries the hash over to the other language's link.
- Portfolio cards: `.item` with `data-groups='["ds-ml","cloud","education"]'` (Shuffle.js
  filters), containing `<article class="wrap">`. The modal reads `data-title`, `data-image`,
  `data-description`, `data-type`, `data-completed`, `data-skills` (comma-separated → chips),
  `data-project-link` (empty = no link button), and optional `data-link-label` and
  `data-image-position` (CSS `object-position` for the wide popup header, e.g. `center 42%`) on `.wrap`.
  The visible card title is a `<button class="card-open">`, which makes the whole card clickable.
- Libraries load from CDNs with SRI hashes: Bootstrap 5.3.3, Typed.js 2.1.0, Shuffle 6.1.0,
  and Line Awesome 1.3.0 (icons, no SRI). Update the `integrity` hash if you bump a version.
  Fonts (Inter, Montserrat, Fira Code) load through `<link>` tags in `<head>`.
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
  `aria-pressed` filters, `aria-live` form status, `prefers-reduced-motion` support.
- The reCAPTCHA badge is hidden with `visibility: hidden`. That's only allowed because the
  attribution text is shown next to the form, so keep that text.

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
3. **Bump the cache-busters** (`main.css?v=YYYYMMDD-tag`, `script.js?v=YYYYMMDD-tag`) in both
   HTML files when you change CSS or JS. `404.html` links `main.css` too. Browsers cache these
   files for a year, so this is required: `deploy.sh` refuses to deploy a changed file whose
   tag wasn't bumped, or pages that disagree on the tag.
4. When page content changes, update `<lastmod>` in `sitemap.xml`. When metadata changes,
   update the JSON-LD block and `<meta>` tags in both HTML files.
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
- Commit the `.tex` changes and the regenerated PDFs together. If the career facts change, update
  the site too (rule 5).
- The GlobalLogic role is client work for Ring (an Amazon company). Don't mention internal
  Ring/Amazon specifics (internal tools, document types, projects, apps) on the CV or the site.

## Verify before finishing

```bash
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate
python3 -m py_compile functions/send_email/lambda_function.py
python3 -m unittest discover -s functions/send_email
node --check sites/root/assets/js/script.js
./deploy.sh root --dryrun   # deploy checks + list of changed files (read-only)
python3 -m http.server 8000 --directory sites/root   # preview at http://localhost:8000 and /es/
```

The contact form won't work from localhost because CORS only allows the production origin
(and reCAPTCHA only allows `localhost`, not `127.0.0.1`). To test the form flow, mock the API
and `grecaptcha` in a headless browser.

## High-risk actions (ask the user first)

- `./deploy.sh root` pushes to **production**: it re-uploads every file, deletes bucket files
  that don't exist locally, and invalidates CloudFront distribution `E6VISQC42W7BR`. It skips
  `assets/scss/` and `*.map`. It only runs from a clean `main` that matches `origin/main`, so
  merge first. `./deploy.sh root --dryrun` shows the checks and the changed files without
  touching anything (works on any branch).
- `terraform apply` changes live resources and the shared remote state (DNS, CDN, SES, Lambda,
  reCAPTCHA). Run `plan` and show the output first.
- Terraform state and the Lambda env contain the GCP API key. Don't print
  `terraform show`, `terraform state pull`, or Lambda configuration in output.

## Git

- Remote: `github.com/charlybgai/carlosbustamante.dev`. Default branch: `main`.
- Work on feature branches (`feat/...`, `fix/...`) and merge through PRs.
- Commit style: Conventional Commits with a scope, e.g. `feat(site): ...` or `fix(infra): ...`.
