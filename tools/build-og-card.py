"""Builds the social card from tools/og-card.html:

  sites/root/assets/images/og-card.jpg           1200x630, used by og:image and twitter:image

    uvx --from playwright==1.58.0 --with pillow==11.3.0 python tools/build-og-card.py

Edit the template's text (title, current role, chips) and re-run. It uses the site's own fonts
and portrait, so the card always matches the page. Pass --browser-executable PATH to use an
existing Chromium build. Otherwise install Playwright's copy first (python -m playwright install
chromium). The 1200x630 size and the og:image:width/height tags in both pages must agree.
"""
import argparse
import io
import pathlib

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "tools/og-card.html"
OUT = ROOT / "sites/root/assets/images/og-card.jpg"
WIDTH, HEIGHT = 1200, 630


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--browser-executable", help="path to a Chromium build to use instead of Playwright's")
    args = parser.parse_args()

    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=args.browser_executable)
        page = browser.new_page(viewport={"width": WIDTH, "height": HEIGHT})
        page.goto(TEMPLATE.as_uri())
        page.wait_for_load_state("load")
        page.evaluate("document.fonts.ready")
        png = page.screenshot()
        browser.close()

    Image.open(io.BytesIO(png)).convert("RGB").save(OUT, "JPEG", quality=88, optimize=True, progressive=True)
    print(f"Wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
