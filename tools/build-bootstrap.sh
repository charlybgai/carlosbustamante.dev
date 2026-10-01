#!/usr/bin/env bash
# Builds sites/root/assets/css/bootstrap.css from Bootstrap's official SCSS source, keeping only
# the modules listed in sites/root/assets/scss/vendor/bootstrap-subset.scss.
#
#   ./tools/build-bootstrap.sh
#
# Needs Node (npx/npm). The Bootstrap package is downloaded to a temporary directory and
# checked against the pinned sha512 below before it's used. After a rebuild, bump the
# bootstrap.css?v= tag in index.html and es/index.html.
set -euo pipefail

BOOTSTRAP_VERSION="5.3.3"
# sha512 of bootstrap-5.3.3.tgz, as published by npm (`npm view bootstrap@5.3.3 dist.integrity`)
BOOTSTRAP_SHA512="8HLCdWgyoMguSO9o+aH+iuZ+aht+mzW0u3HIMzVu7Srrpv7EBBxTnrFlSCskwdY1+EOFQSm7uMJhNQHkdPcmjg=="
SASS_VERSION="1.105.0"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTRY="$ROOT/sites/root/assets/scss/vendor/bootstrap-subset.scss"
OUT="$ROOT/sites/root/assets/css/bootstrap.css"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "-> Downloading bootstrap@$BOOTSTRAP_VERSION"
(cd "$TMP" && npm pack "bootstrap@$BOOTSTRAP_VERSION" --silent >/dev/null)
TARBALL="$TMP/bootstrap-$BOOTSTRAP_VERSION.tgz"
actual="$(openssl dgst -sha512 -binary "$TARBALL" | openssl base64 -A)"
if [[ "$actual" != "$BOOTSTRAP_SHA512" ]]; then
    echo "error: bootstrap-$BOOTSTRAP_VERSION.tgz doesn't match the pinned sha512" >&2
    exit 1
fi
tar -xzf "$TARBALL" -C "$TMP"

echo "-> Compiling the subset with sass@$SASS_VERSION"
# Bootstrap 5.3's own source triggers Sass deprecation warnings that don't affect the output
npx --yes "sass@$SASS_VERSION" \
    --load-path="$TMP/package/scss" \
    --style=compressed --no-source-map --quiet-deps \
    --silence-deprecation=import,global-builtin,color-functions \
    "$ENTRY" "$OUT"

echo "Wrote ${OUT#"$ROOT"/} ($(wc -c <"$OUT") bytes)"
