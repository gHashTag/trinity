# Chrome Web Store Submission Guide - NeoDetect v2.0.0

## Quick Start

Download the latest release from GitHub:
- **Chrome**: https://github.com/gHashTag/trinity/releases/download/ext-v2.0.0/neodetect-chrome-v2.0.0.zip
- **Firefox**: https://github.com/gHashTag/trinity/releases/download/ext-v2.0.0/neodetect-firefox-v2.0.0.zip

## Pre-Submission Checklist

### Developer Account
- [ ] Register at https://chrome.google.com/webstore/devconsole
- [ ] Pay $5 one-time registration fee
- [ ] Complete identity verification (if required)

### Extension Package
- [x] `neodetect-chrome-v2.0.0.zip` created (186KB)
- [x] Manifest V3 compliant
- [x] All icons present (16, 48, 128 px)
- [x] WASM module included and working (529KB, proper magic bytes)
- [x] GitHub Release available: https://github.com/gHashTag/trinity/releases/tag/ext-v2.0.0

### Store Listing Content
- [x] Extension name: "NeoDetect Anti-Detect - WASM-Powered Privacy Protection"
- [x] Short description (122 chars): Ready in STORE_LISTING.md
- [x] Detailed description: Ready in STORE_LISTING.md
- [x] Category: Privacy & Security
- [x] Language: English

### Privacy
- [x] Privacy policy: PRIVACY_POLICY.md
- [x] Single purpose declared: Fingerprint protection
- [x] Data usage disclosure: No data collection

### Assets Needed
- [ ] Screenshots (1-5 at 1280x800) - See SCREENSHOT_GUIDE.md
- [ ] Small promo tile (440x280) - Optional but recommended
- [ ] Large promo tile (920x680) - Optional

## Submission Steps

### Step 1: Upload Package
1. Go to https://chrome.google.com/webstore/devconsole
2. Click "Add new item"
3. Upload `neodetect-v2.0.0.zip`
4. Wait for validation

### Step 2: Store Listing Tab
Copy from `extension/chrome/STORE_LISTING.md`:

**Name**: NeoDetect Anti-Detect - WASM-Powered Privacy Protection

**Summary**: Advanced antidetect browser with WASM fingerprint protection. Canvas, WebGL, Audio, WebRTC. OS/GPU emulation. Open source.

**Description**: Copy the "Detailed Description" section from STORE_LISTING.md

**Category**: Privacy & Security

**Language**: English

### Step 3: Privacy Tab

**Single Purpose**: 
"Protect user privacy by modifying browser fingerprints to prevent tracking"

**Permission Justifications**:

| Permission | Justification |
|------------|---------------|
| storage | Store user settings and saved profiles locally |
| activeTab | Apply fingerprint protection to the current tab |
| scripting | Inject fingerprint modification scripts into pages |
| alarms | Schedule periodic fingerprint updates |
| host_permissions (<all_urls>) | Apply protection on all websites user visits |

**Data Usage**:
- Does NOT collect user data
- Does NOT transmit data externally
- All processing happens locally

**Privacy Policy URL** (copy this exactly):
```
https://github.com/gHashTag/trinity/blob/main/extension/chrome/PRIVACY_POLICY.md
```

### Step 4: Distribution Tab

**Visibility**: Public
**Countries**: All regions
**Pricing**: Free

### Step 5: Upload Screenshots
1. Take screenshots following SCREENSHOT_GUIDE.md
2. Upload 1-5 screenshots at 1280x800 or 640x400

### Step 6: Submit for Review
1. Click "Submit for Review"
2. Confirm submission
3. Wait 1-3 business days for review

## Post-Submission

### If Approved
- Extension will be published automatically (or manually if deferred)
- Share the Chrome Web Store URL

### If Rejected
Common rejection reasons:
1. **Insufficient description** - Add more detail about functionality
2. **Permission justification** - Explain why each permission is needed
3. **Privacy policy issues** - Ensure policy is accessible and complete
4. **Functionality issues** - Test extension thoroughly before resubmitting

## Files Reference

| File | Purpose |
|------|---------|
| `neodetect-v2.0.0.zip` | Upload package |
| `STORE_LISTING.md` | Copy text for store listing |
| `PRIVACY_POLICY.md` | Privacy policy content |
| `SCREENSHOT_GUIDE.md` | Instructions for screenshots |
| `ASSETS_CHECKLIST.md` | Asset requirements checklist |

## Firefox Add-ons Submission

For Firefox submission, see [FIREFOX_SUBMISSION_GUIDE.md](FIREFOX_SUBMISSION_GUIDE.md).

Quick summary:
1. Register at https://addons.mozilla.org/developers/
2. Upload `neodetect-firefox-v2.0.0.zip`
3. Fill in add-on details
4. Submit for review (1-7 days)

## Microsoft Edge Add-ons Submission

For Edge submission, see [EDGE_SUBMISSION_GUIDE.md](EDGE_SUBMISSION_GUIDE.md).

Edge uses the same package as Chrome:
1. Register at https://partner.microsoft.com/dashboard/microsoftedge/
2. Upload `neodetect-chrome-v2.0.0.zip` (same as Chrome!)
3. Fill in extension details
4. Submit for certification (1-7 days)

## Support

- GitHub Issues: https://github.com/gHashTag/trinity/issues
- Repository: https://github.com/gHashTag/trinity

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED**
