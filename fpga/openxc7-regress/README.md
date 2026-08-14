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

## STATUS: the case is valid, but only against `f8e7643` — #109 masks the bug

**Reproduced, then bisected.** Four builds, same netlist, same 318 MB `xc7a200t` chipdb,
same `--freq 100 --seed 1`:

| Build | Result |
|---|---|
| `f8e7643` — the base the PR measured against | **`ERROR: Unable to find legal placement for cell '$auto$clkbufmap.cc:261:execute$2539'`**, no FASM |
| `c8c4064` — the **#109** merge | **places**, 34,788 B |
| `e86f351` — the #115 merge (still no #111) | places, 34,788 B |
| `e86f351` + #111 applied by hand | places, 35,318 B |

The error text and the cell name match the PR exactly. **So the case is real** — and it stops
being real one commit later.

### #109 masks the bug that #111 fixes

`#109` is *"support `set_multicycle_path -setup` (XDC parser + timing)"* and it touches
`xilinx/xdc.cc` (+52). `pack_clocking_xc7.cc` is byte-identical across all of these, so the
packing path never changed: `try_preplace` leaves the fabric-driven buffer unplaced at every
one of these commits. What changed is that after #109 the main placer **finds it a legal
`BUFGCTRL` site unaided**, and the abort never happens.

Two consequences, and the second is the one that matters for a suite:

1. On current `main` this reproduction cannot fail. A regression case built on it would go
   green on the day it was added and stay green forever, guarding nothing.
2. The `#111` fallback is still doing something — the FASM differs, 35,318 B against 34,788 —
   but on this design it only pre-assigns the site the placer would have chosen anyway.

**A regression case must be validated against the commit where the bug was observed, not
against `main`.** Had this been added to a suite without the bisect, it would have been a
permanent false pass — the worst kind, because a green test is never re-examined.

### Two hypotheses that were tested and failed first

Both looked strongest at the moment they were written, and both were cheap to check:

- **prjxray-db bump.** `f8e7643` pins `d429061`, later trees pin `399a099`. A second chipdb
  was generated from `d429061` and compared: **byte-identical**. The bump adds RIOB18 entries
  for kintex7 and virtex7 and cannot touch artix7.
- **`BUFGCTRL` contention.** Designs with 9 and 21 fabric-driven buffers (against 32 sites)
  both **placed** on a build without #111. The buffer count is not the condition.

## What this directory is, after all that

**A historical verification, not a guard on `main`.** `check.py --nextpnr <dir>` now refuses
to report a pass from any tree at or after `c8c4064`:

```
FAIL  nextpnr is at e86f351, which is AFTER f8e7643.
      #109 (set_multicycle_path, xdc.cc) lets the placer find the unplaced
      fabric-driven buffer a site unaided, so this case places and cannot
      fail. A pass here would mean nothing. Build at f8e7643.
```

At `f8e7643` it passes its premise and can be run to the failure. Anywhere newer it refuses
rather than going green — because the green would be the lie.

**A guard on `main` would need something this does not have.** The patch's effect there is
not directly observable: the post-place JSON `nextpnr --write` emits carries no `BEL`
attribute for either buffer, patched or not, so there is nothing to assert beyond a FASM byte
count that differs for incidental reasons. Building a real guard means finding a design where
`#111` still changes the outcome after `#109` — and that design has not been found.

**Said plainly because the alternative is worse.** A case that quietly passes is
indistinguishable from a case that works, and nobody re-reads a green test.

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
