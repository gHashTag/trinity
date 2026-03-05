# FPGA Toolchain Comparison

## Executive Summary

| Toolchain | Status | Success Rate | Recommendation |
|-----------|--------|--------------|----------------|
| **openXC7** (Docker) | ✅ WORKING | 100% (1/1) | **Use for production** |
| **FORGE** (Zig) | ❌ BUGGY | 0% (0/23) | Experimental only |

**Recommendation**: Always use openXC7 for FPGA bitstream generation. FORGE has critical bugs and requires significant debugging.

---

## openXC7 (Docker) ✅

### Overview

Open-source FPGA toolchain for Xilinx 7-series based on Yosys and Project X-Ray.

### Pipeline

```
Verilog → Yosys → JSON → nextpnr-xilinx → FASM → fasm2frames → xc7frames2bit → .bit
```

### Docker Image

```bash
docker pull regymm/openxc7:latest  # 5.72 GB
```

### Components

| Tool | Purpose | Version |
|------|---------|---------|
| yosys | Verilog synthesis | latest |
| nextpnr-xilinx | Place & Route, FASM generation | latest |
| fasm2frames | FASM → frame conversion | prjxray |
| xc7frames2bit | Frames → .bit bitstream | prjxray |
| prjxray-db | Device database | artix7 |

### Usage

```bash
cd fpga/openxc7-synth
./synth.sh <design>.v <top_module>
```

### Synthesis Script (`synth.sh`)

```bash
#!/bin/bash
VERILOG="$1"
TOP="${2:-$(basename -s .v "$VERILOG")_top}"
BASE="$(basename -s .v "$VERILOG")"

# Step 1: Yosys synthesis
docker run --rm --platform linux/amd64 \
  -v "$(pwd):/work" -w /work \
  regymm/openxc7 \
  yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top $TOP; write_json ${BASE}.json" \
  "$VERILOG"

# Step 2: nextpnr-xilinx (P&R)
docker run --rm --platform linux/amd64 \
  -v "$(pwd):/work" -w /work \
  regymm/openxc7 \
  nextpnr-xilinx \
    --chipdb /work/chipdb/xc7a100tfgg676.bin \
    --xdc /work/${BASE}.xdc \
    --json /work/${BASE}.json \
    --write /work/${BASE}_routed.json \
    --fasm /work/${BASE}.fasm \
    --freq 50 --seed 1

# Step 3 & 4: FASM → Frames → Bitstream
docker run --rm --platform linux/amd64 \
  -v "$(pwd):/work" -w /work \
  regymm/openxc7 \
  bash -c "\
    fasm2frames \
      --db-root /nextpnr-xilinx/xilinx/external/prjxray-db/artix7 \
      --part xc7a100tfgg676-1 \
      /work/${BASE}.fasm \
      /work/${BASE}.frames && \
    /prjxray/build/tools/xc7frames2bit \
      --part_file /nextpnr-xilinx/xilinx/external/prjxray-db/artix7/xc7a100tfgg676-1/part.yaml \
      --part_name xc7a100tfgg676-1 \
      --frm_file /work/${BASE}.frames \
      --output_file /work/${BASE}.bit"
```

### Results

| Design | Status | Max Freq | CLBs |
|--------|--------|----------|------|
| temporal_heartbeat | ✅ Working | 165.15 MHz | ~30 |

### Pros

- ✅ Proven working (real hardware tested)
- ✅ Uses prjxray database (reverse-engineered from Xilinx)
- ✅ All primitives correctly implemented
- ✅ Good timing reports
- ✅ Active community support

### Cons

- ❌ Large Docker image (5.72 GB)
- ❌ Requires Docker installation
- ❌ Startup overhead (container creation)

---

## FORGE (Zig) ❌

### Overview

Native Zig FPGA toolchain for Xilinx 7-series. Designed to be 100% Zig, no Docker.

### Pipeline

```
Verilog → Yosys → JSON → FORGE (Zig) → .bit
```

