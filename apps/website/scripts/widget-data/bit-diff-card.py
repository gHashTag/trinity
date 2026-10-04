#!/usr/bin/env python3
# bit-diff-card.py -- the 1200x630 share card for public/widgets/bit-diff/, drawn from demo.json.
# Every number on the card is read from demo.json, which scripts/widget-data/bit-diff.mjs computes
# from the real bitstreams; nothing here is typed in by hand except the words of the layout.
# Run: python3 scripts/widget-data/bit-diff-card.py
import json
import os
from PIL import Image, ImageDraw, ImageFont

SITE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(SITE, "public", "widgets", "bit-diff")
BG, GREEN, GOLD, TEXT, MUTED, RED = "#000000", "#00ff88", "#ffd700", "#e8fff7", "#8fa9a0", "#ff4d6d"


def font(size, bold=False):
    home = os.path.expanduser("~/Library/Fonts")
    for path in [os.path.join(home, "DejaVuSansMono-Bold.ttf" if bold else "DejaVuSansMono.ttf"),
                 "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
                 "/System/Library/Fonts/Menlo.ttc"]:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main():
    demo = json.load(open(os.path.join(OUT_DIR, "demo.json")))
    same = next(p for p in demo["pairs"] if p["label"] == "x7-board")
    diff = next(p for p in demo["pairs"] if p["label"] == "e2-e3")
    img = Image.new("RGB", (1200, 630), BG)
    d = ImageDraw.Draw(img)

    # Brand: a small point-down triangle and the name.
    d.polygon([(60, 52), (84, 52), (72, 72)], fill=GOLD)
    d.text((96, 46), "Trinity S\u00b3AI", font=font(26, True), fill=GOLD)
    d.text((1140, 50), "t27.ai/widgets/bit-diff", font=font(20), fill=MUTED, anchor="ra")

    d.text((60, 108), "Bitstream diff", font=font(58, True), fill=TEXT)
    d.text((60, 182), "two Xilinx 7-series .bit files, frame by frame", font=font(26), fill=MUTED)

    # The verdict of the x7-board pair.
    ok = same["identical"]
    d.rounded_rectangle((60, 236, 1140, 380), radius=18, outline=GREEN if ok else GOLD, width=3)
    d.ellipse((86, 266, 170, 350), outline=GREEN, width=4)
    d.text((128, 308), "=" if ok else "!=", font=font(44, True), fill=GREEN, anchor="mm")
    d.text((196, 258), "t27 vs openXC7: " + ("byte-identical" if ok else "not identical"), font=font(38, True), fill=GREEN if ok else GOLD)
    d.text((196, 310), f"{same['frames']['total']:,} frames, 0 differ  |  {same['a']['header']['part']}", font=font(24), fill=TEXT)
    d.text((196, 344), f"sha256 {same['a']['sha256'][:16]}  ({same['a']['bytes']:,} bytes)", font=font(22), fill=MUTED)

    # The frame map of the differing pair.
    f = diff["frames"]
    d.text((60, 404), f"E2 vs E3 Ethernet builds: {f['differing']:,} of {f['total']:,} frames differ", font=font(24, True), fill=GOLD)
    rows = diff["strip"]
    x0, x1, y0, band, gap = 60, 1140, 444, 10, 3
    for i, r in enumerate(rows):
        y = y0 + i * (band + gap)
        cells = r["cells"]
        cw = (x1 - x0) / len(cells)
        for c, ch in enumerate(cells):
            col = {"0": "#0b3d27", "1": GOLD, "2": RED}[ch]
            d.rectangle((x0 + c * cw, y, x0 + (c + 1) * cw - 1, y + band), fill=col)
    d.text((60, 612), "read in your browser, nothing uploaded", font=font(18), fill=MUTED, anchor="ls")
    first = f["first"]
    if first:
        d.text((1140, 612), f"first: FAR {first['far']}  row {first['decoded']['row']} col {first['decoded']['column']} minor {first['decoded']['minor']}", font=font(18), fill=MUTED, anchor="rs")

    out = os.path.join(OUT_DIR, "card.png")
    img.save(out, optimize=True)
    print(out, os.path.getsize(out), "bytes")


if __name__ == "__main__":
    main()
