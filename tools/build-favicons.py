"""Builds the site's favicon set and sidebar logo from one design (the "Orbit C"):

  sites/root/assets/images/icon.svg              favicon for modern browsers (gradient tile)
  sites/root/assets/images/logo.svg              sidebar mark (gradient C, transparent)
  sites/root/favicon.ico                         16/32/48 px, for browsers and crawlers that ask /favicon.ico
  sites/root/assets/images/apple-touch-icon.png  180 px, full-bleed (iOS rounds the corners itself)

    uvx --from playwright==1.58.0 --with pillow==11.3.0 python tools/build-favicons.py

Rasters are rendered by Chromium, so each size is drawn natively instead of downscaled.
Pass --browser-executable PATH to use an existing Chromium build. Otherwise install Playwright's
copy first (python -m playwright install chromium).

The geometry is on a 64x64 grid and tuned for 16 px: an 11-unit stroke stays about 2.75 px wide,
and the 1.5 px gap between the arc ends and the dot keeps them apart. Colors are the site's:
emerald #10B981 to blue #3B82F6, navy #0F172A, white #F8FAFC.
"""
import argparse
import base64
import io
import math
import pathlib

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE = ROOT / "sites/root"
IMAGES = SITE / "assets/images"

EMERALD, BLUE, NAVY, WHITE = "#10B981", "#3B82F6", "#0F172A", "#F8FAFC"
GRADIENT = (
    '<linearGradient id="g" gradientUnits="userSpaceOnUse" x1="8" y1="8" x2="56" y2="56">'
    f'<stop offset="0" stop-color="{EMERALD}"/><stop offset="1" stop-color="{BLUE}"/>'
    "</linearGradient>"
)


def orbit_c(color):
    """A C open to the right (centre 30,32, r 20, 55 degree half-gap) with a dot in the opening."""
    a = math.radians(55)
    x, y_top, y_bottom = 30 + 20 * math.cos(a), 32 - 20 * math.sin(a), 32 + 20 * math.sin(a)
    arc = f"M{x:.2f} {y_top:.2f}A20 20 0 1 0 {x:.2f} {y_bottom:.2f}"
    return (f'<path d="{arc}" fill="none" stroke="{color}" stroke-width="11" stroke-linecap="round"/>'
            f'<circle cx="50" cy="32" r="7" fill="{WHITE}"/>')


def svg(body, view_box="0 0 64 64"):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view_box}">'
            f"<defs>{GRADIENT}</defs>{body}</svg>\n")


def tile(radius):
    return svg(f'<rect width="64" height="64" rx="{radius}" fill="url(#g)"/>{orbit_c(NAVY)}')


ICON_SVG = tile(14)  # rounded tile; browsers show it as is
TOUCH_SVG = tile(0)  # square; iOS and Android apply their own mask
# The glyph spans x 4.5-57, y 6.5-57.5, so a tight square view box lets it fill the 28 px slot.
LOGO_SVG = svg(orbit_c("url(#g)"), view_box="3.75 5 54 54")


def render(page, source, size):
    """Rasterize an SVG string at size x size CSS px (DPR 1) with a transparent background."""
    data = base64.b64encode(source.encode()).decode()
    page.set_content(
        '<html><body style="margin:0;background:transparent">'
        f'<img id="i" width="{size}" height="{size}" src="data:image/svg+xml;base64,{data}"></body></html>')
    page.wait_for_function("document.getElementById('i').complete")
    png = page.locator("#i").screenshot(omit_background=True)
    image = Image.open(io.BytesIO(png)).convert("RGBA")
    assert image.size == (size, size), image.size
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--browser-executable", help="path to a Chromium binary")
    args = parser.parse_args()

    (IMAGES / "icon.svg").write_text(ICON_SVG)
    (IMAGES / "logo.svg").write_text(LOGO_SVG)

    with sync_playwright() as playwright:
        options = {"executable_path": args.browser_executable} if args.browser_executable else {}
        browser = playwright.chromium.launch(**options)
        page = browser.new_page(device_scale_factor=1)
        frames = {size: render(page, ICON_SVG, size) for size in (16, 32, 48)}
        touch = render(page, TOUCH_SVG, 180)
        browser.close()

    # ICO frames are the exact native renders (append_images), not resamples of the largest one.
    ico = SITE / "favicon.ico"
    frames[48].save(ico, format="ICO", sizes=[(16, 16), (32, 32), (48, 48)],
                    append_images=[frames[32], frames[16]])
    with Image.open(ico) as check:
        for size, frame in frames.items():
            check.size = (size, size)
            assert check.convert("RGBA").tobytes() == frame.tobytes(), f"ICO {size} px frame differs"

    touch.convert("RGB").save(IMAGES / "apple-touch-icon.png", optimize=True)

    for path in (IMAGES / "icon.svg", IMAGES / "logo.svg", ico, IMAGES / "apple-touch-icon.png"):
        print(f"{path.relative_to(ROOT)}  {path.stat().st_size} bytes")


if __name__ == "__main__":
    main()
