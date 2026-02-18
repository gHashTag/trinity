---
sidebar_position: 100
---

# Troubleshooting

Common issues and solutions.

## Build Issues

### Zig Version Mismatch

**Error:**
```
error: no field or member function named 'addStaticLibrary'
```

**Solution:** Install Zig 0.13.0:
```bash
curl -LO https://ziglang.org/download/0.13.0/zig-macos-aarch64-0.13.0.tar.xz
tar -xf zig-macos-aarch64-0.13.0.tar.xz
export PATH="$PWD/zig-macos-aarch64-0.13.0:$PATH"
```

### Build Failures

**Solution:** Run tests directly:
```bash
zig test src/vsa.zig  # Bypasses build.zig
```

## Runtime Issues

### Out of Memory

**Solution:**
- Use smaller model
- Reduce context size
- Use RunPod for large models

### Model Loading Failure

**Solution:**
- Verify file integrity
- Re-download model
- Check file permissions

## Getting Help

1. [GitHub Issues](https://github.com/gHashTag/trinity/issues)
2. Search documentation
3. Run diagnostics: `zig version`
