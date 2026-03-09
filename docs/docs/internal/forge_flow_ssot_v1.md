# FORGE Flow SSOT — Single Source of Truth

**Version:** 1.0
**Date:** 2026-03-08
**Status:** PROPOSED — TODO 7 SA-2

---

## Canonical Pipeline Definition

### Single Source of Truth

**The only supported path** from source to bitstream in Trinity v2.2.0+:

```
.tri / .vibee spec → VIBEE codegen → Verilog + XDC → openXC7 Docker → .bit
                     (zig build vibee)   (tri fpga build)   (synth.sh wrapper)
```

---

## Entry Point CLI (PROPOSED)

### Primary Command: `tri fpga build`

```bash
tri fpga build <input> [options]
```

**Arguments:**
- `<input>`: Path to `.tri`, `.vibee`, or `.v` file

**Options:**
| Option | Default | Description |
|--------|---------|-------------|
| `--target <device>` | `xc7a100t` | Target FPGA device |
| `--top <module>` | `<input>_top` | Top module name |
| `--toolchain <tool>` | `openxc7` | Toolchain (openxc7 only) |
| `--out <path>` | `./build/<name>.bit` | Output bitstream path |
| `--verify` | `false` | Run LED hardware verification |
| `--verbose` | `false` | Enable verbose output |

**Examples:**
```bash
# From .vibee spec
tri fpga build specs/tri/blink.vibee

# From .tri file (if implemented)
tri fpga build design.tri --target xc7a35t

# From existing Verilog
tri fpga build uart_top.v --top uart_top --verify

# Custom output
tri fpga build blink.vibee --out build/blink.bit
```

---

## Pipeline Stages

### Stage 1: Code Generation (VIBEE)

**Input:** `.vibee` specification
**Tool:** `zig build vibee -- gen <spec.vibee>`
**Output:** `trinity-nexus/output/lang/fpga/<name>.v`

**If input is `.v`:** Skip to Stage 2

**If input is `.tri`:** Not yet supported (TODO 7+)

### Stage 2: Synthesis (openXC7 Docker)

**Input:** `<name>.v` + `<name>.xdc`
**Tool:** `regymm/openxc7` Docker image
**Sub-stages:**
1. Yosys synthesis → `<name>.json`
2. nextpnr-xilinx P&R → `<name>.fasm`
3. fasm2frames → `<name>.frames`
4. xc7frames2bit → `<name>.bit`

### Stage 3: Verification (Optional)

**Input:** `<name>.bit`
**Tool:** `../tools/verify_led.sh`
**Output:** PASS/FAIL + video evidence

---

## Supported Devices

| Device | Package | Status | Notes |
|--------|---------|--------|-------|
| xc7a100t | fgg676 | ✅ PRIMARY | QMTECH Artix-7 |
| xc7a35t | cpg236 | ⚠️ FUTURE | synth_10k.sh exists, not integrated |

**Chipdb:** `chipdb/xc7a100tfgg676.bin` (for nextpnr-xilinx)

---

## Toolchain Configuration

### Docker Image

**Repository:** `regymm/openxc7`
**Tag:** `latest`
**Platform:** `linux/amd64`

**Included Tools:**
- Yosys (synthesis)
- nextpnr-xilinx (place & route)
- fasm2frames (FASM converter)
- prjxray (database + xc7frames2bit)

### Local Installation (NOT SUPPORTED)

Direct toolchain installation is **not documented** and **not supported**.
Use Docker for reproducibility.

---

## File Locations

### Input Files
```
specs/tri/*.vibee              # VIBEE specifications
fpga/openxc7-synth/*.v         # Hand-written Verilog
fpga/openxc7-synth/*.xdc       # Pin constraints
```

### Output Files
```
build/*.bit                    # Bitstreams (canonical location)
build/*.json                   # Yosys netlist
build/*.fasm                   # FPGA assembly
build/*.log                    # Synthesis logs
```

### Generated Code
```
trinity-nexus/output/lang/fpga/*.v   # VIBEE-generated Verilog
```

---

## Deprecated Paths

### FORGE Zig Toolchain

**Status:** ⚠️ DEPRECATED for complex designs

**Reason:** 4+ critical OLOGIC bugs documented in GA Final Verdict

**Workaround:** Use openXC7 Docker via `tri fpga build`

**Future:** May be re-enabled after bug fixes (TODO 8+)

### Direct synth.sh invocation

**Status:** ⚠️ DEPRECATED (but still works)

**Replacement:** `tri fpga build <design.v>`

**Rationale:** Single CLI entry point for better DX

---

## Error Handling

### Missing XDC file
```
Error: XDC file not found: <design>.xdc
Hint: Create constraints file or use --top to specify default
```

### Synthesis failure
```
Error: Synthesis failed for <design>
Log: build/<design>.log
Hint: Check Yosys output for syntax errors
```

### P&R failure
```
Error: Place & route failed for <design>
Hint: Design may not fit target device
```

---

## CI Integration

### GitHub Actions (PROPOSED)

```yaml
name: FPGA Synthesis

on: [push, pull_request]

jobs:
  synth:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Zig
        run: # ... install zig 0.15.x
      - name: Build VIBEE
        run: zig build vibee
      - name: Synthesize test designs
        run: |
          tri fpga build fpga/openxc7-synth/blink.v
          tri fpga build fpga/openxc7-synth/counter.v
          tri fpga build fpga/openxc7-synth/uart_top.v
```

---

## Version Compatibility

| Component | Version | Notes |
|-----------|---------|-------|
| openXC7 Docker | latest | Uses prjxray database |
| Yosys | (in Docker) | synth_xilinx -flatten -abc9 |
| nextpnr-xilinx | (in Docker) | --chipdb xc7a100tfgg676 |
| Zig | 0.15.x | For VIBEE compiler |

---

## Migration Guide

### From synth.sh

**Before:**
```bash
cd fpga/openxc7-synth
./synth.sh blink.v blink_top
```

**After:**
```bash
tri fpga build fpga/openxc7-synth/blink.v --top blink_top
```

### From manual Docker

**Before:**
```bash
docker run --rm regymm/openxc7 yosys ...
docker run --rm regymm/openxc7 nextpnr-xilinx ...
```

**After:**
```bash
tri fpga build design.v
```

---

## Non-Goals (Explicitly Out of Scope)

1. **.tri file format** — Not yet implemented (deferred to TODO 8+)
2. **Native Zig toolchain** — FORGE bugs need fixing first
3. **Multi-device support** — Only xc7a100t initially
4. **Partial reconfiguration** — Not supported
5. **Timing closure optimization** — Uses default nextpnr settings

---

φ² + 1/φ² = 3 | TODO 7 SA-2: SSOT FLOW DEFINITION
