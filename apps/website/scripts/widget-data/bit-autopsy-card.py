#!/usr/bin/env python3
# bit-autopsy-card.py -- the 1200x630 share card for public/widgets/bit-autopsy/, drawn from samples.json.
# Every number on the card is read from samples.json, which scripts/widget-data/bit-autopsy.mjs
# computes from the real bitstreams (and checks against prjxray bitread), or from the K_ constants
# of specs/widgets/bit-autopsy.t27; nothing here is typed in by hand except the words of the layout.
# Run: python3 scripts/widget-data/bit-autopsy-card.py
import json
import os
import re
from PIL import Image, ImageDraw, ImageFont

SITE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(SITE, "public", "widgets", "bit-autopsy")
SPEC = os.path.join(SITE, "specs", "widgets", "bit-autopsy.t27")
BG, GREEN, GOLD, TEXT, MUTED, RED, LINE = "#000000", "#00ff88", "#ffd700", "#e8fff7", "#8fa9a0", "#ff4d6d", "#1d2b27"
MASK = 0x0FFFFFFF


def font(size, bold=False):
    home = os.path.expanduser("~/Library/Fonts")
    for path in [os.path.join(home, "DejaVuSansMono-Bold.ttf" if bold else "DejaVuSansMono.ttf"),
                 "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
                 "/System/Library/Fonts/Menlo.ttc"]:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def spec_const(name):
    m = re.search(r"pub const " + name + r" : \w+ = (\d+);", open(SPEC).read())
    if not m:
        raise SystemExit(f"{name} not found in {SPEC}")
    return int(m.group(1))


def mix(a, b, t):
    a, b = [int(a[i:i + 2], 16) for i in (1, 3, 5)], [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def main():
    samples = json.load(open(os.path.join(OUT_DIR, "samples.json")))["samples"]
    bench = spec_const("K_BENCH_IDCODE")
    hook = samples[0]
    receipt = next(s for s in samples if s["id"] == "build_receipt")
    hook_code = int(hook["idcode"], 16)
    t27_same = [s for s in samples if s.get("from", {}).get("repo") == "gHashTag/t27" and int(s["idcode"], 16) & MASK == hook_code & MASK]

    img = Image.new("RGB", (1200, 630), BG)
    d = ImageDraw.Draw(img)

    d.polygon([(60, 52), (84, 52), (72, 72)], fill=GOLD)
    d.text((96, 46), "Trinity S\u00b3AI", font=font(26, True), fill=GOLD)
    d.text((1140, 50), "t27.ai/widgets/bit-autopsy", font=font(20), fill=MUTED, anchor="ra")

    d.text((60, 100), "Bitstream autopsy", font=font(52, True), fill=TEXT)
    d.text((60, 166), "which FPGA does this 7-series .bit really ask for?", font=font(24), fill=MUTED)

    # The hook: a committed t27 bitstream writes another chip's IDCODE than the bench board's.
    miss = hook_code & MASK != bench & MASK
    d.rounded_rectangle((60, 212, 1140, 352), radius=18, outline=GOLD if miss else GREEN, width=3)
    name = hook["from"]["path"].split("/")[-1]
    d.text((86, 230), f"{name}  (gHashTag/t27)", font=font(30, True), fill="#ffffff")
    d.text((86, 274), f"writes IDCODE {hook['idcode']}: {hook['device']['model']} ({hook['device']['family']})", font=font(24), fill=TEXT)
    line = f"bench board: XC7A200T, 0x{bench:08x}" + ("  ->  UG470 ID_ERROR" if miss else "  ->  same chip")
    d.text((86, 310), line, font=font(24, True), fill=GOLD if miss else GREEN)
    d.text((1114, 232), f"{len(t27_same)} of {sum(1 for s in samples if s.get('from', {}).get('repo') == 'gHashTag/t27')} t27 .bit files write it", font=font(18), fill=MUTED, anchor="ra")

    # Its numbers.
    zero = hook["zeroBytes"] / hook["bytes"] * 100
    stats = [(f"{hook['bytes']:,}", "bytes"), (f"{zero:.2f}%", "zero bytes"),
             (f"{hook['configFrames']:,}", "config frames"), (f"{hook['nonzeroFrames']:,}", "non-zero frames")]
    sw = (1140 - 60) / len(stats)
    for i, (v, k) in enumerate(stats):
        x = 60 + i * sw
        d.text((x, 372), v, font=font(34, True), fill=GOLD)
        d.text((x, 414), k, font=font(17), fill=MUTED)

    # Which of its frames are non-zero, one band per configuration row.
    blocks = ["CLB", "BRAM", "CFG"]
    halves = ["top", "bot"]
    x0, x1, y0, band, gap, lw = 60, 1140, 450, 10, 3, 104
    for i, r in enumerate(hook["strip"]):
        y = y0 + i * (band + gap)
        d.text((x0, y + band / 2), f"{blocks[r['block']]} {halves[r['bottom']]} {r['row']}", font=font(11), fill=MUTED, anchor="lm")
        cells = r["cells"]
        cw = (x1 - x0 - lw) / len(cells)
        for c, ch in enumerate(cells):
            col = LINE if ch == "-" else mix(BG, GREEN, 0.16) if ch == "0" else mix(BG, GOLD, 0.35 + 0.65 * int(ch) / 9)
            d.rectangle((x0 + lw + c * cw, y, x0 + lw + (c + 1) * cw - 1, y + band), fill=col)

    rc = int(receipt["idcode"], 16)
    d.text((60, 566), f"build_receipt.bit: IDCODE {receipt['idcode']} {receipt['device']['model']}, {receipt['nonzeroFrames']:,} of {receipt['configFrames']:,} frames non-zero"
           + ("  (bench chip)" if rc & MASK == bench & MASK else ""), font=font(18), fill=GREEN)
    d.text((60, 612), "read in your browser, nothing uploaded; counts equal prjxray bitread", font=font(16), fill=MUTED, anchor="ls")

    out = os.path.join(OUT_DIR, "card.png")
    img.save(out, optimize=True)
    print(out, os.path.getsize(out), "bytes")


if __name__ == "__main__":
    main()
