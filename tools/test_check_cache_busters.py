"""Check the failures that can leave EN, ES or the 404 page using stale assets."""

from pathlib import Path
import tempfile
import unittest

from check_cache_busters import check


class CacheBusterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.site = Path(self.temp.name)
        for directory in ("es", "assets/css", "assets/js", "assets/images"):
            (self.site / directory).mkdir(parents=True, exist_ok=True)
        for asset in ("assets/css/main.css", "assets/js/script.js", "assets/images/icons.svg"):
            (self.site / asset).touch()
        self.write_pages()

    def write_pages(self, es_version="1", not_found_version="1"):
        for name, prefix, version in (("index.html", "", "1"), ("es/index.html", "../", es_version), ("404.html", "/", not_found_version)):
            (self.site / name).write_text(
                f'<link href="{prefix}assets/css/main.css?v={version}">'
                f'<script src="{prefix}assets/js/script.js?v=1"></script>'
                f'<svg><use href="{prefix}assets/images/icons.svg?v=1#home"/></svg>',
                encoding="utf-8",
            )

    def test_relative_root_and_fragment_references_agree(self):
        self.assertEqual(check(self.site), [])

    def test_spanish_version_mismatch(self):
        self.write_pages(es_version="2")
        self.assertTrue(any("disagree" in error for error in check(self.site)))

    def test_404_version_mismatch(self):
        self.write_pages(not_found_version="2")
        self.assertTrue(any("disagree" in error for error in check(self.site)))

    def test_unversioned_reference_even_when_other_pages_are_versioned(self):
        page = self.site / "404.html"
        page.write_text(page.read_text().replace("main.css?v=1", "main.css"))
        self.assertTrue(any("nonempty" in error for error in check(self.site)))

    def test_missing_versioned_asset(self):
        (self.site / "assets/css/main.css").unlink()
        self.assertTrue(any("missing local asset" in error for error in check(self.site)))

    def test_unreferenced_cached_asset(self):
        (self.site / "assets/js/forgotten.js").touch()
        self.assertTrue(any("forgotten.js" in error for error in check(self.site)))

    def test_empty_and_duplicate_versions(self):
        page = self.site / "index.html"
        for version in ("", "1&v=2"):
            page.write_text(f'<script src="assets/js/script.js?v={version}"></script>')
            self.assertTrue(any("nonempty" in error for error in check(self.site)))


if __name__ == "__main__":
    unittest.main()
