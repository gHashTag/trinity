# Regression cases for nextpnr-xilinx

Written 2026-08-10, after `hansfbaier` merged `openXC7/nextpnr-xilinx#111` with:

> "I merged this. I am actually thinking about making a regression test suite for
> nextpnr-xilinx and your example above would be a nice start."

This is that start, in the shape `openXC7/demo-projects` already uses — one directory per
case, a `Makefile` carrying `FAMILY`/`PART`/`BOARD`/`PROJECT` and including `../openXC7.mk`,
the source and the constraints beside it.

## What a regression case owes over a demo project

A demo project passes when it builds. That is too weak here: a test can keep building long
after it stops testing anything.

`regress-fabric-bufg` exists because a global buffer driven from **fabric** used to abort
placement. It works only while Yosys' `clkbufmap` still promotes the flip-flop divider to a
`BUFG`. If a future Yosys stops doing that, the project still places, still writes FASM, and
still goes green — while exercising nothing.

So each case ships a `check.py` that **asserts its own premise before its result**:

```
ok    2 BUFG cells: $auto$clkbufmap.cc:261:execute$2539, ...:execute$2541
ok    FASM written, 35297 bytes
pass
```

Lose the premise and it fails loudly, with an explanation of why relaxing the check is the
wrong repair:

```
FAIL  expected 2 BUFG cells, found 1
      Yosys' clkbufmap must promote BOTH the IBUFDS output and the flip-flop
      divider. If it promotes only one, this test is inert and the design needs
      revisiting -- do not just relax this check.
```

## Cases

| Directory | Pins | Fails before | Symptom it guards |
|---|---|---|---|
| `regress-fabric-bufg` | R4 / T4 / B13, `xc7a200tfbg484-2` | [#111](https://github.com/openXC7/nextpnr-xilinx/pull/111) | `ERROR: Unable to find legal placement for cell '$auto$clkbufmap.cc:261:execute$…'` |

The design is two global buffers whose only difference is how they are driven: one from an
`IBUFDS` on a clock-capable pin, which `try_preplace()` always handled "based on dedicated
routing"; one from a flip-flop, which had no dedicated path and used to abort instead of
falling back.

## What is verified here, and what is not

**Verified on this machine, 2026-08-10.** Synthesis runs and yields exactly two `BUFG`
cells, one of them `$auto$clkbufmap.cc:261:execute$2539` — the same cell named in the
pre-patch error. `check.py` was exercised in three directions: the real netlist passes, a
missing FASM fails with the placement message, and a doctored one-BUFG netlist fails on the
premise.

**Not verified: placement.** `nextpnr-xilinx` is now built here (`ARCH=xilinx`), but chipdb
generation for `xc7a200t` has not finished, so the `--fasm` half of the check has still never
run against a real place-and-route. The outcomes in the table come from the PR's own
measurements, not from a run here.

Anyone adopting this should run it once on base and once on the merged tree and confirm it
**fails then passes**. A regression test nobody has seen fail is not yet a regression test —
it is a build that happens to succeed.

## Running it costs more than the test does — measured 2026-08-10

Anyone adopting this needs to know that the expensive part is not the case, it is getting a
place-and-route at all. On a 16 GB Apple-silicon Mac, from a clean clone:

| Step | Cost |
|---|---|
| `git submodule xilinx/external/prjxray-db` | **813 MB** |
| `git submodule xilinx/external/nextpnr-xilinx-meta` | 24 MB — separate, and `bbaexport.py` dies with a bare `FileNotFoundError` on `wire_intents.json` without it |
| `cmake -DARCH=xilinx` + `make -j6` | a few minutes; needs **`-DUSE_OPENMP=OFF`**, because `CMAKE_CXX_FLAGS_RELEASE` hardcodes `-fopenmp` and Apple clang rejects it |
| `bbaexport.py --device xc7a200tfbg484-2` | **tens of minutes**, ~0.7 GB resident, `.bba` past 350 MB and still growing. No `pypy3` here, which the upstream Makefile prefers |
| `bbasm -l` | fails with `Assertion failed: (streamStack.empty())` if the `.bba` is truncated — that assertion is what a killed export looks like, not a corrupt database |

**So the check that matters is also the one that is hardest to run**, and that asymmetry is
worth stating plainly rather than hiding behind a green build. A CI job that skips
place-and-route is testing the premise only.

`check.py` splits along exactly that line on purpose: the premise check needs `yosys` alone
and runs in seconds, while `--fasm` needs the whole chipdb pipeline. A cheap job can assert
the case is still live; an expensive one asserts it still passes.

## Adding a case

One directory, named for the symptom rather than the patch — patch numbers stop meaning
anything once they merge. Keep the design minimal: every extra cell is another thing a
failure could be blamed on. Give `check.py` an assertion that the case is still live, not
only that the build finished.
