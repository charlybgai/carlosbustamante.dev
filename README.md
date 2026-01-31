# Carlos Bustamante - ML Engineer Portfolio

Personal portfolio website for **Carlos Bustamante**, Machine Learning Engineer, hosted at `carlosbustamante.dev`.

## Project Structure

```
carlosbustamante.dev/
├── sites/
│   └── root/        # ML Engineer portfolio (carlosbustamante.dev)
├── infra/           # Terraform infrastructure (AWS S3, CloudFront, Route 53)
└── deploy.sh        # Deployment script
```

## Sites

| Site | URL | Description |
|------|-----|-------------|
| **Portfolio** | [carlosbustamante.dev](https://carlosbustamante.dev) | Machine Learning Engineer portfolio showcasing projects, certifications, and experience |
| **WWW** | [www.carlosbustamante.dev](https://www.carlosbustamante.dev) | Redirects to main site |

## Technologies

### Frontend
- **HTML5** - Semantic structure
- **SCSS/CSS** - Styling with variables and modern design patterns
- **JavaScript** - Interactivity and animations
- **Bootstrap 5** - Grid system

### Infrastructure
- **Terraform** - Infrastructure as Code
- **AWS S3** - Static site hosting
- **AWS CloudFront** - CDN distribution
- **AWS Route 53** - DNS management

## Deployment

Deploy the portfolio site:

```bash
./deploy.sh root
# or
./deploy.sh all
```

## Infrastructure

Initialize and apply Terraform:

```bash
cd infra
terraform init
terraform plan
terraform apply
```

## Acknowledgements

The portfolio site was developed based on the course offered by **Cheetah Academy** on Udemy:

[Responsive Portfolio Website using HTML5, CSS3, JavaScript & Bootstrap5](https://www.udemy.com/course/responsive-portfolio-website-using-html5-css3-javascript-bootstrap5/)
