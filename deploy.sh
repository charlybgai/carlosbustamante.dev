#!/usr/bin/env bash
# Deploys sites/root/ to the production bucket and invalidates CloudFront.
#
#   ./deploy.sh root            deploy to production
#   ./deploy.sh root --dryrun   run the checks and show what would change; change nothing
#
# A real deploy refuses to run unless:
#   - the current branch is main and matches origin/main (what's live is also on GitHub)
#   - sites/root/ has no uncommitted or untracked files (only committed files go live)
#   - every changed main.css / script.js comes with a new ?v= cache-buster in all pages
# The dry run reports the same checks as warnings, so it can be used on any branch.
#
# Every object is uploaded with a Cache-Control header (see cache_control_groups below), and
# files in the bucket that don't exist locally are deleted.
set -euo pipefail

BUCKET_NAME="carlosbustamante.dev"
BUCKET="s3://${BUCKET_NAME}"
DIST_ID="E6VISQC42W7BR"
DIR="sites/root"

# Source files that exist under sites/root but must never be published
EXCLUDES=(--exclude "assets/scss/*" --exclude "*.map")

# Cache-Control per kind of file:
# - Pages and crawler files: browsers revalidate on every visit (cheap 304s via ETag), while
#   CloudFront keeps them for a day (s-maxage). Every deploy invalidates CloudFront anyway.
# - main.css / script.js are referenced with ?v=<tag>, so a changed file always has a new URL
#   for the browser: they can be cached for a year. The cache-buster check below enforces it.
# - Everything else (images, PDFs) is replaced in place now and then: one day.
CC_PAGES="public, max-age=0, must-revalidate, s-maxage=86400"
CC_VERSIONED="public, max-age=31536000, immutable"
CC_OTHER="public, max-age=86400"

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Usage: ./deploy.sh root [--dryrun]"
    exit 1
}

DRYRUN=0
case "${1:-}" in
    root | all) ;; # "all" kept for backwards compatibility: there is only one site
    *) usage ;;
esac
case "${2:-}" in
    "") ;;
    --dryrun) DRYRUN=1 ;;
    *) usage ;;
esac

# Run from the repo root no matter where the script is called from
cd "$(dirname "${BASH_SOURCE[0]}")"

PROBLEMS=0
problem() {
    if [[ $DRYRUN -eq 1 ]]; then
        echo -e "${YELLOW}   ! $1 (a real deploy would stop here)${NC}"
    else
        echo -e "${RED}   ✗ $1${NC}" >&2
    fi
    PROBLEMS=$((PROBLEMS + 1))
}

md5_of() {
    if command -v md5sum >/dev/null; then md5sum "$1" | cut -d' ' -f1; else md5 -q "$1"; fi
}

check_git() {
    echo "   -> Checking git state..."
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD)
    [[ "$branch" == "main" ]] || problem "Current branch is '$branch'; deploy from main"

    local dirty
    dirty=$(git status --porcelain --untracked-files=all -- "$DIR")
    if [[ -n "$dirty" ]]; then
        problem "Uncommitted or untracked files in $DIR/:"
        while IFS= read -r line; do echo "        $line"; done <<<"$dirty" >&2
    fi

    if git fetch --quiet origin main 2>/dev/null; then
        [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] ||
            problem "HEAD doesn't match origin/main; push or pull first"
    else
        problem "Couldn't fetch origin/main to compare"
    fi
}

