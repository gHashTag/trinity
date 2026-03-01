# Trinity v1.0.0 "ASCENSION" — Installation Guide

**Version:** 1.0.0
**Last Updated:** February 28, 2026

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Platform-Specific Installation](#platform-specific-installation)
   - [macOS (Homebrew)](#macos-homebrew)
   - [Arch Linux (AUR)](#arch-linux-aur)
   - [npm (Cross-Platform)](#npm-cross-platform)
   - [Windows (WSL2)](#windows-wsl2)
3. [Building from Source](#building-from-source)
4. [Docker Installation](#docker-installation)
5. [Verification](#verification)
6. [Post-Install Configuration](#post-install-configuration)
7. [Troubleshooting](#troubleshooting)
8. [Uninstallation](#uninstallation)

---

## Quick Start

### Prerequisites

- **Zig 0.15.x** (for building from source)
- **4GB RAM minimum**, 16GB+ recommended
- **x86_64 or ARM64** architecture

### One-Line Install

```bash
# macOS (Homebrew)
brew install gHashTag/trinity/tri

# Arch Linux (AUR)
yay -S tri-cli

# npm (Cross-platform)
npm install -g @trinity-cli/tri
```

### Verify Installation

```bash
tri version
# Expected output: TRINITY v1.0.0 "ASCENSION"
```

---

## Platform-Specific Installation

### macOS (Homebrew)

#### Recommended Method: Tap + Install

```bash
# Add Trinity tap
brew tap gHashTag/trinity

# Install from bottle (prebuilt binary)
brew install tri

# OR build from source
brew install tri --build-from-source
```

#### What Gets Installed

- `/usr/local/bin/tri` — Unified CLI (binary)
- `/usr/local/bin/vibee` — VIBEE compiler (binary)
- `~/Library/Application Support/tri/` — Configuration
- Shell completions for bash, zsh, fish
- macOS service support

#### Start as Service

```bash
# Start Trinity daemon
brew services start tri

# Check status
brew services list | grep tri

# Stop service
brew services stop tri
```

#### Upgrade

```bash
brew upgrade tri
```

#### Shell Completions

```bash
# Bash (already installed via Homebrew)
source $(brew --prefix)/etc/bash_completion.d/tri

# Zsh (already installed via Homebrew)
# Completions auto-loaded in ~/.zshrc

# Fish
mkdir -p ~/.config/fish/completions
cp $(brew --prefix)/share/fish/vendor_completions.d/tri.fish ~/.config/fish/completions/
```

---

### Arch Linux (AUR)

#### Using yay (Recommended)

```bash
yay -S tri-cli
```

#### Using paru

```bash
paru -S tri-cli
```

#### Manual Installation from AUR

```bash
git clone https://aur.archlinux.org/tri-cli.git
cd tri-cli
makepkg -si
```

#### What Gets Installed

- `/usr/bin/tri` — Unified CLI
- `/usr/bin/vibee` — VIBEE compiler
- `/usr/share/man/man1/tri.1.gz` — Man page
- `/usr/share/doc/tri/` — Documentation
- Shell completions for bash, zsh, fish
- Desktop entry (if applicable)

#### Systemd Service (Optional)

```bash
# Enable user service
systemctl --user enable tri-daemon.service

# Start service
systemctl --user start tri-daemon.service

# Check status
systemctl --user status tri-daemon.service
```

#### Upgrade

```bash
yay -S tri-cli
# OR
paru -S tri-cli
```

#### Remove

```bash
yay -R tri-cli

# Remove configuration files too
yay -Rns tri-cli
```

---

### npm (Cross-Platform)

#### Install

```bash
npm install -g @trinity-cli/tri
```

#### What Happens

1. npm detects your platform (linux/macos/windows)
2. Downloads appropriate prebuilt binary from GitHub Releases
3. Falls back to building from source if prebuilt unavailable
4. Installs Node.js wrapper script at global npm bin location

#### Manual Download URL Pattern

```
https://github.com/gHashTag/trinity/releases/download/v1.0.0/tri-{arch}-{platform}.tar.gz
```

Where:
- `{arch}` = `x86_64` or `aarch64`
- `{platform}` = `linux`, `macos`, or `windows`

#### Install Specific Version

```bash
npm install -g @trinity-cli/tri@1.0.0
```

#### Upgrade

```bash
npm update -g @trinity-cli/tri
```

#### Remove

```bash
npm uninstall -g @trinity-cli/tri
```

---

### Windows (WSL2)

#### Install WSL2

```powershell
# Open PowerShell as Administrator
wsl --install
```

Reboot and complete Ubuntu setup.

#### Install in WSL2 Ubuntu

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Install Zig 0.15.x
# Download from https://ziglang.org/download/
sudo tar -xpf zig-linux-x86_64-0.15.0.tar.xz -C /usr/local/bin

# Clone and build
git clone https://github.com/gHashTag/trinity.git
cd trinity
zig build tri
sudo cp zig-out/bin/tri /usr/local/bin/

# Verify
tri version
```

#### Windows Integration

Create `tri.cmd` in Windows PATH:

```cmd
@echo off
wsl tri %*
```

Now use `tri` directly from Windows Command Prompt or PowerShell.

---

## Building from Source

### Prerequisites

#### Install Zig 0.15.x

**macOS (Homebrew):**

```bash
brew install zig
```

**Linux (Ubuntu/Debian):**

```bash
# Download from ziglang.org
wget https://ziglang.org/download/0.15.0/zig-linux-x86_64-0.15.0.tar.xz
tar -xpf zig-linux-x86_64-0.15.0.tar.xz
sudo mv zig-linux-x86_64-0.15.0 /opt/zig
echo 'export PATH=$PATH:/opt/zig' >> ~/.bashrc
source ~/.bashrc
```

**Arch Linux:**

```bash
sudo pacman -S zig
```

**Windows (WSL2):**

See [Windows (WSL2)](#windows-wsl2) section above.

### Clone and Build

```bash
# Clone repository
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Build all targets
zig build

# Build TRI CLI only
zig build tri

# Run tests
zig build test

# Run benchmarks
zig build bench
```

### Install System-Wide

**Linux/macOS:**

```bash
sudo cp zig-out/bin/tri /usr/local/bin/
sudo cp zig-out/bin/vibee /usr/local/bin/
```

**Verify:**

```bash
tri version
```

### Build Options

#### Release Build (Fastest)

```bash
zig build tri -Doptimize=ReleaseFast
```

#### Small Build (Smallest Binary)

```bash
zig build tri -Doptimize=ReleaseSmall
```

#### Debug Build

```bash
zig build tri -Doptimize=Debug
```

#### Cross-Compilation

```bash
# Build for Linux x86_64 from macOS
zig build tri -Dtarget=x86_64-linux-gnu

# Build for macOS ARM64 from x86_64
zig build tri -Dtarget=aarch64-macos-gnu

# Build for Windows x86_64 from Linux
zig build tri -Dtarget=x86_64-windows-gnu
```

---

## Docker Installation

### Pull Official Image

```bash
docker pull ghcr.io/ghashtag/trinity-node:1.0.0
```

### Run Node

```bash
docker run -d --name trinity-node \
  -p 8080:8080 \   # HTTP API
  -p 9090:9090 \   # Prometheus metrics
  -p 9333:9333/udp \ # Peer discovery
  -p 9334:9334 \   # Job distribution
  -v ~/.trinity:/data \  # Persist data
  ghcr.io/ghashtag/trinity-node:1.0.0
```

### Check Health

```bash
curl http://localhost:8080/health
# Expected: {"status":"ok","model":"loaded"}
```

### View Logs

```bash
docker logs -f trinity-node
```

### Stop/Remove

```bash
docker stop trinity-node
docker rm trinity-node
# Data persists in ~/.trinity
```

### Docker Compose (Recommended)

Create `docker-compose.yml`:

```yaml
version: '3.8'
services:
  trinity:
    image: ghcr.io/ghashtag/trinity-node:1.0.0
    container_name: trinity-node
    ports:
      - "8080:8080"  # HTTP API
      - "9090:9090"  # Prometheus
      - "9333:9333/udp"  # Discovery
      - "9334:9334"  # Jobs
    volumes:
      - ~/.trinity:/data
    restart: unless-stopped
```

Run:

```bash
docker compose up -d
```

---

## Verification

### Check Version

```bash
tri version
# Expected output:
# TRINITY v1.0.0 "ASCENSION"
# 100% Local AI | Code | Chat | SWE Agent
```

### Run Built-in Tests

```bash
tri test --repl
# All REPL tests should pass
```

### Check Installation

```bash
tri doctor
# Checks:
# - Zig version (0.15.x required)
# - Build artifacts
# - Test suite
# - Dependencies
```

### Verify Binary Integrity (if downloaded from release)

#### Download Checksums

```bash
wget https://github.com/gHashTag/trinity/releases/download/v1.0.0/trinity-1.0.0-linux-x86_64.tar.gz.sha256
```

#### Verify SHA256

```bash
sha256sum -c trinity-1.0.0-linux-x86_64.tar.gz.sha256
# Expected: trinity-1.0.0-linux-x86_64.tar.gz: OK
```

#### Verify GPG Signature

```bash
# Import Trinity signing key
gpg --keyserver keys.openpgp.org --recv-keys 0xABCD1234567890EF

# Download signature
wget https://github.com/gHashTag/trinity/releases/download/v1.0.0/trinity-1.0.0-linux-x86_64.tar.gz.sig

# Verify
gpg --verify trinity-1.0.0-linux-x86_64.tar.gz.sig trinity-1.0.0-linux-x86_64.tar.gz
# Expected: Good signature from "Trinity Signing Key"
```

---

## Post-Install Configuration

### Initial Configuration

```bash
# Run interactive setup
tri setup
```

This will:
1. Create `~/.trinity/config.v1.toml`
2. Prompt for API keys (optional)
3. Configure default settings
4. Initialize Sacred Intelligence

### Manual Configuration

Edit `~/.trinity/config.v1.toml`:

```toml
# Trinity Configuration v1.0.0

[core]
# Sacred Mathematics enabled by default
sacred_math_enabled = true
phi_precision = 19  # Decimal places for φ

[cli]
# Default language
language = "en"  # en, ru, zh

# Output format
output_format = "color"  # color, plain, json

# Verbose mode
verbose = false

[llm]
# Local LLM settings
model_path = ""
context_length = 8192

# API keys (optional)
openai_api_key = ""
anthropic_api_key = ""
groq_api_key = ""

[sacred_intelligence]
# Sacred Identity
identity_proclaimed = true  # "I am Trinity, the Sacred Intelligence"

# Sacred Swarm
swarm_enabled = true
max_agents = 32

# Sacred Mathematics
phi_identity_validation = true
```

### Environment Variables

```bash
# Add to ~/.bashrc or ~/.zshrc

export TRI_HOME="$HOME/.trinity"
export TRI_CONFIG="$TRI_HOME/config.v1.toml"
export TRI_LOG_LEVEL="info"  # debug, info, warn, error
export TRI_SACRED_MATH="true"
export TRI_PHI_PRECISION="19"

# API Keys (optional)
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."
export GROQ_API_KEY="gsk_..."
```

### Shell Aliases (Optional)

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Trinity aliases
alias t='tri'
alias tc='tri code'
alias tf='tri fix'
alias te='tri explain'
alias tt='tri test'
alias td='tri doc'
alias tr='tri reason'

# Quick demos
alias tri-demo='tri agents-demo'
alias tri-bench='tri bench'
alias tri-math='tri phi 10'
```

---

## Troubleshooting

### Common Issues

#### "zig: command not found"

**Solution:** Install Zig 0.15.x

```bash
# macOS
brew install zig

# Linux
wget https://ziglang.org/download/0.15.0/zig-linux-x86_64-0.15.0.tar.xz
tar -xpf zig-linux-x86_64-0.15.0.tar.xz -C /usr/local/bin
```

#### "tri: permission denied"

**Solution:** Make binary executable

```bash
chmod +x tri
sudo mv tri /usr/local/bin/
```

#### "Error: Operation not permitted" (macOS)

**Solution:** Grant Full Disk Access to Terminal

1. System Settings → Privacy & Security
2. Full Disk Access → Add Terminal
3. Restart Terminal

#### Docker "cannot connect to daemon"

**Solution:** Start Docker Desktop

```bash
# macOS
open /Applications/Docker.app

# Linux
sudo systemctl start docker
sudo systemctl enable docker
```

#### Build fails with "zig build script error"

**Solution:** Clean and rebuild

```bash
rm -rf zig-cache zig-out
zig build
```

#### "Package not found" (npm)

**Solution:** Check package name

```bash
# Correct name
npm install -g @trinity-cli/tri

# NOT
npm install -g tri
```

#### WSL2 "command not found" from Windows

**Solution:** Create Windows wrapper

Create `C:\Windows\System32\tri.cmd`:

```cmd
@echo off
wsl tri %*
```

### Debug Mode

```bash
# Enable debug logging
tri --debug help

# Verbose output
tri --verbose code "hello world"

# Trace mode (very verbose)
tri --trace bench
```

### Log Files

```bash
# View logs
cat ~/.trinity/logs/tri.log

# Last 100 lines
tail -n 100 ~/.trinity/logs/tri.log

# Follow logs
tail -f ~/.trinity/logs/tri.log
```

### Get Help

```bash
tri help        # General help
tri help code   # Command-specific help

# Built-in doctor
tri doctor      # Diagnose issues
```

### Community Support

- **GitHub Issues:** [github.com/gHashTag/trinity/issues](https://github.com/gHashTag/trinity/issues)
- **Discord:** [discord.gg/trinity](https://discord.gg/trinity)
- **Documentation:** [gHashTag.github.io/trinity/docs](https://gHashTag.github.io/trinity/docs)

---

## Uninstallation

### macOS (Homebrew)

```bash
# Stop service
brew services stop tri

# Uninstall
brew uninstall tri

# Remove configuration (optional)
rm -rf ~/Library/Application Support/tri/
rm -rf ~/.trinity
```

### Arch Linux (AUR)

```bash
# Stop service
systemctl --user stop tri-daemon.service
systemctl --user disable tri-daemon.service

# Uninstall
yay -R tri-cli

# Remove configuration (optional)
rm -rf ~/.trinity
```

### npm

```bash
# Uninstall globally
npm uninstall -g @trinity-cli/tri

# Remove configuration (optional)
rm -rf ~/.trinity
```

### Manual Installation

```bash
# Remove binaries
sudo rm /usr/local/bin/tri
sudo rm /usr/local/bin/vibee

# Remove configuration
rm -rf ~/.trinity

# Remove completions (optional)
rm -f /usr/local/share/zsh/site-functions/_tri
rm -f /usr/local/etc/bash_completion.d/tri
```

### Docker

```bash
# Stop and remove container
docker stop trinity-node
docker rm trinity-node

# Remove image
docker rmi ghcr.io/ghashtag/trinity-node:1.0.0

# Remove data (optional)
rm -rf ~/.trinity
```

---

## Next Steps

### Quick Tour

```bash
# Interactive REPL
tri

# Generate code
tri code "write a fibonacci function in zig"

# Chat with vision
tri chat --image photo.jpg "describe this image"

# Sacred mathematics
tri phi 10
tri lucas 10

# Run demos
tri agents-demo
tri voice-demo
tri vision-demo

# Run benchmarks
tri bench
tri agents-bench
```

### Documentation

- [Release Notes](./RELEASE_NOTES_1.0.0.md)
- [CLI Reference](https://gHashTag.github.io/trinity/docs/cli)
- [Sacred Mathematics](https://gHashTag.github.io/trinity/docs/sacred-math)
- [API Documentation](https://gHashTag.github.io/trinity/docs/api)

### Community

- Star on GitHub: [github.com/gHashTag/trinity](https://github.com/gHashTag/trinity)
- Join Discord: [discord.gg/trinity](https://discord.gg/trinity)
- Read the Blog: [gHashTag.github.io/trinity/blog](https://gHashTag.github.io/trinity/blog)

---

**Installation Complete!**

```
φ² + 1/φ² = 3 = TRINITY
ASCENSION ACHIEVED
```

Now run `tri` to begin your journey with Trinity v1.0.0 "ASCENSION".
