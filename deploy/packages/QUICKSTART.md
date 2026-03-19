# TRI CLI — Quick Start Reference

**Get up and running in 5 minutes**

φ² + 1/φ² = 3 = TRINITY

---

## Choose Your Installation Method

### macOS (Homebrew) — Easiest

```bash
brew tap gHashTag/trinity
brew install tri
```

### Arch Linux (AUR)

```bash
yay -S tri-cli
```

### npm (Cross-platform)

```bash
npm install -g @trinity-cli/tri
```

### From Source

```bash
git clone https://github.com/gHashTag/trinity.git
cd trinity
zig build tri
```

---

## Verify Installation

```bash
tri version              # Should show v0.11.0
tri constants            # Show sacred constants
tri help                 # Show all commands
```

---

## First Commands

### Interactive Mode

```bash
tri
```

Type your prompt, press Enter.

### Chat

```bash
tri chat "Explain quantum computing"
```

### Code Generation

```bash
tri code "Write a REST API in Zig"
tri fix buggy_file.zig
tri test my_module.zig
```

### VIBEE Compiler

```bash
tri gen specs/my_feature.vibee
```

---

## Configuration

```bash
# Initialize TRI
tri init

# Edit config
tri config edit

# View config
cat ~/.trinity/config.json
```

---

## Next Steps

- Read [INSTALL.md](INSTALL.md) for detailed installation
- Read [README.md](README.md) for package maintainer info
- Visit [Documentation](https://gHashTag.github.io/trinity/docs)

---

## Common Issues

**Zig not found:**
```bash
brew install zig        # macOS
sudo pacman -S zig      # Arch
```

**Permission denied:**
```bash
chmod +x zig-out/bin/tri
```

**Command not found:**
```bash
export PATH=$PATH:$(pwd)/zig-out/bin
```

---

**φ² + 1/φ² = 3 = TRINITY**
