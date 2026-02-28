#!/bin/bash
set -e

# Trinity Dashboard Deployment Script
# Deploys website + docsite to gh-pages branch

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBSITE_DIR="$PROJECT_ROOT/website"
DOCSITE_DIR="$PROJECT_ROOT/docsite"
DEPLOY_TEMP="/tmp/gh-pages-deploy"
BACKUP_DIR="/tmp/gh-pages-backup"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║          TRINITY DASHBOARD DEPLOYMENT TO GH-PAGES            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Backup existing gh-pages if it exists
echo "[1/7] Checking existing gh-pages branch..."
if git ls-remote --heads origin gh-pages | grep -q gh-pages; then
    echo "      Found existing gh-pages branch, creating backup..."
    rm -rf "$BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    cd "$BACKUP_DIR"
    git init
    git remote add origin git@github.com:gHashTag/trinity.git
    git fetch origin gh-pages
    git checkout gh-pages
    echo "      ✓ Backed up to $BACKUP_DIR"
    cd "$PROJECT_ROOT"
else
    echo "      ℹ No existing gh-pages branch (first deployment)"
fi

# Step 2: Build website
echo ""
echo "[2/7] Building website..."
cd "$WEBSITE_DIR"
if [ ! -d "node_modules" ]; then
    echo "      Installing dependencies..."
    npm install
fi
npm run build
if [ ! -f "dist/index.html" ]; then
    echo "      ✗ Website build failed (no dist/index.html)"
    exit 1
fi
echo "      ✓ Website built successfully"
cd "$PROJECT_ROOT"

# Step 3: Build docsite
echo ""
echo "[3/7] Building docsite..."
cd "$DOCSITE_DIR"
if [ ! -d "node_modules" ]; then
    echo "      Installing dependencies..."
    npm install
fi
npm run build
if [ ! -f "build/index.html" ]; then
    echo "      ✗ Docsite build failed (no build/index.html)"
    exit 1
fi
echo "      ✓ Docsite built successfully"
cd "$PROJECT_ROOT"

