# Screenshot Guide for Chrome Web Store

## Required Screenshots

Chrome Web Store requires 1-5 screenshots at 1280x800 or 640x400 pixels.

## Screenshot List

### 1. Main Popup Interface (Required)
**File**: `screenshots/01-popup-main.png`
**Size**: 1280x800

**Steps**:
1. Load extension in Chrome
2. Click extension icon to open popup
3. Set OS: Windows 11, Hardware: Intel i7, GPU: NVIDIA RTX 4070
4. Ensure all protection toggles are ON
5. Screenshot the popup with browser visible

**What to show**:
- Protection status (enabled)
- OS/Hardware/GPU dropdowns
- All toggle switches in ON position
- Detection risk indicator

### 2. Profile Management (Required)
**File**: `screenshots/02-profiles.png`
**Size**: 1280x800

**Steps**:
1. Save a profile named "Work Profile"
2. Save another named "Personal"
3. Screenshot showing saved profiles list
4. Show Import/Export buttons

### 3. Protection Presets (Required)
**File**: `screenshots/03-presets.png`
**Size**: 1280x800

**Steps**:
1. Show preset selection (Paranoid/Balanced/Minimal)
2. Highlight the Paranoid preset as selected
3. Show the protection toggles reflecting the preset

### 4. BrowserLeaks Before (Optional)
**File**: `screenshots/04-before.png`
**Size**: 1280x800

**Steps**:
1. Disable extension
2. Go to https://browserleaks.com/canvas
3. Screenshot showing unique fingerprint

### 5. BrowserLeaks After (Optional)
**File**: `screenshots/05-after.png`
**Size**: 1280x800

**Steps**:
1. Enable extension with Paranoid preset
2. Refresh https://browserleaks.com/canvas
3. Screenshot showing modified fingerprint

## Screenshot Specifications

| Requirement | Value |
|-------------|-------|
| Format | PNG or JPEG |
| Size | 1280x800 or 640x400 |
| Min screenshots | 1 |
| Max screenshots | 5 |
| No borders | Chrome Web Store adds its own |

## Tips

1. Use a clean Chrome profile (no other extensions)
2. Use dark mode for consistency with popup
3. Ensure text is readable
4. Highlight key features with annotations if needed
5. Test on both macOS and Windows for variety

## Tools

**macOS**:
```bash
# Full screen: Cmd+Shift+3
# Selection: Cmd+Shift+4
# Window: Cmd+Shift+4, then Space, click window
```

**Windows**:
```bash
# Snipping Tool: Win+Shift+S
# Full screen: PrtScn
```

**Resize**:
```bash
# Using ImageMagick
convert input.png -resize 1280x800 output.png
```

## Directory Structure

```
extension/chrome/screenshots/
├── 01-popup-main.png
├── 02-profiles.png
├── 03-presets.png
├── 04-before.png (optional)
└── 05-after.png (optional)
```

## Promotional Images

### Small Promo Tile (440x280)
**File**: `promo/small-tile.png`
- Extension icon centered
- "NeoDetect" text
- "WASM Privacy" tagline

### Large Promo Tile (920x680)
**File**: `promo/large-tile.png`
- Extension icon
- Feature highlights
- "Advanced Antidetect Browser"

### Marquee (1400x560) - Optional
**File**: `promo/marquee.png`
- Full feature showcase
- Screenshots embedded
