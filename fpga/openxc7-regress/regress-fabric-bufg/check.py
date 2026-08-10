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
import subprocess
import sys


def fail(msg):
    print(f"FAIL  {msg}")
    sys.exit(1)


# The commit this case was observed to fail at. Not decoration: at c8c4064 (#109) and
# everything after, the design places and this case cannot fail. Running it against a
# newer tree produces a pass that means nothing.
OBSERVED_AT = "f8e7643"


def check_base(nextpnr_dir):
    """Refuse to report a pass from a tree where the bug is unreachable."""
    try:
        r = subprocess.run(["git", "-C", nextpnr_dir, "merge-base", "--is-ancestor",
                            OBSERVED_AT, "HEAD"], capture_output=True)
    except Exception as exc:
        print(f"warn  could not check the base commit: {exc}")
        return
    head = subprocess.run(["git", "-C", nextpnr_dir, "rev-parse", "--short", "HEAD"],
                          capture_output=True, text=True).stdout.strip()
    if head.startswith(OBSERVED_AT):
        print(f"ok    nextpnr at {OBSERVED_AT} — the commit this case was observed to fail at")
    elif r.returncode == 0:
        fail(f"nextpnr is at {head}, which is AFTER {OBSERVED_AT}.\n"
             f"      #109 (set_multicycle_path, xdc.cc) lets the placer find the unplaced\n"
             f"      fabric-driven buffer a site unaided, so this case places and cannot\n"
             f"      fail. A pass here would mean nothing. Build at {OBSERVED_AT}.")


def main():
    if len(sys.argv) < 2:
        fail("usage: check.py <netlist.json> [--fasm <file.fasm>] [--nextpnr <dir>]")
    if "--nextpnr" in sys.argv:
        check_base(sys.argv[sys.argv.index("--nextpnr") + 1])
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
