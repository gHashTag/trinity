#!/usr/bin/env python3
"""uart-bucket-card.py -- draw public/widgets/uart-bucket/card.png from data.json.

Every number on the card is read from data.json (scripts/widget-data/uart-bucket.mjs, which parses
the gHashTag/trinity-fpga record files). The spec's IMAGE_ALT, HOOK and DESCRIPTION quote numbers
too, so this script refuses to draw when any number in them is not one the data holds: refresh the
data, then the spec's words, then draw.

Usage: python3 scripts/widget-data/uart-bucket-card.py
"""
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DATA = os.path.join(SITE, "public/widgets/uart-bucket/data.json")
SPEC = os.path.join(SITE, "specs/widgets/uart-bucket.t27")
OUT = os.path.join(SITE, "public/widgets/uart-bucket/card.png")

W, H = 1200, 630
BLACK, WHITE, MUTED, GOLD, RED = "#000000", "#ffffff", "#a8a8a8", "#ffd700", "#ff4d6d"
BRAND = "Trinity S\u00b3AI"


def font(size, bold=False):
    for path, index in (("/System/Library/Fonts/Menlo.ttc", 1 if bold else 0),
                        ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf" if bold else
                         "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 0)):
        if os.path.exists(path):
            return ImageFont.truetype(path, size, index=index)
    return ImageFont.load_default()


def fmt(n):
    return f"{n:,}" if isinstance(n, int) else str(n)


def known_numbers(d):
    """Every number the data holds, in the spellings the spec's words may use."""
    out = set()

    def walk(v):
        if isinstance(v, bool):
            return
        if isinstance(v, (int, float)):
            out.update({str(v), fmt(v)})
        elif isinstance(v, str) and re.fullmatch(r"[\d.]+", v):
            out.add(v)
        elif isinstance(v, dict):
            for x in v.values():
                walk(x)
        elif isinstance(v, list):
            for x in v:
                walk(x)
    walk(d)
    out.update({"2102", "7203"})  # part names CP2102N and AX7203, not measurements
    return out


def check_words(d):
    spec = open(SPEC).read()
    allowed = known_numbers(d)
    bad = []
    for name in ("IMAGE_ALT", "HOOK", "DESCRIPTION", "TITLE"):
        text = re.search(rf'pub const {name} : str = "(.*)";', spec).group(1)
        for tok in re.findall(r"\d[\d,]*(?:\.\d+)?", text):
            tok = tok.rstrip(",")
            if tok not in allowed:
                bad.append(f"{name}: {tok}")
    if bad:
        sys.exit(f"uart-bucket-card: numbers in {SPEC} that data.json does not hold: {bad}")


def bucket(g, x, y, w, h, frac, label):
    """A bucket whose brim (gold) is the 512-byte buffer; frac > 1 spills in red."""
    top_l, top_r, bot_l, bot_r = x, x + w, x + w * 0.12, x + w * 0.88
    level = y + h - h * min(frac, 1.0)
    t = (level - y) / h
    wl, wr = top_l + (bot_l - top_l) * t, top_r + (bot_r - top_r) * t
    g.polygon([(wl, level), (wr, level), (bot_r, y + h), (bot_l, y + h)], fill="#cfcfcf")
    g.line([(top_l - 8, y - 10), (bot_l, y + h), (bot_r, y + h), (top_r + 8, y - 10)], fill=WHITE, width=5, joint="curve")
    for xx in range(int(top_l), int(top_r), 16):
        g.line([(xx, y), (min(xx + 9, top_r), y)], fill=GOLD, width=3)
    if frac > 1:
        for side, xx in ((-1, top_l), (1, top_r)):
            g.line([(xx, y), (xx + side * 22, y + 24), (xx + side * 26, y + h + 14)], fill=RED, width=7)
    g.text((x + w / 2, y + h + 22), label, font=font(24, True), fill=WHITE, anchor="ma")


def main():
    d = json.load(open(DATA))
    check_words(d)
    rx, ans = d["rxBytes"], d["answerBytes"]
    a64, a24 = d["arms"][0], d["arms"][1]

    img = Image.new("RGB", (W, H), BLACK)
    g = ImageDraw.Draw(img)
    g.polygon([(60, 52), (84, 52), (72, 72)], fill=WHITE)
    g.text((98, 46), BRAND, font=font(26, True), fill=WHITE)
    g.text((W - 60, 50), f"{d['board']} board, {d['date']}", font=font(22), fill=MUTED, anchor="ra")

    g.text((60, 104), "The bucket under the tap", font=font(56, True), fill=WHITE)
    g.text((60, 178), f"CP2102N receive buffer {rx} B, one answer {ans} B: {rx} / {ans} = {d['ratio']}, "
                      f"so {d['largestFit']} fit", font=font(24), fill=WHITE)

    bucket(g, 90, 270, 170, 190, a64["inFlight"] / rx, f"window {a64['window']}")
    bucket(g, 330, 270, 170, 190, a24["inFlight"] / rx, f"window {a24['window']}")
    g.text((175, 228), f"{fmt(a64['inFlight'])} B", font=font(24, True), fill=RED, anchor="ma")
    g.text((415, 228), f"{fmt(a24['inFlight'])} B", font=font(24, True), fill=WHITE, anchor="ma")

    x = 600
    g.text((x, 240), f"{fmt(d['jobsPerArm'])} jobs per window, measured", font=font(24), fill=MUTED)
    g.text((x, 290), f"window {a64['window']}", font=font(30, True), fill=WHITE)
    g.text((x, 330), f"{fmt(a64['lost'])} answers lost, {a64['elapsedS']} s", font=font(30, True), fill=RED)
    g.text((x, 390), f"window {a24['window']}", font=font(30, True), fill=WHITE)
    g.text((x, 430), f"{fmt(a24['lost'])} lost, {a24['elapsedS']} s", font=font(30, True), fill=WHITE)
    g.text((x, 490), "The smaller window cost no time.", font=font(24), fill=WHITE)

    g.text((60, 570), "The record: the pattern fits the buffer; it does not prove the buffer is the cause.",
           font=font(21), fill=MUTED)
    img.save(OUT, optimize=True)
    print(f"uart-bucket-card: wrote {os.path.relpath(OUT, SITE)} ({os.path.getsize(OUT)} bytes)")


if __name__ == "__main__":
    main()
