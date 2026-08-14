---
slug: six-and-a-half-years
title: "Six and a Half Years in One Discarded Return Value"
authors: [dmitrii]
tags: [fpga, openxc7, nextpnr, open-source]
---

Last week the openXC7 demo-projects CI went green. Every project builds. That
is the headline, and it is the least interesting thing that happened.

The interesting thing is what three of us found underneath it — including a
defect that had been sitting in the placer since **February 2020**, quietly
throwing away the one piece of information that would have caught it.

<!-- truncate -->

## What openXC7 is

openXC7 is a fully open toolchain for Xilinx 7-series FPGAs: yosys for
synthesis, nextpnr-xilinx for place-and-route, and the prjxray bitstream
database to turn the result into something a chip will actually load. No
Vivado anywhere in the path. If you want to build for an Artix-7 without a
40 GB vendor install and a license server, this is the road.

Roads like this have potholes. Some of them are old.

## The oldest one: a return value nobody read

nextpnr's HeAP placer finishes its analytic placement and then runs a
simulated-annealing refinement pass, `placer1_refine()`. That function returns
a bool. When its final post-placement validity check fails, it returns `false`.

The call site looked like this:

```cpp
placer1_refine(ctx, placer1_cfg);
```

The result went nowhere. And because the validity check's `log_error` is caught
*inside* `placer1_refine`, nothing else escaped either. A placement that had
already been judged invalid by the tool's own checker went straight on to the
router, where it reappeared as an unreadable intra-site arc failure — an error
message pointing at routing, for a fault that was decided during placement.

The fix ([#145](https://github.com/openXC7/nextpnr-xilinx/pull/145)) is five
lines, and four of them are a comment explaining why:

```cpp
if (!placer1_refine(ctx, placer1_cfg))
    return false;
```

`git blame` puts that call site at commit `1b587cb5`, David Shah,
**2020-02-13** — "HeAP: pass through parameters to refinement". It was merged
**2026-08-13**. Six years and six months during which the tool knew the answer
was wrong and discarded the note.

This is worth sitting with, because it is not a story about a careless author.
The placer was correct when it was written and the refinement pass rarely
failed. The bug only becomes reachable when something *else* starts producing
placements that fail validity — which is exactly what the rest of this post is
about. Latent defects in old code are activated by new code, and the blame
line points at the wrong year.

## The one that still bites

The second old defect is an omission rather than a mistake. In a 7-series
slice, each letter position (A/B/C/D) has exactly one selectable output pin —
the `xMUX` — besides the dedicated O6 pin and the flip-flop's Q. One pin, one
claimant.

nextpnr's xc7 placement validity checker never budgeted it. So the packer was
free to co-locate a 5-LUT whose O5 needs to reach the fabric, a carry whose sum
output feeds something off-position, and a carry-out going somewhere other than
the chain — three claimants, one pin. The placer said yes. The router then died
with `Failed to route arc ... CARRY4_O3 to AFFMUX_OUT`.

The same slice geometry — a carry lane with both `O` and non-chain `CO` going to
the fabric — has a nastier relative that is still open as I write this.
[#134](https://github.com/openXC7/nextpnr-xilinx/issues/134), filed by
**cheungxi**, describes a bitstream that places, routes, and meets timing, and
then does not work on the chip: the board never answers the first UART command.
The root cause is elsewhere (relocated carry pass-through lanes were driving
`S` from a constant net, which has no physical realization on xc7 — each `S`
must come from its 6-LUT's `O6`), and #146 does *not* fix it. A bug that
survives placement, routing, timing, and CI, and only shows up as silence from
a board, is the expensive kind.

[#146](https://github.com/openXC7/nextpnr-xilinx/pull/146) adds the per-position
budget — 138 lines that count claimants and reject the position if there is more
than one, so the legaliser keeps searching instead of handing the router an
impossible site. The validity checker it patches dates to David Shah's xc7
legality work in late 2019 and early 2020. The check was never there to be
broken; it simply was never written.

## The young ones

Not everything was ancient. Two of the four fixes were in code from this
spring:

- [#142](https://github.com/openXC7/nextpnr-xilinx/pull/142) — the RAM256X1S
  mux tree was being built into the SPO half of the slice instead of its own
  half. The fix changes one value: `m256 ? 4` becomes `m256 ? 0`. The code it
  corrects landed 2026-05-29, so this defect was about ten weeks old.
- [#144](https://github.com/openXC7/nextpnr-xilinx/pull/144) — RAM128X1S scalar
  addresses `A0..A6` were not wired into the distributed-RAM control set.

Both are LUTRAM packing, and both are why LiteX designs — which lean hard on
distributed RAM for cache tag memory — were the designs that fell over.

## Three people, three days

The work ran from 2026-08-12 to 2026-08-14 between three developers:

- **Carlos Venegas Arrabé** ([@cavearr](https://github.com/cavearr)) — #144 and
  #146, the OUTMUX budget included.
- **Dmitrii Vasilev** ([@gHashTag](https://github.com/gHashTag)) — #142 and
  #145, plus the [#141](https://github.com/openXC7/nextpnr-xilinx/issues/141)
  reproduction that started it.
- **Hans Baier** ([@hansfbaier](https://github.com/hansfbaier)) — maintainer:
  reviewed every one, merged them, and kept the demo-projects CI honest enough
  to show the failures in the first place.

The part I want to record is a mistake, because it is the most useful thing in
the whole exchange. We initially attributed the `picosoc` failure to #146.
It was not — it was #142's class. The reason we could not reproduce it was that
our lab trees had *already* been carrying #142's one-line fix since an earlier
campaign. Every build in the sweep silently included the fix. We were sweeping
the wrong variable, and the experiment could not have told us so.

Once that was spotted, the picture came out clean: with #146 alone, both failing
seeds die at the LUTRAM address placement and never reach the carry stage; with
#142 and #146 together, both pass — zero validity firings, zero route failures.
Order matters, and we only learned the order by getting it wrong first.

## What is actually true now

[All demo projects build.](https://github.com/openXC7/demo-projects/actions/runs/31778234320)

That is a real milestone and it is also a narrow claim, so let me quote the
maintainer rather than improve on him:

> That does not mean that the bitstreams work. Which is what we have to tackle
> next.

A green CI proves the toolchain produces a bitstream without falling over. It
does not prove the bitstream configures a chip, or that the design inside it
does what it should. The next target is `litex-ddr-arty-s7` — getting a LiteX
DDR design not merely built but *running* on the board.

#134 above is the sharpest illustration of the gap: a design that passes every
automated gate we have and still does nothing on hardware. Until a board answers,
the gates are measuring the toolchain, not the design.

There is also a known non-toolchain failure still open: `litex-ddr-hdmi-stlv7325`
fails because the generated Verilog ties the `SHIFTOUT1/2` outputs of a slave
OSERDESE2 to constants. Vivado warns and ignores it; yosys refuses. The honest
fix is in LiteX's emission, not in a wrapper that hides a generator emitting
nonsense.

## The moral, if there is one

Two of the four defects were six years old. Neither had been dormant because
nobody cared — they were dormant because nothing had yet asked the tool the
question that would expose them. The LUTRAM packing work from May was what
started asking.

So the useful lesson is not "check your return values", true as that is. It is
that **new features are how you audit old code**, and that a toolchain gets
trustworthy only by being driven hard enough to fail in new places. CI going
green is not the end of that process. It is the point at which the next class of
bug becomes visible.

*Thanks to Hans for the openness to patches from strangers, and to Carlos for
the kind of debugging that admits when the experiment was wrong.*
