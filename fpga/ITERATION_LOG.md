# FPGA Development Iteration Log

This document tracks all FPGA development sessions to accumulate experience and prevent repeating mistakes.

---

## 2026-03-04 - Vision LED Test Integration

**Agent**: Claude (Opus 4)
**Session**: Camera-based LED verification for FPGA

### Activities

1. **Created Vision LED Test Pipeline** (`fpga/test_with_camera.sh`)
   - Full pipeline: build → flash → photo → evidence
   - iPhone Continuity Camera integration via ffmpeg
   - Evidence management with metadata

2. **Created Camera Snapshot Tool** (`fpga/tools/cam_snapshot.sh`)
   - 3-second video capture for autofocus
   - Extracts last frame as photo

3. **Added Link 23 to Golden Chain v4.2**
   - Module: `src/tri/vision_led_test.zig`
   - Updated: `src/tri/golden_chain.zig` (24 links)
   - Updated: `src/tri/pipeline_executor.zig`

4. **LED Blink Testing**
   - Captured 150 frames @ 30fps (5 seconds)
   - Result: No brightness variation detected (LED NOT blinking)
   - Issue: d6_blink.bit may not be working correctly

### Results

| Design | Status | Notes |
|--------|--------|-------|
| led_on | ✅ PASS | LED D6 ON confirmed (evidence photos saved) |
| d6_blink | ⚠️ FAIL | No blinking detected in 150-frame analysis |

### Lessons Learned

1. **Single photo cannot detect blinking** > 1 Hz
   - Need video capture (30fps, 3-5 sec minimum)

2. **Vision API has limitations**
   - file:// URLs not supported
   - Inconsistent analysis results
   - Better to analyze pixel brightness locally

3. **Module name mismatch**
   - `d6_blink.v` defines `trinity_top` but build expects `d6_blink_top`
   - Always match module name with build parameter

### Files Created

```
fpga/
├── test_with_camera.sh
├── tools/cam_snapshot.sh
└── evidence/
    ├── led_on_forge_fix_20260304.jpg
    ├── led_on_forge_fix_closeup_20260304.jpg
    └── ...

src/tri/
├── vision_led_test.zig
├── golden_chain.zig (updated)
└── pipeline_executor.zig (updated)
```

### Next Steps

- [ ] Verify d6_blink.bit module name issue
- [ ] Implement proper video analysis for blink detection
- [ ] Complete vision_led_test.zig implementation (currently placeholder)

---

## 2026-03-03 - Temporal Trinity Heartbeat Success

**Agent**: Claude (Opus 4)
**Session**: First successful FPGA bitstream

### Activities

1. **Generated working bitstream** with openXC7 toolchain
   - Design: `temporal_heartbeat.v` (88 lines)
   - Output: `temporal_heartbeat.bit` (3.6 MB)
   - LED pattern: phi-second timing (past → present → future)

2. **Verified on hardware**
   - LED D6 blinking with 3-layer pattern confirmed
   - Cycle time: 3φ = 4.854 seconds

3. **Documented success**
   - Created `OPENXC7_SUCCESS_REPORT.md`
   - Created `ROUTING_DEEP_DIVE.md`

### Results

| Metric | Value |
|--------|-------|
| Max frequency | 165.15 MHz (target: 50 MHz) |
| Routing overuse | 0 |
| CLBs used | ~30 slices |
| CARRY4 instances | 64 |
| FASM features | 1707 lines |

### Key Finding

**openXC7 succeeded on first try after 23 FORGE failures**

The open-source Yosys+nextpnr-xilinx toolchain generates CORRECT bitstreams.

### Lessons Learned

1. **openXC7 is production-ready**
   - Uses prjxray database (reverse-engineered from Xilinx)
   - All primitives correctly implemented

2. **FORGE has fundamental bugs**
   - LUT INIT truth tables wrong
   - FFMUX strategy incorrect
   - VCC IMUX override bug
   - Missing OLOGIC features

---

## Previous Sessions (Feb 2026 - FORGE Failures)

**Reference**: `fpga/openxc7-synth/FORGE_SESSION_RULES.md`

### Version History

| Version | Result | Root Cause |
|---------|--------|------------|
| v18 | D6 OFF | Wrong XDC + IMUX conflicts |
| v19 | Not tested | Diagonal routing + priority dedup |
| v22 | No blink | CARRY4.O→FF.D routed through INT, overriding VCC |
| v23 | No blink | Same fix applied but 1142 bit diffs remain |

### Critical Rules Discovered

1. **NEVER route CARRY4.O/CO → FF.D through INT tiles**
   - Use internal FFMUX.XOR path instead

2. **VCC IMUX pins are SACRED**
   - Left tiles: IMUX_L{4,12,35,43} must ALWAYS be VCC_WIRE

3. **OBUF destination is INT tile at (tile_x, tile_y + 1)**
   - Signal must reach INT tile, not IOB tile

4. **ppips have NO config bits**
   - Ignore them in bitstream comparison

5. **Always verify with reference FASM**
   - Reference: `blinker_t23.fasm` (635 features, confirmed working)

---

## Session Template

When adding new entries, follow this format:

```markdown
## YYYY-MM-DD - Session Title

**Agent**: [Name/Version]
**Session**: [Brief description]

### Activities
1. [Action 1]
2. [Action 2]

### Results
| Design/Task | Status | Notes |
|-------------|--------|-------|
| ... | ... | ... |

### Lessons Learned
1. [Lesson 1]
2. [Lesson 2]

### Files Modified
- [File 1]
- [File 2]

### Next Steps
- [ ] [Task 1]
- [ ] [Task 2]
```

---

## Statistics

| Toolchain | Attempts | Successes | Success Rate |
|-----------|----------|-----------|--------------|
| openXC7 | 1 | 1 | 100% |
| FORGE | 23 | 0 | 0% |

| Design | Status | Date |
|--------|--------|------|
| temporal_heartbeat | ✅ Working | 2026-03-03 |
| led_on | ✅ Working | 2026-03-04 |
| d6_blink | ⚠️ Issues | 2026-03-04 |

---

## φ² + 1/φ² = 3 = TRINITY
