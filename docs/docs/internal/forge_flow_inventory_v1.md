# FORGE Flow Inventory — Trinity v2.2.0

**Date:** 2026-03-08
**Purpose:** Complete inventory of all .tri → .bit synthesis paths
**Status:** DRAFT — TODO 7 SA-1

---

## Executive Summary

Current FORGE synthesis has **multiple parallel paths** from source to bitstream:

1. **Direct Shell Scripts** — `synth.sh` calls Docker/openXC7 directly
2. **FORGE Zig Toolchain** — Native Zig implementation (has known bugs)
3. **VIBEE Code Generator** — `.vibee` → Verilog (no unified CLI)
4. **Manual Toolchain Calls** — Direct Yosys/nextpnr invocation

**Problem:** No single canonical CLI entry point for .tri → .bit flow.

---

## Path 1: Shell Scripts (ACTIVE)

### synth.sh — Single Design Synthesis

**Location:** `fpga/openxc7-synth/synth.sh`

**Command:**
```bash
./synth.sh <design.v> [top_module_name]
```

**Flow:**
1. Yosys synthesis (Docker: regymm/openxc7)
2. nextpnr-xilinx place & route
3. fasm2frames conversion
4. xc7frames2bit bitstream generation
5. LED hardware verification (optional)

**Target:** xc7a100tfgg676 (QMTECH Artix-7)

**Status:** ✅ ACTIVE — Used for manual synthesis and GA certification

**Artifacts:** `*.json`, `*_routed.json`, `*.fasm`, `*.frames`, `*.bit`

---

### synth_batch.sh — Batch Synthesis

**Location:** `fpga/openxc7-synth/synth_batch.sh`

**Command:**
```bash
./synth_batch.sh <designs_list.txt>
```

**Flow:** Calls `synth.sh` for each design in list

**Status:** ✅ ACTIVE — Used for multi-design synthesis

**Artifacts:** `*.bit` per design, `*.log` files

---

### Other synth scripts

| Script | Status | Notes |
|--------|--------|-------|
| `synth_10k.sh` | ⚠️ SPECIALIZED | 10K FPGA target |
| `synth_10k_all.sh` | ⚠️ SPECIALIZED | Batch for 10K |
| `synth_tqnn.sh` | ⚠️ SPECIALIZED | TQNN-specific |
| `synth_conscious.sh` | ❌ UNKNOWN | Consciousness-specific (unclear if used) |

---

## Path 2: FORGE Zig Toolchain (PARTIAL)

**Location:** `src/forge/`

**Entry Point:** `src/forge/main.zig`

**Components:**
- `json_parser.zig` — Yosys JSON parsing
- `tech_map.zig` — Technology mapping
- `placer.zig` — Simulated annealing placement
- `router.zig` — Pathfinder routing
- `fasm_gen.zig` — FASM generation
- `bitstream.zig` — Bitstream generation
- `tri_parser.zig` — .tri file parsing
- `auto_fix.zig` — Error diagnosis

**Status:** ⚠️ PARTIAL — Has 4+ critical OLOGIC bugs for complex designs

**Known Issues (GA Final Verdict):**
1. IOB placement incorrect for LED mapping
2. OLOGIC config missing ZINV/TFF features
3. net-to-port matching fails for complex designs

**Workaround:** Use openXC7 Docker for production

**Command (if working):**
```bash
./zig-out/bin/forge run \
  --input <design.json> \
  --device xc7a100t \
  --constraints <design.xdc> \
  --output <design.bit>
```

---

## Path 3: VIBEE Code Generator (ACTIVE)

**Location:** `trinity-nexus/lang/src/`

**Entry Point:** `gen_cmd.zig` → `zig build vibee`

**Supported Languages:**
- Zig (`language: zig`)
- Verilog (`language: varlog`)
- Python, Rust, Go, TypeScript

**Command:**
```bash
zig build vibee -- gen <spec.vibee>
```

**Output:** `trinity-nexus/output/lang/<language>/`

**Verilog Output:** `trinity-nexus/output/lang/fpga/*.v`

**Status:** ✅ ACTIVE — Used for code generation from .vibee specs

**Gap:** No unified `tri fpga build` command that ties VIBEE + synth together

---

