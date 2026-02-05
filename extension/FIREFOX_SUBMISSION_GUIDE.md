# Firefox Add-ons Submission Guide - NeoDetect v2.0.0

## Quick Start

Download the latest release from GitHub:
- **Firefox**: https://github.com/gHashTag/trinity/releases/download/ext-v2.0.0/neodetect-firefox-v2.0.0.zip

## Pre-Submission Checklist

### Developer Account
- [ ] Register at https://addons.mozilla.org/developers/
- [ ] Verify email address
- [ ] Complete developer agreement

### Extension Package
- [x] `neodetect-firefox-v2.0.0.zip` created (169KB)
- [x] Manifest V2 compliant
- [x] All icons present (16, 48, 128 px)
- [x] WASM module included (529KB)
- [x] `browser_specific_settings.gecko.id` set
- [x] GitHub Release: https://github.com/gHashTag/trinity/releases/tag/ext-v2.0.0

### Store Listing Content
- [x] Extension name: "NeoDetect Anti-Detect"
- [x] Summary: Ready below
- [x] Description: Ready below
- [x] Category: Privacy & Security
- [x] License: MIT

### Privacy
- [x] Privacy policy URL ready
- [x] No data collection declared

## Submission Steps

### Step 1: Create Developer Account

1. Go to https://addons.mozilla.org/developers/
2. Click "Register or Log In"
3. Create Firefox Account or sign in
4. Accept Developer Agreement

### Step 2: Submit New Add-on

1. Go to https://addons.mozilla.org/developers/addon/submit/
2. Select "On this site" for distribution
3. Upload `neodetect-firefox-v2.0.0.zip`
4. Wait for automated validation

### Step 3: Source Code (if requested)

Firefox may request source code for review. Provide:
```
https://github.com/gHashTag/trinity/tree/ext-v2.0.0/extension/firefox
```

Or upload a ZIP of the source directory.

### Step 4: Add-on Details

**Name**: NeoDetect Anti-Detect

**Add-on URL**: neodetect-antidetect (will become addons.mozilla.org/addon/neodetect-antidetect)

**Summary** (250 chars max):
```
Advanced antidetect browser extension with WASM-powered fingerprint protection. Spoofs canvas, WebGL, audio, and navigator. Open source.
```

**Description**:
```
NeoDetect Anti-Detect

Protect your online privacy with WASM-powered fingerprint protection.

FEATURES:
• Canvas fingerprint protection - Adds noise to canvas operations
• WebGL protection - Spoofs GPU vendor and renderer
• Audio fingerprint protection - Modifies audio context
• Navigator spoofing - Spoofs platform, userAgent, hardware info
• WebRTC IP leak protection - Filters local IP addresses
• Battery API spoofing - Returns spoofed battery status
• OS emulation - Windows 10/11, macOS, Linux
• Hardware emulation - Intel, AMD, Apple Silicon
• GPU emulation - NVIDIA, AMD, Intel, Apple
• Profile management - Save, load, import, export profiles
• Protection presets - Paranoid, Balanced, Minimal

PRIVACY:
• Zero data collection - Everything stays on your device
• No accounts required - Just install and protect
• No network requests - Works completely offline
• Open source - Full code transparency

TECHNICAL:
• WASM engine compiled from Zig
• Deterministic fingerprint generation
• AI-powered fingerprint evolution

SOURCE CODE:
https://github.com/gHashTag/trinity/tree/main/extension/firefox

KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED
```

**Category**: Privacy & Security

**License**: MIT License

**Privacy Policy URL**:
```
https://github.com/gHashTag/trinity/blob/main/extension/chrome/PRIVACY_POLICY.md
```

**Homepage**:
```
https://github.com/gHashTag/trinity
```

**Support URL**:
```
https://github.com/gHashTag/trinity/issues
```

### Step 5: Version Notes

```
Version 2.0.0 - Initial Release

• WASM-powered fingerprint protection
• Canvas, WebGL, Audio fingerprint spoofing
• OS/Hardware/GPU emulation
• Profile management
• AI-powered fingerprint evolution
```

### Step 6: Upload Screenshots

Required: 1-5 screenshots

Recommended sizes:
- 1280x800 (preferred)
- 1280x720
- 640x480

Screenshot suggestions:
1. Main popup interface
2. OS/Hardware/GPU selection
3. Profile management
4. Protection presets

### Step 7: Submit for Review

1. Review all information
2. Click "Submit Version"
3. Wait for review (typically 1-7 days)

## Review Process

### What Reviewers Check

1. **Functionality** - Extension works as described
2. **Permissions** - All permissions are justified
3. **Privacy** - No unexpected data collection
4. **Security** - No malicious code
5. **Source code** - Matches submitted package

### Common Rejection Reasons

1. **Missing source code** - Provide GitHub link or ZIP
2. **Unjustified permissions** - Explain `<all_urls>` is needed for fingerprint protection
3. **Privacy policy issues** - Ensure policy is accessible
4. **Functionality issues** - Test thoroughly before submitting

### Permission Justifications

| Permission | Justification |
|------------|---------------|
| `storage` | Store user settings and profiles locally |
| `activeTab` | Apply fingerprint protection to current tab |
| `<all_urls>` | Apply protection on all websites |
| `alarms` | Schedule periodic fingerprint updates |

## Post-Submission

### If Approved
- Extension published to Firefox Add-ons
- URL: `https://addons.mozilla.org/addon/neodetect-antidetect`
- Share the link!

### If Rejected
1. Read reviewer feedback carefully
2. Address all issues
3. Resubmit with fixes
4. Reply to reviewer if clarification needed

## Updating the Extension

1. Increment version in `manifest.json`
2. Create new release: `git tag ext-v2.1.0 && git push origin ext-v2.1.0`
3. Download new package from GitHub Release
4. Go to Add-on Developer Hub
5. Click "Upload New Version"
6. Submit for review

## Files Reference

| File | Purpose |
|------|---------|
| `neodetect-firefox-v2.0.0.zip` | Upload package |
| `firefox/manifest.json` | Extension manifest |
| `PRIVACY_POLICY.md` | Privacy policy |
| `SCREENSHOT_GUIDE.md` | Screenshot instructions |

## Support

- GitHub Issues: https://github.com/gHashTag/trinity/issues
- Repository: https://github.com/gHashTag/trinity

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED**
