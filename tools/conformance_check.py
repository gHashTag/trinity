#!/usr/bin/env python3
"""Exhaustive conformance for one decoder, against an implementation that is not yours.

The free tier is structural: it establishes that a design elaborates, infers no
latch, synthesises, and holds clocked logic. None of that says the design is
correct, and the page says so. This is the tier that does say something about
correctness, and it says it in the only form worth buying — every input, not a
sample.

Two properties do the work, and both are checkable rather than asserted:

  * The reference is `ml_dtypes`, from the JAX project. You did not write it, I
    did not write it, and it was not derived from the design under test. A model
    derived from the RTL agrees with the RTL including where it is wrong — that
    is not a worry but T9 on <https://t27.ai/#/verification>, and it has a
    measured example behind it.

  * The input space is enumerated. A 4-bit format has 16 code points, an 8-bit
    format 256, a 16-bit format 65,536. Every one is applied, so there is no
    sampling, no confidence level, and no bound: the disagreement count is over
    the whole format. That is T11, and it is available exactly because these
    spaces are small — one more bit doubles the work.

What it does not establish: anything about the design that instantiates the
decoder, about sequences of inputs, about synthesis preserving the behaviour, or
about formats ml_dtypes does not implement.

Usage:
  python3 tools/conformance_check.py \\
      --module fp8_e5m2_decode --sources src/rtl/fp8_e5m2_decode.v \\
      --input-port e5m2_in --output-port fp32_out \\
      --width 8 --reference float8_e5m2
"""

from __future__ import annotations

import argparse
import json
import os
import re
import struct
import subprocess
import sys
import tempfile

IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_$]{0,127}$")

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


def ident_or_die(name: str, what: str) -> str:
    """Module and port names are pasted into generated Verilog. Anything that is
    not an identifier is refused here rather than compiled."""
    if not IDENT.match(name):
        print(f"error: --{what} must be a Verilog identifier, got {name!r}", file=sys.stderr)
        raise SystemExit(2)
    return name


def rtl_outputs(mod: str, sources: list[str], inp: str, outp: str, width: int) -> dict[int, int]:
    n = 1 << width
    with tempfile.TemporaryDirectory() as td:
        tb_path = os.path.join(td, "tb.v")
        with open(tb_path, "w") as f:
            f.write(TB.format(win=width - 1, mod=mod, inp=inp, outp=outp, n=n))
        exe = os.path.join(td, "a.out")
        build = subprocess.run(["iverilog", "-g2012", "-o", exe, tb_path, *sources],
                               capture_output=True, text=True)
        if build.returncode != 0:
            raise RuntimeError(f"iverilog failed:\n{build.stderr[:900]}")
        run = subprocess.run(["vvp", exe], capture_output=True, text=True)
        if run.returncode != 0:
            raise RuntimeError(f"vvp failed:\n{run.stderr[:900]}")

    got: dict[int, int] = {}
    for line in run.stdout.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1].lower() != "xxxxxxxx":
            got[int(parts[0])] = int(parts[1], 16)
    # A short capture is a broken measurement, not a partial pass. Without this a
    # testbench that stopped early reports "0 disagreements" over whatever it
    # happened to reach, which is the most expensive kind of green there is.
    if len(got) != n:
        raise RuntimeError(f"expected {n} outputs from the simulation, captured {len(got)}")
    return got


def oracle_outputs(reference: str, width: int) -> dict[int, int]:
    import ml_dtypes
    import numpy as np

    if not hasattr(ml_dtypes, reference):
        avail = ", ".join(sorted(n for n in dir(ml_dtypes) if n.startswith(("float", "bfloat", "int"))))
        raise RuntimeError(f"ml_dtypes has no {reference!r}. Available: {avail}")
    dt = getattr(ml_dtypes, reference)
    n = 1 << width
    itemsize = np.dtype(dt).itemsize
    if itemsize * 8 < width:
        raise RuntimeError(f"{reference} is {itemsize * 8} bits wide, cannot cover a {width}-bit space")
    codes = np.arange(n, dtype=np.uint16 if itemsize == 2 else np.uint8)
    vals = codes.view(dt).astype(np.float32)
    return {i: int(struct.unpack("<I", struct.pack("<f", float(v)))[0]) for i, v in enumerate(vals)}


