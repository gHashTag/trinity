#!/usr/bin/env python3
"""fits-on-card.py -- draw public/widgets/fits-on/card.png: how many node0 designs fit on an XC7A200T.

Every number on the card is read from public/widgets/fits-on/device.json (written by
scripts/widget-data/fits-on.mjs from two real nextpnr-xilinx logs) and from the K_ constants of
specs/widgets/fits-on.t27, which that script checks against the logs. The card's alt text is
IMAGE_ALT in the spec, so this script refuses to draw a card the alt text does not describe.
The grid is the page's grid for the node0 preset: one cell per copy, a hollow cell for what is left.

Usage: python3 scripts/widget-data/fits-on-card.py
"""
import json
import math
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DATA = os.path.join(SITE, "public/widgets/fits-on/device.json")
SPEC = os.path.join(SITE, "specs/widgets/fits-on.t27")
OUT = os.path.join(SITE, "public/widgets/fits-on/card.png")

W, H = 1200, 630
BLACK, GREEN, GOLD, TEXT, MUTED, LINE = "#000000", "#00ff88", "#ffd700", "#e8fff7", "#8fa9a0", "#1f5c43"
BRAND = "Trinity S\u00b3AI"


def font(size, bold=False):
    for path, index in (("/System/Library/Fonts/Menlo.ttc", 1 if bold else 0),
                        ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf" if bold else
                         "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 0)):
        if os.path.exists(path):
            return ImageFont.truetype(path, size, index=index)
    return ImageFont.load_default()


def spec_consts(text):
    out = {}
    for name, value in re.findall(r"^pub const (\w+) : [^=]+= (.*);$", text, re.M):
        try:
            out[name] = json.loads(value)
        except ValueError:
            pass
    return out


def main():
    k = spec_consts(open(SPEC, encoding="ascii").read())
    d = json.load(open(DATA))
    ex = next(e for e in d["examples"] if e["id"] == "node0")
    cap = d["capacity"]
    if cap["LUT"] != k["K_LUT_POSITIONS"] or ex["fits"]["copies"] != k["K_EX_NODE0_COPIES"]:
        sys.exit("fits-on-card: device.json and the spec disagree; run scripts/widget-data/fits-on.mjs first")
    used = ex["used"]
    n = ex["fits"]["copies"]
    ff = ex["fits"]["per"]["FF"]
    binding = ex["fits"]["binding"]
    left = cap["LUT"] - n * used["SLICE_LUTX"]
    c = lambda v: f"{v:,}"

    alt = k["IMAGE_ALT"]
    need = [f"{n} copies", ex["board"].split()[-1], c(used["SLICE_LUTX"]) + " LUTs", c(used["SLICE_FFX"]) + " FFs",
            f"{used['RAMB36E1']} RAMB36E1", f"{n} cells over {c(cap['LUT'])} LUT6 positions", f"would allow {ff}"]
    missing = [s for s in need if s not in alt]
    if missing or binding != ["LUT"]:
        sys.exit(f"fits-on-card: IMAGE_ALT in {SPEC} does not say {missing} (binding {binding}); update it first")

    img = Image.new("RGB", (W, H), BLACK)
    g = ImageDraw.Draw(img)
    g.polygon([(60, 52), (84, 52), (72, 72)], fill=GREEN)
    g.text((98, 46), BRAND, font=font(26, True), fill=GREEN)
    g.text((W - 60, 50), "fits on a 200T", font=font(22), fill=MUTED, anchor="ra")

    def say(xy, text, f, fill):
        # The left column ends where the grid starts; refuse to draw text that runs into it.
        if g.textlength(text, font=f) > 640 - 24 - xy[0]:
            sys.exit(f"fits-on-card: {text!r} is too wide for the left column")
        g.text(xy, text, font=f, fill=fill)

    say((60, 104), f"{n} copies", font(84, True), GREEN)
    say((60, 204), f"of {ex['top']}", font(26, True), TEXT)
    say((60, 238), "fit on an XC7A200T", font(26, True), TEXT)
    say((60, 278), f"{c(used['SLICE_LUTX'])} LUTs \u00b7 {c(used['SLICE_FFX'])} FFs \u00b7 {used['RAMB36E1']} RAMB36E1 per copy",
         font(19), MUTED)

    # Grid: n green cells and one hollow cell for the leftover, over the right half.
    gx0, gy0, gw, gh = 640, 104, 500, 280
    cells = n + 1
    cols = max(1, math.ceil(math.sqrt(cells * gw / gh)))
    size = min(gw // cols, gh // math.ceil(cells / cols))
    gap = max(2, size // 10)
    for i in range(cells):
        x = gx0 + (i % cols) * size
        y = gy0 + (i // cols) * size
        if i < n:
            g.rectangle([x, y, x + size - gap, y + size - gap], fill=GREEN)
        else:
            frac = left / used["SLICE_LUTX"]
            g.rectangle([x, y + (size - gap) * (1 - frac), x + size - gap, y + size - gap], fill="#4d4300")
            g.rectangle([x, y, x + size - gap, y + size - gap], outline=GOLD, width=3)
    rows = math.ceil(cells / cols)
    g.text((gx0, gy0 + rows * size + 6), f"one cell per copy \u00b7 {c(cap['LUT'])} LUT6 positions", font=font(17), fill=MUTED)
    g.text((gx0, gy0 + rows * size + 30), f"hollow: {c(left)} left over", font=font(17), fill=GOLD)

    say((60, 326), "LUTs run out first", font(30, True), GOLD)
    say((60, 366), f"flip-flops would allow {ff}", font(22), TEXT)
    say((60, 398), f"block RAM would allow {ex['fits']['per']['BRAM']}", font(22), TEXT)

    g.line([(60, 452), (W - 60, 452)], fill=LINE, width=1)
    g.text((60, 470), f"nextpnr printed {c(used['SLICE_LUTX'])}/{c(cap['LUT_BELS'])} LUT BELs = {ex['lut_pct_printed']}%."
           f" A LUT6 position is 2 BELs,", font=font(18), fill=MUTED)
    g.text((60, 496), f"and node0 put {c(ex['routed']['lut_cells'])} LUT cells on {c(ex['routed']['lut6_positions'])} positions."
           " At 100%: an upper bound.", font=font(18), fill=MUTED)
    g.text((60, 540), f"totals: nextpnr-xilinx {ex['nextpnr_version']} Device utilisation, two {ex['board']} logs ({ex['part']})",
           font=font(16), fill=MUTED)
    g.text((60, 584), "t27.ai/widgets/fits-on/", font=font(22, True), fill=GREEN)

    img.save(OUT, optimize=True)
    print(f"fits-on-card: wrote {OUT} ({os.path.getsize(OUT)} bytes, {W}x{H}): {n} copies of {ex['top']}, "
          f"binding {binding}, FF {ff}, BRAM {ex['fits']['per']['BRAM']}, leftover {left} LUT6 positions")


if __name__ == "__main__":
    main()
