# TRI CLI — Installation Guide

**Unified Trinity Command Line Interface**

φ² + 1/φ² = 3 = TRINITY

---

## Quick Install

### macOS (Homebrew) — Recommended

```bash
brew tap gHashTag/trinity
brew install tri
```

This installs:
- `tri` — Unified CLI
- `vibee` — VIBEE compiler
- Shell completions (bash, zsh, fish)
- macOS service support

**Install from bottle (prebuilt binary):**

```bash
brew install tri
```

**Build from source:**

```bash
brew install tri --build-from-source
```

**Start as a service:**

```bash
brew services start tri
```

---

### Arch Linux (AUR)

```bash
# Using yay (recommended)
yay -S tri-cli

# Or using paru
paru -S tri-cli

# Or manually
git clone https://aur.archlinux.org/tri-cli.git
cd tri-cli
makepkg -si
```

This installs:
- `/usr/bin/tri` — Unified CLI
- `/usr/bin/vibee` — VIBEE compiler
- Shell completions (bash, zsh, fish)
- Man pages
- Documentation

**Remove:**

```bash
yay -R tri-cli
```

---

### npm (cross-platform)

```bash
npm install -g @trinity-cli/tri
```

This automatically:
1. Downloads prebuilt binary for your platform
2. Falls back to building from source if needed
3. Installs Node.js wrapper script

**Manual download URL pattern:**

```
https://github.com/gHashTag/trinity/releases/download/v0.11.0/tri-{arch}-{platform}.tar.gz
```

Where:
- `{arch}` = `x86_64` or `aarch64`
- `{platform}` = `linux`, `macos`, or `windows`

---

### Windows (WSL)

TRI CLI runs on Windows via WSL2.

**Step 1: Install WSL2**

```powershell
# PowerShell (Admin)
wsl --install -d Ubuntu
```

**Step 2: Install dependencies (inside WSL)**

```bash
# Update package list
sudo apt update

# Install Zig 0.15.x
sudo snap install zig --classic
# OR download from https://ziglang.org/download/

# Install build dependencies
sudo apt install -y git pkg-config cmake
```

**Step 3: Build TRI**

```bash
# Clone repository
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Build
zig build tri

# Test
./zig-out/bin/tri --help
```

**Step 4: Add to PATH**

```bash
# Add to ~/.bashrc
echo 'export PATH=$PATH:~/trinity/zig-out/bin' >> ~/.bashrc
source ~/.bashrc

# Now you can run:
tri --help
```

**Step 5: (Optional) Install system-wide**

```bash
sudo cp zig-out/bin/tri /usr/local/bin/
sudo cp zig-out/bin/vibee /usr/local/bin/
```

---

### From Source (any platform)

