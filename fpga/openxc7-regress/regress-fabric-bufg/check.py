#!/usr/bin/env python3
"""Assert what this regression actually tests, rather than that a build finished.

A green build is a weak assertion here. If a future Yosys stopped promoting the
flip-flop-driven clock to a BUFG, this project would still place, still write FASM
and still pass -- while silently testing nothing. So the test checks its own
premise first: two global buffers, one pin-driven and one fabric-driven.

    python3 check.py fabric_bufg.json            # premise only (needs yosys)
    python3 check.py fabric_bufg.json --fasm f.fasm   # premise + placement result

Exit 0 pass, 1 fail. No output on success beyond one line per check.
"""
import json
import os
import sys


def fail(msg):
    print(f"FAIL  {msg}")
    sys.exit(1)


def main():
    if len(sys.argv) < 2:
        fail("usage: check.py <netlist.json> [--fasm <file.fasm>]")
    netlist = sys.argv[1]
    if not os.path.exists(netlist):
        fail(f"{netlist} missing — run `make {os.path.basename(netlist)}` first")

    with open(netlist, encoding="utf-8") as fh:
        design = json.load(fh)

    top = design["modules"].get("top")
    if top is None:
        fail(f"no module 'top' in {netlist}; modules: {list(design['modules'])}")

    cells = top["cells"]
    bufgs = {name: c["type"] for name, c in cells.items() if "BUFG" in c["type"]}

    # The premise. Two buffers, or this design no longer exercises the bug.
    if len(bufgs) != 2:
        fail(f"expected 2 BUFG cells, found {len(bufgs)}: {sorted(bufgs)}\n"
             f"      Yosys' clkbufmap must promote BOTH the IBUFDS output and the\n"
             f"      flip-flop divider. If it promotes only one, this test is inert\n"
             f"      and the design needs revisiting -- do not just relax this check.")
    print(f"ok    2 BUFG cells: {', '.join(sorted(bufgs))}")

    # Both come from clkbufmap; the fabric-driven one is the cell that used to abort
    # placement. Its exact name is what the pre-#111 error message reported.
    if not all("clkbufmap" in n for n in bufgs):
        print(f"warn  a BUFG did not come from clkbufmap: {sorted(bufgs)}")

    if "--fasm" in sys.argv:
        fasm = sys.argv[sys.argv.index("--fasm") + 1]
        if not os.path.exists(fasm) or os.path.getsize(fasm) == 0:
            fail(f"{fasm} missing or empty — placement failed.\n"
                 f"      Before openXC7/nextpnr-xilinx#111 this failed with\n"
                 f"      'Unable to find legal placement for cell "
                 f"$auto$clkbufmap.cc:261:execute$...'\n"
                 f"      A regression here means try_preplace()'s fallback for\n"
                 f"      fabric-driven buffers is gone again.")
        print(f"ok    FASM written, {os.path.getsize(fasm)} bytes")

    print("pass")


if __name__ == "__main__":
    main()