## Path 4: Manual Toolchain (REFERENCE)

**Direct Docker Commands:**

```bash
# Yosys synthesis
docker run --rm --platform linux/amd64 \
  -v "$(pwd):/work" -w /work \
  regymm/openxc7 \
  yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top $TOP; \
           write_json ${BASE}.json" \
  "$VERILOG"

# nextpnr-xilinx
docker run --rm --platform linux/amd64 \
  -v "$(pwd):/work" -w /work \
  regymm/openxc7 \
  nextpnr-xilinx --chipdb /work/chipdb/xc7a100tfgg676.bin ...

# fasm2frames
docker run --rm --platform linux/amd64 \
  -v "$(pwd):/work" -w /work \
  regymm/openxc7 \
  fasm2frames ...

# xc7frames2bit
docker run --rm --platform linux/amd64 \
  -v "$(pwd):/work" -w /work \
  regymm/openxc7 \
  /prjxray/build/tools/xc7frames2bit ...
```

**Status:** ℹ️ REFERENCE — Documented but not recommended for daily use

---

## Current Gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| No `tri fpga build` CLI | Users must call synth.sh directly | HIGH |
| No .tri → Verilog flow in CLI | VIBEE exists but not integrated | HIGH |
| FORGE Zig has bugs | Can't use native toolchain | MEDIUM |
| No single SSOT for path | Multiple confusing options | HIGH |

---

## Usage by Context

### Dev/Debug
- **Primary:** `synth.sh` for single designs
- **Batch:** `synth_batch.sh` for multiple

### CI
- **Status:** Not currently automated in CI
- **GA Certification:** Used `synth.sh` manually

### Production (GA-certified)
- **Toolchain:** openXC7 Docker (regymm/openxc7)
- **Entry Point:** `synth.sh` script
- **Verified:** 60+ designs synthesize successfully

---

## File Inventory

### Synthesis Scripts
```
fpga/openxc7-synth/
├── synth.sh              ✅ ACTIVE (main path)
├── synth_batch.sh        ✅ ACTIVE (batch)
├── synth_10k.sh          ⚠️ SPECIALIZED
├── synth_10k_all.sh      ⚠️ SPECIALIZED
├── synth_tqnn.sh         ⚠️ SPECIALIZED
└── synth_conscious.sh    ❌ UNKNOWN
```

### FORGE Zig Code
```
src/forge/
├── main.zig              ⚠️ Entry point (buggy)
├── tri_parser.zig        ✅ .tri parsing
├── json_parser.zig       ✅ Yosys JSON
├── tech_map.zig          ✅ Tech mapping
├── placer.zig            ⚠️ Has issues
├── router.zig            ✅ Routing
├── fasm_gen.zig          ⚠️ Missing features
├── bitstream.zig         ✅ Bitstream gen
└── auto_fix.zig          ✅ Error diagnosis
```

### VIBEE Compiler
```
trinity-nexus/lang/src/
├── compiler.zig          ✅ Main compiler
├── gen_cmd.zig           ✅ CLI entry
├── codegen/emitter.zig   ✅ Code generation
└── lang_generators.zig   ✅ Multi-language
```

### Generated Verilog
```
trinity-nexus/output/lang/fpga/
├── blink.v
├── counter.v
├── uart_top.v
├── fpga_mvp.v
└── ... (24 files)
```

---

## Target Devices

| Device | Status | Notes |
|--------|--------|-------|
| xc7a100tfgg676 | ✅ SUPPORTED | QMTECH Artix-7 (main target) |
| xc7a35tcpg236 | ⚠️ PARTIAL | synth_10k.sh mentions |
| Other 7-series | ❌ NOT SUPPORTED | No testing done |

---

## Recommendations (for TODO 7)

1. **Create `tri fpga build` CLI** — Single entry point
2. **Integrate VIBEE Verilog gen** — `.vibee` → `.v` → `.bit`
3. **Deprecate FORGE Zig** (until bugs fixed) — Document openXC7 Docker as SSOT
4. **Unify synth scripts** — Make them wrappers around `tri fpga build`
5. **Add CI automation** — Run synthesis in GitHub Actions

---

φ² + 1/φ² = 3 | TODO 7 SA-1: FORGE FLOW INVENTORY