**Requirements:**
- Zig 0.15.x ([download](https://ziglang.org/download/))
- Git
- 2 GB RAM minimum (for compilation)

```bash
# Clone repository
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Build TRI CLI
zig build tri

# Run
./zig-out/bin/tri --help

# Install (optional)
sudo cp zig-out/bin/tri /usr/local/bin/
sudo cp zig-out/bin/vibee /usr/local/bin/
```

---

## Verify Installation

```bash
tri version              # Should show "v0.11.0"
tri constants            # Show sacred constants (φ, π, e, etc.)
tri help                 # Show all commands
```

Expected output:

```
$ tri version
TRI CLI v0.11.0
Trinity Network - Ternary AI Inference

$ tri constants
φ = 1.6180339887498948482
π = 3.1415926535897932384
e = 2.7182818284590452353
φ² + 1/φ² = 3 = TRINITY
```

---

## Quick Start

### Interactive REPL

```bash
tri                      # Start interactive mode
```

### Chat

```bash
tri chat "Explain quantum computing in simple terms"
```

### Code Generation

```bash
tri code "Implement quicksort in Zig"
tri fix buggy_file.zig
tri test my_module.zig
tri explain algorithm.zig
tri doc my_module.zig
```

### VIBEE Compiler

```bash
# Generate Zig code from .vibee spec
tri gen specs/my_feature.vibee

# Or use vibee directly
vibee gen specs/my_feature.vibee
```

---

## System Requirements

| Platform | Minimum | Recommended |
|----------|---------|-------------|
| **macOS** | macOS 11+ | macOS 13+ |
| **Linux** | glibc 2.17+ | Ubuntu 20.04+ |
| **Windows** | WSL2 | WSL2 + Ubuntu 22.04 |
| **RAM** | 2 GB | 4 GB |
| **Disk** | 500 MB | 1 GB |

### Optional Dependencies

| Feature | Dependency | Install |
|---------|-----------|---------|
| Local LLM | Ollama | `brew install ollama` |
| Vision | ffmpeg | `brew install ffmpeg` |
| Voice | ffmpeg | `brew install ffmpeg` |
| GPU | CUDA 11.x | [NVIDIA CUDA](https://developer.nvidia.com/cuda-downloads) |

---

## Configuration

TRI stores configuration in `~/.trinity/`:

```
~/.trinity/
├── config.json          # Main configuration
├── specs/               # Your .vibee specs
├── cache/               # Build cache
├── history              # Command history
└── models/              # Downloaded models (if using Ollama)
```

**Initialize manually:**

```bash
tri init
```

**Edit config:**

```bash
# Open config in editor
tri config edit

# Or edit directly
nano ~/.trinity/config.json
```

---

## Updating

### Homebrew

```bash
brew upgrade tri
```

### AUR

```bash
yay -S tri-cli  # or your AUR helper
```

### npm

```bash
npm update -g @trinity-cli/tri
```

### From Source

```bash
cd trinity
git pull
zig build tri
```

---

## Uninstalling

### Homebrew

```bash
brew uninstall tri
brew untap gHashTag/trinity
rm -rf ~/.trinity
```

### AUR

```bash
yay -R tri-cli
rm -rf ~/.trinity
```

### npm

```bash
npm uninstall -g @trinity-cli/tri
rm -rf ~/.trinity
```

### From Source

```bash
sudo rm /usr/local/bin/tri
sudo rm /usr/local/bin/vibee
rm -rf ~/.trinity
```

---

## Troubleshooting

### Zig not found

**macOS:**

```bash
brew install zig
```

**Arch Linux:**

```bash
sudo pacman -S zig
```

**Ubuntu/Debian:**

```bash
# Option 1: Snap
sudo snap install zig --classic

# Option 2: Download binary
wget https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz
tar -xf zig-linux-x86_64-0.13.0.tar.xz
sudo mv zig-linux-x86_64-0.13.0 /opt/zig
echo 'export PATH=$PATH:/opt/zig' >> ~/.bashrc
```

### Version mismatch

TRI requires Zig 0.15.x. Check your version:

```bash
zig version
```

Expected output: `0.15.x`

### Permission denied

```bash
chmod +x zig-out/bin/tri
chmod +x zig-out/bin/vibee
```

### "command not found: tri"

Add to PATH:

```bash
# Temporary
export PATH=$PATH:$(pwd)/zig-out/bin

# Permanent (bash)
echo 'export PATH=$PATH:~/trinity/zig-out/bin' >> ~/.bashrc
source ~/.bashrc

# Permanent (zsh)
echo 'export PATH=$PATH:~/trinity/zig-out/bin' >> ~/.zshrc
source ~/.zshrc
```

### Build fails

**Out of memory:**

Close other applications or increase swap:

```bash
# Create 4GB swap file
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

**Missing dependencies:**

```bash
# Ubuntu/Debian
sudo apt install -y git pkg-config cmake build-essential

# macOS (Xcode)
xcode-select --install
```

---

## Development

### Running Tests

```bash
zig build test           # Run all tests
zig build test-repl      # Run TRI REPL tests
```

### Building Release Binaries

```bash
zig build release        # Cross-platform release builds
```

Output: `zig-out/release/`

| Platform | Binary |
|----------|--------|
| linux-x86_64 | `tri-x86_64-linux` |
| linux-aarch64 | `tri-aarch64-linux` |
| macos-x86_64 | `tri-x86_64-macos` |
| macos-aarch64 | `tri-aarch64-macos` |
| windows-x86_64 | `tri.exe` |

---

## Package Maintainer Notes

### Homebrew Release Process

1. **Create GitHub Release**
   ```bash
   gh release create v0.11.0 --notes "Release notes"
   ```

2. **Upload binaries**
   ```bash
   # Build all platforms
   zig build release

   # Upload to release
   gh release upload v0.11.0 zig-out/release/*
   ```

3. **Update Homebrew formula**
   ```ruby
   # homebrew-tap/Formula/tri.rb
   url "https://github.com/gHashTag/trinity/archive/refs/tags/v0.11.0.tar.gz"
   sha256 "..."  # Use: sha256sum tri-x86_64-linux
   ```

4. **Submit PR to homebrew-core** (for official tap)

### AUR Release Process

1. **Update PKGBUILD**
   ```bash
   pkgver=0.11.0
   pkgrel=1
   ```

2. **Update .SRCINFO**
   ```bash
   makepkg --printsrcinfo > .SRCINFO
   ```

3. **Commit to AUR**
   ```bash
   git add PKGBUILD .SRCINFO
   git commit -m "Upgrade to v0.11.0"
   git push
   ```

### npm Release Process

1. **Update package.json**
   ```json
   {
     "version": "0.11.0"
   }
   ```

2. **Publish**
   ```bash
   npm publish
   ```

---

## Getting Help

- **Documentation**: https://gHashTag.github.io/trinity/docs
- **GitHub Issues**: https://github.com/gHashTag/trinity/issues
- **GitHub Discussions**: https://github.com/gHashTag/trinity/discussions
- **Quick Start**: https://gHashTag.github.io/trinity

---

**φ² + 1/φ² = 3 = TRINITY**

**Trinity Network — Decentralized Ternary AI Inference**
