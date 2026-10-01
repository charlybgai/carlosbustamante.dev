#!/usr/bin/env python3
"""Validate local asset version tags without credentials or network access."""

from html.parser import HTMLParser
from pathlib import Path
import sys
from urllib.parse import parse_qs, unquote, urlsplit


class AssetReferences(HTMLParser):
    def __init__(self):
        super().__init__()
        self.references = []

    def handle_starttag(self, tag, attrs):
        for name, value in attrs:
            if value and name in ("href", "src", "data-pause-icon", "data-play-icon"):
                self.references.append(value)


def check(site):
    site = site.resolve()
    versions = {}
    errors = []
    for page in (site / "index.html", site / "es/index.html", site / "404.html"):
        parser = AssetReferences()
        parser.feed(page.read_text(encoding="utf-8"))
        for reference in parser.references:
            url = urlsplit(reference)
            if url.scheme or url.netloc or not url.path:
                continue
            path = unquote(url.path)
            asset = ((site / path.lstrip("/")) if path.startswith("/") else (page.parent / path)).resolve()
            query = parse_qs(url.query, keep_blank_values=True)
            needs_version = asset.suffix in (".css", ".js") or asset.name == "icons.svg" or "v" in query
            if not needs_version:
                continue
            if not asset.is_relative_to(site) or not asset.is_file():
                errors.append(f"{page.relative_to(site)}: missing local asset {reference}")
                continue
            tokens = query.get("v", [])
            if len(tokens) != 1 or not tokens[0].strip():
                errors.append(f"{page.relative_to(site)}: {reference} needs one nonempty ?v= tag")
                continue
            versions.setdefault(asset, set()).add(tokens[0])

    for asset, tokens in sorted(versions.items()):
        if len(tokens) != 1:
            errors.append(f"{asset.relative_to(site)}: pages disagree on the cache-buster: {', '.join(sorted(tokens))}")
    for asset in sorted((site / "assets").rglob("*")):
        if asset.is_file() and asset.suffix in (".css", ".js") and asset not in versions:
            errors.append(f"{asset.relative_to(site)}: cached for a year but no page loads it with ?v=")
    return errors


if __name__ == "__main__":
    errors = check(Path(__file__).resolve().parents[1] / "sites/root")
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    if errors:
        sys.exit(1)
    print("Offline cache-buster checks passed.")
