# TRI CLI — Package Definitions Summary

**Prepared for Public Release**

Created: 2026-02-28
Version: 0.11.0
φ² + 1/φ² = 3 = TRINITY

---

## Overview

Complete package definitions have been created for distributing TRI CLI across all major platforms:

**Files created:**

| Package | File | Purpose |
|---------|------|---------|
| Homebrew | `packages/homebrew/tri.rb` | Formula for macOS |
| AUR | `packages/aur/PKGBUILD` | Arch build script |
| AUR | `packages/aur/.SRCINFO` | Package metadata |
| AUR | `packages/aur/tri-cli-cli.install` | Install hooks |
| npm | `packages/npm/package.json` | npm manifest |
| npm | `packages/npm/bin/tri.js` | Node wrapper |
| npm | `packages/npm/scripts/install.js` | Download binary |
| npm | `packages/npm/scripts/check-deps.js` | Preinstall check |
| npm | `packages/npm/scripts/test.js` | Validation |
| Completions | `packages/completions/tri.bash` | Bash completion |
| Completions | `packages/completions/tri.zsh` | Zsh completion |
| Completions | `packages/completions/tri.fish` | Fish completion |
| Docs | `packages/INSTALL.md` | Installation guide |
| Docs | `packages/README.md` | Package overview |
| Docs | `packages/QUICKSTART.md` | Quick reference |
| Docs | `packages/RELEASE.md` | Release checklist |

**Total: 17 files**

---

## Package Features

### Homebrew (macOS)

**File:** `packages/homebrew/tri.rb`

- Builds from source using Zig 0.15.x
- Supports bottles for arm64/x64 (prebuilt binaries)
- Installs `tri` and `vibee` binaries
- Includes shell completions (bash, zsh, fish)
- macOS service support (`brew services start tri`)
- Post-install initialization

**Installation:**
```bash
brew tap gHashTag/trinity
brew install tri
```

---

### Arch Linux (AUR)

**Files:**
- `packages/aur/PKGBUILD`
- `packages/aur/.SRCINFO`
- `packages/aur/tri-cli-cli.install`

- Builds from source
- Installs to `/usr/bin/`
- Includes shell completions
- Man pages and documentation
- .vibee specifications to `/usr/share/tri/specs/`
- Post-install initialization script

**Installation:**
```bash
yay -S tri-cli
# or
paru -S tri-cli
```

---

### npm (Cross-platform)

**Files:**
- `packages/npm/package.json`
- `packages/npm/bin/tri.js`
- `packages/npm/scripts/install.js`
- `packages/npm/scripts/check-deps.js`
- `packages/npm/scripts/test.js`

- Downloads prebuilt binaries when available
- Falls back to building from source
- Node.js wrapper for cross-platform compatibility
- Automatic dependency checking
- Installation verification

**Installation:**
```bash
npm install -g @trinity-cli/tri
```

---

## Shell Completions

All three package managers include shell completions for:

**Bash** (`packages/completions/tri.bash`)
- 100+ commands
- Subcommand-aware completion
- File completion for specs

**Zsh** (`packages/completions/tri.zsh`)
- Descriptive command list
- File type filtering
- Model name completion

**Fish** (`packages/completions/tri.fish`)
- Auto-loading
- Command descriptions
- Smart completion

---

## Documentation

### INSTALL.md

Comprehensive installation guide covering:
- macOS (Homebrew)
- Arch Linux (AUR)
- npm (cross-platform)
- Windows (WSL)
- From source
- Verification steps
- Troubleshooting
- System requirements
- Updating
- Uninstalling

### README.md

Package maintainer guide:
- Directory structure
- Release process
- Testing packages
- Platform-specific notes
- Contributing guidelines

### QUICKSTART.md

User-focused quick reference:
- Installation choices
- First commands
- Configuration
- Common issues

### RELEASE.md

Release checklist for maintainers:
- Pre-release steps
- Build process
- GitHub release
- Package updates
- Post-release tasks
- Rollback procedures

---

## Release Binary URLs

Prebuilt binaries follow this pattern:

```
https://github.com/gHashTag/trinity/releases/download/v0.11.0/tri-{arch}-{platform}.tar.gz
```

Where:
- `{arch}` = `x86_64` or `aarch64`
- `{platform}` = `linux`, `macos`, or `windows`

---

## Next Steps

### For Public Release:

1. **Test packages locally**
   ```bash
   # Homebrew
   brew install --build-from-source packages/homebrew/tri.rb

   # AUR
   cd packages/aur && makepkg -si

   # npm
   cd packages/npm && npm link
   ```

2. **Create GitHub release**
   - Tag release: `git tag v0.11.0`
   - Build binaries: `zig build release`
   - Upload to GitHub Releases

3. **Update SHA256 checksums**
   - Calculate: `sha256sum zig-out/release/*`
   - Update `tri.rb` with checksums
   - Update `package.json` if needed

4. **Publish packages**
   - Push Homebrew formula to tap
   - Submit to AUR
   - Publish to npm: `npm publish`

5. **Update documentation**
   - Deploy website and docsite
   - Update GitHub releases page

---

## Platform Support Matrix

| Platform | Package Manager | Status | Notes |
|----------|----------------|--------|-------|
| macOS 11+ | Homebrew | ✅ Ready | Formula complete, bottles optional |
| macOS 11+ | npm | ✅ Ready | Downloads binary or builds |
| Arch Linux | AUR | ✅ Ready | PKGBUILD complete |
| Ubuntu 20.04+ | npm | ✅ Ready | Downloads binary or builds |
| Debian 11+ | npm | ✅ Ready | Downloads binary or builds |
| Windows 10+ | WSL2 | ⚠️ Manual | Requires manual build |
| Other Linux | Source | ✅ Ready | `zig build tri` |

---

## Dependencies

### Required
- **Zig 0.15.x** (build from source)
- **glibc 2.17+** (Linux)
- **macOS 11+** (macOS)

### Optional
- **Ollama** (local LLM support)
- **ffmpeg** (vision and voice I/O)
- **CUDA 11.x** (GPU acceleration)

---

## Troubleshooting Common Issues

### Build fails (out of memory)

Increase swap:
```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Zig not found

**macOS:**
```bash
brew install zig
```

**Arch:**
```bash
sudo pacman -S zig
```

**Ubuntu:**
```bash
sudo snap install zig --classic
```

### "command not found: tri"

Add to PATH:
```bash
export PATH=$PATH:$(pwd)/zig-out/bin
```

Or install globally:
```bash
sudo cp zig-out/bin/tri /usr/local/bin/
```

---

## Package Maintainer Checklist

Before release:
- [ ] Update version in all package files
- [ ] Update CHANGELOG.md
- [ ] Run all tests: `zig build test`
- [ ] Build release binaries: `zig build release`
- [ ] Calculate SHA256 checksums
- [ ] Test package installations locally

During release:
- [ ] Create git tag
- [ ] Create GitHub release with binaries
- [ ] Update Homebrew formula and push to tap
- [ ] Update AUR and push
- [ ] Publish to npm

After release:
- [ ] Verify installations on all platforms
- [ ] Update documentation
- [ ] Deploy website/docsite
- [ ] Announce release

---

## Contact

- **Issues**: https://github.com/gHashTag/trinity/issues
- **Discussions**: https://github.com/gHashTag/trinity/discussions
- **Documentation**: https://gHashTag.github.io/trinity/docs

---

**φ² + 1/φ² = 3 = TRINITY**

**Trinity Network — Decentralized Ternary AI Inference**

**Package definitions prepared for public release 🚀**
