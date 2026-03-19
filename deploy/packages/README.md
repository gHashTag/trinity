# TRI CLI — Package Definitions

This directory contains package definitions for distributing **TRI CLI** across multiple platforms.

φ² + 1/φ² = 3 = TRINITY

---

## Directory Structure

```
packages/
├── homebrew/
│   └── tri.rb                 # Homebrew formula
├── aur/
│   ├── PKGBUILD               # Arch Linux package build
│   ├── .SRCINFO               # Package metadata
│   └── tri-cli.install        # Install script
├── npm/
│   ├── package.json           # npm package manifest
│   ├── bin/
│   │   └── tri.js             # Node.js wrapper
│   └── scripts/
│       ├── install.js         # Post-install (downloads binary)
│       ├── check-deps.js      # Pre-install dependency check
│       └── test.js            # Installation test
├── completions/
│   ├── tri.bash               # Bash completion
│   ├── tri.zsh                # Zsh completion
│   └── tri.fish               # Fish completion
├── INSTALL.md                 # Installation guide
└── README.md                  # This file
```

---

## Packages

### Homebrew (macOS)

**Formula:** `homebrew/tri.rb`

**Install:**

```bash
brew tap gHashTag/trinity
brew install tri
```

**Features:**
- Builds from source using Zig 0.15.x
- Optional bottles for arm64/x64
- Installs `tri` and `vibee` binaries
- Includes shell completions
- macOS service support

**Maintainer tasks:**

1. Update version in `tri.rb`
2. Update SHA256 checksums
3. Build bottles: `brew build-bottle`
4. Upload to GitHub Releases
5. Update formula with bottle URLs

### Arch Linux (AUR)

**Package:** `aur/tri-cli`

**Install:**

```bash
yay -S tri-cli
# or
paru -S tri-cli
```

**Features:**
- Builds from source
- Installs to `/usr/bin/`
- Includes shell completions
- Man pages and documentation

**Maintainer tasks:**

1. Update `pkgver` in `PKGBUILD`
2. Run `makepkg --printsrcinfo > .SRCINFO`
3. Commit to AUR: `git push`

### npm (cross-platform)

**Package:** `@trinity-cli/tri`

**Install:**

```bash
npm install -g @trinity-cli/tri
```

**Features:**
- Downloads prebuilt binaries (Linux, macOS, Windows)
- Falls back to building from source
- Node.js wrapper script
- Cross-platform support

**Maintainer tasks:**

1. Update `version` in `package.json`
2. Run `npm publish`
3. CI/CD handles binary uploads

---

## Shell Completions

All packages include shell completions for:
- **Bash** → `completions/tri.bash`
- **Zsh** → `completions/tri.zsh`
- **Fish** → `completions/tri.fish`

**Usage:**

```bash
# Bash (autoload)
source completions/tri.bash

# Zsh (autoload)
source completions/tri.zsh

# Fish (autoload)
copy completions/tri.fish ~/.config/fish/completions/
```

---

## Release Process

### 1. Version Bump

Update version numbers in:
- `homebrew/tri.rb` → `version "0.11.0"`
- `aur/PKGBUILD` → `pkgver=0.11.0`
- `npm/package.json` → `"version": "0.11.0"`

### 2. Build Release Binaries

```bash
zig build release
```

Output: `zig-out/release/`

| Platform | Binary |
|----------|--------|
| linux-x86_64 | `tri-x86_64-linux` |
| linux-aarch64 | `tri-aarch64-linux` |
| macos-x86_64 | `tri-x86_64-macos` |
| macos-aarch64 | `tri-aarch64-macos` |
| windows-x86_64 | `tri.exe` |

### 3. Create GitHub Release

```bash
gh release create v0.11.0 \
  --notes "Release notes here" \
  zig-out/release/*
```

### 4. Update Package Definitions

**Homebrew:**

```bash
# Calculate SHA256
sha256sum zig-out/release/tri-aarch64-macos

# Update tri.rb with new URLs and checksums
```

**AUR:**

```bash
cd aur/
makepkg --printsrcinfo > .SRCINFO
git add PKGBUILD .SRCINFO
git commit -m "Upgrade to v0.11.0"
git push
```

**npm:**

```bash
cd npm/
npm publish
```

### 5. Update Documentation

- Update `INSTALL.md` with any changes
- Update `CHANGELOG.md` in root
- Tag commit: `git tag v0.11.0`

---

## Testing Packages

### Homebrew

```bash
# Test formula locally
brew install --build-from-source ./homebrew/tri.rb

# Test bottle
brew install ./homebrew/tri.rb
```

### AUR

```bash
cd aur/
makepkg -si
```

### npm

```bash
cd npm/
npm link
tri --help
```

---

## Platform-Specific Notes

### macOS

- **Minimum version:** macOS 11 (Big Sur)
- **Architectures:** x86_64, arm64 (Apple Silicon)
- **Dependencies:** Zig 0.15.x (via Homebrew)
- **Bottles:** Provide prebuilt binaries for faster installation

### Linux

- **Distributions:** Ubuntu 20.04+, Arch, Debian 11+
- **Architectures:** x86_64, aarch64
- **Dependencies:** glibc 2.17+, Zig 0.15.x
- **Package managers:** AUR, npm, source

### Windows

- **Via WSL2 only** (native Windows support planned)
- **Distributions:** Ubuntu 22.04 LTS
- **Dependencies:** Zig 0.15.x, build-essential
- **Alternative:** Use Docker image

---

## Troubleshooting

### Build failures

**Out of memory:**
```bash
# Increase swap
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

**Zig not found:**
```bash
# macOS
brew install zig

# Arch
sudo pacman -S zig

# Ubuntu
sudo snap install zig --classic
```

### Binary downloads fail

The npm package will automatically fall back to building from source if prebuilt binaries are unavailable.

### Completions not working

**Bash:**
```bash
# Add to ~/.bashrc
source /path/to/completions/tri.bash
```

**Zsh:**
```bash
# Add to ~/.zshrc
fpath=(/path/to/completions $fpath)
autoload -U compinit && compinit
```

**Fish:**
```bash
# Copy to completions dir
cp completions/tri.fish ~/.config/fish/completions/
```

---

## Contributing

When adding new features to TRI CLI:

1. Update completion files with new commands
2. Update `INSTALL.md` if new dependencies are required
3. Test package builds on all supported platforms
4. Update this README with any changes

---

## License

MIT — See [LICENSE](../LICENSE) in root directory.

---

**φ² + 1/φ² = 3 = TRINITY**

**Trinity Network — Decentralized Ternary AI Inference**