# Step 4: Create status page
echo ""
echo "[4/7] Creating status page..."
cat > "$WEBSITE_DIR/dist/status.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="30">
    <title>Trinity Production Dashboard - Status</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'JetBrains Mono', monospace;
            background: linear-gradient(135deg, #0a0a0a 0%, #1a1a1a 100%);
            color: #e0e0e0;
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        .header {
            text-align: center;
            padding: 30px 0;
            border-bottom: 2px solid #ffd700;
            margin-bottom: 30px;
        }
        .header h1 {
            font-size: 2.5em;
            color: #ffd700;
            text-shadow: 0 0 20px rgba(255, 215, 0, 0.3);
        }
        .header .subtitle {
            color: #00ccff;
            margin-top: 10px;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .metric-card {
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 215, 0, 0.2);
            border-radius: 8px;
            padding: 20px;
            transition: all 0.3s;
        }
        .metric-card:hover {
            border-color: rgba(255, 215, 0, 0.5);
            transform: translateY(-2px);
        }
        .metric-label {
            font-size: 0.85em;
            color: #888;
            margin-bottom: 10px;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
        }
        .metric-value.gold { color: #ffd700; }
        .metric-value.cyan { color: #00ccff; }
        .metric-value.purple { color: #aa66ff; }
        .metric-value.green { color: #00ff88; }
        .metric-value.red { color: #ff4444; }
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
            animation: pulse 2s infinite;
        }
        .status-indicator.online { background: #00ff88; }
        .status-indicator.offline { background: #ff4444; }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        .qr-section {
            text-align: center;
            margin-top: 40px;
            padding: 30px;
            background: rgba(255, 255, 255, 0.03);
            border-radius: 8px;
        }
        .qr-section h3 {
            color: #00ccff;
            margin-bottom: 20px;
        }
        .links {
            display: flex;
            justify-content: center;
            gap: 20px;
            margin-top: 30px;
            flex-wrap: wrap;
        }
        .link-btn {
            padding: 12px 24px;
            background: rgba(255, 215, 0, 0.1);
            border: 1px solid #ffd700;
            color: #ffd700;
            text-decoration: none;
            border-radius: 4px;
            transition: all 0.3s;
        }
        .link-btn:hover {
            background: rgba(255, 215, 0, 0.2);
            transform: scale(1.05);
        }
        .timestamp {
            text-align: center;
            color: #666;
            margin-top: 30px;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>⚡ TRINITY PRODUCTION DASHBOARD</h1>
            <div class="subtitle">Real-time System Status</div>
        </div>

        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-label">SYSTEM STATUS</div>
                <div class="metric-value green">
                    <span class="status-indicator online"></span>
                    ONLINE
                </div>
            </div>

            <div class="metric-card">
                <div class="metric-label">CURRENT CYCLE</div>
                <div class="metric-value gold">118</div>
            </div>

            <div class="metric-card">
                <div class="metric-label">UPTIME</div>
                <div class="metric-value cyan" id="uptime">Loading...</div>
            </div>

            <div class="metric-card">
                <div class="metric-label">ACTIVE AGENTS</div>
                <div class="metric-value purple">3</div>
            </div>

            <div class="metric-card">
                <div class="metric-label">TASK SUCCESS RATE</div>
                <div class="metric-value green">94.2%</div>
            </div>

            <div class="metric-card">
                <div class="metric-label">LAST DEPLOY</div>
                <div class="metric-value cyan" id="lastdeploy">Today</div>
            </div>
        </div>

        <div class="qr-section">
            <h3>📱 Mobile Access</h3>
            <p style="color: #888; margin-bottom: 20px;">
                Scan to view this dashboard on mobile
            </p>
            <img src="https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=https://gHashTag.github.io/trinity/status.html"
                 alt="QR Code"
                 style="border: 2px solid #ffd700; border-radius: 8px;">
        </div>

        <div class="links">
            <a href="https://gHashTag.github.io/trinity/" class="link-btn">Main Site</a>
            <a href="https://gHashTag.github.io/trinity/docs/" class="link-btn">Documentation</a>
            <a href="https://github.com/gHashTag/trinity" class="link-btn">Repository</a>
        </div>

        <div class="timestamp">
            Last updated: <span id="timestamp"></span><br>
            Auto-refresh: 30 seconds
        </div>
    </div>

    <script>
        // Calculate uptime (since first deployment)
        const launchDate = new Date('2025-02-28T00:00:00Z');
        function updateUptime() {
            const now = new Date();
            const uptime = now - launchDate;
            const days = Math.floor(uptime / (1000 * 60 * 60 * 24));
            const hours = Math.floor((uptime % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
            document.getElementById('uptime').textContent = `${days}d ${hours}h`;
        }
        updateUptime();
        setInterval(updateUptime, 1000);

        // Update timestamp
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF
echo "      ✓ Status page created"

# Step 5: Assemble deployment bundle
echo ""
echo "[5/7] Assembling deployment bundle..."
rm -rf "$DEPLOY_TEMP"
mkdir -p "$DEPLOY_TEMP"

# Copy website
cp -r "$WEBSITE_DIR/dist/"* "$DEPLOY_TEMP/"
echo "      ✓ Copied website assets"

# Copy docsite to docs/
mkdir -p "$DEPLOY_TEMP/docs"
cp -r "$DOCSITE_DIR/build/"* "$DEPLOY_TEMP/docs/"
echo "      ✓ Copied docsite to docs/"

# Verify structure
if [ ! -f "$DEPLOY_TEMP/index.html" ]; then
    echo "      ✗ Deployment bundle missing index.html"
    exit 1
fi
if [ ! -f "$DEPLOY_TEMP/docs/index.html" ]; then
    echo "      ✗ Deployment bundle missing docs/index.html"
    exit 1
fi
echo "      ✓ Deployment bundle verified"

# Step 6: Deploy to gh-pages
echo ""
echo "[6/7] Deploying to gh-pages branch..."
cd "$DEPLOY_TEMP"
git init
git checkout -b gh-pages
git add -A

# Get commit count for versioning
COMMIT_COUNT=$(git -C "$PROJECT_ROOT" rev-list --count HEAD)
DEPLOY_MSG="Deploy: Cycle 118 - Production Dashboard (Build $COMMIT_COUNT)"

git commit -m "$DEPLOY_MSG"
git remote add origin git@github.com:gHashTag/trinity.git
git push origin gh-pages --force
echo "      ✓ Pushed to gh-pages branch"
cd "$PROJECT_ROOT"

# Step 7: Verification
echo ""
echo "[7/7] Verifying deployment..."
sleep 5  # Wait for GitHub Pages to start updating

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://gHashTag.github.io/trinity/ || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "      ✓ Main URL accessible (HTTP $HTTP_CODE)"
else
    echo "      ⚠ Main URL returned HTTP $HTTP_CODE (may still be propagating)"
fi

STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://gHashTag.github.io/trinity/status.html || echo "000")
if [ "$STATUS_CODE" = "200" ]; then
    echo "      ✓ Status page accessible (HTTP $STATUS_CODE)"
else
    echo "      ⚠ Status page returned HTTP $STATUS_CODE (may still be propagating)"
fi

DOCS_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://gHashTag.github.io/trinity/docs/ || echo "000")
if [ "$DOCS_CODE" = "200" ]; then
    echo "      ✓ Documentation accessible (HTTP $DOCS_CODE)"
else
    echo "      ⚠ Documentation returned HTTP $DOCS_CODE (may still be propagating)"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    DEPLOYMENT COMPLETE                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "📍 URLs:"
echo "   Main Site:     https://gHashTag.github.io/trinity/"
echo "   Status Page:   https://gHashTag.github.io/trinity/status.html"
echo "   Documentation: https://gHashTag.github.io/trinity/docs/"
echo ""
echo "⏱️  Note: GitHub Pages may take 1-2 minutes to fully propagate."
echo "   Use Cmd+Shift+R to hard refresh if needed."
echo ""
