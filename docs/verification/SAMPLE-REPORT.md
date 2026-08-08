# Hardware Verification Report — SAMPLE

> **This is a sample report.** It documents a real design from my own work (the GF16 4×4
> matrix multiplier), measured on real hardware, and is published so prospective clients can
> see exactly what they receive before commissioning a run. It is not client work, and no
> third-party design is described here.

---

**Design under test:** GF16 4×4 matrix multiplier (`gf16_matmul`)
**Client:** — (sample / own design)
**Report ID:** SAMPLE-001
**Engineer:** Dmitrii Vasilev · admin@t27.ai · github.com/gHashTag
**Target device:** Xilinx Artix-7 `XC7A200T` (ALINX AX7203 board)
**Date:** 2026-08-08

---

## 1. Summary

| Check | Result |
|---|---|
| Functional conformance (bit-exact vs independent model) | **PASS** — all KAT vectors match |
| Latch-free (no inferred latches) | **PASS** — 0 latches |
| Hard-multiplier independence | **PASS** — 0 DSP48, by fabric mapping |
| Place and route on the target device | **PASS** |
| Timing | **not applicable** — this block is combinational |

**Verdict:** the design meets its specification bit-exactly and implements on the target device
without hard multipliers.

> **On the missing frequency.** This particular block holds no registers, so it has no clock and
> no achieved-frequency figure can belong to it. An earlier version of this report quoted one; it
> was withdrawn on 8 August 2026 after re-checking the RTL. For a **sequential** design the report
> does carry achieved frequency from the router — see §5.2.

---

## 2. What was verified

The design computes a 4×4 matrix product in the GF16 number format. The correctness
criterion agreed for this run was:

> For every input vector in the test set, the hardware output must be **bit-identical** to the
> output of an independent reference model derived from the format specification — not from
> the RTL.

This distinction matters. A testbench written from the same source as the design will agree
with the design even when both are wrong. The reference model here was written separately
from the written specification, so a disagreement between them is evidence of a real defect
rather than a copied assumption.

---

## 3. Method

1. **Independent reference model.** A Python model implementing the GF16 arithmetic directly
   from the format specification. It shares no code with the RTL.
2. **Known-answer test (KAT) vectors.** Vectors generated per pipeline stage, covering
   ordinary values, zeros, boundary exponents and saturation cases.
3. **Simulation cross-check.** `iverilog` runs the RTL against every vector; outputs are
   compared bit-for-bit with the reference model. Any mismatch fails the run and is reported
   with the offending vector.
4. **Synthesis and place-and-route.** Fully open-source flow, no proprietary vendor tools.
5. **Hardware execution.** The bitstream is loaded onto a live board over JTAG and the same
   vectors are replayed on hardware; hardware output is compared against the reference model
   again.

Step 5 is the one most reports skip. Simulation agreement does not prove silicon agreement —
synthesis, place-and-route and timing are all opportunities for divergence.

---

## 4. Toolchain (all open-source, reproducible)

| Stage | Tool |
|---|---|
| Simulation | `iverilog` |
| Synthesis | `yosys` |
| Place & route | `nextpnr-xilinx` |
| Bitstream | `prjxray` |
| Programming | `openFPGALoader` |
| Reference model | Python 3 |

Host: macOS arm64. **No vendor licence is required to reproduce any number in this report** —
every step can be re-run by the client on their own machine.

---

## 5. Results

### 5.1 Functional conformance

| Stage | Vectors | Mismatches |
|---|---|---|
| Multiplier core | full KAT set | 0 |
| Accumulator | full KAT set | 0 |
| Full 4×4 matmul | full KAT set | 0 |
| **Hardware replay on XC7A200T** | full KAT set | **0** |

### 5.2 Timing

| Metric | Value |
|---|---|
| Achieved frequency | **not applicable** — combinational block, no clock domain |
| Inferred latches | **0** |

For a design that does contain registers, this section reports the router's achieved frequency
for each clock domain, with the critical path listed. A worked example on a sequential
multiply-accumulate unit came out at **112.33 MHz** post-route on this device, with the critical
path through the accumulator adder.

One caveat learned the hard way and passed on: `nextpnr-xilinx` produces no frequency at all for
designs that use DSP48 blocks — it has no timing model through the hard block, so the
register-to-register path is broken and the tool reports `No clocks found in design` rather than a
number. Where that happens, this report says so instead of quoting something the tool never
computed.

### 5.3 Resources

| Resource | Used |
|---|---|
| DSP48 blocks | **0** — with hard multipliers disabled |
| LUTs | **32,252** in that configuration; **21,223** if the 64 DSP blocks are allowed |
| Registers | **0** — the block is combinational |
| Device | fits comfortably within XC7A200T |

Zero DSP usage is a design property worth calling out: the arithmetic is carried entirely in
logic, which leaves the DSP columns free for the rest of the system and makes the core
portable to devices with few or no DSP blocks.

---

## 6. Observations and recommendations

- **Latch-free confirmed.** All sequential elements are explicit flip-flops; no accidental
  latch inference, which is a common source of silicon-only failures.
- **Portability.** Because the design uses no DSP primitives and no vendor-specific IP, it
  ports to other families with minimal effort. This was validated by taking the same source
  through to an ASIC process (SKY130, via Tiny Tapeout).
- **Verification hygiene.** The per-stage vectors mean that when a change breaks something,
  the failing stage is identified immediately rather than at the top level.

---

## 7. Artefacts delivered

A commissioned run includes:

- this report (Markdown + PDF)
- the reference model source
- the complete KAT vector set
- simulation and place-and-route logs
- the generated bitstream
- a `README` with the exact commands and tool versions to reproduce every number

---

## 8. Scope and limits (stated honestly)

- Device is a **Xilinx Artix-7 XC7A200T**; designs that do not fit, or that require
  transceivers/hard IP the board does not expose, cannot be measured here.
- Encrypted netlists and vendor-encrypted IP cannot be processed by an open-source flow.
- This is **functional and timing verification on one device**. It is not a substitute for
  full sign-off, DFT, or multi-corner characterisation.
- Where a result is estimated rather than measured, it is labelled as such. Nothing in a
  report of mine is presented as measured unless it was measured.

---

## 9. Reproduction

Every number above was produced by commands included with the delivery. The client can re-run
the entire flow independently — that is the point: the report is not asking to be believed,
it is showing its work.

---

*Prepared by Dmitrii Vasilev — creator of the GF-T ternary number format (arXiv:2606.05017),
author of a bit-exact conformance catalogue for 83 numeric formats (arXiv:2606.09686), and of
an open-source spec→RTL→silicon toolchain with a completed SKY130 tape-out.*
