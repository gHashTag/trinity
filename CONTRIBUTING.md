# Contributing to Trinity

Thank you for your interest in contributing to Trinity!

---

## Quick Links

- [Development Setup](#development-setup)
- [Code Style](#code-style)
- [Pull Request Process](#pull-request-process)
- [Testing](#testing)
- [Documentation](#documentation)

---

## Development Setup

### Prerequisites

- **Zig 0.13.0** (required version)
- **Git** for version control
- **Make** (optional, for convenience scripts)

### Installation

```bash
# Clone the repository
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Verify Zig version
zig version  # Should show 0.13.0

# Build
zig build

# Run tests
zig build test
```

See [docs/getting-started/DEVELOPMENT_SETUP.md](docs/getting-started/DEVELOPMENT_SETUP.md) for detailed setup instructions.

---

## Development Workflow

### Golden Chain Methodology

Trinity follows the **specification-first** development approach:

1. **Create specification** — Write `.vibee` file first
2. **Generate code** — `./bin/vibee gen spec.vibee`
3. **Test** — `zig test trinity/output/module.zig`
4. **Write TOXIC VERDICT** — Self-criticism of implementation
5. **Propose TECH TREE** — 3 options for next iteration

```bash
# View methodology
./bin/vibee koschei
```

### Branch Naming

| Prefix | Use |
|--------|-----|
| `feature/` | New features |
| `fix/` | Bug fixes |
| `docs/` | Documentation |
| `refactor/` | Code refactoring |
| `test/` | Test additions |

Example: `feature/vsa-similarity-metrics`

---

## Code Style

### Zig Code

- Follow [Zig Style Guide](https://ziglang.org/documentation/master/#Style-Guide)
- Use 4-space indentation
- Max line length: 120 characters
- Add doc comments for public functions

```zig
/// Binds two vectors via element-wise multiplication.
/// Properties:
/// - bind(a, a) = all +1 (self-inverse)
/// - bind(a, bind(a, b)) = b (unbind)
pub fn bind(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    // Implementation
}
```

### Specification Files

- Use 2-space indentation in YAML
- Include version and module name
- Document all behaviors

```yaml
name: module_name
version: "1.0.0"
language: zig
module: module_name

behaviors:
  - name: function_name
    given: Precondition
    when: Action
    then: Expected result
```

### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

| Type | Description |
|------|-------------|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `docs:` | Documentation |
| `refactor:` | Code refactoring |
| `test:` | Test changes |
| `chore:` | Build/tooling |

Example:
```
feat: Add cosine similarity to VSA module

- Implement normalized dot product
- Add SIMD acceleration
- Include tests for edge cases
```

---

## Pull Request Process

### Before Submitting

1. **Run tests:**
   ```bash
   zig build test
   zig test src/vsa.zig  # Specific module
   ```

2. **Check formatting:**
   ```bash
   zig fmt src/
   ```

3. **Update documentation** if changing public APIs

### PR Template

```markdown
## Description
Brief description of changes.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation
- [ ] Refactoring

## Testing
How was this tested?

## Checklist
- [ ] Tests pass
- [ ] Documentation updated
- [ ] Follows code style
```

### Review Process

1. Create PR against `main` branch
2. Automated tests run via CI
3. Maintainer reviews code
4. Address feedback
5. Merge when approved

---

## Testing

### Running Tests

```bash
# All tests
zig build test

# Specific module
zig test src/vsa.zig
zig test src/vm.zig
zig test src/hybrid.zig

# With verbose output
zig test src/vsa.zig --verbose

# Specific test
zig test src/vsa.zig --filter "bind"
```

### Writing Tests

```zig
test "function description" {
    // Arrange
    var a = HybridBigInt.random(100);
    var b = HybridBigInt.random(100);

    // Act
    const result = bind(&a, &b);

    // Assert
    try std.testing.expect(result.trit_len == 100);
}
```

### Test Coverage

- All public functions must have tests
- Test edge cases (empty, max size, etc.)
- Include performance tests for critical paths

---

## Documentation

### What to Document

- Public API functions
- Configuration options
- Examples and tutorials
- Architecture decisions

### Documentation Style

- Use Markdown
- Include code examples
- Add "See Also" cross-references

### Building Docs

Documentation is in `docs/` directory:
- `docs/INDEX.md` — Main navigation
- `docs/api/` — API reference
- `docs/getting-started/` — Tutorials

---

## Release Process

### Tag Conventions

Trinity uses different tag prefixes to trigger specific release workflows:

| Tag Pattern | Workflow | Purpose |
|-------------|----------|---------|
| `ext-v*` | Extension Release | NeoDetect browser extension (Chrome + Firefox) |
| `compiler-v*` | Build Compiler Release | VIBEE compiler binaries |
| `v*` | Build & Release | Main project releases |

### Creating a Release

#### Extension Release (NeoDetect)

```bash
# 1. Ensure all changes are committed and pushed
git status

# 2. Create extension release tag
git tag -a ext-v2.1.0 -m "NeoDetect v2.1.0 - Description of changes"

# 3. Push tag to trigger workflow
git push origin ext-v2.1.0

# 4. Monitor workflow at:
# https://github.com/gHashTag/trinity/actions/workflows/extension-release.yml
```

The workflow will:
- Build WASM module with Zig
- Package Chrome and Firefox extensions
- Create GitHub Release with both packages
- Generate release notes with installation instructions

#### Compiler Release

```bash
git tag -a compiler-v1.0.0 -m "VIBEE Compiler v1.0.0"
git push origin compiler-v1.0.0
```

#### Main Project Release

```bash
git tag -a v1.0.0 -m "Trinity v1.0.0"
git push origin v1.0.0
```

### Manual Workflow Dispatch

All release workflows support manual triggering:

1. Go to Actions → Select workflow
2. Click "Run workflow"
3. Enter version number
4. Click "Run workflow"

### Release Artifacts

| Release Type | Artifacts |
|--------------|-----------|
| Extension | `neodetect-chrome-v*.zip`, `neodetect-firefox-v*.zip` |
| Compiler | Linux/macOS binaries (x86_64, aarch64) |
| Main | Platform-specific installers |

### Extension Build Script

For local development:

```bash
cd extension

# Build all (WASM + Chrome + Firefox)
npm run build

# Build specific target
npm run build:chrome
npm run build:firefox
npm run build:wasm

# Clean artifacts
npm run clean
```

---

## Getting Help

- **Issues:** https://github.com/gHashTag/trinity/issues
- **Discussions:** GitHub Discussions
- **Documentation:** `docs/INDEX.md`

---

## Recognition

Contributors are recognized in:
- Git commit history
- Release notes
- CONTRIBUTORS.md (for significant contributions)

Thank you for contributing to Trinity!
