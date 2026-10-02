#!/usr/bin/env python3
"""Check the static pages against the same CSP template Terraform deploys."""

import base64
import hashlib
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=False)
        self.scripts = []
        self.inline = []
        self.endpoint = None
        self.problems = []
        self.script = None
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if any(name.startswith('on') for name in attrs) or 'style' in attrs or tag == 'style':
            self.problems.append('Inline handlers/styles require a CSP review')
        if tag == 'form':
            self.endpoint = attrs.get('action')
        if tag == 'script':
            if attrs.get('src'):
                self.scripts.append(attrs['src'])
            self.script = None if attrs.get('src') or attrs.get('type') == 'application/ld+json' else []

    def handle_data(self, data):
        if self.script is not None:
            self.script.append(data)

    def handle_endtag(self, tag):
        if tag == 'script' and self.script is not None:
            self.inline.append(''.join(self.script))
            self.script = None


def policy_for(endpoint):
    origin = urlsplit(endpoint)
    return ' '.join((ROOT / 'infra/csp-policy.txt').read_text().splitlines()).replace(
        '${contact_api_origin}', f'{origin.scheme}://{origin.netloc}'
    ).replace('${contact_form_url}', endpoint)


def check():
    errors = []
    pages = [Page((ROOT / 'sites/root' / name).read_text()) for name in ['index.html', 'es/index.html', '404.html']]
    endpoint = pages[0].endpoint
    if not endpoint or pages[1].endpoint != endpoint:
        raise ValueError('EN/ES contact endpoints must match')
    policy = policy_for(endpoint)
    scripts = next(part.split()[1:] for part in policy.split(';') if part.strip().startswith('script-src '))
    for name, page in zip(['EN', 'ES', '404'], pages):
        errors.extend(f'{name}: {problem}' for problem in page.problems)
        for body in page.inline:
            digest = base64.b64encode(hashlib.sha256(body.encode()).digest()).decode()
            if f"'sha256-{digest}'" not in scripts:
                errors.append(f'{name}: inline script hash is missing from CSP')
        for src in page.scripts:
            if urlsplit(src).scheme and not any(src.startswith(source) for source in scripts if source.startswith('https://')):
                errors.append(f'{name}: external script is not allowed by CSP: {src}')
    if errors:
        raise ValueError('\n'.join(errors))
    return policy


if __name__ == '__main__':
    check()
    print('CSP template matches EN, ES and 404 scripts; no inline handlers/styles.')
