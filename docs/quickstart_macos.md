# Quick Start - macOS

Complete guide to get Trinity running on macOS.

---

## Prerequisites

### Required

- **macOS 12.0+** (Monterey or later)
- **Xcode Command Line Tools**
  ```bash
  xcode-select --install
  ```

### Optional

- **Homebrew** — for package management
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

---

## Installation

### Option 1: Pre-built Binary (Recommended)

```bash
# Install via Homebrew
brew tap gHashTag/trinity
brew install trinity

# Verify installation
tri --version
```

### Option 2: Build from Source

```bash
# Clone repository
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Install Zig 0.15.x
brew install zig

# Build TRI CLI
zig build tri

# Run (optional: add to PATH)
./zig-out/bin/tri --version
```

### Option 3: NPM Package

```bash
npm install -g @playra/tri
tri --version
```

---

## Quick Test

```bash
# Show sacred constants
tri constants

# Interactive REPL
tri

# Run tests
zig build test
```

---

## FPGA Setup (macOS)

### Hardware

- QMTech XC7A100T FPGA board
- FTDI JTAG cable

### Install Tools

```bash
# Install openFPGALoader
brew install openfpgaloader

# Install fxload (for JTAG cable)
brew install fxload
```

### Flash FPGA

```bash
# CRITICAL: Switch JTAG cable to JTAG mode first
fxload -t fx2 -I ./fpga/openxc7-synth/xc7a-xc7s-ftdi.hex -d 0x0013

# Now flash
tri fpga flash
```

---

## Common Issues on macOS

### "zig: command not found"

```bash
# Add Zig to PATH (add to ~/.zshrc or ~/.bash_profile)
export PATH="/opt/homebrew/bin:$PATH"

# Or use full path
/opt/homebrew/bin/zig build tri
```

### "Permission denied" when running tri

```bash
# Make executable
chmod +x ./zig-out/bin/tri

# Or install globally
zig build tri
sudo cp ./zig-out/bin/tri /usr/local/bin/
```

### Xcode license not accepted

```bash
sudo xcodebuild -license accept
```

---

## IDE Setup

### VS Code

1. Install Zig extension
2. Install CodeLLDB for debugging
3. Configure settings:

```json
{
  "zig.zigPath": "/opt/homebrew/bin/zig",
  "zig.formattingProvider": "zls"
}
```

### JetBrains CLion

1. Install Zig plugin
2. Configure Zig SDK
3. Set up build configuration

---

## Next Steps

- Read [README.md](../README.md) for all commands
- Check [CONTRIBUTING.md](../CONTRIBUTING.md) for development
- See [docs/troubleshooting.md](troubleshooting.md) for issues

---

*Last updated: 2026-03-24*
