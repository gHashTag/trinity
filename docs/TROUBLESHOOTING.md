# Troubleshooting Guide

> Common issues and solutions for Trinity

---

## Build Issues

### Zig Version Mismatch

**Error:**
```
error: no field or member function named 'addStaticLibrary' in 'Build'
```

**Cause:** Project requires Zig 0.13.0, but you have a newer version (0.14+).

**Solutions:**

1. **Install Zig 0.13.0:**
   ```bash
   # macOS
   brew install zig@0.13

   # Or download directly
   wget https://ziglang.org/download/0.13.0/zig-macos-aarch64-0.13.0.tar.xz
   tar -xf zig-macos-aarch64-0.13.0.tar.xz
   export PATH="$PWD/zig-macos-aarch64-0.13.0:$PATH"
   ```

2. **Run tests directly (bypasses build.zig):**
   ```bash
   zig test src/vsa.zig              # Works with any Zig version
   zig test src/vibeec/plugin/*.zig  # Plugin tests
   ```

---

### ArrayList API Changed

**Error:**
```
error: member function expected 2 argument(s), found 1
```

**Cause:** Zig 0.14+ changed ArrayList API (allocator now per-call).

**Solution:** Use Zig 0.13.0 or run module tests directly:
```bash
zig test src/vsa.zig    # Works
zig test src/hybrid.zig # Works
```

---

### Missing Dependencies

**Error:**
```
error: unable to open file 'src/bigint.zig'
```

**Solution:** Ensure you're in the project root:
```bash
cd /path/to/trinity
zig build
```

---

## Runtime Issues

### Out of Memory (OOM)

**Symptom:** Process killed during model loading.

**Solutions:**

1. **Use smaller model:**
   ```bash
   # 1.5B instead of 7B
   ./bin/firebird chat --model models/bitnet-1.5b.gguf
   ```

2. **Reduce context size:**
   ```bash
   ./bin/firebird chat --model model.gguf --context 1024
   ```

3. **Use RunPod for large models:**
   See [runpod_direct_workflow.md](runpod_direct_workflow.md)

---

### Model Loading Failure

**Error:**
```
Failed to load model: Invalid GGUF format
```

**Solutions:**

1. **Verify file integrity:**
   ```bash
   sha256sum model.gguf
   # Compare with expected hash
   ```

2. **Check file size:**
   ```bash
   ls -lh model.gguf
   # Should match expected size
   ```

3. **Re-download:**
   ```bash
   rm model.gguf
   wget <model_url>
   ```

---

### WASM Plugin Load Failure

**Error:**
```
Invalid WASM: bad magic number
```

**Solutions:**

1. **Verify WASM format:**
   ```bash
   file plugin.wasm
   # Should show: WebAssembly (wasm) binary module
   ```

2. **Rebuild plugin:**
   ```bash
   zig build-lib -target wasm32-freestanding plugin.zig
   ```

---

## Test Issues

### Tests Timing Out

**Symptom:** Tests hang or timeout.

**Solutions:**

1. **Run with verbose output:**
   ```bash
   zig test src/vsa.zig --verbose
   ```

2. **Run specific test:**
   ```bash
   zig test src/vsa.zig --filter "bind"
   ```

---

### Random Test Failures

**Symptom:** Tests pass sometimes, fail sometimes.

**Cause:** Usually uninitialized memory or race conditions.

**Solution:** Run with debug allocator:
```bash
zig test src/module.zig -ODebug
```

---

## FPGA Issues

### Connection Timeout

**Error:**
```
FPGA connection timeout
```

**Solutions:**

1. **Check USB connection:**
   ```bash
   ls /dev/ttyUSB*  # Linux
   ls /dev/cu.*     # macOS
   ```

2. **Reset FPGA:**
   - Power cycle the board
   - Press reset button

3. **Check drivers:**
   - Install FTDI drivers if needed

---

### Bitstream Upload Failed

**Error:**
```
Failed to upload bitstream
```

**Solutions:**

1. **Verify bitstream file:**
   ```bash
   file design.bit
   ```

2. **Check board compatibility:**
   - Ensure bitstream matches your FPGA model

---

## Performance Issues

### Slow Inference

**Symptom:** Tokens/second much lower than expected.

**Solutions:**

1. **Enable SIMD:**
   ```bash
   zig build -Doptimize=ReleaseFast
   ```

2. **Use packed mode for storage:**
   ```zig
   vector.pack();  // 5 trits/byte instead of 1
   ```

3. **Profile hotspots:**
   ```bash
   zig build -Doptimize=ReleaseSafe  # With profiling
   ```

---

### High Memory Usage

**Symptom:** Memory keeps growing.

**Solutions:**

1. **Check for leaks:**
   ```bash
   zig test src/module.zig -Dleak-detection
   ```

2. **Use packed storage:**
   ```zig
   // Pack vectors when not computing
   for (vectors) |*v| v.pack();
   ```

---

## Common Errors Reference

| Error | Cause | Solution |
|-------|-------|----------|
| `FileNotFound` | Wrong path | Check file exists |
| `OutOfMemory` | Vector too large | Use smaller dimension |
| `InvalidMagic` | Corrupt file | Re-download |
| `Timeout` | Deadlock/hang | Check for infinite loops |
| `AccessDenied` | Permissions | `chmod +x` or run as admin |

---

## Getting Help

1. **Check existing issues:**
   https://github.com/gHashTag/trinity/issues

2. **Search documentation:**
   ```bash
   grep -r "error message" docs/
   ```

3. **Run diagnostics:**
   ```bash
   zig version
   zig build --help
   ```

4. **Report new issue:**
   Include:
   - Zig version (`zig version`)
   - OS and version
   - Full error message
   - Steps to reproduce

---

## See Also

- [DEVELOPMENT_SETUP.md](getting-started/DEVELOPMENT_SETUP.md)
- [INDEX.md](INDEX.md) — Documentation index
