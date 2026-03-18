# TRI CLI — Release Checklist

For package maintainainers releasing new versions.

φ² + 1/φ² = 3 = TRINITY

---

## Pre-Release

### 1. Update Version Numbers

Update in all files:

- `/Users/playra/trinity-w1/src/trinity.zig` → `pub const version = "0.11.0";`
- `/Users/playra/trinity-w1/homebrew-tap/Formula/tri.rb` → `version "0.11.0"`
- `/Users/playra/trinity-w1/packages/homebrew/tri.rb` → `version "0.11.0"`
- `/Users/playra/trinity-w1/packages/aur/PKGBUILD` → `pkgver=0.11.0`
- `/Users/playra/trinity-w1/packages/npm/package.json` → `"version": "0.11.0"`
- `/Users/playra/trinity-w1/package.json` → `"version": "0.11.0"`

### 2. Update CHANGELOG

```bash
# Edit root CHANGELOG.md
vim CHANGELOG.md
```

Format:

```markdown
## [0.11.0] - 2026-02-XX

### Added
- New feature A
- New feature B

### Changed
- Updated X to Y

### Fixed
- Bug fix A
```

### 3. Run Tests

```bash
zig build test           # All tests
zig build tri            # Build TRI
./zig-out/bin/tri test   # Verify TRI works
```

---

## Build Release

### 4. Build Release Binaries

```bash
zig build release
```

Output: `zig-out/release/`

```
tri-x86_64-linux
tri-aarch64-linux
tri-x86_64-macos
tri-aarch64-macos
tri.exe (Windows)
```

### 5. Calculate Checksums

```bash
cd zig-out/release/
sha256sum * > SHA256SUMS
cat SHA256SUMS
```

Save these checksums for package files.

---

## GitHub Release

### 6. Create Git Tag

```bash
git add -A
git commit -m "Release v0.11.0"
git tag -a v0.11.0 -m "Release v0.11.0"
git push origin main --tags
```

### 7. Create GitHub Release

```bash
gh release create v0.11.0 \
  --title "v0.11.0" \
  --notes-file CHANGELOG.md \
  zig-out/release/*
```

Or use GitHub web UI to:
1. Go to https://github.com/gHashTag/trinity/releases
2. Click "Draft a new release"
3. Tag: `v0.11.0`
4. Upload binaries from `zig-out/release/`
5. Paste CHANGELOG section
6. Publish

---

## Update Packages

### 8. Homebrew

**Update formula:**

```bash
cd /Users/playra/trinity-w1/homebrew-tap/Formula/
vim tri.rb
```

Update:
- `version "0.11.0"`
- `sha256 "..."` (from SHA256SUMS)

**Build bottles (optional):**

```bash
brew audit tri.rb
brew style tri.rb
brew install --build-bottle tri.rb
brew bottle tri.rb
```

**Commit and push:**

```bash
git add Formula/tri.rb
git commit -m "tri 0.11.0"
git push
```

### 9. AUR

**Update PKGBUILD:**

```bash
cd /Users/playra/trinity-w1/packages/aur/
vim PKGBUILD
```

Update:
- `pkgver=0.11.0`
- `pkgrel=1`
- `sha256sums=('SKIP')`

**Update .SRCINFO:**

```bash
makepkg --printsrcinfo > .SRCINFO
```

**Commit to AUR:**

```bash
# If this is your first time, clone AUR repo first
git clone ssh://aur@aur.archlinux.org/tri-cli.git
cd tri-cli

# Copy files
cp /Users/playra/trinity-w1/packages/aur/PKGBUILD .
cp /Users/playra/trinity-w1/packages/aur/.SRCINFO .
cp /Users/playra/trinity-w1/packages/aur/tri-cli-cli.install .

# Commit
git add PKGBUILD .SRCINFO tri-cli-cli.install
git commit -m "Upgrade to v0.11.0"
git push
```

### 10. npm

**Publish:**

```bash
cd /Users/playra/trinity-w1/packages/npm/
npm publish
```

**Verify:**

```bash
npm view @trinity-cli/tri
```

---

## Post-Release

### 11. Update Documentation

- Update `packages/INSTALL.md` if any new dependencies
- Update `packages/README.md` with release notes
- Update docsite if needed: `cd docsite && npm run build`

### 12. Deploy Website

```bash
cd website && npx vite build
cd ../docsite && npm run build
# Assemble and deploy to gh-pages (see CLAUDE.md)
```

### 13. Announce

- GitHub release is already done
- Post on Discord/Slack if applicable
- Update project status page

---

## Verify Release

### Test Installations

**macOS:**
```bash
brew install tri
tri --help
```

**Arch:**
```bash
yay -S tri-cli
tri --help
```

**npm:**
```bash
npm install -g @trinity-cli/tri
tri --help
```

**Source:**
```bash
git clone --branch v0.11.0 https://github.com/gHashTag/trinity.git
cd trinity
zig build tri
./zig-out/bin/tri --help
```

---

## Rollback (if needed)

```bash
# Delete release
gh release delete v0.11.0 --yes

# Delete tag
git tag -d v0.11.0
git push origin :refs/tags/v0.11.0

# Revert commits
git revert HEAD
git push
```

---

## Template

Use this for release notes:

```markdown
## TRI CLI v0.11.0

### Installation

**macOS:**
```bash
brew install gHashTag/trinity/tri
```

**Arch Linux:**
```bash
yay -S tri-cli
```

**npm:**
```bash
npm install -g @trinity-cli/tri
```

### What's New

- [Feature 1]
- [Feature 2]
- [Bug fix 1]

### Upgrade

**macOS:**
```bash
brew upgrade tri
```

**Arch:**
```bash
yay -S tri-cli
```

**npm:**
```bash
npm update -g @trinity-cli/tri
```

### Documentation

https://gHashTag.github.io/trinity/docs

### SHA256 Checksums

```
tri-x86_64-linux    SHA256
tri-aarch64-linux   SHA256
tri-x86_64-macos    SHA256
tri-aarch64-macos   SHA256
tri.exe             SHA256
```

---

**φ² + 1/φ² = 3 = TRINITY**
