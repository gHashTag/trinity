# GF-T multiplier — width-corrected and pipelined

Measured 8 August 2026. Reference: `trinity-fpga/build/gft_mul8/gft_mul.v`, the
hand-transcribed realization of `specs/tri_gft_arith.t27`.

## Measured, post-route on XC7A200T (nextpnr-xilinx, hard multipliers off)

| Variant | LUTs | DSP48 (if allowed) | Fmax | Latency |
|---|---|---|---|---|
| `gft_mul` — 32-bit ports, as written | 1,179 | 3 | 81 MHz | 0 |
| `gft_mul_w` — widths the values need | **219** | 1 | **81.35 MHz** | 0 |
| `gft_mul_wp` — the same, two stages | **219** | 1 | **147.32 MHz** | 1 cycle |

For context: ALTFP_MUL on a Cyclone IV publishes 119–132 MHz at 6–10 cycles of
latency, with 832–1041 logic elements and 18 embedded multipliers.

## The finding

Every port in the original is declared 32 bits wide. Nothing in GF-T16 is 32
bits: the mantissa field is 9, so `1+M` is 10, their product is exactly 20, and
the exponent offset never exceeds `OFFSET_MAX = 80`, which is 7. Synthesis built
a 32×32 multiplier and a 32-bit compare tree and charged full price — **1,179
LUTs, or three DSP48 blocks**.

Nothing about the arithmetic changes in `gft_mul_w`. Only the buses are the size
of the values they carry, and the constant divides by powers of two become the bit
selects they always were.

## Equivalence, proven rather than assumed

```bash
iverilog -g2012 -o tb.vvp tb_gft_equiv.v gft_mul_w.v gft_mul.v && vvp tb.vvp
# compared 321156 input combinations, 0 mismatches → EQUIVALENT

iverilog -g2012 -o p.vvp tb_pipe_equiv.v gft_mul_wp.v gft_mul_w.v && vvp p.vvp
# compared 199994 cycles, 0 mismatches → EQUIVALENT
```

`tb_gft_equiv.v` sweeps the mantissa space in full at offset pairs that exercise
underflow, the middle and saturation, then sweeps the offsets in full at
mantissas that do and do not carry — every path through the carry, the saturation
and the underflow clamp.

## Where the pipeline cut is

Between the product and the renormalisation. Those are the two natural halves: a
10×10 multiply, then a carry test, an exponent add with saturation, and a bit
select. One register between them nearly doubles the frequency for one cycle of
latency.
