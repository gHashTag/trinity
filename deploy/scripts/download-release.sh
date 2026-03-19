#!/bin/bash
# Download TRI CLI binary from GitHub Releases
# Usage: download-release.sh [version] [arch]
#   version: Git tag (default: latest)
#   arch:    linux-amd64, linux-arm64 (default: linux-amd64)

set -e

REPO="${GITHUB_REPO:-gHashTag/trinity}"
VERSION="${1:-latest}"
ARCH="${2:-linux-amd64}"

# Map architecture names
case "$ARCH" in
  linux-amd64|x86_64)
    ARCH_PATTERN="linux-amd64"
    BINARY_NAME="tri"
    ;;
  linux-arm64|aarch64)
    ARCH_PATTERN="linux-arm64"
    BINARY_NAME="tri"
    ;;
  *)
    echo "Error: Unsupported architecture: $ARCH"
    echo "Supported: linux-amd64, linux-arm64"
    exit 1
    ;;
esac

echo "Downloading TRI CLI from GitHub..."
echo "  Repository: $REPO"
echo "  Version: $VERSION"
echo "  Architecture: $ARCH"

# Get download URL
if [ "$VERSION" = "latest" ]; then
  RELEASE_API="https://api.github.com/repos/$REPO/releases/latest"
else
  RELEASE_API="https://api.github.com/repos/$REPO/releases/tags/$VERSION"
fi

# Fetch release info
RELEASE_INFO=$(curl -s "$RELEASE_API")
RELEASE_NAME=$(echo "$RELEASE_INFO" | jq -r '.name // .tag_name')
DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r ".assets[] | select(.name | contains(\"$ARCH_PATTERN\")) | select(.name | endswith(\".tar.gz\") or endswith(\".tar.bz2\")) | .browser_download_url" | head -1)

if [ -z "$DOWNLOAD_URL" ]; then
  echo "Error: No download URL found for $ARCH_PATTERN in release $VERSION"
  echo ""
  echo "Available assets:"
  echo "$RELEASE_INFO" | jq -r '.assets[] .name'
  exit 1
fi

echo "  Release: $RELEASE_NAME"
echo "  Download URL: $DOWNLOAD_URL"

# Download and extract
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo "Downloading..."
curl -sL -o release.tar.gz "$DOWNLOAD_URL"

echo "Extracting..."
tar xzf release.tar.gz

# Find and copy the tri binary
if [ -f "tri" ]; then
  echo "Installing tri to /usr/local/bin/"
  cp tri /usr/local/bin/tri
  chmod +x /usr/local/bin/tri
elif [ -f "$ARCH_PATTERN/tri" ]; then
  echo "Installing tri from $ARCH_PATTERN/ to /usr/local/bin/"
  cp "$ARCH_PATTERN/tri" /usr/local/bin/tri
  chmod +x /usr/local/bin/tri
else
  echo "Error: Could not find tri binary in archive"
  echo "Contents:"
  find . -type f
  exit 1
fi

# Cleanup
cd /
rm -rf "$TEMP_DIR"

echo ""
echo "✓ TRI CLI installed successfully!"
/usr/local/bin/tri --version || echo "Binary installed, version check failed"
