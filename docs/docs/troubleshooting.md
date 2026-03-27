---
sidebar_position: 100
description: "Common issues and solutions for Trinity"
---

# Troubleshooting

Common issues and solutions.

## Build Issues

### Zig Version Mismatch

**Error:**
```
error: no field or member function named 'addStaticLibrary'
```

**Solution:** Install Zig 0.15.x:
```bash
curl -LO https://ziglang.org/download/0.15.2/zig-macos-aarch64-0.15.2.tar.xz
tar -xf zig-macos-aarch64-0.15.2.tar.xz
export PATH="$PWD/zig-macos-aarch64-0.15.2:$PATH"
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

## FPGA Issues

### Segbits Data Not Found

**Error:**
```
segbits_data.zig: FileNotFound
```

**Solution:** Generate segbits data:
```bash
python3 tools/gen_segbits.py --part xc7a100t
```

### JTAG Connection Failed

**Solution:**
1. Check USB cable connection
2. Install FTDI drivers
3. Verify with: `lsusb | grep FTDI`

## CLI Issues

### Command Not Found

**Error:**
```
tri: command not found
```

**Solution:**
```bash
# Build TRI CLI
zig build tri

# Add to PATH or use directly
./zig-out/bin/tri --version
```

### Configuration Directory Missing

**Error:**
```
error: unable to open config directory
```

**Solution:**
```bash
mkdir -p ~/.config/trinity
```

## Getting Help

If your issue isn't listed here:

1. Search [GitHub Issues](https://github.com/gHashTag/trinity/issues)
2. Run diagnostics: `tri doctor`
3. Open a new issue with `tri doctor` output attached
