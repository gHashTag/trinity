# Reproducibility Guide

This document provides instructions for reproducing Trinity's results in an academic setting.

## Quick Start

### One-Command Reproduction

```bash
# Clone and run all tests
git clone https://github.com/gHashTag/trinity.git
cd trinity
./scripts/reproduce.sh
```

### Docker (Recommended)

```bash
# Build reproducibility image
docker build -f Dockerfile.reproducibility -t trinity-repro .

# Run all tests
docker run trinity-repro

# Run benchmarks
docker run trinity-repro zig build bench

# Interactive exploration
docker run -it trinity-repro /bin/bash
```

---

## Environment Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| **Zig** | 0.15.x | Required, other versions may not work |
| **OS** | Linux/macOS/Windows | Cross-platform support |
| **RAM** | 4GB+ | For large VSA dimensions |
| **CPU** | x86_64 or ARM64 | SIMD acceleration |

### Installing Zig 0.15.x

```bash
# Linux x86_64
curl -L https://ziglang.org/builds/zig-linux-x86_64-0.15.0-dev.367+a68210b2e.tar.xz | tar -xJ
export PATH="$PWD/zig-linux-x86_64-0.15.0-dev.367+a68210b2e:$PATH"

# macOS ARM64
curl -L https://ziglang.org/builds/zig-macos-aarch64-0.15.0-dev.367+a68210b2e.tar.xz | tar -xJ
export PATH="$PWD/zig-macos-aarch64-0.15.0-dev.367+a68210b2e:$PATH"

# Verify
zig version
```

---

## Reproducing Results

### 1. Core VSA Tests (3500+ tests)

```bash
# Run all tests
zig build test

# Expected output:
# All 3588 tests passed.
```

### 2. Mathematical Theorems Verification

```bash
# VSA theorems (bind, bundle, permute)
zig test src/vsa/tests.zig

# Verify Trinity Identity: φ² + 1/φ² = 3
zig build tri -- constants verify
```

### 3. Benchmarks

```bash
# Run VSA benchmarks
zig build bench

# Expected metrics:
# - bind 1000D: ~X ns/op
# - bundle 1000D: ~Y ns/op
# - cosine similarity: ~Z ns/op
```

### 4. VIBEE Compiler

```bash
# Generate code from specification
zig build vibee -- gen trinity-nexus/tri/example.vibee

# Run generated tests
zig test trinity-nexus/output/tri/zig/example.zig
```

---

## Zenodo Archive

### Obtaining DOI

Trinity releases are archived on Zenodo for permanent citation:

1. **Visit**: https://zenodo.org/deposit/new
2. **Upload**: Release tarball or link GitHub release
3. **Metadata**:
   - Title: `Trinity: Ternary VSA Framework v0.11.0`
   - Authors: See `CITATION.cff`
   - License: MIT
   - Keywords: ternary-computing, vsa, hyperdimensional-computing
4. **Publish** and receive DOI

### Citing with DOI

Once published, cite as:

```bibtex
@software{trinity2026,
  author       = {Vasilev, Dmitrii},
  title        = {Trinity: Ternary Vector Symbolic Architecture Framework},
  year         = 2026,
  publisher    = {Zenodo},
  version      = {v0.11.0},
  doi          = {10.5281/zenodo.XXXXXXX},
  url          = {https://doi.org/10.5281/zenodo.XXXXXXX}
}
```

### GitHub-Zenodo Integration

To automatically archive releases:

1. Go to https://zenodo.org/account/settings/github/
2. Connect your GitHub account
3. Enable the `gHashTag/trinity` repository
4. Each GitHub release will automatically get a DOI

---

## Reproducing Specific Results

### VSA Capacity Bounds (Theorem 3.2)

```bash
# Run capacity test
zig test src/vsa/tests.zig --test-filter "bundle capacity"

# Expected: For n=64 vectors, avg similarity ≈ 0.1
```

### Trinity Identity

```bash
# Verify φ² + 1/φ² = 3
zig build tri -- math verify-identity

# Expected output:
# φ = 1.6180339887498949
# φ² = 2.6180339887498949
# 1/φ² = 0.38196601125010515
# φ² + 1/φ² = 3.0000000000000000 ✓
```

### Bind Self-Inverse Property

```zig
// src/vsa/tests.zig
test "bind self-inverse" {
    var a = randomVector(1000, 42);
    var b = randomVector(1000, 43);
    
    var bound = bind(&a, &b);
    var recovered = unbind(&bound, &a);
    
    // recovered ≈ b
    const sim = cosineSimilarity(&recovered, &b);
    try testing.expect(sim > 0.99);
}
```

---

## Hardware Benchmarks

### Reference Hardware

Results in documentation were obtained on:

| Component | Specification |
|-----------|--------------|
| CPU | Apple M1 Pro / AMD Ryzen 9 |
| RAM | 16GB+ |
| OS | macOS 14 / Ubuntu 22.04 |

### Running Benchmarks

```bash
# Standard benchmarks
zig build bench

# With detailed output
zig build bench 2>&1 | tee benchmark_results.txt

# Compare with reference
diff benchmark_results.txt benchmarks/reference_m1pro.txt
```

---

## Troubleshooting

### Zig Version Mismatch

```
error: expected 0.15.x but found 0.14.x
```

**Solution**: Install Zig 0.15.x as shown above.

### Out of Memory

```
error: OutOfMemory
```

**Solution**: Reduce VSA dimension or increase swap:

```bash
# Create 4GB swap
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### SIMD Not Available

```
warning: SIMD not available, falling back to scalar
```

**Note**: This is informational. Scalar fallback is functionally correct but slower.

---

## Verification Checklist

- [ ] `zig build` completes without errors
- [ ] `zig build test` passes 3500+ tests
- [ ] `zig build bench` produces numeric results
- [ ] VSA similarity values in expected ranges
- [ ] Trinity Identity verified: φ² + 1/φ² = 3

---

## Contact

For reproducibility issues:
- GitHub Issues: https://github.com/gHashTag/trinity/issues
- Email: dmitrii@trinity.dev

---

*φ² + 1/φ² = 3 | TRINITY*
