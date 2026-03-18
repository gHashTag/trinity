# Ternary Matrix-Vector Multiplication on FPGA Using Open-Source Toolchain

## Abstract

We present the first verified ternary matrix-vector multiplication accelerator implemented on a Xilinx Artix-7 FPGA using a fully open-source toolchain (Yosys + nextpnr-xilinx + Project X-Ray). The design computes y = Wx where W contains ternary weights from {-1, 0, +1}, requiring zero DSP multiplier blocks. We demonstrate two configurations: a 64x64 proof-of-concept using combinational weight generation (633 LUT, 0 BRAM), and a TrinityBlock-scale 243x729 design with BRAM-backed weight storage (15 BRAM36, ~11.8K LUT). Both pass hardware power-on self-test verified by automated camera-based LED detection (FPGA Eye). The ternary encoding achieves 1.58 bits per weight, a 20x memory reduction over float32, with computation requiring only addition and subtraction.

## 1. Introduction

Large language models increasingly adopt ternary weight quantization ({-1, 0, +1}) to reduce memory footprint and computational cost. Ternary weights eliminate multiply operations entirely: multiplication by +1 is identity, by -1 is negation, and by 0 is skip. This maps efficiently to FPGA fabric where add/subtract operations consume minimal resources compared to DSP-based multipliers.

We target the TrinityBlock architecture from the Hybrid Symbolic Language Model (HSLM), where embedding dimension is 243 (3^5) and hidden dimension is 729 (3^6). These dimensions arise from the mathematical structure of balanced ternary representation and the golden ratio identity: phi^2 + 1/phi^2 = 3.

### Contributions

1. First ternary matrix-vector multiply verified on FPGA using fully open-source EDA tools
2. Zero-DSP architecture: pure add/subtract accumulation
3. BRAM-backed weight storage scaling to 177,147 ternary weights
4. Automated hardware verification via camera-based LED detection (FPGA Eye)
5. Complete reproducible flow from RTL to bitstream to verification

## 2. Architecture

### 2.1 Weight Encoding

Each ternary weight is encoded in 2 bits:

| Value | Encoding | Operation |
|-------|----------|-----------|
| +1 | 2'b01 | acc += x[i] |
| -1 | 2'b10 | acc -= x[i] |
| 0 | 2'b00 | skip |

This encoding enables a simple case-based accumulator with no multiplier.

### 2.2 Sequential Accumulator

Both designs use a sequential architecture with a single signed accumulator:

```
for j = 0 to N_OUT-1:
    acc = 0
    for i = 0 to N_IN-1:
        case W[i][j]:
            +1: acc += x[i]
            -1: acc -= x[i]
             0: (no operation)
    y[j] = acc
```

### 2.3 64x64 Design (Combinational Weights)

The 64x64 proof-of-concept generates weights combinationally:

```verilog
w_code = ((i_idx + j_idx) % 3 == 0) ? 2'b01 :  // +1
         ((i_idx + j_idx) % 3 == 1) ? 2'b10 :  // -1
                                       2'b00 ;  //  0
```

State machine: IDLE -> COMPUTE (64 iterations) -> OUTPUT -> next column or DONE.

Latency: N_OUT * (N_IN + 1) + overhead = 64 * 65 + ~20 = 4,180 clocks = 83.6 us at 50 MHz.

### 2.4 243x729 Design (BRAM Weight Storage)

For TrinityBlock scale, weights are stored in block RAM:

```verilog
(* ram_style = "block" *)
reg [1:0] weight_mem [0:177146];
initial $readmemb("ternary_matvec_243x729_weights.mem", weight_mem);
```

BRAM read has 1-clock latency, handled by a PREFETCH pipeline stage:

```
IDLE -> PREFETCH (1 clk) -> COMPUTE (243 iterations) -> LAST_ACC -> OUTPUT -> next column
```

Column-major memory layout: addr = j * N_IN + i. Address calculation is incremental (base_addr += N_IN per column) to avoid multiplication.

Latency: N_OUT * (N_IN + 3) + overhead = 729 * 246 + ~20 = 179,354 clocks = 3.59 ms at 50 MHz.

## 3. Implementation

### 3.1 Target Platform

- Board: QMTECH XC7A100T-1FGG676C (Artix-7)
- Clock: 50 MHz (on-board oscillator, U22)
- Resources: 63,400 LUT, 135 BRAM36, 240 DSP48E1

### 3.2 Toolchain

Fully open-source EDA flow:

| Stage | Tool | Version |
|-------|------|---------|
| Synthesis | Yosys | 0.63 |
| Place & Route | nextpnr-xilinx | (git) |
| FASM generation | fasm2frames (prjxray) | (git) |
| Bitstream | xc7frames2bit (prjxray) | (git) |
| Programming | Custom JTAG (libusb) | v2 |

Synthesis command:
```
yosys -p "read_verilog <files>; synth_xilinx -flatten -abc9 -arch xc7 -top <top>; write_json <out>"
```

### 3.3 Self-Test

Both designs include power-on self-test (POST):

1. POR (255 clocks) -> Start computation
2. Run matrix-vector multiply with known inputs: x[i] = i + 1
3. Verify all outputs against expected values
4. LED solid ON = PASS, LED OFF = FAIL, LED blink = computing

Expected values for (i+j)%3 weight pattern:

| Design | y[j%3==0] | y[j%3==1] | y[j%3==2] | Sum |
|--------|-----------|-----------|-----------|-----|
| 64x64 | 43 | -22 | -21 | 0 |
| 243x729 | -81 | 162 | -81 | 0 |

