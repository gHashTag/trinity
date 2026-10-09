#!/usr/bin/env python3
"""jtag-verdict-card.py -- draw public/widgets/jtag-verdict/card.png: one even DR word, two verdicts.

The two readings drawn are vectors 1 and 2 of specs/widgets/jtag-verdict.t27 (K_CASE_IR, K_CASE_DR,
K_CASE_WANT), which are the test vectors of t27 specs/port/tools/jtag/tdo_verdict.t27. Every word is
a SAY_ constant of that spec. The card's alt text is IMAGE_ALT there, so this script refuses to draw
a card the alt text does not describe.

Usage: python3 scripts/widget-data/jtag-verdict-card.py
"""
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SPEC = os.path.join(SITE, "specs/widgets/jtag-verdict.t27")
OUT = os.path.join(SITE, "public/widgets/jtag-verdict/card.png")

BLACK, GREEN, GOLD, RED, TEXT, MUTED, CELL = "#000000", "#00ff88", "#ffd700", "#ff5c5c", "#e8fff7", "#8fa9a0", "#0b1210"


def font(size, bold=False):
    for path, index in (("/System/Library/Fonts/Menlo.ttc", 1 if bold else 0),
                        ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf" if bold else
                         "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 0)):
        if os.path.exists(path):
            return ImageFont.truetype(path, size, index=index)
    return ImageFont.load_default()


def spec_consts(text):
    """The spec's pub consts: str, numbers and arrays of either (the shapes this spec uses)."""
    out = {}
    for name, value in re.findall(r"^pub const (\w+) : [^=]+= (.*);$", text, re.M):
        out[name] = json.loads(value) if value[0] in '"[' else (value == "true" if value in ("true", "false") else int(value))
    return out


def fill(s, *v):
    return re.sub(r"\{(\d+)\}", lambda m: str(v[int(m.group(1))]), s)


def verdict(k, ir, dr):
    if dr == k["K_ALL_ONES"]:
        return k["K_V_STUCK_HIGH"]
    if dr == 0 and ir == 0:
        return k["K_V_STUCK_LOW"]
    if ir & k["K_IR_MASK"] != k["K_IR_LOW"]:
        return k["K_V_BROKEN_SHIFT"]
    if not dr & 1:
        return k["K_V_BYPASS"]
    return k["K_V_IDCODE"]


def main():
    k = spec_consts(open(SPEC, encoding="ascii").read())
    W, H = k["K_CARD_WIDTH"], k["K_CARD_HEIGHT"]
    irs, drs, want = k["K_CASE_IR"], k["K_CASE_DR"], k["K_CASE_WANT"]
    for i in range(len(irs)):
        if verdict(k, irs[i], drs[i]) != want[i]:
            sys.exit(f"jtag-verdict-card: vector {i} gives {verdict(k, irs[i], drs[i])}, the spec wants {want[i]}")
    if drs[1] != drs[2]:
        sys.exit("jtag-verdict-card: vectors 1 and 2 must share one DR word")
    dr = drs[1]
    names = k["SAY_VERDICT_NAMES"]
    alt = k["IMAGE_ALT"]
    need = ["0x%08x" % dr, "0x%02x" % irs[1], "0x%02x" % irs[2], names[want[1] - 1], names[want[2] - 1],
            "low two bits are 01", "low bits 00", "five checks", "tdo_verdict.t27", "8 tests"]
    missing = [n for n in need if n not in alt]
    if missing:
        sys.exit(f"jtag-verdict-card: IMAGE_ALT in {SPEC} does not say {missing}; update it first")

    img = Image.new("RGB", (W, H), BLACK)
    g = ImageDraw.Draw(img)
    g.polygon([(60, 52), (84, 52), (72, 72)], fill=GREEN)
    g.text((98, 46), k["SAY_CARD_BRAND"].replace("S3AI", "S³AI"), font=font(26, True), fill=GREEN)
    g.text((W - 60, 50), k["SAY_CARD_TITLE"], font=font(22), fill=MUTED, anchor="ra")
    g.text((60, 96), k["SAY_CARD_HEAD"], font=font(44, True), fill="#ffffff")
    g.text((60, 152), "DR 0x%08x" % dr, font=font(30, True), fill=TEXT)

    colours = {k["K_V_BYPASS"]: GOLD, k["K_V_BROKEN_SHIFT"]: RED, k["K_V_IDCODE"]: GREEN}
    for col, i in enumerate((1, 2)):
        x0 = 60 + col * 550
        ir, v = irs[i], want[i]
        c = colours.get(v, RED)
        g.rounded_rectangle([x0, 206, x0 + 520, 406], radius=16, outline=c, width=3)
        g.text((x0 + 24, 224), fill(k["SAY_CARD_IR_LINE"], "0x%02x" % ir, format(ir & k["K_IR_MASK"], "02b")),
               font=font(22), fill=MUTED)
        cw = 52
        for b in range(6):
            bit = (ir >> (5 - b)) & 1
            x = x0 + 24 + b * (cw + 8)
            low = b >= 4
            g.rectangle([x, 262, x + cw, 316], fill=CELL, outline=c if low else MUTED, width=3 if low else 1)
            g.text((x + cw / 2, 274), str(bit), font=font(30, True), fill=c if low else TEXT, anchor="mt")
        g.text((x0 + 24, 336), names[v - 1], font=font(46, True), fill=c)

    steps = k["SAY_LADDER_STEPS"]
    g.text((60, 432), k["SAY_LADDER_TITLE"], font=font(18), fill=MUTED)
    for i, step in enumerate(steps):
        y = 462 + (i % 3) * 30
        x = 60 + (i // 3) * 550
        g.text((x, y), "%d. %s -> %s" % (i + 1, step, names[i]), font=font(20), fill=TEXT)
    g.text((60, 588), k["SAY_CARD_URL"], font=font(20), fill=GREEN)
    g.text((W - 60, 592), k["SAY_CARD_SPEC"], font=font(15), fill=MUTED, anchor="ra")

    img.save(OUT, optimize=True)
    print(f"jtag-verdict-card: wrote {OUT} ({os.path.getsize(OUT)} bytes, {W}x{H}); DR 0x{dr:08x}: "
          f"IR 0x{irs[1]:02x} -> {names[want[1] - 1]}, IR 0x{irs[2]:02x} -> {names[want[2] - 1]}; "
          f"{len(irs)}/{len(irs)} vectors agree")


if __name__ == "__main__":
    main()
