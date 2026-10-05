#!/usr/bin/env python3
"""t27-cell-card.py -- draw public/widgets/t27-cell/card.png: 27 seats against 16.

Every number on the card is read from public/widgets/t27-cell/data.json, which
scripts/widget-data/t27-cell.mjs writes from the trinity-fpga pre-registrations
(specs/numeric/ternary_storage_search*.t27) and the measured run
(research/block/ternary_storage_search_v2.json). Only the layout words are typed here.
Look: black field, white type, gold for the one accent (T27); no green.

Usage (from apps/website): node scripts/widget-data/t27-cell.mjs && python3 scripts/widget-data/t27-cell-card.py
"""
import json
import math
import os

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DATA = os.path.join(SITE, "public/widgets/t27-cell/data.json")
OUT = os.path.join(SITE, "public/widgets/t27-cell/card.png")
BLACK, WHITE, TEXT, MUTED, SUBTLE, GOLD = "#000000", "#ffffff", "#e8e8e8", "#a8a8a8", "#6e6e6e", "#ffd700"


def font(size, bold=False):
    home = os.path.expanduser("~/Library/Fonts")
    for path in (os.path.join(home, "DejaVuSansMono-Bold.ttf" if bold else "DejaVuSansMono.ttf"),
                 "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf" if bold else
                 "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def seats(levels, top):
    pos = [l / top for l in levels[1:]]
    return [-v for v in reversed(pos)] + [0.0] + pos


def main():
    d = json.load(open(DATA))
    row = {r["id"]: r for r in d["storage"]}
    t, nv, e2 = row["T27"], row["NVFP4"], row["E2M2"]
    img = Image.new("RGB", (1200, 630), BLACK)
    g = ImageDraw.Draw(img)

    g.text((60, 40), "Trinity S³AI", font=font(24, True), fill=WHITE)
    g.text((1140, 44), "t27.ai/widgets/t27-cell", font=font(20), fill=MUTED, anchor="ra")
    g.text((60, 84), f"{d['cell']['codes']} seats vs {d['e2m1']['codes']}", font=font(62, True), fill=WHITE)
    g.text((60, 160), f"a {d['cell']['trits']}-trit T27 cell ({math.log2(d['cell']['codes']):.2f} bits) against a "
                      f"{int(math.log2(d['e2m1']['codes']))}-bit E2M1 (FP4) code", font=font(24), fill=MUTED)

    # One number line, -1..1, T27_N above in gold, E2M1 below in white.
    x0, x1, ax = 60, 1140, 290
    X = lambda v: x0 + (v + 1) / 2 * (x1 - x0)
    g.line((x0, ax, x1, ax), fill=SUBTLE, width=2)
    for v in seats(d["t27"]["levels"], d["t27"]["top"]):
        g.line((X(v), ax - 48, X(v), ax - 6), fill=GOLD, width=4)
    for v in seats(d["e2m1"]["levels"], d["e2m1"]["top"]):
        g.line((X(v), ax + 6, X(v), ax + 48), fill=WHITE, width=4)
    g.text((x0, ax - 84), f"{d['t27']['name']}: {d['cell']['codes']} seats", font=font(22, True), fill=GOLD)
    g.text((x0, ax + 58), f"E2M1: {d['e2m1']['distinct']} seats (+0 = -0)", font=font(22, True), fill=WHITE)
    for v, a in ((0, "ma"), (1, "ra")):
        g.text((X(v), ax + 60), str(v), font=font(20), fill=MUTED, anchor=a)

    # Storage per 32 weights.
    y = 418
    cols = (60, 400, 620, 900)
    for c, h in zip(cols, ("per 32 weights", "trits", "bits", "test ppl")):
        g.text((c, y), h, font=font(20), fill=SUBTLE)
    g.line((60, y + 30, 1140, y + 30), fill=SUBTLE, width=1)
    for i, (name, r, col) in enumerate((("T27", t, GOLD), ("NVFP4", nv, WHITE), ("E2M2 (5-bit)", e2, WHITE))):
        yy = y + 40 + i * 38
        bits = f"{r['bits']} dense" if r["dense"] else f"{r['bits']} +{r['tensorBits']}/tensor" if r["tensorBits"] else str(r["bits"])
        g.text((cols[0], yy), name, font=font(26, True), fill=col)
        g.text((cols[1], yy), str(r["trits"]), font=font(26, r is t), fill=GOLD if r is t else TEXT)
        g.text((cols[2], yy), bits, font=font(26, r is nv), fill=WHITE if r is nv else TEXT)
        g.text((cols[3], yy), f"{r['ppl']:.2f}", font=font(26), fill=TEXT)
    g.text((60, 588), "Better than NVFP4 on a ternary substrate only. In binary bits T27 is larger; E2M2 beats it on quality.",
           font=font(17), fill=MUTED)
    img.save(OUT, optimize=True)
    print(f"t27-cell-card: wrote {OUT} ({os.path.getsize(OUT)} bytes)")


if __name__ == "__main__":
    main()
