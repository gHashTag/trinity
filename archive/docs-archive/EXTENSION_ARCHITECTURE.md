# FIREBIRD Browser Extension Architecture

## Overview

Browser extension for FIREBIRD integrates the ternary B2T pipeline with a real browser, providing fingerprint evasion and DePIN rewards.

```
┌─────────────────────────────────────────────────────────────────┐
│                    BROWSER EXTENSION                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   Popup     │◄──►│ Background  │◄──►│   Content   │         │
│  │    UI       │    │   Script    │    │   Script    │         │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘         │
│         │                  │                  │                 │
│         └──────────────────┼──────────────────┘                 │
│                            │                                    │
│                    ┌───────▼───────┐                            │
│                    │  WASM Module  │                            │
│                    │  (Zig→WASM)   │                            │
│                    └───────┬───────┘                            │
│                            │                                    │
│         ┌──────────────────┼──────────────────┐                 │
│         │                  │                  │                 │
│  ┌──────▼──────┐    ┌──────▼──────┐    ┌──────▼──────┐         │
│  │     VSA     │    │     B2T     │    │   DePIN     │         │
│  │  Operations │    │  Pipeline   │    │   Rewards   │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Popup UI (`popup.html` + `popup.js`)

User interface for extension management:

```
┌────────────────────────────────────┐
│  FIREBIRD 🔥              v1.0.0  │
│  ● Online                          │
├────────────────────────────────────┤
│  Evasion: [ON]                     │
│  ████████████░░░░ 80%              │
│  Similarity: 0.80 / 0.90           │
│  Risk: LOW                         │
├────────────────────────────────────┤
│  Profile: Default_12345            │
│  [Generate New] [Delete]           │
├────────────────────────────────────┤
│  Navigation                        │
│  Steps: 25 | Sim: 0.80             │
│  [Navigate] [Reset]                │
├────────────────────────────────────┤
│  $TRI Rewards                      │
│  Pending: 0.0025 $TRI              │
│  Total: 1.2500 $TRI                │
│  [Claim] [Stake]                   │
├────────────────────────────────────┤
│  ▼ Fingerprint Details             │
│  Canvas: 0x7a3f...                 │
│  WebGL: 0x9c2e...                  │
│  Audio: 0x4b1d...                  │
└────────────────────────────────────┘
```

### 2. Background Script (`background.js`)

Service worker for:
- WASM module initialization
- Profile management
- DePIN synchronization
- Message handling

```javascript
// Pseudocode (generated from .vibee)
chrome.runtime.onInstalled.addListener(() => {
  initWasmModule();
  loadConfig();
  startDePINSync();
});

chrome.runtime.onMessage.addListener((msg, sender, respond) => {
  switch(msg.type) {
    case 'CREATE_PROFILE': return createProfile(msg.seed);
    case 'NAVIGATE_STEP': return navigateStep(msg.strength);
    case 'CLAIM_REWARDS': return claimRewards();
  }
});
```

### 3. Content Script (`content.js`)

Fingerprint override injection:

```javascript
// Pseudocode (generated from .vibee)
(function() {
  const profile = getProfileFromStorage();
  
  // Canvas override
  const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;
  HTMLCanvasElement.prototype.toDataURL = function() {
    const data = originalToDataURL.apply(this, arguments);
    return addNoise(data, profile.canvasSeed);
  };
  
  // WebGL override
  const originalGetParameter = WebGLRenderingContext.prototype.getParameter;
  WebGLRenderingContext.prototype.getParameter = function(param) {
    if (param === VENDOR) return profile.vendor;
    if (param === RENDERER) return profile.renderer;
    return originalGetParameter.apply(this, arguments);
  };
  
  // Navigator override
  Object.defineProperty(navigator, 'platform', {
    get: () => profile.platform
  });
})();
```

### 4. WASM Module (`firebird.wasm`)

Compiled from Zig module:

```zig
// src/firebird/extension_wasm.zig
export fn wasm_create_profile(seed: u64, dim: u32) i32;
export fn wasm_navigate_step(strength: f64) f64;
export fn wasm_get_canvas_hash() u64;
export fn wasm_get_pending_tri() f64;
export fn wasm_claim_rewards() f64;
```

## Data Flows

### Profile Creation

```
User clicks "Generate"
        │
        ▼
    Popup.js
        │
        ▼ chrome.runtime.sendMessage
        │
  Background.js
        │
        ▼ wasm_create_profile()
        │
    WASM Module
        │
        ▼ TritVec.random()
        │
    VSA Operations
        │
        ▼ Return profile
        │
  Background.js
        │
        ▼ chrome.storage.local.set()
        │
    Storage
        │
        ▼ Response
        │
    Popup.js
        │
        ▼ Update UI