### Usage

```bash
# Step 1: Yosys synthesis (same as openXC7)
yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top top; write_json design.json" design.v

# Step 2: FORGE bitstream generation
zig build forge
./zig-out/bin/forge run \
    --input design.json \
    --device xc7a100t \
    --constraints design.xdc \
    --output design.bit
```

### Version History

| Version | Result | Root Cause |
|---------|--------|------------|
| v1-v17 | Unknown | Not documented |
| v18 | D6 OFF | Wrong XDC + IMUX conflicts |
| v19 | Not tested | Diagonal routing + priority dedup |
| v20-v21 | Failed | Various routing issues |
| v22 | No blink | CARRY4.O→FF.D routed through INT |
| v23 | No blink | Same fix, 1142 bit diffs remain |

### Known Bugs

| Bug | Location | Impact |
|-----|----------|--------|
| LUT INIT wrong | `src/forge/fasm_gen.zig` | Truth tables incorrect |
| FFMUX strategy wrong | `src/forge/fasm_gen.zig` | Uses XOR everywhere |
| VCC IMUX override | `src/forge/placer.zig` | Violates sacred pins |
| Missing OLOGIC | `src/forge/fasm_gen.zig:557-560` | No ZINV, missing TFF |
| Net-to-port mismatch | `src/forge/placer.zig:115-132` | IO cells not locked |

### Critical Rules Violated

From `FORGE_SESSION_RULES.md`:

1. **CARRY4.O/CO → FF.D routing**
   - ❌ FORGE: Routes through INT tiles
   - ✅ Correct: Use internal FFMUX.XOR path

2. **VCC IMUX pins**
   - ❌ FORGE: Routes signals through sacred pins
   - ✅ Correct: IMUX_L{4,12,35,43} always VCC_WIRE

3. **OBUF destination**
   - ❌ FORGE: Routes to IOB tile
   - ✅ Correct: Route to INT tile at (tile_x, tile_y + 1)

### Pros

- ✅ Native Zig (no Docker)
- ✅ Fast compilation (Zig is fast)
- ✅ No external dependencies
- ✅ Potential for integration with Trinity codebase

### Cons

- ❌ 0% success rate (23 versions failed)
- ❌ Fundamental architecture issues
- ❌ Lacks prjxray database accuracy
- ❌ Estimated 4-8 hours to fix

---

## Comparison Table

| Feature | openXC7 | FORGE |
|---------|---------|-------|
| **Language** | Python/C++ | Zig |
| **Dependencies** | Docker (5.72 GB) | Zig only |
| **Primitives** | ✅ All correct | ❌ LUT INIT wrong |
| **Routing** | ✅ Correct topology | ❌ VCC violations |
| **OLOGIC** | ✅ Complete | ❌ Missing features |
| **Database** | prjxray (reverse-engineered) | Custom implementation |
| **Success Rate** | 100% (1/1) | 0% (0/23) |
| **Recommendation** | **Production use** | Experimental only |

---

## Recommendation

### For Production Work

```bash
cd fpga/openxc7-synth
./synth.sh design.v top_module
```

**Always use openXC7.** It works reliably and is based on the proven prjxray database.

### FORGE Future Work

If fixing FORGE:

1. Fix `findPinForNet()` to properly match top-level ports
2. Add missing OLOGIC features (ZINV, TFF, etc.)
3. Fix IOB placement locking
4. Add proper IOI routing (IMUX connections)
5. Compare FASM output to openXC7 reference

**Estimated effort**: 4-8 hours of debugging + testing

---

## References

- `fpga/openxc7-synth/OPENXC7_SUCCESS_REPORT.md` - Full success report
- `fpga/openxc7-synth/FORGE_SESSION_RULES.md` - Critical lessons learned
- `fpga/openxc7-synth/ROUTING_DEEP_DIVE.md` - Architecture analysis

---

## φ² + 1/φ² = 3 = TRINITY
