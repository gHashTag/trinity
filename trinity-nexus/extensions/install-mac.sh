#!/bin/bash
# NeoDetect Extension Installer for macOS
# Works on MacBook Pro M4 and all Apple Silicon Macs

set -e

echo "═══════════════════════════════════════════════════════════"
echo "  NeoDetect Anti-Detect Browser Extension Installer"
echo "  Version: 2.0.0"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

INSTALL_DIR="$HOME/Applications/NeoDetect"
CHROME_EXT_DIR="$INSTALL_DIR/chrome"
FIREFOX_EXT_DIR="$INSTALL_DIR/firefox"

# Create installation directory
echo -e "${CYAN}Creating installation directory...${NC}"
mkdir -p "$INSTALL_DIR"
mkdir -p "$CHROME_EXT_DIR"
mkdir -p "$FIREFOX_EXT_DIR"

# Download latest release
RELEASE_URL="https://github.com/gHashTag/trinity/releases/download/ext-v2.0.0"
CHROME_ZIP="neodetect-chrome-v2.0.0.zip"
FIREFOX_ZIP="neodetect-firefox-v2.0.0.zip"

echo -e "${CYAN}Downloading Chrome extension...${NC}"
curl -L -o "$INSTALL_DIR/$CHROME_ZIP" "$RELEASE_URL/$CHROME_ZIP"

echo -e "${CYAN}Downloading Firefox extension...${NC}"
curl -L -o "$INSTALL_DIR/$FIREFOX_ZIP" "$RELEASE_URL/$FIREFOX_ZIP"

# Extract extensions
echo -e "${CYAN}Extracting Chrome extension...${NC}"
unzip -o "$INSTALL_DIR/$CHROME_ZIP" -d "$CHROME_EXT_DIR"

echo -e "${CYAN}Extracting Firefox extension...${NC}"
unzip -o "$INSTALL_DIR/$FIREFOX_ZIP" -d "$FIREFOX_EXT_DIR"

# Clean up zip files
rm "$INSTALL_DIR/$CHROME_ZIP"
rm "$INSTALL_DIR/$FIREFOX_ZIP"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Extensions installed to: ${YELLOW}$INSTALL_DIR${NC}"
echo ""
echo -e "${CYAN}To install in Chrome:${NC}"
echo "  1. Open Chrome"
echo "  2. Go to chrome://extensions/"
echo "  3. Enable 'Developer mode' (top right)"
echo "  4. Click 'Load unpacked'"
echo "  5. Select: $CHROME_EXT_DIR"
echo ""
echo -e "${CYAN}To install in Firefox:${NC}"
echo "  1. Open Firefox"
echo "  2. Go to about:debugging#/runtime/this-firefox"
echo "  3. Click 'Load Temporary Add-on'"
echo "  4. Select: $FIREFOX_EXT_DIR/manifest.json"
echo ""
echo -e "${CYAN}To install in Safari:${NC}"
echo "  Safari requires a native app wrapper (not supported yet)"
echo ""
echo -e "${CYAN}To install in Arc/Brave/Edge:${NC}"
echo "  Use the Chrome extension - same process as Chrome"
echo ""

# Open Chrome extensions page
echo -e "${YELLOW}Opening Chrome extensions page...${NC}"
open "chrome://extensions/" 2>/dev/null || echo "Could not open Chrome automatically"

echo ""
echo "KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED"
