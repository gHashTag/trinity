#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""cost-curves-card.py -- public/widgets/cost-curves/card.png, drawn from the real synthesis run.

Reads public/widgets/cost-curves/data.json (written by scripts/widget-data/cost-curves.mjs) and
draws the chart the widget opens on: LUTs against operand width with -nodsp, log scale, for the
binary multiplier, the binary adder and the binary-encoded ternary adder, under the XC7A200T's
LUT6 count. Every number and point on the card is read from data.json. 1200x630 PNG, under 1 MB.

Run (from apps/website):  python3 scripts/widget-data/cost-curves-card.py
Needs Pillow; uses Menlo (macOS) or DejaVu Sans Mono when present.
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DIR = os.path.join(SITE, "public/widgets/cost-curves")
OUT = os.path.join(DIR, "card.png")
W, H = 1200, 630
BG = (0, 0, 0)
PANEL = (5, 8, 7)
GREEN = (0, 255, 136)
GOLD = (255, 215, 0)
RED = (255, 77, 109)
TEXT = (232, 255, 247)
MUTED = (173, 201, 192)
SUBTLE = (143, 169, 160)
LINE = (0, 70, 40)
GRID = (0, 36, 22)

FONTS = ["/System/Library/Fonts/Menlo.ttc", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"]


def font(size, bold=False):
    for f in FONTS:
        if os.path.exists(f):
            return ImageFont.truetype(f, size, index=1 if bold and f.endswith(".ttc") else 0)
    sys.exit("cost-curves-card: no monospace font found")


def main():
    data = json.load(open(os.path.join(DIR, "data.json")))
    res = data["results"]
    cap = data["capacity"]["lut"]

    def series(family, op):
        pts = [r for r in res if r["family"] == family and r["op"] == op and r["dsp"] is False and r["status"] == "ok"]
        return sorted(((r["info_bits"], r["metrics"]["lut"]) for r in pts))

    mul = series("binary", "mul")
    add = series("binary", "add")
    tadd = series("ternary-ref", "add")
    widest = max(r["width"] for r in res if r["family"] == "binary" and r["op"] == "mul")
    hook = next(r for r in res if r["family"] == "binary" and r["op"] == "mul" and r["width"] == widest and r["dsp"] is False)
    dsp = next(r for r in res if r["family"] == "binary" and r["op"] == "mul" and r["width"] == widest and r["dsp"] is True)
    luts = hook["metrics"]["lut"]
    pct = math.floor(luts * 10000 / cap) / 100

    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.text((48, 34), "TRINITY S3AI  /  COST CURVES", font=font(18, True), fill=GREEN)
    d.text((48, 66), f"A {widest}x{widest} multiplier with -nodsp:", font=font(30, True), fill=TEXT)
    big = f"{luts:,} LUTs = {pct:.2f}% of an XC7A200T"
    d.text((48, 106), big, font=font(46, True), fill=GREEN)
    d.text((48, 166), f"With DSPs allowed: {dsp['metrics']['dsp']} DSP48E1 + {dsp['metrics']['lut']:,} LUTs.  yosys synth_xilinx -family xc7, post-synthesis.",
           font=font(17), fill=MUTED)

    # chart box
    x0, y0, x1, y1 = 112, 214, 1150, 546
    d.rectangle((x0 - 64, y0 - 10, x1 + 20, y1 + 36), fill=PANEL, outline=LINE)
    lo, hi = math.log2(3.4), math.log2(72)
    ytop = math.log10(1 + cap * 2.2)

    def X(bits):
        return x0 + (math.log2(bits) - lo) / (hi - lo) * (x1 - x0)

    def Y(v):
        return y1 - math.log10(1 + v) / ytop * (y1 - y0)

    tick = font(14)
    for t in [1, 10, 100, 1000, 10000, 100000]:
        d.line((x0, Y(t), x1, Y(t)), fill=GRID, width=1)
        label = f"{t // 1000}k" if t >= 1000 else str(t)
        d.text((x0 - 10, Y(t)), label, font=tick, fill=SUBTLE, anchor="rm")
    for t in [4, 8, 16, 32, 64]:
        d.line((X(t), y0, X(t), y1), fill=GRID, width=1)
        d.text((X(t), y1 + 16), str(t), font=tick, fill=SUBTLE, anchor="mm")
    d.text((X(5.66), y1 + 16), "operand bits", font=font(13), fill=SUBTLE, anchor="mm")

    # capacity
    yc = Y(cap)
    for xs in range(x0, x1, 18):
        d.line((xs, yc, min(xs + 10, x1), yc), fill=TEXT, width=2)
    d.text((x0 + 8, yc - 8), f"XC7A200T: {cap:,} LUT6 sites (prjxray-db, nextpnr-xilinx)", font=font(15, True), fill=TEXT, anchor="ls")

    def draw(pts, color, width):
        xy = [(X(b), Y(v)) for b, v in pts]
        d.line(xy, fill=color, width=width, joint="curve")
        for x, y in xy:
            d.ellipse((x - 5, y - 5, x + 5, y + 5), fill=color)

    draw(add, GREEN, 3)
    draw(tadd, GOLD, 3)
    draw(mul, RED, 4)
    legend = [
        (RED, f"binary multiply, -nodsp: {mul[-1][1]:,} LUTs at {widest} bits"),
        (GOLD, f"ternary add, 2 wires per trit: {tadd[-1][1]:,} LUTs at {round(tadd[-1][0], 1)} bits ({len(tadd) and max(r['trits'] for r in res if r['family'] == 'ternary-ref')} trits)"),
        (GREEN, f"binary add: {add[-1][1]:,} LUTs at {round(add[-1][0])} bits"),
    ]
    for i, (color, words) in enumerate(legend):
        ly = yc + 26 + i * 24
        d.ellipse((x0 + 10, ly - 6, x0 + 22, ly + 6), fill=color)
        d.text((x0 + 32, ly), words, font=font(15, True), fill=color, anchor="lm")
    hx, hy = X(mul[-1][0]), Y(mul[-1][1])
    d.ellipse((hx - 11, hy - 11, hx + 11, hy + 11), outline=TEXT, width=2)

    d.text((48, 608), "Binary-encoded trits on a binary FPGA are not ternary hardware.  t27.ai/widgets/cost-curves",
           font=font(15), fill=SUBTLE, anchor="lm")
    img.save(OUT, optimize=True)
    size = os.path.getsize(OUT)
    if size > 1024 * 1024:
        sys.exit(f"cost-curves-card: {OUT} is {size} bytes, over 1 MB")
    print(f"cost-curves-card: wrote {OUT} ({size} bytes, {W}x{H}); hook {luts} LUTs = {pct:.2f}%")


if __name__ == "__main__":
    main()