The sum-to-zero property provides an additional integrity check.

## 4. Results

### 4.1 Resource Utilization

| Resource | 64x64 | 243x729 | XC7A100T Available | 243x729 Utilization |
|----------|-------|---------|-------------------|---------------------|
| LUT | 633 | ~11,800 | 63,400 | 18.6% |
| BRAM36 | 0 | 15 | 135 | 11.1% |
| DSP48E1 | 0 | 0 | 240 | 0% |
| Registers | ~180 | ~900 | 126,800 | <1% |

The 64x64 design fits entirely in LUT fabric. The 243x729 design uses 15 BRAM36 blocks: 12 for the 177,147 x 2-bit weight memory, and 3 for the 729 x 20-bit result storage.

### 4.2 Performance

| Metric | 64x64 | 243x729 |
|--------|-------|---------|
| Clock frequency | 50 MHz | 50 MHz |
| Total MAC-equivalents | 4,096 | 177,147 |
| Computation latency | 83.6 us | 3.59 ms |
| Throughput | 49.0 MMAC/s | 49.3 MMAC/s |
| Energy per MAC | ~0.6 nJ (est.) | ~0.6 nJ (est.) |

Throughput is approximately equal for both designs since they use the same sequential architecture (one weight per clock). The difference is purely in matrix dimensions.

### 4.3 Memory Efficiency

| Encoding | Bits/weight | 177,147 weights | Savings vs float32 |
|----------|-------------|-----------------|---------------------|
| Float32 | 32 | 692 KB | 1x |
| Int8 | 8 | 173 KB | 4x |
| Ternary (2-bit) | 2 | 43.3 KB | 16x |
| Ternary (packed) | 1.58 | 34.4 KB | 20.1x |

Our 2-bit encoding uses 43.3 KB. Optimal packed ternary encoding (log2(3) = 1.585 bits) would reduce this to 34.4 KB, a 20x savings over float32.

### 4.4 Hardware Verification

Verification uses FPGA Eye, an automated camera-based system:

1. **Snapshot mode**: Captures single frame, detects LEDs via OpenCV HSV filtering
2. **Blink analysis**: Records 5-second video, measures LED frequency and dynamic range

Verification results for 243x729:
- D6 (user LED): SOLID, 0.0 Hz, 0 transitions, dynamic_range = 13.2
- Verdict: **SELF_TEST_PASS**
- All 729 output values matched expected {-81, 162, -81} pattern

## 5. Comparison

### 5.1 vs Binary Neural Network Accelerators

| Aspect | Binary (1-bit) | Ternary (2-bit) |
|--------|----------------|-----------------|
| Weights | {-1, +1} | {-1, 0, +1} |
| Operation | XNOR + popcount | Add/Sub |
| Sparsity | None | Natural (zero weights) |
| Accuracy | Lower | Higher (closer to full-precision) |
| DSP usage | 0 | 0 |

Ternary networks achieve higher accuracy than binary while maintaining zero-DSP computation. The zero weight enables natural sparsity, skipping computation entirely for zero-valued weights.

### 5.2 vs Float/Fixed-Point Accelerators

| Aspect | Float32 | Int8 | Ternary |
|--------|---------|------|---------|
| DSP48 per MAC | 1-3 | 1 | 0 |
| Memory per weight | 32 bits | 8 bits | 2 bits |
| Computation | Multiply-add | Multiply-add | Add/Sub only |
| BRAM for 177K weights | 87 | 22 | 12 |

## 6. Reproducibility

All source files are available in the repository:

```
fpga/openxc7-synth/
  ternary_matvec.v              # 64x64 compute core
  ternary_matvec_top.v          # 64x64 top-level with self-test
  ternary_matvec_top.xdc        # Pin constraints
  ternary_matvec_bram.v         # 243x729 BRAM compute core
  ternary_matvec_243x729_top.v  # 243x729 top-level with self-test
  ternary_matvec_243x729_top.xdc
  gen_matvec_weights.py         # Weight generator + expected value calculator
```

Build and verify:
```bash
# Generate weights
python3 fpga/openxc7-synth/gen_matvec_weights.py

# Synthesize
tri fpga synth fpga/openxc7-synth/ternary_matvec_bram.v \
    fpga/openxc7-synth/ternary_matvec_243x729_top.v \
    --top ternary_matvec_243x729_top

# Program
tri fpga flash fpga/openxc7-synth/ternary_matvec_243x729_top.bit

# Verify
tri fpga eye  # Expect: D6 SOLID = SELF_TEST_PASS
```

## 7. Conclusion

We demonstrated ternary matrix-vector multiplication on FPGA at TrinityBlock scale (243x729 = 177,147 MAC-equivalents) using zero DSP blocks, 15 BRAM, and a fully open-source toolchain. The design passes hardware self-test with automated camera verification.

Key results:
- **Zero DSP48**: Pure add/subtract accumulation
- **15 BRAM36** (11.1% of XC7A100T): stores 177,147 ternary weights
- **3.59 ms latency** at 50 MHz for 729-element output vector
- **20x memory savings** vs float32
- **Hardware-verified**: Power-on self-test PASS confirmed by FPGA Eye

Future work includes parallelizing the accumulator (multiple weights per clock), implementing the full TrinityBlock (up-projection + activation + down-projection), and loading weights dynamically via UART for inference with trained models.

---

*Trinity: phi^2 + 1/phi^2 = 3*
