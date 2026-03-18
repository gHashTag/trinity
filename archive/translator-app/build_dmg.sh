#!/bin/bash
# Build Offline Translator as macOS .dmg
# Run this on your Mac (requires Python 3.10+, Homebrew)

set -e

APP_NAME="Offline Translator"
DMG_NAME="OfflineTranslator-1.0.0"

echo "=== Step 1: Install system dependencies ==="
brew install tesseract tesseract-lang

echo "=== Step 2: Create virtual environment ==="
python3 -m venv .venv
source .venv/bin/activate

echo "=== Step 3: Install Python dependencies ==="
pip install --upgrade pip
pip install -r requirements.txt

echo "=== Step 4: Download default language packages (en<->ru) ==="
python3 -c "
import argostranslate.package
argostranslate.package.update_package_index()
available = argostranslate.package.get_available_packages()
for pkg in available:
    if (pkg.from_code == 'en' and pkg.to_code == 'ru') or \
       (pkg.from_code == 'ru' and pkg.to_code == 'en'):
        print(f'Installing {pkg.from_code} -> {pkg.to_code}')
        pkg.install()
print('Language packages installed.')
"

echo "=== Step 5: Build .app with PyInstaller ==="
pyinstaller translator.spec --noconfirm

echo "=== Step 6: Create .dmg ==="
# Create a temporary DMG directory
DMG_DIR="dmg_temp"
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# Copy .app bundle
cp -R "dist/${APP_NAME}.app" "$DMG_DIR/"

# Create symlink to Applications
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "dist/${DMG_NAME}.dmg"

# Cleanup
rm -rf "$DMG_DIR"

echo ""
echo "=== BUILD COMPLETE ==="
echo "DMG location: dist/${DMG_NAME}.dmg"
echo ""
echo "To install:"
echo "  1. Open dist/${DMG_NAME}.dmg"
echo "  2. Drag 'Offline Translator' to Applications"
echo "  3. Launch from Applications"
echo ""
echo "First launch will download translation models (~50MB per language pair)."
