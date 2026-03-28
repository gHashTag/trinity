# Versioning Architecture

## Modular Version System

Trinity uses a **modular version architecture** where different components release independently. This design allows each component to evolve at its own pace while maintaining compatibility.

### Why Versions Differ

| Component | Version | Purpose | Release Cycle |
|-----------|---------|---------|---------------|
| **Core CLI** | 5.1.0 | Main tri binary — primary interface | Per release |
| **npm packages** | 5.1.0 | Installer wrappers — track core version | Sync with CLI |
| **Homebrew** | 5.1.0 | Formula for macOS users | Sync with CLI |
| **AUR** | 5.1.0 | Arch Linux package | Sync with CLI |
| **Docker** | 5.1.0 | Container image tags | Sync with CLI |
| **Website** | Separate | Landing page (Vite + React) | Independent |
| **Zenodo bundles** | v9.0 | Scientific publications | Independent |
| **FPGA bitstream** | Separate | Hardware artifact | Per synthesis |

**Installers always share the same version** (5.1.0) to avoid confusion. The version number follows the core `tri` binary.

### Component Version Mapping

```
┌─────────────────────────────────────────────────────────────┐
│                    Core: tri binary (5.1.0)                  │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    All installers sync to 5.1.0           │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │ │
│  │  │   npm    │  │ Homebrew │  │   AUR    │  │  Docker  │ │ │
│  │  │  @playra │  │  tri.rb  │  │PKGBUILD  │  │  :5.1.0  │ │ │
│  │  │  5.1.0   │  │  5.1.0   │  │  5.1.0   │  │  5.1.0   │ │ │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Independent components                      │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │ │
│  │  │ Website  │  │  Zenodo  │  │   FPGA   │              │ │
│  │  │ Separate │  │   v9.0   │  │ Separate │              │ │
│  │  └──────────┘  └──────────┘  └──────────┘              │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### npm Package Aliases

Two npm packages provide the same binaries (the `tri` package name is taken by another project):

| Package | Purpose | Version |
|---------|---------|---------|
| `@trinity-cli/tri` | Official organization package | 5.1.0 |
| `@playra/tri` | Personal alias (same content) | 5.1.0 |

Both packages install identical binaries. Use either:

```bash
npm install -g @trinity-cli/tri
# OR
npm install -g @playra/tri
```

### Semver Rules

Trinity follows **Semantic Versioning 2.0.0**:

```
MAJOR.MINOR.PATCH
  │    │     │
  │    │     └─ PATCH: Bug fixes, no breaking changes
  │    └─────── MINOR: New features, backward compatible
  └──────────── MAJOR: Breaking changes
```

**When to bump each:**

| Change | Bump | Example |
|--------|------|---------|
| Bug fix | PATCH | 5.1.0 → 5.1.1 |
| New command, backward compatible | MINOR | 5.1.0 → 5.2.0 |
| Breaking API change | MAJOR | 5.1.0 → 6.0.0 |

**Current:** `5.1.0 "HEARTBEAT"` — Sacred mathematics framework, CLARA proposal

### Which Version to Reference

| Context | Use | Example |
|---------|-----|---------|
| **CLI output** | Core version | `TRI CLI v5.1.0` |
| **npm install** | Either package | `npm install -g @playra/tri` |
| **Homebrew** | Formula version | `brew install trinity` (uses 5.1.0) |
| **AUR** | pkgver | `yay -S trinity-cli` (uses 5.1.0) |
| **Docker** | Image tag | `ghcr.io/ghashtag/trinity:5.1.0` |
| **Git tags** | Release tags | `v5.1.0` |

### Release Checklist

Before each release:

```bash
# 1. Update version constant in build.zig
# 2. Update all installer files
# 3. Build release binaries
zig build -Doptimize=ReleaseFast -Dtarget=aarch64-macos
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-macos
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux
zig build -Doptimize=ReleaseFast -Dtarget=aarch64-linux

# 4. Package binaries
tar -czf tri-5.1.0-aarch64-macos.tar.gz -C zig-out/bin tri vibee
tar -czf tri-5.1.0-x86_64-macos.tar.gz -C zig-out/bin tri vibee
tar -czf tri-5.1.0-x86_64-linux.tar.gz -C zig-out/bin tri vibee
tar -czf tri-5.1.0-aarch64-linux.tar.gz -C zig-out/bin tri vibee

# 5. Generate SHA256 checksums
shasum -a 256 tri-5.1.0-*.tar.gz

# 6. Update Homebrew formula with checksums
# Edit deploy/packages/homebrew/tri.rb

# 7. Create git tag
git tag -a v5.1.0 -m "Release v5.1.0 HEARTBEAT"
git push origin v5.1.0

# 8. Create GitHub Release with assets
gh release create v5.1.0 tri-5.1.0-*.tar.gz

# 9. Publish npm packages
cd deploy/packages/npm
npm publish
npm publish --file=package.playra.json

# 10. Update AUR PKGBUILD (manual on aur.archlinux.org)

# 11. Push Docker image
docker build -t ghcr.io/ghashtag/trinity:5.1.0 .
docker push ghcr.io/ghashtag/trinity:5.1.0
```

### Homebrew Tap

Trinity uses a custom tap for distribution:

```bash
# Install via tap
brew tap gHashTag/trinity
brew install trinity

# Update formula in tap repo
# Repo: gHashTag/homebrew-trinity
# File: Formula/tri.rb
```

See [Homebrew Distribution Guide](https://justin.searls.co/posts/how-to-distribute-your-own-scripts-via-homebrew/) for details.

### Historical Versions

| Version | Codename | Date | Key Features |
|---------|----------|------|--------------|
| 5.1.0 | HEARTBEAT | 2026-03-28 | Sacred math, CLARA proposal, 3000+ tests |
| 5.0.0 | HEARTBEAT | 2026-03-27 | Major framework update |
| ... | ... | ... | ... |

### Verify Current Version

```bash
tri --version          # Core CLI version
npm info @playra/tri    # npm package version
brew info trinity       # Homebrew version
pacman -Si trinity-cli # AUR version
docker inspect ghcr.io/ghashtag/trinity:5.1.0
```

### Automation

See Issue #472 for automated release pipeline with GitHub Actions:
- Auto-build for all platforms
- Auto-generate SHA256 checksums
- Auto-publish to npm
- Auto-update Homebrew formula

---

**φ² + 1/φ² = 3 = TRINITY**
