# NeoDetect Installation on MacBook Pro M4

## Quick Install (One Command)

Open Terminal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/gHashTag/trinity/main/extension/install-mac.sh | bash
```

This will:
1. Download Chrome and Firefox extensions
2. Extract to `~/Applications/NeoDetect/`
3. Open Chrome extensions page

## Manual Installation

### Chrome / Arc / Brave / Edge

1. **Download**: [neodetect-chrome-v2.0.0.zip](https://github.com/gHashTag/trinity/releases/download/ext-v2.0.0/neodetect-chrome-v2.0.0.zip)

2. **Extract**: Double-click the ZIP file to extract

3. **Install**:
   - Open Chrome (or Arc/Brave/Edge)
   - Go to `chrome://extensions/` (or `arc://extensions/`, `brave://extensions/`, `edge://extensions/`)
   - Enable **Developer mode** (toggle in top right)
   - Click **Load unpacked**
   - Select the extracted folder

4. **Verify**: Click the NeoDetect icon in toolbar

### Firefox

1. **Download**: [neodetect-firefox-v2.0.0.zip](https://github.com/gHashTag/trinity/releases/download/ext-v2.0.0/neodetect-firefox-v2.0.0.zip)

2. **Install**:
   - Open Firefox
   - Go to `about:debugging#/runtime/this-firefox`
   - Click **Load Temporary Add-on**
   - Select the ZIP file (or manifest.json inside)

3. **Note**: Firefox temporary add-ons are removed when Firefox closes. For permanent installation, submit to Firefox Add-ons.

### Safari

Safari requires extensions to be packaged as native macOS apps. This is not currently supported.

**Workaround**: Use Chrome, Arc, or Brave on your MacBook Pro M4.

## Recommended Browser for M4

For best performance on Apple Silicon (M4):

| Browser | Recommendation |
|---------|----------------|
| **Arc** | ⭐ Best - Native Apple Silicon, Chrome extensions |
| **Chrome** | ✅ Good - Native Apple Silicon |
| **Brave** | ✅ Good - Native Apple Silicon, privacy-focused |
| **Firefox** | ✅ Good - Native Apple Silicon |
| **Safari** | ❌ Extension not supported |

## Verify Installation

1. Click the NeoDetect icon in your browser toolbar
2. You should see the popup with:
   - Protection status (Enabled)
   - OS/Hardware/GPU dropdowns
   - Protection toggles

3. Test fingerprint protection:
   - Go to https://browserleaks.com/canvas
   - Your fingerprint should be different from your real one

## Troubleshooting

### Extension not loading

1. Make sure Developer mode is enabled
2. Check that you selected the correct folder (containing `manifest.json`)
3. Check Chrome console for errors: `chrome://extensions/` → Details → Errors

### WASM not loading

1. Check that `wasm/neodetect.wasm` exists in the extension folder
2. Try reloading the extension

### Popup not opening

1. Click the puzzle icon in Chrome toolbar
2. Pin NeoDetect extension
3. Click the NeoDetect icon

## Uninstall

### Chrome / Arc / Brave / Edge

1. Go to `chrome://extensions/`
2. Find NeoDetect
3. Click **Remove**

### Firefox

1. Go to `about:addons`
2. Find NeoDetect
3. Click **Remove**

### Remove files

```bash
rm -rf ~/Applications/NeoDetect
```

## Support

- **Issues**: https://github.com/gHashTag/trinity/issues
- **Releases**: https://github.com/gHashTag/trinity/releases

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED**
