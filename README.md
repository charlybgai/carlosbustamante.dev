# Carlos Bustamante - Cloud & MLOps Engineer Portfolio

Personal portfolio website for **Carlos Bustamante**, Cloud & MLOps Engineer, hosted at
[carlosbustamante.dev](https://carlosbustamante.dev) (English) and
[carlosbustamante.dev/es/](https://carlosbustamante.dev/es/) (Spanish).

## Project Structure

```
carlosbustamante.dev/
├── sites/root/          # Static site deployed to S3 (EN at /, ES at /es/)
├── functions/send_email # Python Lambda behind the contact form
├── infra/               # Terraform (AWS + Google reCAPTCHA Enterprise)
└── deploy.sh            # Syncs the site to S3 and invalidates CloudFront
```

## Technologies

### Frontend
- **HTML5**: semantic, accessible markup (one page per language)
- **SCSS**: design tokens and partials, compiled to `assets/css/main.css`
- **JavaScript**: vanilla, one shared script (section routing, filters, modal, contact form)
- **Bootstrap 5** grid and modal, **Shuffle.js** filters, **Typed.js** hero animation

### Infrastructure
- **Terraform**: all infrastructure as code, remote state in S3
- **AWS S3 + CloudFront**: private bucket behind CloudFront (OAC), security headers at the edge
- **AWS Route 53**: DNS, plus a `www` → apex redirect
- **API Gateway + Lambda + SES**: serverless contact form
- **Google reCAPTCHA Enterprise**: spam protection for the form

## Local development

```bash
# Rebuild CSS after editing SCSS
npx sass sites/root/assets/scss/main.scss sites/root/assets/css/main.css

# Preview
python3 -m http.server 8000 --directory sites/root
```

See [AGENTS.md](AGENTS.md) for conventions and checks.

## Deployment

```bash
./deploy.sh root
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
