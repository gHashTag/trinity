#!/usr/bin/env python3
"""idcode-card.py -- draw public/widgets/idcode/card.png: 0x03636093 taken apart.

The code drawn is K_TABLE_IDCODE from specs/widgets/idcode.t27; its row (manufacturer, family,
model, IR length) is read from public/widgets/idcode/parts.json (openFPGALoader v1.1.1's part.hpp,
written by scripts/widget-data/idcode.mjs), and the bench line from that file's bench record. The
card's alt text is IMAGE_ALT in the spec, so this script refuses to draw a card the alt text does
not describe. The layout matches the card tool.js saves in the browser.

Usage: python3 scripts/widget-data/idcode-card.py
"""
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DATA = os.path.join(SITE, "public/widgets/idcode/parts.json")
SPEC = os.path.join(SITE, "specs/widgets/idcode.t27")
OUT = os.path.join(SITE, "public/widgets/idcode/card.png")

BLACK, GREEN, GOLD, TEXT, MUTED, BLUE, CELL = "#000000", "#00ff88", "#ffd700", "#e8fff7", "#8fa9a0", "#6cb6ff", "#0b1210"
FIELD_COLOUR = [GOLD, GREEN, BLUE, TEXT]


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


def main():
    k = spec_consts(open(SPEC, encoding="ascii").read())
    d = json.load(open(DATA))
    code = k["K_TABLE_IDCODE"]
    lsb, width = k["K_FIELD_LSB"], k["K_FIELD_WIDTH"]
    field = [(code >> lsb[i]) & ((1 << width[i]) - 1) for i in range(4)]
    mfr = field[2]
    cont, ident = mfr >> k["K_MFR_CODE_BITS"], mfr & ((1 << k["K_MFR_CODE_BITS"]) - 1)
    names = {int(c, 16): n for c, n in d["manufacturers"]}
    row = next(r for r in d["fpga"] if int(r[0], 16) == code)
    raw = int(d["bench"]["raw"][0], 16)
    W, H = k["K_CARD_WIDTH"], k["K_CARD_HEIGHT"]
    if field[3] != 1 or (raw & k["K_VERSION_MASK"]) != code:
        sys.exit("idcode-card: bit 0 is not 1, or the bench raw word does not mask to the table key")

    hex8 = "0x%08x" % code
    alt = k["IMAGE_ALT"]
    need = [hex8, "version 0x%x" % field[0], "part number 0x%04x" % field[1], "manufacturer 0x%03x" % mfr,
            "bank %d" % (cont + 1), "code 0x%02x" % ident, names[mfr], "bit 0 set to 1", d["source"]["tag"],
            row[3], row[2], "IR length %d" % row[4], "0x%08x raw" % raw, "version %d" % (raw >> 28)]
    missing = [n for n in need if n not in alt]
    if missing:
        sys.exit(f"idcode-card: IMAGE_ALT in {SPEC} does not say {missing}; update it first")

    img = Image.new("RGB", (W, H), BLACK)
    g = ImageDraw.Draw(img)
    g.polygon([(60, 52), (84, 52), (72, 72)], fill=GREEN)
    g.text((98, 46), k["SAY_CARD_BRAND"].replace("S3AI", "S\u00b3AI"), font=font(26, True), fill=GREEN)
    g.text((W - 60, 50), k["SAY_CARD_TITLE"], font=font(22), fill=MUTED, anchor="ra")
    g.text((60, 100), hex8, font=font(92, True), fill="#ffffff")
    g.text((60, 214), "%s \u00b7 %s \u00b7 %s %d" % (row[3], row[2], k["SAY_DEVICE_FIELDS"][3], row[4]),
           font=font(30, True), fill=GREEN)

    x0, y0, ch = 60, 290, 70
    cw = (W - 120) / 32
    for i in range(32):
        b = 31 - i
        f = next(j for j in range(4) if lsb[j] <= b < lsb[j] + width[j])
        on = (code >> b) & 1
        x = x0 + i * cw
        g.rectangle([x + 2, y0, x + cw - 2, y0 + ch], fill=FIELD_COLOUR[f] if on else CELL, outline=FIELD_COLOUR[f], width=2)
        g.text((x + cw / 2, y0 + 20), str(on), font=font(28, True), fill=BLACK if on else FIELD_COLOUR[f], anchor="mt")
        g.text((x + cw / 2, y0 + ch + 8), str(b), font=font(14), fill=MUTED, anchor="mt")
    digits = [1, 4, 3, 1]
    for f in range(4):
        left = x0 + (31 - (lsb[f] + width[f] - 1)) * cw
        right = x0 + (32 - lsb[f]) * cw
        g.line([(left + 4, y0 + ch + 34), (right - 4, y0 + ch + 34)], fill=FIELD_COLOUR[f], width=2)
        cx, anchor = (right, "rt") if f == 3 else ((left + right) / 2, "mt")
        value = str(field[3]) if f == 3 else "0x%0*x" % (digits[f], field[f])
        g.text((cx, y0 + ch + 44), value, font=font(22, True), fill=FIELD_COLOUR[f], anchor=anchor)
        if f != 3:
            g.text((cx, y0 + ch + 72), k["SAY_FIELD_NAMES"][f], font=font(16), fill=MUTED, anchor=anchor)

    g.text((60, 500), fill(k["SAY_BANK_LINE"], cont + 1, cont, "0x%02x" % ident) + " \u00b7 " + names[mfr],
           font=font(22), fill=TEXT)
    bench = d["bench"]
    line = fill(k["SAY_BENCH_LINE"], bench["date"].replace("T", " "), "0x%08x" % raw, raw >> 28,
                bench["tool"].replace("openFPGALoader ", ""), "0x%x" % int(bench["printed"][0], 16))
    head, _, tail = line.partition("; ")
    g.text((60, 530), head + ";", font=font(17), fill=GOLD)
    g.text((60, 552), tail, font=font(17), fill=MUTED)
    g.text((60, 588), fill(k["SAY_CARD_URL"], hex8), font=font(20), fill=GREEN)
    g.text((W - 60, 592), "openFPGALoader %s, Apache-2.0" % d["source"]["tag"], font=font(15), fill=MUTED, anchor="ra")

    img.save(OUT, optimize=True)
    print(f"idcode-card: wrote {OUT} ({os.path.getsize(OUT)} bytes, {W}x{H}) for {hex8}: "
          f"version {field[0]}, part 0x{field[1]:04x}, manufacturer 0x{mfr:03x} bank {cont + 1} code 0x{ident:02x} {names[mfr]}, "
          f"{row[3]} / {row[2]} / IR {row[4]}; bench raw 0x{raw:08x}")


if __name__ == "__main__":
    main()
