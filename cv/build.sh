#!/usr/bin/env bash
# Builds the CV PDFs from cv/CV.tex (English) and cv/CV_ES.tex (Spanish) with pdfLaTeX,
# inside a pinned TeX Live 2025 image (the same TeX Live year Overleaf used), and copies them
# to sites/root/assets/files/. Only Docker is needed; nothing is installed on the host.
#
#   ./cv/build.sh          build both CVs and publish them to the site
#   ./cv/build.sh --check  build into cv/build/ only (don't touch the site files)
set -euo pipefail

# TeX Live 2025 "historic" is frozen, and the digest pins the exact image.
# To upgrade TeX Live, change this line and compare the output before publishing.
IMAGE="texlive/texlive@sha256:f25ee2dcd00f58198f918064f4a1c8562410b33e84155bd55b02b419d73d9391" # TL2025-historic

CV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_FILES="$CV_DIR/../sites/root/assets/files"
BUILD_DIR="$CV_DIR/build"
PUBLISH=1
[[ "${1:-}" == "--check" ]] && PUBLISH=0

command -v docker >/dev/null || { echo "error: docker is required" >&2; exit 1; }
mkdir -p "$BUILD_DIR"

# Reproducible output: the same sources always give byte-identical PDFs. The PDF dates and
# document ID come from the last commit that touched cv/ (not from the clock), and every run
# compiles from scratch (-g) so a stale latexmk cache can't keep old timestamps.
SOURCE_DATE_EPOCH=$(git -C "$CV_DIR" log -1 --format=%ct -- . 2>/dev/null || true)
SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-0}

for doc in CV CV_ES; do
    echo "-> Building $doc.pdf"
    # Run as the host user so files in build/ aren't owned by root.
    # -no-shell-escape: the sources never need to run shell commands.
    if ! docker run --rm --network none \
        --user "$(id -u):$(id -g)" \
        -e HOME=/tmp \
        -e SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" -e FORCE_SOURCE_DATE=1 \
        -v "$CV_DIR:/cv" -w /cv \
        "$IMAGE" \
        latexmk -g -pdf -no-shell-escape -interaction=nonstopmode -halt-on-error \
            -outdir=build -quiet "$doc.tex" >"$BUILD_DIR/$doc.build.log" 2>&1; then
        echo "error: $doc failed to build. Last lines of the log:" >&2
        tail -n 30 "$BUILD_DIR/$doc.log" >&2 2>/dev/null || tail -n 30 "$BUILD_DIR/$doc.build.log" >&2
        exit 1
    fi

    # Fail if the content doesn't fit (the CVs are designed to be exactly one page).
    # pdfTeX reports it in the log: "Output written on build/CV.pdf (1 page, 92054 bytes)."
    pages=$(sed -n 's/^Output written on .*(\([0-9]*\) pages\{0,1\},.*/\1/p' "$BUILD_DIR/$doc.log" | tail -n 1)
    if [[ "$pages" != "1" ]]; then
        echo "error: $doc.pdf has $pages pages; it must fit on one page" >&2
        exit 1
    fi
    if grep -q 'Overfull \\hbox' "$BUILD_DIR/$doc.log"; then
        echo "warning: $doc has lines that stick out past the margin:" >&2
        grep -A1 'Overfull \\hbox' "$BUILD_DIR/$doc.log" | head -n 6 >&2
    fi
done

if [[ $PUBLISH -eq 1 ]]; then
    cp "$BUILD_DIR/CV.pdf" "$SITE_FILES/CV.pdf"
    cp "$BUILD_DIR/CV_ES.pdf" "$SITE_FILES/CV_ES.pdf"
    echo "Published to sites/root/assets/files/ (CV.pdf, CV_ES.pdf)"
else
    echo "Built in cv/build/ (not published)"
fi
