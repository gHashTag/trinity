# NeoDetect Anti-Detect Browser Extension

Advanced antidetect browser extension with WASM-powered fingerprint protection.

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

### From Release
1. Download `neodetect-v2.0.0.zip` from releases
2. Open `chrome://extensions/`
3. Enable "Developer mode"
4. Click "Load unpacked"
5. Select the extracted folder

### From Source
```bash
# Clone repository
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Build WASM module
zig build-lib src/firebird/neodetect_wasm.zig \
  -target wasm32-freestanding \
  -O ReleaseFast \
  -femit-bin=extension/chrome/wasm/neodetect.wasm

# Load extension/chrome folder in Chrome
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

## Version History

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

MIT License - See LICENSE file for details.

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED**