```

### Evasion Application

```
Page loads
    │
    ▼
Content.js (document_start)
    │
    ▼ chrome.storage.local.get()
    │
Get profile
    │
    ▼ Inject overrides
    │
Page context
    │
    ▼ Canvas/WebGL/Navigator spoofed
    │
Fingerprint evasion active
    │
    ▼ Record DePIN operation
    │
Background.js
    │
    ▼ wasm_record_evasion()
    │
$TRI reward added
```

## File Structure

```
extension/
├── manifest.json           # Extension manifest (V3)
├── popup/
│   ├── popup.html          # Popup UI
│   ├── popup.js            # Popup logic
│   └── popup.css           # Popup styles
├── background/
│   └── background.js       # Service worker
├── content/
│   └── content.js          # Content script
├── wasm/
│   ├── firebird.wasm       # Compiled WASM
│   └── firebird.js         # WASM loader
├── icons/
│   ├── firebird-16.png
│   ├── firebird-32.png
│   ├── firebird-48.png
│   └── firebird-128.png
└── options/
    ├── options.html        # Settings page
    └── options.js          # Settings logic
```

## Build

### WASM Compilation

```bash
# From project root
zig build-lib src/firebird/extension_wasm.zig \
  -target wasm32-freestanding \
  -O ReleaseFast \
  -femit-bin=extension/wasm/firebird.wasm
```

### Extension Packaging

```bash
# Create ZIP for Chrome Web Store
cd extension
zip -r ../firebird-extension.zip .
```

## Security

### Content Security Policy

```json
{
  "content_security_policy": {
    "extension_pages": "script-src 'self' 'wasm-unsafe-eval'; object-src 'self'"
  }
}
```

### Stealth Techniques

1. **Injection trace removal** - DOM cleanup after injection
2. **Proxy-based interception** - Transparent interception without prototype modification
3. **Consistent behavior** - Same results on repeated calls
4. **Timing randomization** - Random delays to avoid timing attacks

## Performance Metrics

| Operation | Time | Memory |
|-----------|------|--------|
| WASM init | 50ms | 2MB |
| Profile create | 10ms | 100KB |
| Navigate step | 1ms | 10KB |
| Canvas override | <1ms | - |
| WebGL override | <1ms | - |

## Testing

### Unit Tests (Zig)

```bash
zig test src/firebird/extension_wasm.zig
# 31 tests passed
```

### Integration Tests

1. Load extension in Chrome
2. Open https://browserleaks.com/canvas
3. Verify canvas hash differs from original
4. Verify consistency on reload

### E2E Tests

```bash
# Using Puppeteer
npm run test:extension
```

## Roadmap

### v1.0.0 (Current)
- [x] WASM module with VSA
- [x] Basic overrides (canvas, webgl, navigator)
- [x] DePIN mock rewards
- [x] Popup UI specification

### v1.1.0
- [ ] Real $TRI staking
- [ ] More fingerprint overrides
- [ ] Firefox support

### v2.0.0
- [ ] Full browser integration
- [ ] Automated profile rotation
- [ ] AI-based evasion optimization

---

*φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL*
