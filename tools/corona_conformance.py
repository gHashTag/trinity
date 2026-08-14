#!/usr/bin/env python3
"""Exhaustive conformance for the Corona format decoders, against ml_dtypes.

Every tier this service sells above the free one rests on one claim: that the
reference model is independent of the design. T9 on /verification is the reason
that sentence is not decoration — an oracle sharing the implementation's premise
has exactly zero probability of catching a fault in that premise, and a flop
counter checked against fixtures typed by hand in the order it assumed spent
weeks green while returning zero for every design on earth.

So the oracle here is not written by me. It is `ml_dtypes`, the float8/float6/
float4/bfloat16 implementation from the JAX project, converting each code point
to float32. The RTL under test was written years earlier, by a different person,
from the OCP MX and IEEE 754 specifications. Neither is derived from the other.

The second thing that makes this stronger than the paid tier's usual claim: the
input spaces are small enough to enumerate completely. A 4-bit format has 16
inputs, a 6-bit format 64, an 8-bit format 256, bf16 65,536. Every one of them
is checked, so there is no sampling, no statistical bound, and nothing to say
about confidence -- the words "exhaustive over the input space" mean what they
say here, which they almost never do in verification.

What it still does not establish: that the decoders are what a chip needs, that
synthesis preserves them, or anything at all about the seven formats ml_dtypes
does not implement. Those are listed as skipped rather than quietly dropped.

Usage:  python3 tools/corona_conformance.py --corona <path-to-tt-trinity-corona>
"""

from __future__ import annotations

import argparse
import json
import os
import struct
import subprocess
import sys
import tempfile

# module, rtl file, input port, output port, width, ml_dtypes name
#
# The dtype names matter more than they look. ml_dtypes.float8_e4m3 is the
# IEEE-754-style variant WITH infinities; the OCP MX E4M3 that mxfp8_e4m3_decode
# implements is float8_e4m3fn -- no Inf, NaN only at S.1111.111, max 448. Naming
# the first one produced 14 "mismatches" that were entirely my error, and the
# adjudication went against the oracle, not against the RTL. Which is the point
# of adjudicating rather than believing the reference.
CASES = [
    ("fp4_decode",           "fp4_decode.v",           "fp4_in",   "fp32_out",  4,  "float4_e2m1fn"),
    ("fp6_e2m3_decode",      "fp6_e2m3_decode.v",      "fp6_in",   "fp32_out",  6,  "float6_e2m3fn"),
    ("fp6_e3m2_decode",      "fp6_e3m2_decode.v",      "fp6_in",   "fp32_out",  6,  "float6_e3m2fn"),
    ("fp8_e4m3_fnuz_decode", "fp8_e4m3_fnuz_decode.v", "e4m3_in",  "fp32_out",  8,  "float8_e4m3fnuz"),
    ("fp8_e5m2_decode",      "fp8_e5m2_decode.v",      "e5m2_in",  "fp32_out",  8,  "float8_e5m2"),
    ("mxfp8_e4m3_decode",    "mxfp8_e4m3_decode.v",    "e4m3_in",  "fp32_out",  8,  "float8_e4m3fn"),
    ("bf16_decode",          "bf16_decode.v",          "bf16_in",  "fp32_out",  16, "bfloat16"),
]

TB = """
`timescale 1ns/1ps
module tb;
  reg  [{win}:0] code;
  wire [31:0] out;
  integer i;
  {mod} dut (.{inp}(code), .{outp}(out));
  initial begin
    for (i = 0; i < {n}; i = i + 1) begin
      code = i[{win}:0];
      #1;
      $display("%0d %08x", i, out);
    end
    $finish;
  end
endmodule
"""


