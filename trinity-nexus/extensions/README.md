# NeoDetect Anti-Detect Browser Extension

Advanced antidetect browser extension with WASM-powered fingerprint protection.

## Downloads

| Browser | Package | Store |
|---------|---------|-------|
| Chrome | [neodetect-chrome-v2.0.0.zip](https://github.com/gHashTag/trinity/releases/download/ext-v2.0.0/neodetect-chrome-v2.0.0.zip) | Coming soon |
| Firefox | [neodetect-firefox-v2.0.0.zip](https://github.com/gHashTag/trinity/releases/download/ext-v2.0.0/neodetect-firefox-v2.0.0.zip) | Coming soon |
| Edge | [Same as Chrome](https://github.com/gHashTag/trinity/releases/download/ext-v2.0.0/neodetect-chrome-v2.0.0.zip) | Coming soon |

**Latest Release**: [ext-v2.0.0](https://github.com/gHashTag/trinity/releases/tag/ext-v2.0.0)

## Browser Support

| Browser | Version | Status |
|---------|---------|--------|
| Chrome | 88+ | ✅ Supported |
| Edge | 88+ | ✅ Supported |
| Firefox | 109+ | ✅ Supported |
| Opera | 74+ | ✅ Supported (use Chrome package) |
| Brave | Latest | ✅ Supported (use Chrome package) |
| Safari | - | ❌ Not supported |

## Features

### Core Protections
- **Canvas Fingerprint** - Adds ternary noise to canvas operations
- **WebGL Fingerprint** - Spoofs GPU vendor and renderer
- **Audio Fingerprint** - Injects noise into audio context
- **Navigator Spoofing** - Spoofs platform, userAgent, hardware info

### Advanced Protections
- **WebRTC IP Leak** - Filters local IP addresses from ICE candidates
- **Battery API** - Returns spoofed battery status (100%, charging)
- **Bluetooth API** - Blocks device enumeration
- **Permissions API** - Returns configured permission states
- **Storage API** - Spoofs quota and usage information
- **Client Hints** - Spoofs User-Agent Client Hints

### Profile Management
- Save/load multiple browser profiles
- Import/export profiles as JSON
- Deterministic fingerprint recreation from seed
- Profile presets (Paranoid, Balanced, Minimal)

### OS Emulation
Emulate different operating systems without VM:
- Windows 10/11
- macOS Sonoma
- Linux Ubuntu

### Hardware Emulation
- Intel i5/i7/i9
- AMD Ryzen 5/7/9
- Apple M1/M2/M3

### GPU Emulation
- NVIDIA RTX 3060/4070/4090
- AMD RX 6700/7900
- Intel UHD 770
- Apple M1/M2/M3 GPU

## Installation

### Chrome / Edge / Brave / Opera

1. Download [neodetect-chrome-v2.0.0.zip](https://github.com/gHashTag/trinity/releases/download/ext-v2.0.0/neodetect-chrome-v2.0.0.zip)
2. Extract the ZIP file
3. Open browser extensions page:
   - Chrome: `chrome://extensions/`
   - Edge: `edge://extensions/`
   - Brave: `brave://extensions/`
   - Opera: `opera://extensions/`
4. Enable "Developer mode"
5. Click "Load unpacked"
6. Select the extracted folder

### Firefox

1. Download [neodetect-firefox-v2.0.0.zip](https://github.com/gHashTag/trinity/releases/download/ext-v2.0.0/neodetect-firefox-v2.0.0.zip)
2. Open `about:debugging#/runtime/this-firefox`
3. Click "Load Temporary Add-on"
4. Select the ZIP file

### From Source

```bash
# Clone repository
git clone https://github.com/gHashTag/trinity.git
cd trinity/extension

# Build all (WASM + Chrome + Firefox)
npm run build

# Or build specific target
npm run build:chrome
npm run build:firefox
npm run build:wasm
```

## Usage

### Quick Start
1. Click the NeoDetect icon in toolbar
2. Select a preset (Paranoid, Balanced, or Minimal)
3. Browse normally - fingerprint protection is active

### Protection Presets

| Preset | Description | Use Case |
|--------|-------------|----------|
| Paranoid | All protections enabled | Maximum privacy |
| Balanced | Most protections, some disabled for compatibility | Daily browsing |
| Minimal | Basic protections only | When sites break |

### Profile Management
1. Configure OS/Hardware/GPU settings
2. Click "Save" to save current profile
3. Click a saved profile to load it
4. Use "Export" to backup profiles
5. Use "Import" to restore profiles

## File Structure

```
extension/chrome/
├── manifest.json           # Chrome Manifest V3
├── background/
│   └── service-worker.js   # WASM initialization, state management
├── content/
│   └── content.js          # Fingerprint injection
├── popup/
│   ├── popup.html          # Extension popup UI
│   └── popup.js            # Popup logic
├── wasm/
│   ├── neodetect.wasm      # Compiled WASM module
│   └── neodetect-loader.js # WASM JavaScript wrapper
└── icons/
    └── *.png               # Extension icons
```

## WASM API

The extension uses a custom WASM module for fingerprint generation:

```javascript
// Initialize
NeoDetect.loadWasm();
NeoDetect.init(seed);

// Create profile
NeoDetect.createProfile({ osType, hwType, gpuType });

// Get profile data
const profile = NeoDetect.getProfileData();

// Evolution
NeoDetect.evolveFingerprint(targetSimilarity, maxGenerations);
NeoDetect.aiEvolve(targetSimilarity);
```

## Testing

### Fingerprint Test Page
Open `extension/test/fingerprint-test.html` to verify protections:
- Navigator properties
- Screen properties
- Canvas fingerprint
- WebGL fingerprint
- Audio fingerprint
- WebRTC IP leak
- Battery API
- Bluetooth API
- Permissions API
- Client Hints
- Storage API

### External Testing
- [BrowserLeaks](https://browserleaks.com) - Comprehensive fingerprint test
- [CreepJS](https://abrahamjuliot.github.io/creepjs/) - Advanced detection test
- [AmIUnique](https://amiunique.org) - Uniqueness test

## Privacy

- **No data collection** - All processing happens locally
- **No external requests** - Extension works offline
- **No telemetry** - Zero tracking or analytics
- **Open source** - Full code transparency

## Specifications

All code is generated from `.vibee` specifications:

| Specification | Purpose |
|---------------|---------|
| `neodetect_core.vibee` | Core antidetect types and behaviors |
| `neodetect_wasm.vibee` | WASM exports and memory layout |
| `os_emulation.vibee` | OS fingerprint emulation |
| `behavior_simulation.vibee` | Human behavior simulation |
| `ai_evolution.vibee` | AI-powered fingerprint evolution |
| `profile_manager.vibee` | Profile storage and encryption |
| `advanced_protection.vibee` | WebRTC, Battery, Bluetooth protection |

## Store Submission Guides

| Store | Guide | Status |
|-------|-------|--------|
| Chrome Web Store | [SUBMISSION_GUIDE.md](SUBMISSION_GUIDE.md) | Ready |
| Firefox Add-ons | [FIREFOX_SUBMISSION_GUIDE.md](FIREFOX_SUBMISSION_GUIDE.md) | Ready |
| Edge Add-ons | [EDGE_SUBMISSION_GUIDE.md](EDGE_SUBMISSION_GUIDE.md) | Ready |

## Documentation

| Document | Description |
|----------|-------------|
| [CHANGELOG.md](CHANGELOG.md) | Version history and release notes |
| [SUBMISSION_GUIDE.md](SUBMISSION_GUIDE.md) | Chrome Web Store submission |
| [FIREFOX_SUBMISSION_GUIDE.md](FIREFOX_SUBMISSION_GUIDE.md) | Firefox Add-ons submission |
| [EDGE_SUBMISSION_GUIDE.md](EDGE_SUBMISSION_GUIDE.md) | Edge Add-ons submission |
| [chrome/PRIVACY_POLICY.md](chrome/PRIVACY_POLICY.md) | Privacy policy |
| [chrome/STORE_LISTING.md](chrome/STORE_LISTING.md) | Store listing content |
| [chrome/SCREENSHOT_GUIDE.md](chrome/SCREENSHOT_GUIDE.md) | Screenshot instructions |

## Project Structure

```
extension/
├── README.md                    # This file
├── CHANGELOG.md                 # Version history
├── SUBMISSION_GUIDE.md          # Chrome submission guide
├── FIREFOX_SUBMISSION_GUIDE.md  # Firefox submission guide
├── EDGE_SUBMISSION_GUIDE.md     # Edge submission guide
├── build.js                     # Unified build script
├── package.json                 # Build dependencies
├── chrome/                      # Chrome/Edge extension
│   ├── manifest.json            # Manifest V3
│   ├── background/              # Service worker
│   ├── content/                 # Content scripts
│   ├── popup/                   # Popup UI
│   ├── wasm/                    # WASM module
│   ├── icons/                   # Extension icons
│   ├── PRIVACY_POLICY.md        # Privacy policy
│   └── STORE_LISTING.md         # Store listing
├── firefox/                     # Firefox extension
│   ├── manifest.json            # Manifest V2
│   ├── background/              # Background script
│   ├── content/                 # Content scripts
│   ├── popup/                   # Popup UI
│   ├── wasm/                    # WASM module
│   └── icons/                   # Extension icons
└── test/                        # E2E tests
    ├── package.json             # Test dependencies
    ├── wasm-test.js             # WASM module tests
    └── fingerprint-test.html    # Browser fingerprint test
```

## CI/CD

### GitHub Actions Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| Extension Tests | Push to `extension/**` | Build WASM, run tests |
| Extension Release | Tag `ext-v*` | Build and release packages |

### Creating a Release

```bash
# Create extension release
git tag -a ext-v2.1.0 -m "NeoDetect v2.1.0"
git push origin ext-v2.1.0

# Workflow automatically:
# 1. Builds WASM module
# 2. Packages Chrome and Firefox extensions
# 3. Creates GitHub Release with artifacts
```

## Version History

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

MIT License - See LICENSE file for details.

## Links

- **Repository**: https://github.com/gHashTag/trinity
- **Releases**: https://github.com/gHashTag/trinity/releases
- **Issues**: https://github.com/gHashTag/trinity/issues
- **Privacy Policy**: https://github.com/gHashTag/trinity/blob/main/extension/chrome/PRIVACY_POLICY.md

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED**
