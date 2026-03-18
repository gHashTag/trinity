#!/bin/bash
# Quick verification script before deployment

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     DEPLOYMENT VERIFICATION                                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_file() {
  if [ -f "$1" ]; then
    echo -e "${GREEN}✓${NC} $1"
    return 0
  else
    echo -e "${RED}✗${NC} $1 (missing)"
    return 1
  fi
}

check_dir() {
  if [ -d "$1" ]; then
    echo -e "${GREEN}✓${NC} $1/"
    return 0
  else
    echo -e "${RED}✗${NC} $1/ (missing)"
    return 1
  fi
}

echo "Checking build outputs..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_dir "website/dist"
check_dir "docs/build"
echo ""

echo "Checking critical files..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_file "website/dist/index.html"
check_file "docs/build/index.html"
check_file "website/src/components/ProductionDashboard.tsx"
echo ""

echo "Checking ProductionDashboard integration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if grep -q "ProductionDashboard" website/src/App.tsx 2>/dev/null; then
  echo -e "${GREEN}✓${NC} ProductionDashboard imported in App.tsx"
else
  echo -e "${YELLOW}⚠${NC} ProductionDashboard not found in App.tsx (may be route-based)"
fi
echo ""

echo "Checking gh-pages branch status..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if git rev-parse --verify gh-pages >/dev/null 2>&1; then
  LAST_DEPLOY=$(git log gh-pages -1 --format="%cd" --date=relative 2>/dev/null || echo "unknown")
  echo -e "${GREEN}✓${NC} gh-pages branch exists (last deploy: $LAST_DEPLOY)"
else
  echo -e "${YELLOW}⚠${NC} gh-pages branch not found (will be created on first deploy)"
fi
echo ""

echo "Repository info..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
REMOTE=$(git config --get remote.origin.url)
echo "Origin: $REMOTE"
BRANCH=$(git branch --show-current)
echo "Current branch: $BRANCH"
echo ""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                     NEXT STEPS                                ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  1. Review verification results above                        ║"
echo "║  2. Run: ./deploy-gh-pages.sh \"Production Dashboard\"         ║"
echo "║  3. Wait 1-2 minutes for GitHub Pages to update              ║"
echo "║  4. Verify at: https://ghashtag.github.io/trinity/           ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
