# IGLA v1.0 Quick Install Guide

**Version:** 1.0.0
**Release:** https://github.com/gHashTag/trinity/releases/tag/v1.0.0-igla

---

## One-Line Install

### macOS (M1/M2/M3 Apple Silicon)

```bash
curl -LO https://github.com/gHashTag/trinity/releases/download/v1.0.0-igla/igla-macos-arm64 && chmod +x igla-macos-arm64 && ./igla-macos-arm64
```

### macOS (Intel)

```bash
curl -LO https://github.com/gHashTag/trinity/releases/download/v1.0.0-igla/igla-macos-x64 && chmod +x igla-macos-x64 && ./igla-macos-x64
```

### Linux x64

```bash
curl -LO https://github.com/gHashTag/trinity/releases/download/v1.0.0-igla/igla-linux-x64 && chmod +x igla-linux-x64 && ./igla-linux-x64
```

### Windows (PowerShell)

```powershell
Invoke-WebRequest -Uri "https://github.com/gHashTag/trinity/releases/download/v1.0.0-igla/igla-windows-x64.exe" -OutFile "igla.exe"; .\igla.exe
```

---

## Expected Output

```
╔══════════════════════════════════════════════════════════════╗
║     IGLA METAL GPU v2.0 — VSA ACCELERATION                   ║
║     Scalable Benchmark | Dim: 300 | 8-thread SIMD            ║
║     φ² + 1/φ² = 3 = TRINITY                                  ║
╚══════════════════════════════════════════════════════════════╝

═══════════════════════════════════════════════════════════════
     SCALABLE BENCHMARK RESULTS
═══════════════════════════════════════════════════════════════
  Vocab Size │ ops/s     │ M elem/s │ Time(ms) │ Status
  ───────────┼───────────┼──────────┼──────────┼────────────
       1000 │      2389 │    716.7 │    418.6 │ 1K+
       5000 │      1713 │   2570.0 │    583.7 │ 1K+
      10000 │      3147 │   9441.5 │    317.7 │ 1K+
      25000 │      4571 │  34284.8 │    218.8 │ 1K+
      50000 │      4854 │  72823.4 │    206.0 │ PRODUCTION
```

---

## Binary Sizes

| Platform | Binary | Size |
|----------|--------|------|
| macOS ARM64 | `igla-macos-arm64` | 264 KB |
| macOS x64 | `igla-macos-x64` | 271 KB |
| Linux x64 | `igla-linux-x64` | 2.3 MB |
| Windows x64 | `igla-windows-x64.exe` | 543 KB |

---

## System Requirements

| Platform | Minimum |
|----------|---------|
| macOS | macOS 11+ (Big Sur) |
| Linux | glibc 2.17+ (CentOS 7+) |
| Windows | Windows 10+ |
| RAM | 64 MB (50K vocab) |
| CPU | Any x64/ARM64 |

---

## Troubleshooting

### macOS: "cannot be opened because the developer cannot be verified"

```bash
xattr -d com.apple.quarantine igla-macos-arm64
```

### Linux: Permission denied

```bash
chmod +x igla-linux-x64
```

### Windows: SmartScreen warning

Click "More info" → "Run anyway"

---

## Performance Tips

1. **M1/M2/M3 Mac:** Use ARM64 binary (264KB, fastest)
2. **Intel Mac:** Use x64 binary
3. **Linux:** Ensure glibc 2.17+ installed
4. **Windows:** Run from PowerShell for best output

---

## Build from Source

```bash
git clone https://github.com/gHashTag/trinity.git
cd trinity
zig build-exe src/vibeec/igla_metal_gpu.zig -O ReleaseFast
./igla_metal_gpu
```

Requires: Zig 0.15.x

---

## Links

- **Release:** https://github.com/gHashTag/trinity/releases/tag/v1.0.0-igla
- **Repository:** https://github.com/gHashTag/trinity
- **Documentation:** https://gHashTag.github.io/trinity

---

**φ² + 1/φ² = 3 = TRINITY**