check_cache_busters() {
    echo "   -> Checking cache-busters..."
    local asset name pages_token deployed_html deployed_token
    # The deployed index.html tells which ?v= tags are live (missing on a first deploy)
    deployed_html=$(aws s3 cp "$BUCKET/index.html" - 2>/dev/null || true)

    for asset in assets/css/main.css assets/js/script.js; do
        name=${asset##*/}
        # All pages that load the asset must use the same tag
        pages_token=$(grep -oh "${name}?v=[^\"]*" "$DIR/index.html" "$DIR/es/index.html" "$DIR/404.html" | sort -u || true)
        if [[ $(wc -l <<<"$pages_token") -ne 1 ]]; then
            problem "The pages don't agree on the ${name} cache-buster: $(tr '\n' ' ' <<<"$pages_token")"
            continue
        fi
        [[ -z "$deployed_html" ]] && continue
        # S3 ETag is the file's MD5 for these small single-part SSE-S3 uploads
        if [[ "$(md5_of "$DIR/$asset")" == "$(aws s3api head-object --bucket "$BUCKET_NAME" --key "$asset" \
            --query ETag --output text 2>/dev/null | tr -d '"')" ]]; then
            continue
        fi
        deployed_token=$(grep -o "${name}?v=[^\"]*" <<<"$deployed_html" | head -n 1 || true)
        [[ "$pages_token" != "$deployed_token" ]] ||
            problem "${name} changed but its cache-buster is still ${pages_token#*\?}; bump it in all pages"
    done
}

# Lists what a deploy changes, comparing file contents (local MD5 vs S3 ETag). `aws s3 sync`
# compares size and modification time instead, so after a git checkout it reports unchanged files.
preview_changes() {
    declare -A remote=()
    local key etag path rel added=0 changed=0 deleted=0
    while IFS=$'\t' read -r key etag; do
        [[ -n "$key" && "$key" != "None" ]] && remote["$key"]=${etag//\"/}
    done < <(aws s3api list-objects-v2 --bucket "$BUCKET_NAME" --query 'Contents[].[Key,ETag]' --output text)

    while IFS= read -r -d '' path; do
        rel=${path#"$DIR"/}
        [[ "$rel" == assets/scss/* || "$rel" == *.map ]] && continue
        if [[ -z "${remote[$rel]+set}" ]]; then
            echo "      + $rel"
            added=$((added + 1))
        elif [[ "${remote[$rel]}" != "$(md5_of "$path")" ]]; then
            echo "      ~ $rel"
            changed=$((changed + 1))
        fi
        unset "remote[$rel]"
    done < <(find "$DIR" -type f -print0 | sort -z)

    for key in "${!remote[@]}"; do
        echo "      - $key"
        deleted=$((deleted + 1))
    done
    echo "      ($added new, $changed changed, $deleted to delete)"
}

upload_group() {
    local cache_control=$1
    shift
    aws s3 cp "$DIR" "$BUCKET" --recursive --only-show-errors \
        --exclude "*" "$@" "${EXCLUDES[@]}" --cache-control "$cache_control"
}

echo -e "${BLUE}🚀 Deploying the portfolio$([[ $DRYRUN -eq 1 ]] && echo ' (dry run)')...${NC}"
aws sts get-caller-identity >/dev/null || { echo "error: AWS credentials aren't working" >&2; exit 1; }
check_git
check_cache_busters

if [[ $DRYRUN -eq 0 && $PROBLEMS -gt 0 ]]; then
    echo -e "${RED}Deploy cancelled: fix the problems above and try again.${NC}" >&2
    exit 1
fi

echo "   -> Changes compared with the bucket (+ new, ~ changed, - deleted):"
preview_changes

if [[ $DRYRUN -eq 1 ]]; then
    echo "   -> Every file is re-uploaded so its Cache-Control header is current:"
    echo "      pages/xml/txt '$CC_PAGES' | css/js '$CC_VERSIONED' | other '$CC_OTHER'"
    echo -e "${GREEN}Dry run finished ($PROBLEMS problem(s)). Nothing was changed.${NC}"
    exit 0
fi

echo "   -> Uploading with Cache-Control headers..."
upload_group "$CC_PAGES" --include "*.html" --include "*.xml" --include "*.txt"
upload_group "$CC_VERSIONED" --include "*.css" --include "*.js"
upload_group "$CC_OTHER" --include "*" --exclude "*.html" --exclude "*.xml" --exclude "*.txt" --exclude "*.css" --exclude "*.js"

echo "   -> Deleting files that no longer exist locally..."
# Everything was just uploaded, so sync only has deletions left to do
aws s3 sync "$DIR" "$BUCKET" --delete --only-show-errors "${EXCLUDES[@]}"
aws s3 rm "$BUCKET" --recursive --only-show-errors --exclude "*" --include "assets/scss/*" --include "*.map"

echo "   -> Invalidating CloudFront..."
INVALIDATION_ID=$(aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*" \
    --query Invalidation.Id --output text)
aws cloudfront wait invalidation-completed --distribution-id "$DIST_ID" --id "$INVALIDATION_ID"

echo -e "${GREEN}✅ Deployed $(git rev-parse --short HEAD) to https://${BUCKET_NAME}${NC}"
