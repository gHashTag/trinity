# Chrome Web Store Assets Checklist

## Required Icons

| Size | File | Status | Notes |
|------|------|--------|-------|
| 16x16 | icons/icon16.png | ✅ Placeholder | Replace with professional |
| 48x48 | icons/icon48.png | ✅ Placeholder | Replace with professional |
| 128x128 | icons/icon128.png | ✅ Placeholder | Replace with professional |

## Store Promotional Images

| Size | Purpose | Status |
|------|---------|--------|
| 440x280 | Small promo tile | ⏳ Needed |
| 920x680 | Large promo tile | ⏳ Needed |
| 1400x560 | Marquee promo | ⏳ Optional |

## Screenshots (Required: 1-5)

| # | Description | Size | Status |
|---|-------------|------|--------|
| 1 | Popup main view | 1280x800 or 640x400 | ⏳ Needed |
| 2 | Evolution progress | 1280x800 or 640x400 | ⏳ Needed |
| 3 | Settings toggles | 1280x800 or 640x400 | ⏳ Needed |
| 4 | Browserleaks before | 1280x800 or 640x400 | ⏳ Optional |
| 5 | Browserleaks after | 1280x800 or 640x400 | ⏳ Optional |

## Icon Design Guidelines

**Color Palette:**
- Primary: #f39c12 (Firebird orange)
- Secondary: #1a1a2e (Dark background)
- Accent: #2ecc71 (Active/success green)

**Symbol:**
- Fire/Phoenix bird
- Or stylized flame
- Clean, recognizable at 16px

## Screenshot Guidelines

1. Use Chrome on macOS/Windows
2. Clean browser (no other extensions visible)
3. Show popup in action
4. Highlight key features
5. Use consistent styling

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

- [ ] All icons in PNG format
- [ ] Icons have transparent background
- [ ] Screenshots show actual extension
- [ ] No placeholder text in screenshots
- [ ] Privacy policy URL ready
- [ ] Store listing text reviewed
- [ ] Extension tested on Chrome stable

## Quick Icon Generation (Temporary)

```bash
# Using ImageMagick to create orange icons
convert -size 16x16 xc:'#f39c12' icon16.png
convert -size 48x48 xc:'#f39c12' icon48.png
convert -size 128x128 xc:'#f39c12' icon128.png
```

## Professional Icon Services

- Fiverr: $20-50 for icon set
- 99designs: $100-300 for full branding
- Noun Project: $3 for base icon to customize
