#!/usr/bin/env python3
"""lut-explain-card.py -- draw public/widgets/lut-explain/card.png from design.json.

Every number on the card is read from public/widgets/lut-explain/design.json, which
scripts/widget-data/lut-explain.mjs wrote by running the page's own decoder over node.fasm. The
XOR6 grid is drawn from the INIT itself, and this script checks that it is the parity of six inputs
before drawing it. The card's alt text is IMAGE_ALT in specs/widgets/lut-explain.t27; the script
refuses to draw a card the alt text does not describe.

Usage: python3 scripts/widget-data/lut-explain-card.py
"""
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DATA = os.path.join(SITE, "public/widgets/lut-explain/design.json")
SPEC = os.path.join(SITE, "specs/widgets/lut-explain.t27")
OUT = os.path.join(SITE, "public/widgets/lut-explain/card.png")

W, H = 1200, 630
BLACK, GREEN, GOLD, TEXT, MUTED, SUBTLE, LINE = "#000000", "#00ff88", "#ffd700", "#e8fff7", "#adc9c0", "#8fa9a0", "#0f3b29"
BRAND = "Trinity S\u00b3AI"
XOR6 = "6996966996696996"
# The card's short words for the decoder's keys (the page's words are SAY_CLASS_* in the spec).
NAMES = {"xor/2/0": "XOR2", "xnor/2/0": "XNOR2", "mux2/3/0": "2:1 mux", "xnor/3/0": "XNOR3",
         "carry2/5/0": "2-bit carry", "xor/3/0": "XOR3", "and/2/0": "AND2"}


def font(size, bold=False):
    for path, index in (("/System/Library/Fonts/Menlo.ttc", 1 if bold else 0),
                        ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf" if bold else
                         "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 0)):
        if os.path.exists(path):
            return ImageFont.truetype(path, size, index=index)
    return ImageFont.load_default()


def main():
    d = json.load(open(DATA))
    hist = dict(d["hist"])
    luts, named = d["luts"], d["named"]
    other = luts - named
    xor_family = sum(n for k, n in hist.items() if k.startswith("xor/") or k.startswith("xnor/"))
    shown = [(k, hist[k]) for k in ("xor/2/0", "xnor/2/0", "mux2/3/0", "xnor/3/0", "carry2/5/0", "xor/3/0", "and/2/0")]

    value = int(XOR6, 16)
    bits = [(value >> i) & 1 for i in range(64)]
    if any(bits[i] != bin(i).count("1") % 2 for i in range(64)):
        sys.exit("lut-explain-card: 64'h%s is not the parity of six inputs" % XOR6)

    alt = re.search(r'pub const IMAGE_ALT : str = "(.*)";', open(SPEC).read()).group(1)
    need = [XOR6, f"{luts} LUTs", f"XOR2 {hist['xor/2/0']}", f"XNOR2 {hist['xnor/2/0']}",
            f"2:1 mux {hist['mux2/3/0']}", f"{other} with no short name"]
    missing = [n for n in need if n not in alt]
    if missing:
        sys.exit(f"lut-explain-card: IMAGE_ALT in {SPEC} does not say {missing}; update it to design.json first")

    img = Image.new("RGB", (W, H), BLACK)
    g = ImageDraw.Draw(img)
    g.polygon([(60, 52), (84, 52), (72, 72)], fill=GREEN)
    g.text((98, 46), BRAND, font=font(26, True), fill=GREEN)
    g.text((W - 60, 50), "7-series LUT6", font=font(22), fill=GOLD, anchor="ra")
    g.text((60, 100), "LUT explain", font=font(60, True), fill=GREEN)
    g.text((60, 176), "64 INIT bits, read as logic", font=font(24), fill=TEXT)

    # Left: the XOR6 INIT as an 8x8 grid, INIT[63] top left, as the page's game draws it.
    g.text((60, 230), f"64'h{XOR6}", font=font(26, True), fill=GOLD)
    x0, y0, c = 60, 276, 30
    for k in range(64):
        i = 63 - k
        x, y = x0 + (k % 8) * (c + 4), y0 + (k // 8) * (c + 4)
        if bits[i]:
            g.rectangle([x, y, x + c, y + c], fill=GREEN)
        else:
            g.rectangle([x, y, x + c, y + c], outline=LINE, width=2)
    g.text((60, 556), "= XOR6, parity of A1..A6", font=font(24, True), fill=GREEN)

    # Right: the histogram of one routed design.
    rx = 420
    g.text((rx, 230), f"{luts} LUTs of one routed design", font=font(24, True), fill=TEXT)
    g.text((rx, 262), f"nextpnr-xilinx, {d['source']['part']}", font=font(18), fill=SUBTLE)
    top = max(n for _, n in shown + [("other", other)])
    bar_x, bar_w, y = rx + 190, W - 60 - (rx + 190) - 70, 294
    rows = shown + [("other", other)]
    for k, n in rows:
        label = NAMES.get(k, "no short name")
        colour = SUBTLE if k == "other" else GOLD if k.startswith(("xor/", "xnor/")) else GREEN
        g.text((rx, y + 2), label, font=font(20), fill=MUTED if k == "other" else TEXT)
        g.rectangle([bar_x, y + 6, bar_x + max(2, round(bar_w * n / top)), y + 24], fill=colour)
        g.text((W - 60, y + 2), str(n), font=font(20, True), fill=TEXT, anchor="ra")
        y += 31
    g.text((rx, y + 6), f"{xor_family} are XOR or XNOR. Guess the gate.", font=font(20, True), fill=GOLD)
    g.text((W - 60, 82), "t27.ai/widgets/lut-explain/", font=font(20), fill=GREEN, anchor="ra")

    img.save(OUT, optimize=True)
    print(f"lut-explain-card: wrote {OUT} ({os.path.getsize(OUT)} bytes)")


if __name__ == "__main__":
    main()
