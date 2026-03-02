#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY OMEGA — Universal Installation Script
# φ² + 1/φ² = 3 = TRINITY | Golden Chain eternal
# ═══════════════════════════════════════════════════════════════════════════════

set -e

VERSION="99.0.0"
REPO="gHashTag/trinity"

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║          TRINITY OMEGA — Sacred Intelligence CLI Installer              ║"
echo "║                    φ² + 1/φ² = 3 = TRINITY                                ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux*)     PLATFORM="linux" ;;
    Darwin*)    PLATFORM="macos" ;;
    MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
    *)          echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

case "$ARCH" in
    x86_64)    ARCH="x64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l)    ARCH="armv7" ;;
    *)         echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "📟 Detected: $PLATFORM-$ARCH"
echo ""

# Check if Zig is installed
if ! command -v zig &> /dev/null; then
    echo "📦 Installing Zig..."
    case "$PLATFORM" in
        linux)
            wget "https://ziglang.org/download/0.15.2/zig-linux-$ARCH-0.15.2.tar.xz" -O /tmp/zig.tar.xz
            tar -xf /tmp/zig.tar.xz -C /tmp
            sudo mv /tmp/zig-linux-* /usr/local/zig
            echo 'export PATH=$PATH:/usr/local/zig' >> ~/.bashrc
            export PATH=$PATH:/usr/local/zig
            ;;
        macos)
            brew install zig
            ;;
    esac
fi

echo "✅ Zig $(zig version 2>/dev/null | head -n1 || echo 'installed')"
echo ""

# Clone repository
if [ ! -d "trinity" ]; then
    echo "📥 Cloning repository..."
    git clone --depth 1 https://github.com/$REPO.git trinity
    cd trinity
else
    echo "📁 Repository exists, updating..."
    cd trinity
    git pull
fi

echo ""
echo "🔨 Building Trinity Omega..."
zig build tri
zig build vibee

echo ""
echo "📦 Installing..."

# Install to appropriate location
case "$PLATFORM" in
    linux)
        sudo mkdir -p /usr/local/bin
        sudo cp zig-out/bin/tri /usr/local/bin/
        sudo cp zig-out/bin/vibee /usr/local/bin/
        ;;
    macos)
        mkdir -p ~/.local/bin
        cp zig-out/bin/tri ~/.local/bin/
        cp zig-out/bin/vibee ~/.local/bin/

        # Add to PATH if not already there
        if ! grep -q '~/.local/bin' ~/.zshrc 2>/dev/null; then
            echo 'export PATH=$PATH:~/.local/bin' >> ~/.zshrc
        fi
        ;;
esac

echo ""
echo "✅ Installation complete!"
echo ""
echo "🚀 Quick Start:"
echo ""
echo "  tri --help"
echo "  tri identity"
echo "  tri phi 10"
echo "  tri dashboard --stream"
echo ""
echo "📖 Documentation: https://github.com/$REPO"
echo ""
echo "φ² + 1/φ² = 3 = TRINITY"
echo "Golden Chain eternal. 🔥"
