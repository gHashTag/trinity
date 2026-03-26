# Trinity Zenodo v6.1 Docker Reproducibility

Containerized environments for reproducing Trinity Zenodo bundle results.

## Images

| Bundle | Dockerfile | Purpose | Base Image |
|--------|------------|---------|------------|
| B001 | Dockerfile.B001 | HSLM training | ziglang/zig:0.15.0-alpine |
| B002 | Dockerfile.B002 | FPGA synthesis | ziglang/zig:0.15.0-alpine |
| B003 | Dockerfile.B003 | TRI-27 emulation | ziglang/zig:0.15.0-alpine |
| B004 | Dockerfile.B004 | Queen Lotus Cycle | ziglang/zig:0.15.0-alpine |
| B005 | Dockerfile.B005 | VIBEE compiler | ziglang/zig:0.15.0-alpine |
| B006 | Dockerfile.B006 | Sacred formats | ziglang/zig:0.15.0-alpine |
| B007 | Dockerfile.B007 | VSA operations | ziglang/zig:0.15.0-alpine |

## Building Images

```bash
# Build all images
for bundle in B001 B002 B003 B004 B005 B006 B007; do
  docker build -f docker/Dockerfile.$bundle -t trinity-$bundle .
done

# Build specific bundle
docker build -f docker/Dockerfile.B001 -t trinity-b001 .
```

## Running Containers

### B001: HSLM Training
```bash
# Download TinyStories dataset (if not present)
docker run --rm -v $(pwd)/data:/data trinity-b001 \
  hslm-train --download-tinystories

# Run training
docker run --rm -v $(pwd)/data:/data trinity-b001 \
  hslm-train --dataset /data/tinystories --steps 30000
```

### B002: FPGA Synthesis
```bash
# Run synthesis on Verilog source
docker run --rm -v $(pwd)/fpga:/workspace trinity-b002 \
  fpga-synth --input hslm_accelerator.v --output bitstream.bit
```

### B003: TRI-27 Emulation
```bash
# Assemble TRI-27 program
echo "MOV R0, #42" | docker run --rm -i trinity-b003 tri27-asm > program.t27

# Run in emulator
docker run --rm -v $(pwd):/workspace trinity-b003 \
  tri27-emu program.t27 --debug
```

### B007: VSA Benchmarks
```bash
# Run SIMD benchmarks
docker run --rm trinity-b007 \
  vsa-bench --mode all --iterations 100000
```

## Resource Requirements

| Bundle | Docker Image Size | Runtime RAM | CPU |
|--------|------------------|--------------|------|
| B001 | ~150 MB | 512 MB | ARM64/x86_64 |
| B002 | ~100 MB | 256 MB | ARM64/x86_64 |
| B003 | ~50 MB | 64 MB | ARM64/x86_64 |
| B007 | ~80 MB | 128 MB | ARM64 (NEON) |

## CI/CD Integration

```yaml
# .github/workflows/zenodo-bundles.yml
name: Zenodo Bundle Tests

on: [push, pull_request]

jobs:
  test-b001:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: docker build -f docker/Dockerfile.B001 -t trinity-b001 .
      - run: docker run --rm trinity-b001 hslm-train --help
```

φ² + 1/φ² = 3 | TRINITY