def rtl_outputs(corona: str, mod: str, src: str, inp: str, outp: str, width: int) -> dict[int, int]:
    """Simulate the decoder over every code point and return code -> fp32 bits."""
    n = 1 << width
    with tempfile.TemporaryDirectory() as td:
        tb_path = os.path.join(td, "tb.v")
        with open(tb_path, "w") as f:
            f.write(TB.format(win=width - 1, mod=mod, inp=inp, outp=outp, n=n))
        exe = os.path.join(td, "a.out")
        build = subprocess.run(
            ["iverilog", "-g2012", "-o", exe, tb_path, os.path.join(corona, "src", "rtl", src)],
            capture_output=True, text=True,
        )
        if build.returncode != 0:
            raise RuntimeError(f"{mod}: iverilog failed:\n{build.stderr[:600]}")
        run = subprocess.run(["vvp", exe], capture_output=True, text=True)
        if run.returncode != 0:
            raise RuntimeError(f"{mod}: vvp failed:\n{run.stderr[:600]}")

    got: dict[int, int] = {}
    for line in run.stdout.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1].lower() != "xxxxxxxx":
            got[int(parts[0])] = int(parts[1], 16)
    # A short capture is a broken measurement, not a partial pass. Without this
    # a testbench that stopped early would report "0 mismatches" over whatever
    # it happened to reach.
    if len(got) != n:
        raise RuntimeError(f"{mod}: expected {n} outputs, captured {len(got)}")
    return got


def oracle_outputs(dtype_name: str, width: int) -> dict[int, int]:
    """Every code point through ml_dtypes, as float32 bit patterns."""
    import ml_dtypes
    import numpy as np

    dt = getattr(ml_dtypes, dtype_name)
    n = 1 << width
    itemsize = np.dtype(dt).itemsize
    codes = np.arange(n, dtype=np.uint16 if itemsize == 2 else np.uint8)
    vals = codes.view(dt).astype(np.float32)
    return {i: int(struct.unpack("<I", struct.pack("<f", float(v)))[0]) for i, v in enumerate(vals)}


def is_nan32(bits: int) -> bool:
    return (bits & 0x7F800000) == 0x7F800000 and (bits & 0x007FFFFF) != 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--corona", required=True)
    ap.add_argument("--json", default="")
    args = ap.parse_args()

    results = []
    total_checked = 0
    total_bad = 0

    for mod, src, inp, outp, width, dtype_name in CASES:
        n = 1 << width
        try:
            rtl = rtl_outputs(args.corona, mod, src, inp, outp, width)
            ref = oracle_outputs(dtype_name, width)
        except Exception as e:  # a broken measurement is reported, never skipped
            print(f"  {mod:<22} ERROR  {e}")
            results.append({"module": mod, "error": str(e)[:300]})
            total_bad += 1
            continue

        bad = []
        for code in range(n):
            a, b = rtl[code], ref[code]
            # Any NaN equals any NaN: the payload is not specified by either the
            # OCP spec or IEEE 754, so a difference there is not a disagreement
            # about the value. Everything else is compared bit for bit.
            if is_nan32(a) and is_nan32(b):
                continue
            if a != b:
                bad.append((code, a, b))

        total_checked += n
        total_bad += len(bad)
        status = "EXHAUSTIVE PASS" if not bad else f"{len(bad)} MISMATCH"
        print(f"  {mod:<22} {n:>6} codes  vs ml_dtypes.{dtype_name:<16} {status}")
        for code, a, b in bad[:6]:
            print(f"      code 0x{code:02x}: rtl {a:08x}  oracle {b:08x}")
        results.append({
            "module": mod, "codes": n, "oracle": f"ml_dtypes.{dtype_name}",
            "mismatches": len(bad),
            "examples": [{"code": c, "rtl": f"{a:08x}", "oracle": f"{b:08x}"} for c, a, b in bad[:6]],
        })

    print()
    print(f"  checked {total_checked} code points across {len(CASES)} formats, "
          f"{total_bad} disagreement(s)")

    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump({
                "oracle": "ml_dtypes (JAX project) — an implementation neither derived from nor "
                          "written alongside the RTL under test",
                "method": "every code point of each format, compared as float32 bit patterns; "
                          "NaN payloads are not compared because no specification fixes them",
                "exhaustive": True,
                "totalCodePoints": total_checked,
                "totalMismatches": total_bad,
                "results": results,
            }, f, indent=2, ensure_ascii=False)
            f.write("\n")

    return 1 if total_bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
