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
- **AWS Route 53**: DNS, plus a `www` → apex redirect
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

`tools/build-bootstrap.sh` and `tools/build-icons.py` regenerate `assets/css/bootstrap.css` and
`assets/images/icons.svg`; you only need them when changing those. See [AGENTS.md](AGENTS.md)
for conventions and checks.

## Deployment

```bash
./deploy.sh root --dryrun   # checks + list of changed files, changes nothing
./deploy.sh root            # from a clean main that matches origin/main
```

## Infrastructure

```bash
cd infra
terraform init
terraform plan
terraform apply
```

## Acknowledgements

The original layout of the portfolio was based on the course offered by **Cheetah Academy** on Udemy:

[Responsive Portfolio Website using HTML5, CSS3, JavaScript & Bootstrap5](https://www.udemy.com/course/responsive-portfolio-website-using-html5-css3-javascript-bootstrap5/)
