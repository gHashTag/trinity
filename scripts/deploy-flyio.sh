#!/bin/bash
set -e

# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY Fly.io Deployment Script
# Deploys the Unified API Server to fly.io
# φ² + 1/φ² = 3 | TRINITY v10.2
# ═══════════════════════════════════════════════════════════════════════════════

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     TRINITY API DEPLOYMENT - Fly.io                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="trinity-api"
PRIMARY_REGION="iad"
REGIONS="iad,ams,nrt"

# Check if flyctl is installed
if ! command -v flyctl &> /dev/null; then
    echo -e "${RED}✗ flyctl not found${NC}"
    echo "  Install with: curl -L https://fly.io/install.sh | sh"
    exit 1
fi

# Step 1: Build TRI
echo -e "${BLUE}[1/4] Building TRI CLI...${NC}"
zig build tri
echo -e "${GREEN}✓ TRI built successfully${NC}"
echo ""

# Step 2: Check fly.io authentication
echo -e "${BLUE}[2/4] Checking fly.io authentication...${NC}"
if ! flyctl auth whoami &> /dev/null; then
    echo -e "${YELLOW}! Not authenticated, running login...${NC}"
    flyctl auth login
fi
echo -e "${GREEN}✓ Authenticated to fly.io${NC}"
echo ""

# Step 3: Deploy
echo -e "${BLUE}[3/4] Deploying to fly.io...${NC}"
flyctl deploy --remote-only
echo -e "${GREEN}✓ Deployment complete${NC}"
echo ""

# Step 4: Status and info
echo -e "${BLUE}[4/4] Deployment status...${NC}"
flyctl status
echo ""

# Health check
echo -e "${CYAN}Waiting for health check...${NC}"
sleep 5

# Try to hit the health endpoint
APP_URL="https://${APP_NAME}.fly.io"
if curl -s -f "${APP_URL}/api/health" > /dev/null 2>&1 || curl -s -f "${APP_URL}/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Health check passed${NC}"
    echo ""
    echo -e "${CYAN}API Endpoints:${NC}"
    echo "  • REST API:     ${APP_URL}/api/v1/"
    echo "  • GraphQL:     ${APP_URL}/graphql"
    echo "  • Health:       ${APP_URL}/health"
    echo "  • OpenAPI:      ${APP_URL}/api/openapi.json"
    echo ""
else
    echo -e "${YELLOW}! Health check not yet available (may still be starting)${NC}"
    echo "  Check with: flyctl status"
fi

echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}φ² + 1/φ² = 3 | DEPLOYMENT COMPLETE${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
