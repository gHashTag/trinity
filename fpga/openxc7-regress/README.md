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

## STATUS: this case does not currently reproduce the failure — 2026-08-10

**Measured, not assumed.** `nextpnr-xilinx` was built here from `e86f351` (the #115 merge,
which predates #111 — `git diff` confirms `pack_clocking_xc7.cc` carries none of the #111
fallback), a 318 MB `xc7a200t` chipdb was generated, and the case was run:

```
nextpnr-BASE --chipdb xc7a200t.bin --xdc fabric_bufg.xdc --json fab.json \
             --fasm fab-base.fasm --freq 100 --seed 1
→ exit 0, FASM written, 34788 bytes
```

**It placed.** On a binary that provably lacks the patch. So as written this case guards
nothing, and calling it a regression test would be wrong.

### What is and is not explained

- The premise still holds: synthesis yields exactly two `BUFG` cells, one of them
  `$auto$clkbufmap.cc:261:execute$2539` — the cell the original error named.
- `pack_clocking_xc7.cc` is **byte-identical** between `f8e7643` (the base the PR measured
  against) and the build used here. The xc7 clocking path did not change, so an intervening
  merge is not the explanation.
- `#110` raised a clock-buffer preplace cap, but in `pack_clocking_xcup.cc` — UltraScale+,
  not xc7. It cannot be the cause.
- What *did* change between `f8e7643` and here: `xilinx/external/prjxray-db` was bumped, and
  `xdc.cc` gained 52 lines from #109. **A different prjxray-db yields a different chipdb and
  a different set of legal BELs**, which is the leading candidate and is untested.

### Before this is offered to anyone

Build at `f8e7643` with the prjxray-db submodule *that commit pins*, regenerate the chipdb
from it, and confirm the case fails there. If it does, the case is valid and needs its
prjxray-db version pinned alongside the part. If it does not, the reproduction in the PR
depended on something not captured here and the case must be rebuilt from whatever that was.

**A regression test nobody has seen fail is not a regression test.** This one has now been
seen *not* to fail, which is worse — it would have gone green forever while guarding nothing.

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
