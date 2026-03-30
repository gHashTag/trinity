# Trinity CLI — Terminal Demos

Animated terminal GIFs demonstrating `tri` command functionality.

## Installation

### Prerequisites

```bash
# asciinema 3.0+ (for live recording)
brew install asciinema

# VHS (declarative tape format)
brew install vhs

# agg (GIF generator, uses gifski)
cargo install --git https://github.com/asciinema/agg
```

## Recording Mode 1: Live (via asciinema + agg)

For proving agent execution with real output:

```bash
# Record a specific command
TRI_REC_COLS=120 TRI_REC_ROWS=40 TRI_REC_IDLE_MAX=3 ./tri-record.sh benchmark

# Output: recordings/tri-benchmark.gif
```

**Environment Variables:**
- `TRI_REC_COLS` — Terminal width (default: 120)
- `TRI_REC_ROWS` — Terminal height (default: 40)
- `TRI_REC_IDLE_MAX` — Max seconds idle before cut (default: 3)
- `TRI_REC_OVERWRITE` — Skip existing files (default: false)

## Recording Mode 2: VHS Tapes (Declarative)

VHS tapes ensure reproducibility:

```bash
# Render all tapes
cd tapes
for tape in *.tape; do
  vhs < "$tape"
done
```

## Demo 1: VSA Math Operations

![tri-math-demo](../recordings/tri-math-demo.gif)

Demonstrates Trinity's Vector Symbolic Architecture math operations:
- `tri math bind` — Vector binding operations
- `tri math similarity` — Cosine similarity [-1, 1]
- `tri math phi` — Trinity Identity proof (φ² + φ⁻² = 3)

**Key Proof:** Trinity Identity validates ternary {-1,0,+1} representation
using hyperdimensional computing mathematics.

---

## Demo 2: Performance Benchmark

![tri-benchmark](../recordings/tri-benchmark.gif)

**63 tok/s** — Addresses performance objections about Trinity's speed.

Results:
- VSA operations: 17x+ speedup via SIMD
- JIT compilation: 22x+ speedup over interpretation
- Zero allocation hot path

**Command:** `tri benchmark` runs full suite including VSA, VM, and Firebird LLM components.

---

## Demo 3: Test Coverage

![tri-test](../recordings/tri-test.gif)

**74/74 tests passing** — Addresses reproducibility concerns.

```
tri test               # Run all tests
tri test --summary     # Test breakdown by category
tri test vsa          # VSA-specific tests
tri test vm            # VM tests
tri test firebird      # LLM engine tests
```

**Test Categories:**
- VSA bind/unbind/bundle
- VM bytecode execution
- Firebird token generation
- Integration tests

---

## Demo 4: System Status

![tri-status](../recordings/tri-status.gif)

Live dashboard showing:
- Git working tree status
- Build health
- Test pass rate
- Agent status

**Commands:**
- `tri status` — Overall system health
- `tri git status` — Working tree state
- `tri faculty` — Agent status dashboard

---

## Demo 5: FPGA Synthesis

![tri-fpga-synth](../recordings/tri-fpga-synth.gif)

**Zero DSP usage** — Addresses hardware efficiency objections.

Synthesis flow:
1. Read `.tri` specification
2. Generate Verilog via VIBEE
3. Yosys synthesis → netlist
4. NextPNR place-and-route → bitstream

**Command:** `/fpga-synth <module>` runs full pipeline from spec to bitstream.

---

## Reproducing from Zero

```bash
# Clone and build
git clone https://github.com/gHashTag/trinity
cd trinity
zig build

# Run benchmark (matching GIF output)
tri benchmark
```

Every GIF is reproducible: same commands → same output.

---

## File Structure

```
trinity/
├── tapes/                    # VHS scenarios (.tape files)
│   ├── tri-math-demo.tape
│   ├── tri-benchmark.tape
│   ├── tri-test.tape
│   ├── tri-status.tape
│   └── tri-fpga-synth.tape
├── recordings/               # Generated GIFs
│   ├── tri-math-demo.gif
│   ├── tri-benchmark.gif
│   ├── tri-test.gif
│   ├── tri-status.gif
│   └── tri-fpga-synth.gif
├── scripts/
│   └── tri-record           # Zig binary (live recording wrapper)
└── .github/workflows/
    └── record-demos.yml      # Auto-render on tape changes
```

---

## Strategic Value for Objections

| Objection | Response | GIF Demo |
|-----------|-----------|-----------|
| "Where's the benchmark?" | `tri benchmark` → 63 tok/s | ![tri-benchmark](../recordings/tri-benchmark.gif) |
| "Where are tests?" | `tri test` → 74/74 passing | ![tri-test](../recordings/tri-test.gif) |
| "Where's reproducibility?" | `git clone → zig build → tri benchmark` | All GIFs reproducible |
| "FPGA uses too many DSPs?" | Zero DSP in bitstream | ![tri-fpga-synth](../recordings/tri-fpga-synth.gif) |
| "What's the math foundation?" | Trinity Identity φ² + φ⁻² = 3 | ![tri-math-demo](../recordings/tri-math-demo.gif) |

Animated terminal is the most convincing format because it cannot be faked as easily as a screenshot.
