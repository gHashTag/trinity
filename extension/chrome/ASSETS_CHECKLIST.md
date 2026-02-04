# Chrome Web Store Assets Checklist - NeoDetect

## Required Icons

| Size | File | Status | Notes |
|------|------|--------|-------|
| 16x16 | icons/icon16.png | ✅ Present | Shield/lock design |
| 48x48 | icons/icon48.png | ✅ Present | Shield/lock design |
| 128x128 | icons/icon128.png | ✅ Present | Shield/lock design |

## Store Promotional Images

| Size | Purpose | Status |
|------|---------|--------|
| 440x280 | Small promo tile | ⏳ Needed |
| 920x680 | Large promo tile | ⏳ Needed |
| 1400x560 | Marquee promo | ⏳ Optional |

## Screenshots (Required: 1-5)

| # | Description | Size | Status |
|---|-------------|------|--------|
| 1 | Popup main view with OS/Hardware/GPU selection | 1280x800 or 640x400 | ⏳ Needed |
| 2 | Profile management (save/load/export) | 1280x800 or 640x400 | ⏳ Needed |
| 3 | Protection presets (Paranoid/Balanced/Minimal) | 1280x800 or 640x400 | ⏳ Needed |
| 4 | BrowserLeaks test - before protection | 1280x800 or 640x400 | ⏳ Optional |
| 5 | BrowserLeaks test - after protection | 1280x800 or 640x400 | ⏳ Optional |

## Icon Design Guidelines

**Color Palette:**
- Primary: #6366f1 (Indigo/purple)
- Secondary: #1e1e2e (Dark background)
- Accent: #22c55e (Success green)

**Symbol:**
- Shield with lock
- Or fingerprint with shield
- Clean, recognizable at 16px

## Screenshot Guidelines

1. Use Chrome on macOS/Windows
2. Clean browser (no other extensions visible)
3. Show popup in action with all features visible
4. Highlight OS/Hardware/GPU emulation
5. Use consistent dark theme styling

## Tools for Asset Creation

**Icons:**
- Figma (free)
- Canva (free)
- Adobe Illustrator

**Screenshots:**
- macOS: Cmd+Shift+4
- Windows: Win+Shift+S
- Chrome DevTools device mode

## Submission Checklist

- [x] All icons in PNG format
- [x] Icons present (16, 48, 128)
- [ ] Screenshots show actual extension
- [ ] No placeholder text in screenshots
- [x] Privacy policy ready (PRIVACY_POLICY.md)
- [x] Store listing text reviewed (STORE_LISTING.md)
- [x] Extension tested on Chrome stable
- [x] WASM module compiled and working
- [x] Manifest V3 compliant

## Developer Account Requirements

1. Register at https://chrome.google.com/webstore/devconsole
2. Pay one-time $5 registration fee
3. Verify identity (may require ID verification)
4. Set up payment profile if needed

## Submission Process

1. Go to Chrome Developer Dashboard
2. Click "Add new item"
3. Upload neodetect-v2.0.0.zip
4. Fill in store listing from STORE_LISTING.md
5. Add privacy policy from PRIVACY_POLICY.md
6. Upload screenshots (when ready)
7. Submit for review

## Review Timeline

- Initial review: 1-3 business days
- May take longer for extensions with broad permissions
- WebRTC/storage permissions may trigger additional review
