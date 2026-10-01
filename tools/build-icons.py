"""Builds sites/root/assets/images/icons.svg, an SVG sprite with the Line Awesome 1.3.0 icons the
site uses, so pages don't need the 108 KB icon CSS and two icon fonts from a third-party CDN.

    uvx --from 'fonttools[woff]==4.60.1' python tools/build-icons.py

To add an icon, add its Line Awesome name to SOLID or BRANDS, run the script, then reference it
as <svg class="ico" aria-hidden="true" focusable="false"><use href=".../icons.svg?v=TAG#name"></use></svg>
and bump the icons.svg?v= tag in the pages.

Each symbol keeps the font's geometry: a 1024x1024 viewBox with the baseline at 896, which is
what a Line Awesome glyph occupies at line-height 1. With `.ico { width: 1em; height: 1em;
vertical-align: -0.125em }` the icons render at the same size and position as the font did.
"""
import hashlib
import pathlib
import re
import urllib.request

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

BASE = "https://maxst.icons8.com/vue-static/landings/line-awesome/line-awesome/1.3.0"
SOURCES = {  # path -> sha256, pinned so a changed upstream file can't slip in
    "css/line-awesome.min.css": "4716ecc4c3d6816c0cce4e62bd854fa32c81f9ced9eccd36d009723879e27fea",
    "fonts/la-solid-900.woff2": "10a68e01209d939afa9318ee71601b0a6e10f025d4cd6d98a492d340b73941fb",
    "fonts/la-brands-400.woff2": "ff70c9bc4650cf5e6b12d1feaa7af29ebf0681993fc0c5ffe3658cea0dbd5403",
}
SOLID = [
    "arrow-right", "arrow-up", "brain", "briefcase", "calendar-check", "certificate", "cloud",
    "code", "cogs", "download", "envelope", "external-link-alt", "file-alt", "graduation-cap",
    "home", "language", "layer-group", "map-marker-alt", "paper-plane", "pause", "phone", "play",
    "times", "tools", "user",
]
BRANDS = ["github", "kaggle", "linkedin-in"]

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "sites/root/assets/images/icons.svg"


def fetch(path):
    data = urllib.request.urlopen(f"{BASE}/{path}", timeout=30).read()
    digest = hashlib.sha256(data).hexdigest()
    if digest != SOURCES[path]:
        raise SystemExit(f"error: {path} doesn't match its pinned sha256 ({digest})")
    return data


def main():
    css = fetch("css/line-awesome.min.css").decode("utf-8")
    symbols = []
    for font_path, names in (("fonts/la-solid-900.woff2", SOLID), ("fonts/la-brands-400.woff2", BRANDS)):
        tmp = ROOT / "cv/build" / pathlib.Path(font_path).name  # gitignored scratch location
        tmp.parent.mkdir(parents=True, exist_ok=True)
        tmp.write_bytes(fetch(font_path))
        font = TTFont(tmp)
        upm = font["head"].unitsPerEm
        ascent = font["hhea"].ascent
        cmap = font.getBestCmap()
        glyphs = font.getGlyphSet()
        for name in names:
            match = re.search(r"\.la-" + re.escape(name) + r":before\s*\{\s*content:\s*'\\([0-9a-f]+)'", css)
            if not match:
                raise SystemExit(f"error: no Line Awesome icon named {name}")
            glyph = cmap[int(match.group(1), 16)]
            pen = SVGPathPen(glyphs, ntos=lambda v: str(round(v)))
            # Font units are y-up with the baseline at 0; SVG is y-down from the top of the em box
            glyphs[glyph].draw(TransformPen(pen, (1, 0, 0, -1, 0, ascent)))
            symbols.append(f'<symbol id="{name}" viewBox="0 0 {upm} {upm}"><path d="{pen.getCommands()}"/></symbol>')
        tmp.unlink()

    OUT.write_text(
        '<svg xmlns="http://www.w3.org/2000/svg">\n'
        "<!-- Line Awesome 1.3.0 by Icons8 (MIT or Good Boy License). Built by tools/build-icons.py -->\n"
        + "\n".join(symbols) + "\n</svg>\n",
        encoding="utf-8",
    )
    print(f"Wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size} bytes, {len(symbols)} icons)")


if __name__ == "__main__":
    main()
