# Microsoft Edge Add-ons Submission Guide - NeoDetect v2.0.0

## Overview

Edge uses the same extension format as Chrome (Manifest V3), so the Chrome package works directly on Edge without modification.

## Quick Start

Download the Chrome package (works on Edge):
- **Edge/Chrome**: https://github.com/gHashTag/trinity/releases/download/ext-v2.0.0/neodetect-chrome-v2.0.0.zip

## Pre-Submission Checklist

### Developer Account
- [ ] Register at https://partner.microsoft.com/dashboard/microsoftedge/
- [ ] Microsoft account required
- [ ] Complete developer registration (free)

### Extension Package
- [x] `neodetect-chrome-v2.0.0.zip` works on Edge (186KB)
- [x] Manifest V3 compliant
- [x] All icons present (16, 48, 128 px)
- [x] WASM module included (529KB)
- [x] GitHub Release: https://github.com/gHashTag/trinity/releases/tag/ext-v2.0.0

## Submission Steps

### Step 1: Create Partner Center Account

1. Go to https://partner.microsoft.com/dashboard/microsoftedge/
2. Sign in with Microsoft account
3. Complete developer registration
4. Accept Developer Agreement

### Step 2: Submit New Extension

1. Go to Partner Center Dashboard
2. Click "Create new extension"
3. Upload `neodetect-chrome-v2.0.0.zip`
4. Wait for package validation

### Step 3: Extension Properties

**Extension name**: NeoDetect Anti-Detect

**Short description** (250 chars):
```
Advanced antidetect browser extension with WASM-powered fingerprint protection. Spoofs canvas, WebGL, audio, and navigator. Open source.
```

**Description**:
```
NeoDetect Anti-Detect

Protect your online privacy with WASM-powered fingerprint protection.

FEATURES:
• Canvas fingerprint protection
• WebGL fingerprint spoofing
• Audio fingerprint protection
• Navigator property spoofing
• WebRTC IP leak protection
• Battery API spoofing
• OS emulation (Windows, macOS, Linux)
• Hardware emulation (Intel, AMD, Apple)
• GPU emulation (NVIDIA, AMD, Intel, Apple)
• Profile management
• Protection presets (Paranoid, Balanced, Minimal)

PRIVACY:
• Zero data collection
• No accounts required
• Works completely offline
• Open source

SOURCE CODE:
https://github.com/gHashTag/trinity
```

**Category**: Privacy & Security

**Privacy Policy URL**:
```
https://github.com/gHashTag/trinity/blob/main/extension/chrome/PRIVACY_POLICY.md
```

**Support URL**:
```
https://github.com/gHashTag/trinity/issues
```

**Website**:
```
https://github.com/gHashTag/trinity
```

### Step 4: Store Listing

**Language**: English

**Screenshots**: Upload 1-10 screenshots
- Recommended: 1280x800 or 640x480
- Show popup interface
- Show settings/configuration

**Promotional images** (optional):
- Small: 440x280
- Large: 1400x560

### Step 5: Availability

**Markets**: All markets (or select specific)
**Visibility**: Public
**Pricing**: Free

### Step 6: Submit for Review

1. Review all information
2. Click "Publish"
3. Wait for certification (1-7 days)

## Review Process

### What Microsoft Checks

1. **Security** - No malicious code
2. **Privacy** - Matches privacy policy
3. **Functionality** - Works as described
4. **Content** - Appropriate for all audiences
5. **Permissions** - Justified and minimal

### Certification Requirements

- Extension must work on Edge
- All permissions must be justified
- Privacy policy must be accessible
- No deceptive practices

### Common Rejection Reasons

1. **Missing privacy policy** - Ensure URL is accessible
2. **Unjustified permissions** - Explain `<all_urls>` need
3. **Broken functionality** - Test on Edge before submitting
4. **Incomplete listing** - Fill all required fields

## Post-Submission

### If Approved
- Extension published to Edge Add-ons
- URL: `https://microsoftedge.microsoft.com/addons/detail/neodetect-anti-detect/[id]`

### If Rejected
1. Read certification report
2. Fix identified issues
3. Resubmit

## Updating the Extension

1. Create new release: `git tag ext-v2.1.0 && git push origin ext-v2.1.0`
2. Download new Chrome package from GitHub Release
3. Go to Partner Center
4. Select extension → "Update"
5. Upload new package
6. Submit for certification

## Local Testing on Edge

```bash
# 1. Open Edge
# 2. Go to edge://extensions/
# 3. Enable "Developer mode"
# 4. Click "Load unpacked"
# 5. Select extension/chrome folder
```

## Files Reference

| File | Purpose |
|------|---------|
| `neodetect-chrome-v2.0.0.zip` | Upload package (same as Chrome) |
| `chrome/manifest.json` | Extension manifest |
| `PRIVACY_POLICY.md` | Privacy policy |

## Support

- GitHub Issues: https://github.com/gHashTag/trinity/issues
- Repository: https://github.com/gHashTag/trinity

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED**
