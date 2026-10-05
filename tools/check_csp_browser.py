#!/usr/bin/env python3
"""Exercise the site under CSP without posting messages to production.

Requires playwright==1.58.0 and its Chromium browser. Local mode injects the
Terraform policy; --live checks the actual production report-only header.
Google is mocked unless --real-recaptcha is supplied. API requests are always
intercepted, including in live mode. CDN libraries remain real, including SRI.
"""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread

from playwright.sync_api import expect, sync_playwright

from check_csp import ROOT, check


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live', action='store_true')
    parser.add_argument('--real-recaptcha', action='store_true')
    parser.add_argument('--browser-executable')
    args = parser.parse_args()
    policy = check()
    header = 'Content-Security-Policy-Report-Only'

    class Handler(SimpleHTTPRequestHandler):
        def end_headers(self):
            self.send_header(header, policy)
            super().end_headers()

        def log_message(self, *_):
            pass

    server = None
    if args.live:
        base = 'https://carlosbustamante.dev'
    else:
        server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(ROOT / 'sites/root')))
        Thread(target=server.serve_forever, daemon=True).start()
        base = f'http://localhost:{server.server_port}'
    try:
        with sync_playwright() as playwright:
            options = {'headless': True}
            if args.browser_executable:
                options['executable_path'] = args.browser_executable
            browser = playwright.chromium.launch(**options)
            context = browser.new_context(viewport={'width': 1280, 'height': 900})
            context.add_init_script("""
                window.cspViolations = [];
                document.addEventListener('securitypolicyviolation', (event) => {
                    window.cspViolations.push({directive: event.effectiveDirective,
                        blocked: event.blockedURI, disposition: event.disposition});
                });
            """)
            if not args.real_recaptcha:
                context.route('https://www.google.com/recaptcha/enterprise.js*', lambda route: route.fulfill(
                    content_type='application/javascript', body="window.grecaptcha={enterprise:{ready:f=>f(),execute:()=>Promise.resolve('csp-test-token')}};"))
            submissions = []

            def mock_api(route):
                request = route.request
                headers = {'Access-Control-Allow-Origin': base, 'Access-Control-Allow-Headers': 'content-type', 'Access-Control-Allow-Methods': 'POST,OPTIONS'}
                if request.method == 'POST':
                    submissions.append(request.post_data_json)
                route.fulfill(status=200, headers=headers, content_type='application/json', body='{"message":"ok"}')

            context.route('https://*.execute-api.us-east-1.amazonaws.com/**', mock_api)
            page = context.new_page()
            page.set_default_timeout(20000)
            # reCAPTCHA must stay unloaded until someone uses the contact form
            recaptcha_requests = []
            page.on('request', lambda request: recaptcha_requests.append(request.url)
                    if '/recaptcha/' in request.url else None)
            for path in ['/', '/es/']:
                response = page.goto(base + path, wait_until='load')
                assert response.status == 200
                assert response.headers.get(header.lower()) == policy, 'Live CSP differs from workspace policy'
                page.wait_for_function("typeof Typed==='function' && typeof Shuffle==='function' && !!window.bootstrap?.Modal")
                expect(page.locator('#home .typed-cursor')).to_be_visible()
                page.locator('#home .motion-toggle').click()
                expect(page.locator('#home .motion-toggle')).to_have_attribute('aria-pressed', 'true')
                page.locator('a[href="#my_resume"]').first.click()
                expect(page.locator('#my_resume')).to_have_class('active')
                page.locator('a[href="#my_work"]').first.click()
                expect(page.locator('#my_work')).to_have_class('active')
                page.locator('button[data-group="cloud"]').click()
                expect(page.locator('button[data-group="cloud"]')).to_have_attribute('aria-pressed', 'true')
                page.locator('button[data-group="all"]').click()
                trigger = page.locator('.card-open').first
                trigger.click()
                expect(page.locator('#workModal')).to_be_visible()
                expect(page.locator('#workModal .modal-close-button')).to_be_focused()
                page.keyboard.press('Escape')
                expect(page.locator('#workModal')).not_to_be_visible()
                expect(trigger).to_be_focused()
                page.locator('a[href="#contact_me"]').first.click()
                assert not recaptcha_requests, f'reCAPTCHA loaded before the form was used: {recaptcha_requests}'
                for field, value in {'name': 'CSP browser test', 'email': 'test@example.com', 'subject': 'Intercepted test', 'message': 'This request never reaches AWS.'}.items():
                    page.locator(f'#contactForm [name="{field}"]').fill(value)
                page.locator('#contactForm button[type="submit"]').click()
                expect(page.locator('#contactForm .form-status')).to_have_class('form-status is-success')
                assert len(submissions) == (1 if path == '/' else 2)
                assert submissions[-1]['g-recaptcha-response'], 'Token missing'
                assert any('enterprise.js?render=' in url for url in recaptcha_requests), 'reCAPTCHA never loaded'
                recaptcha_requests.clear()
                assert not page.evaluate('window.cspViolations'), page.evaluate('window.cspViolations')
                # Verify the observer really catches report-only violations. No
                # external request: a harmless unsigned inline script is enough.
                page.evaluate("const s=document.createElement('script');s.textContent='window.cspNegativeControl=true';document.head.append(s)")
                page.wait_for_function("window.cspViolations.some(v=>v.directive==='script-src-elem' && v.disposition==='report')")
                print(f'{path}: navigation, libraries, pause, filters, modal/focus, on-demand reCAPTCHA, token and mocked submit passed; zero flow CSP violations; negative control detected.')
            response = page.goto(base + '/404.html', wait_until='load')
            assert response.status == 200
            assert response.headers.get(header.lower()) == policy
            assert not page.evaluate('window.cspViolations'), page.evaluate('window.cspViolations')
            print('/404.html: zero CSP violations.')
            browser.close()
    finally:
        if server:
            server.shutdown()
            server.server_close()


if __name__ == '__main__':
    main()
