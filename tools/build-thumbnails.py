"""Builds the portfolio card thumbnails from one design (tools/thumbnails.html):

  sites/root/assets/images/works/<name>.webp     1200x750 (16:10), one per project

    uvx --from playwright==1.58.0 --with pillow==11.3.0 python tools/build-thumbnails.py [name ...]

Without names it renders every project in THUMBNAILS. Pass --browser-executable PATH to use an
existing Chromium build. Otherwise install Playwright's copy first (python -m playwright install
chromium).

Every thumbnail shares the template's background (navy, emerald/blue glow, faint grid) and adds
one bold illustration, drawn in inline SVG with the site's palette. Keep the motif around the
center and the bottom-left corner quiet: the card puts its label chip there, and the popup crops
the image to 21:9. Strokes of 6 px or more survive the ~300 px wide cards.

To add a project: add a <template id="..."> to thumbnails.html, add it to THUMBNAILS below, run
this script, and reference assets/images/works/<name>.webp from both pages (card and data-image).
"""
import argparse
import io
import pathlib

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "tools/thumbnails.html"
OUT = ROOT / "sites/root/assets/images/works"

# Output file name -> template id in thumbnails.html
THUMBNAILS = {
    "portfolio-site": "site",
    "loan-approval": "loan",
    "paris": "paris",
    "water-stress": "water",
    "ibm-capstone": "ibm",
    "qr-attendance": "qr",
    "fraud-detection": "fraud",
    "volcanic-eruption": "volcano",
}
WIDTH, HEIGHT = 1200, 750


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("names", nargs="*", help=f"thumbnails to build (default: all): {', '.join(THUMBNAILS)}")
    parser.add_argument("--browser-executable", help="path to a Chromium build to use instead of Playwright's")
    args = parser.parse_args()
    names = args.names or list(THUMBNAILS)
    unknown = [n for n in names if n not in THUMBNAILS]
    if unknown:
        parser.error(f"unknown thumbnail(s): {', '.join(unknown)}")

    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=args.browser_executable)
        page = browser.new_page(viewport={"width": WIDTH, "height": HEIGHT})
        for name in names:
            page.goto(f"{TEMPLATE.as_uri()}?p={THUMBNAILS[name]}")
            page.wait_for_load_state("load")
            png = page.screenshot()
            dest = OUT / f"{name}.webp"
            Image.open(io.BytesIO(png)).convert("RGB").save(dest, "WEBP", quality=82, method=6)
            print(f"Wrote {dest.relative_to(ROOT)} ({dest.stat().st_size} bytes)")
        browser.close()


if __name__ == "__main__":
    main()
