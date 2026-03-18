#!/bin/bash
set -e

# TRI Production Deployment Script
# Deploys BOTH website and docs to gh-pages branch
#
# CRITICAL: Always deploy both together - gh-pages contains:
#   / (root)           = website (Vite React SPA)
#   /docs/             = docs (Docusaurus)

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     TRINITY PRODUCTION DEPLOYMENT - gh-pages                 ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Step 1: Build Website
echo -e "${BLUE}[1/5] Building website...${NC}"
cd website
npm run build
cd ..
echo -e "${GREEN}✓ Website built successfully${NC}"
echo ""

# Step 2: Build Docsite
echo -e "${BLUE}[2/5] Building docs...${NC}"
cd docs
npm run build
cd ..
echo -e "${GREEN}✓ Docsite built successfully${NC}"
echo ""

# Step 3: Prepare temporary directory
echo -e "${BLUE}[3/5] Assembling gh-pages structure...${NC}"
DEPLOY_DIR="/tmp/gh-pages-deploy-$(date +%s)"
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"

# Copy website to root
cp -r website/dist/* "$DEPLOY_DIR/"

# Copy docs to docs/ subdirectory
mkdir -p "$DEPLOY_DIR/docs"
cp -r docs/build/* "$DEPLOY_DIR/docs/"

# Verify structure
echo -e "${GREEN}✓ gh-pages structure assembled${NC}"
echo "  ├─ website/ → $DEPLOY_DIR/"
echo "  └─ docs/ → $DEPLOY_DIR/docs/"
echo ""

# Step 4: Create .nojekyll and CNAME if needed
touch "$DEPLOY_DIR/.nojekyll"

if [ -f "website/CNAME" ]; then
  cp website/CNAME "$DEPLOY_DIR/"
fi

# Step 5: Git operations
echo -e "${BLUE}[4/5] Pushing to gh-pages branch...${NC}"
cd "$DEPLOY_DIR"
git init
git checkout -b gh-pages
git add -A

DEPLOY_MESSAGE="Deploy: $(date '+%Y-%m-%d %H:%M:%S')"

if [ -n "$1" ]; then
  DEPLOY_MESSAGE="Deploy: $1"
fi

git commit -m "$DEPLOY_MESSAGE"

git remote add origin git@github.com:gHashTag/trinity.git

echo -e "${YELLOW}Force pushing to gh-pages...${NC}"
git push origin gh-pages --force

echo ""
echo -e "${GREEN}✓ Pushed to gh-pages${NC}"
echo ""

# Step 6: Cleanup and verification
cd /Users/playra/trinity-w1
rm -rf "$DEPLOY_DIR"

echo -e "${BLUE}[5/5] Deployment complete!${NC}"
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    LIVE URLS                                  ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  Website: https://ghashtag.github.io/trinity/                 ║"
echo "║  Docsite: https://ghashtag.github.io/trinity/docs/            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${YELLOW}Note: GitHub Pages takes 1-2 minutes to update.${NC}"
echo -e "      Use Cmd+Shift+R for hard refresh in browser."
echo ""