def describe(reference: str, width: int) -> str:
    """The dtype name is the easiest thing to get wrong, and getting it wrong
    manufactures disagreements that look like defects. ml_dtypes.float8_e4m3 is
    the IEEE-style variant with infinities; OCP MX E4M3 is float8_e4m3fn. That
    mistake produced fourteen phantom mismatches here once, so the reference is
    now described by enumeration and printed before any verdict."""
    import numpy as np

    ref = oracle_outputs(reference, width)
    vals = np.array([struct.unpack("<f", struct.pack("<I", v))[0] for v in ref.values()], dtype=np.float32)
    finite = vals[np.isfinite(vals)]
    nonzero = np.abs(finite[finite != 0])
    return (f"{reference}: max {finite.max():g}, min subnormal {nonzero.min():g}, "
            f"{int(np.isinf(vals).sum())} infinities, {int(np.isnan(vals).sum())} NaN")


def is_nan32(bits: int) -> bool:
    return (bits & 0x7F800000) == 0x7F800000 and (bits & 0x007FFFFF) != 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--module", required=True)
    ap.add_argument("--sources", required=True, help="space-separated Verilog sources")
    ap.add_argument("--input-port", required=True)
    ap.add_argument("--output-port", default="fp32_out")
    ap.add_argument("--width", type=int, required=True)
    ap.add_argument("--reference", required=True, help="an ml_dtypes name, e.g. float8_e5m2")
    ap.add_argument("--expect-mismatches", default="",
                    help="assert exactly this many disagreements. Used by the self-test: a "
                         "checker whose verdict is the only thing ever asserted can return the "
                         "same answer for every design on earth and stay green (T10).")
    ap.add_argument("--json", default="")
    args = ap.parse_args()

    mod = ident_or_die(args.module, "module")
    inp = ident_or_die(args.input_port, "input-port")
    outp = ident_or_die(args.output_port, "output-port")
    if not 1 <= args.width <= 20:
        print(f"error: --width must be between 1 and 20; {args.width} would enumerate "
              f"{1 << args.width} points", file=sys.stderr)
        return 2

    sources = [s for s in args.sources.split() if s]
    missing = [s for s in sources if not os.path.isfile(s)]
    if missing:
        print(f"error: sources not found: {' '.join(missing)}", file=sys.stderr)
        return 2

    n = 1 << args.width
    print(f"  reference   {describe(args.reference, args.width)}")
    print(f"  enumerating {n} code points of {mod}")

    rtl = rtl_outputs(mod, sources, inp, outp, args.width)
    ref = oracle_outputs(args.reference, args.width)

    bad = []
    for code in range(n):
        a, b = rtl[code], ref[code]
        # Any NaN equals any NaN: no specification fixes the payload, so a
        # difference there is not a disagreement about a value.
        if is_nan32(a) and is_nan32(b):
            continue
        if a != b:
            bad.append((code, a, b))

    print()
    if bad:
        print(f"  FAIL {len(bad)} of {n} code points disagree with ml_dtypes.{args.reference}")
        for code, a, b in bad[:12]:
            print(f"    code 0x{code:02x}: rtl {a:08x}  reference {b:08x}")
        if len(bad) > 12:
            print(f"    ... and {len(bad) - 12} more")
    else:
        print(f"  PASS all {n} code points agree with ml_dtypes.{args.reference}")
        print(f"       exhaustive over the input space, so this is a count and not a bound")

    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump({"module": mod, "codePoints": n, "reference": f"ml_dtypes.{args.reference}",
                       "mismatches": len(bad), "exhaustive": True,
                       "examples": [{"code": c, "rtl": f"{a:08x}", "reference": f"{b:08x}"}
                                    for c, a, b in bad[:12]]}, f, indent=2)
            f.write("\n")

    if args.expect_mismatches != "":
        want = int(args.expect_mismatches)
        if len(bad) != want:
            print(f"  FAIL asserted {want} disagreements, measured {len(bad)}")
            return 1
        print(f"  PASS disagreement count is {len(bad)}, as asserted")
        return 0

    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
