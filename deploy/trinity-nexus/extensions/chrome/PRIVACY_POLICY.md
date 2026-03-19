# NeoDetect Anti-Detect Privacy Policy

**Last Updated**: February 4, 2026  
**Version**: 2.0.0

---

## Overview

NeoDetect Anti-Detect ("NeoDetect", "we", "our", "the extension") is a browser extension that protects your privacy by modifying browser fingerprints. This privacy policy explains how we handle your data.

## Data Collection

### What We DO NOT Collect

NeoDetect does **NOT** collect, store, transmit, or share:

- Personal information (name, email, address)
- Browsing history or visited URLs
- Cookies or session data
- Form data or passwords
- IP addresses
- Device identifiers
- Any data that leaves your browser

### What We Store Locally

NeoDetect stores the following data **only on your device** using Chrome's local storage API:

- **Extension settings**: Your protection preferences (canvas, WebGL, audio, WebRTC toggles)
- **Fingerprint seed**: A random number used to generate consistent fingerprint modifications
- **Profile data**: Saved browser profiles (OS, hardware, GPU configurations)
- **Protection preset**: Your selected preset (Paranoid, Balanced, Minimal)

This data:
- Never leaves your device
- Is not transmitted to any server
- Is not shared with third parties
- Can be deleted by uninstalling the extension or clearing extension data

## How NeoDetect Works

1. **Local Processing**: All fingerprint modifications happen entirely in your browser via WASM
2. **No Network Requests**: NeoDetect makes zero network requests to external servers
3. **No Analytics**: We do not use any analytics, tracking, or telemetry
4. **No Accounts**: No registration or login required
5. **Deterministic Generation**: Fingerprints are generated from a seed, ensuring reproducibility

## Permissions Explained

| Permission | Purpose |
|------------|---------|
| `storage` | Save your settings and profiles locally |
| `activeTab` | Apply protection to current tab |
| `scripting` | Inject fingerprint protection code |
| `alarms` | Schedule periodic fingerprint updates |
| `<all_urls>` | Protect you on all websites |

## Third-Party Services

NeoDetect does **NOT** use any third-party services, APIs, or SDKs.

## Data Security

- All data remains on your device
- No encryption needed as no data is transmitted
- Chrome's built-in storage security applies
- Profile export files are plain JSON (user responsibility to secure)

## Children's Privacy

NeoDetect does not knowingly collect data from anyone, including children under 13.

## Changes to This Policy

We may update this policy. Changes will be posted here with an updated date.

## Contact

For privacy questions:
- GitHub: https://github.com/gHashTag/trinity
- Issues: https://github.com/gHashTag/trinity/issues

## Open Source

NeoDetect is open source. You can verify our privacy claims by reviewing the code:
https://github.com/gHashTag/trinity/tree/main/extension/chrome

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED**

*Your privacy is protected by code, not promises.*
