#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

ROOT_BUCKET="s3://carlosbustamante.dev"
ROOT_DIST_ID="E6VISQC42W7BR"
ROOT_DIR="sites/root/"

deploy_site() {
    local SITE_NAME=$1
    local DIR=$2
    local BUCKET=$3
    local DIST_ID=$4

    echo -e "${BLUE}🚀 Deploying ${SITE_NAME}...${NC}"
    
    echo "   -> Syncing S3..."
    aws s3 sync "$DIR" "$BUCKET" --delete --quiet \
        --exclude "assets/scss/*" \
        --exclude "assets/css/*.map"

    echo "   -> Removing deploy-excluded source files..."
    aws s3 rm "$BUCKET/assets/scss/" --recursive --quiet
    aws s3 rm "$BUCKET/assets/css/main.css.map" --quiet
    
    echo "   -> Invalidating CloudFront..."
    aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*" > /dev/null
    
    echo -e "${GREEN}✅ ${SITE_NAME} Deployed Successfully!${NC}\n"
}


case "$1" in
    root)
        deploy_site "Portfolio" "$ROOT_DIR" "$ROOT_BUCKET" "$ROOT_DIST_ID"
        ;;
    all)
        deploy_site "Portfolio" "$ROOT_DIR" "$ROOT_BUCKET" "$ROOT_DIST_ID"
        ;;
    *)
        echo "Usage: ./deploy.sh [root|all]"
        exit 1
        ;;
esac
