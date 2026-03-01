# Production Dashboard Deployment Guide

## Status: READY FOR DEPLOYMENT

**Date:** 2026-02-28
**Build Status:** ✓ Both website and docsite built successfully
**ProductionDashboard:** ✓ Integrated at `/dashboard` route

---

## Build Artifacts Verification

| Component | Path | Status |
|-----------|------|--------|
| Website Build | `/Users/playra/trinity-w1/website/dist/` | ✓ EXISTS |
| Docsite Build | `/Users/playra/trinity-w1/docsite/build/` | ✓ EXISTS |
| ProductionDashboard | `website/src/components/ProductionDashboard.tsx` | ✓ EXISTS |
| Route Integration | `website/src/main.tsx` → `/dashboard` | ✓ CONFIGURED |

---

## Deployment Script

### Script Location
```
/Users/playra/trinity-w1/deploy-gh-pages.sh
```

### Usage

```bash
# Basic deployment
./deploy-gh-pages.sh

# Deployment with custom message
./deploy-gh-pages.sh "Production Dashboard - Cycle 98"
```

---

## What the Script Does

### Step 1: Build Website (Vite React SPA)
```bash
cd website && npm run build && cd ..
```
Output: `website/dist/` → gh-pages **root**

### Step 2: Build Docsite (Docusaurus)
```bash
cd docsite && npm run build && cd ..
```
Output: `docsite/build/` → gh-pages **docs/**

### Step 3: Assemble gh-pages Structure
```
/tmp/gh-pages-deploy-<timestamp>/
├── index.html              # Website entry point
├── assets/                 # Website assets
├── wasm/                   # WebAssembly modules
├── docs/                   # Docsite content
│   ├── index.html          # Docs landing
│   ├── api/
│   ├── research/
│   └── ...
├── .nojekyll               # Bypass Jekyll processing
└── CNAME                   # (if website/CNAME exists)
```

### Step 4: Force Push to gh-pages
```bash
cd /tmp/gh-pages-deploy-<timestamp>
git init && git checkout -b gh-pages
git add -A
git commit -m "Deploy: <message>"
git push origin gh-pages --force
```

### Step 5: Cleanup
```bash
cd /Users/playra/trinity-w1
rm -rf /tmp/gh-pages-deploy-<timestamp>
```

---

## Live URLs (After Deployment)

| Site | URL | Base |
|------|-----|------|
| **Website** | https://ghashtag.github.io/trinity/ | `/trinity/` |
| **Docsite** | https://ghashtag.github.io/trinity/docs/ | `/trinity/docs/` |
| **Production Dashboard** | https://ghashtag.github.io/trinity/dashboard | `/trinity/dashboard` |

---

## Verification Steps

### Pre-Deployment Checklist
```bash
# Run verification script
./verify-deploy.sh
```

Expected output:
```
✓ website/dist/
✓ docsite/build/
✓ website/dist/index.html
✓ docsite/build/index.html
✓ ProductionDashboard.tsx
```

### Post-Deployment Verification

1. **Wait 1-2 minutes** for GitHub Pages to build

2. **Hard refresh** browser: `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows/Linux)

3. **Verify URLs:**
   - https://ghashtag.github.io/trinity/ → Website loads
   - https://ghashtag.github.io/trinity/dashboard → Production Dashboard loads
   - https://ghashtag.github.io/trinity/docs/ → Documentation loads

4. **Check for errors:** Open browser DevTools Console (F12)

---

## Deployment Architecture

### Directory Mapping

| Source | Destination | Purpose |
|--------|-------------|---------|
| `website/dist/*` | `gh-pages:/` | Vite React SPA |
| `docsite/build/*` | `gh-pages:/docs/` | Docusaurus docs |

### Key Configuration Files

| File | Purpose | Value |
|------|---------|-------|
| `docsite/docusaurus.config.ts` → `baseUrl` | Docsite base path | `'/trinity/docs/'` |
| `docsite/docusaurus.config.ts` → `routeBasePath` | Docs routing | `'/'` |
| `docsite/src/pages/index.tsx` | **MUST NOT EXIST** | Avoids duplicate routes |

---

## FORBIDDEN Deployment Methods

| Method | Why Forbidden |
|--------|--------------|
| `USE_SSH=true npm run deploy` | Force-pushes ONLY docsite, **deletes website** |
| `npx gh-pages -d dist` | Unreliable, often fails silently |
| Deploy website alone | **Deletes docs/** from gh-pages |
| Deploy docsite alone | **Deletes website** from gh-pages |

**ALWAYS deploy both together using `deploy-gh-pages.sh`**

---

## Troubleshooting

### Issue: Changes not visible after deployment

**Solution:**
1. Wait 2 minutes for GitHub Pages cache
2. Hard refresh: `Cmd+Shift+R`
3. Clear browser cache
4. Check in incognito/private mode

### Issue: 404 on `/docs/` routes

**Solution:**
1. Verify `docsite/docusaurus.config.ts` has `baseUrl: '/trinity/docs/'`
2. Verify `routeBasePath: '/'` (not `'docs'`)
3. Check `docsite/build/` contains `index.html` at root

### Issue: Website loads but docs don't

**Solution:**
1. Check deployment script merged both builds
2. Verify `docs/` directory exists in gh-pages root
3. Check GitHub Pages build logs in repository Settings

### Issue: Production Dashboard not accessible

**Solution:**
1. Check route exists in `website/src/main.tsx`:
   ```tsx
   <Route path="/dashboard" element={<ProductionDashboard />} />
   ```
2. Verify component exists: `website/src/components/ProductionDashboard.tsx`
3. Access via: https://ghashtag.github.io/trinity/dashboard

---

## Quick Commands Reference

```bash
# Verify pre-deployment
./verify-deploy.sh

# Deploy to production
./deploy-gh-pages.sh "Production Dashboard"

# Manual build (for testing)
cd website && npm run build && cd ..
cd docsite && npm run build && cd ..

# Check gh-pages branch history
git log gh-pages --oneline -10

# View gh-pages branch locally
git worktree add ../trinity-gh-pages gh-pages
open ../trinity-gh-pages/index.html
```

---

## Deployment Safety Checklist

- [x] Both `website/dist/` and `docsite/build/` exist
- [x] ProductionDashboard component exists at `/dashboard` route
- [x] `baseUrl` in docsite config is `/trinity/docs/`
- [x] `routeBasePath` in docsite config is `/`
- [x] No `src/pages/index.tsx` in docsite (avoids duplicate routes)
- [x] Deployment script is executable (`chmod +x`)
- [x] Repository remote is `git@github.com:gHashTag/trinity.git`
- [x] Current branch is `main` (not `gh-pages`)

---

## Next Actions

### Immediate (Run Now)
```bash
# 1. Verify everything is ready
./verify-deploy.sh

# 2. Deploy to production
./deploy-gh-pages.sh "Production Dashboard - Cycle 98 - Self-Aware Multi-Agent Sacred Swarm"

# 3. Wait 2 minutes, then verify
open https://ghashtag.github.io/trinity/dashboard
```

### Post-Deployment
- [ ] Verify website loads at https://ghashtag.github.io/trinity/
- [ ] Verify dashboard loads at https://ghashtag.github.io/trinity/dashboard
- [ ] Verify docs load at https://ghashtag.github.io/trinity/docs/
- [ ] Check browser console for errors
- [ ] Test dashboard interactivity
- [ ] Commit deployment scripts to repository

---

## Script Contents

### deploy-gh-pages.sh
Location: `/Users/playra/trinity-w1/deploy-gh-pages.sh`

```bash
#!/bin/bash
set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     TRINITY PRODUCTION DEPLOYMENT - gh-pages                 ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Build Website
echo "[1/5] Building website..."
cd website && npm run build && cd ..
echo "✓ Website built"
echo ""

# Build Docsite
echo "[2/5] Building docsite..."
cd docsite && npm run build && cd ..
echo "✓ Docsite built"
echo ""

# Assemble
echo "[3/5] Assembling gh-pages structure..."
DEPLOY_DIR="/tmp/gh-pages-deploy-$(date +%s)"
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"
cp -r website/dist/* "$DEPLOY_DIR/"
mkdir -p "$DEPLOY_DIR/docs"
cp -r docsite/build/* "$DEPLOY_DIR/docs/"
touch "$DEPLOY_DIR/.nojekyll"
echo "✓ gh-pages structure assembled"
echo ""

# Push
echo "[4/5] Pushing to gh-pages branch..."
cd "$DEPLOY_DIR"
git init
git checkout -b gh-pages
git add -A
git commit -m "Deploy: $(date '+%Y-%m-%d %H:%M:%S')"
git remote add origin git@github.com:gHashTag/trinity.git
git push origin gh-pages --force
echo "✓ Pushed to gh-pages"
echo ""

# Cleanup
cd /Users/playra/trinity-w1
rm -rf "$DEPLOY_DIR"
echo "[5/5] Deployment complete!"
echo ""
echo "Website: https://ghashtag.github.io/trinity/"
echo "Docsite: https://ghashtag.github.io/trinity/docs/"
echo ""
```

---

## Success Criteria

Deployment is successful when:
1. ✓ https://ghashtag.github.io/trinity/ loads without errors
2. ✓ https://ghashtag.github.io/trinity/dashboard displays Production Dashboard
3. ✓ https://ghashtag.github.io/trinity/docs/ displays documentation
4. ✓ Browser console shows no errors
5. ✓ All dashboard widgets render correctly
6. ✓ Navigation between website and docs works

---

**Prepared by:** Claude Code (Sonnet 4.5)
**Repository:** gHashTag/trinity
**Branch:** main
**Commit:** 5698c7bda (Cycle 98 - TRINITY OMEGA AWAKENING)
