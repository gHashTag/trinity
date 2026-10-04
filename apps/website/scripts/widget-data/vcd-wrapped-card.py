#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""vcd-wrapped-card.py -- public/widgets/vcd-wrapped/card.png, drawn from a real sample run.

Asks scripts/widget-data/vcd-wrapped.mjs --card-data for the spec's words (SAY_*) and the card
sample's summary (K_CARD_SAMPLE in specs/widgets/vcd-wrapped.t27, as samples.json holds it after
vcdstats.js read the VCD vvp dumped). Every number and word on the card comes from there; this file
holds only the layout, the same one tool.js draws when the reader saves a card. 1200x630 PNG,
under 1 MB.

Run (from apps/website, after node scripts/widget-data/vcd-wrapped.mjs):
  python3 scripts/widget-data/vcd-wrapped-card.py
Needs Pillow and node; uses Menlo (macOS) or DejaVu Sans Mono when present.
"""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(SITE, "public/widgets/vcd-wrapped/card.png")
W, H = 1200, 630
BG = (0, 0, 0)
GREEN = (0, 255, 136)
GOLD = (255, 215, 0)
RED = (255, 77, 109)
TEXT = (232, 255, 247)
MUTED = (173, 201, 192)
SUBTLE = (143, 169, 160)
LINE = (0, 70, 40)
BAR_BG = (0, 32, 20)

FONTS = ["/System/Library/Fonts/Menlo.ttc", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"]


def font(size, bold=False):
    for f in FONTS:
        if os.path.exists(f):
            return ImageFont.truetype(f, size, index=1 if bold and f.endswith(".ttc") else 0)
    sys.exit("vcd-wrapped-card: no monospace font found")


def fmt(template, *args):
    for i, a in enumerate(args):
        template = template.replace("{%d}" % i, str(a))
    return template


def num(n):
    return "{:,}".format(n)


def fit(d, text, f, room):
    """Cuts text from the left (keeps the leaf of a hierarchical name) until it fits."""
    if d.textlength(text, font=f) <= room:
        return text
    while len(text) > 1 and d.textlength("..." + text, font=f) > room:
        text = text[1:]
    return "..." + text


def wrap(d, text, f, room):
    lines, cur = [], ""
    for w in text.split(" "):
        t = (cur + " " + w).strip()
        if d.textlength(t, font=f) > room and cur:
            lines.append(cur)
            cur = w
        else:
            cur = t
    if cur:
        lines.append(cur)
    return lines


def main():
    raw = subprocess.run(["node", "scripts/widget-data/vcd-wrapped.mjs", "--card-data"], cwd=SITE, capture_output=True, text=True)
    if raw.returncode != 0:
        sys.exit("vcd-wrapped-card: vcd-wrapped.mjs --card-data failed:\n" + raw.stderr)
    data = json.loads(raw.stdout)
    S, s = data["say"], data["sample"]["summary"]
    value, unit = data["span"]
    span = "%s %s" % (("%g" % value), S["SAY_UNITS"][unit]) if unit >= 0 else "%s %s" % (num(value), S["SAY_NO_TIMESCALE"])

    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    # brand row
    d.polygon([(48, 40), (66, 40), (57, 55)], fill=GREEN)
    d.text((78, 47), S["SAY_CARD_BRAND"], font=font(20, True), fill=GREEN, anchor="lm")
    d.text((W - 48, 47), S["SAY_CARD_URL"].split(" ")[0], font=font(17), fill=SUBTLE, anchor="rm")

    # left: the headline
    d.text((48, 98), S["SAY_KICKER"], font=font(26, True), fill=GOLD, anchor="ls")
    head = S["SAY_HEADLINE"]
    before, _, after = head.partition("{0}")
    big = font(124, True)
    d.text((44, 238), before + num(s["changes"]), font=big, fill=GREEN, anchor="ls")
    d.text((48, 288), after.strip(), font=font(36, True), fill=TEXT, anchor="ls")
    d.text((48, 330), fmt(S["SAY_SUBHEAD"], span), font=font(22), fill=MUTED, anchor="ls")
    if s["busiest"]:
        top = s["busiest"][0]
        line = fmt(S["SAY_BUSIEST_LINE"], top["name"], num(top["changes"]))
    else:
        line = S["SAY_NO_MOVERS"]
    y = 384
    for ln in wrap(d, line, font(22, True), 600)[:2]:
        d.text((48, y), ln, font=font(22, True), fill=TEXT, anchor="ls")
        y += 32

    # right: busiest nets as bars, then the names that never left X or Z
    x0, x1 = 700, W - 48
    d.line([(x0 - 28, 80), (x0 - 28, 446)], fill=LINE, width=1)
    d.text((x0, 98), S["SAY_LIST_TITLES"][0], font=font(20, True), fill=GOLD, anchor="ls")
    rows = s["busiest"][:5]
    most = max([r["changes"] for r in rows] or [1])
    small, label = font(16), font(18, True)
    y = 128
    for r in rows:
        cnt = num(r["changes"])
        room = x1 - x0 - d.textlength(cnt, font=label) - 12
        d.text((x0, y), fit(d, r["name"], label, room), font=label, fill=TEXT, anchor="ls")
        d.text((x1, y), cnt, font=label, fill=GREEN, anchor="rs")
        d.rectangle([x0, y + 8, x1, y + 14], fill=BAR_BG)
        d.rectangle([x0, y + 8, x0 + max(3, (x1 - x0) * r["changes"] / most), y + 14], fill=GREEN)
        y += 46
    y += 8
    stuck_col = RED if s["stuck_xz"] else SUBTLE
    d.text((x0, y), S["SAY_LIST_TITLES"][2], font=font(18, True), fill=stuck_col, anchor="ls")
    y += 26
    names = s["stuck_xz_names"][:3]
    for n in names:
        d.text((x0, y), fit(d, n, small, x1 - x0), font=small, fill=MUTED, anchor="ls")
        y += 22
    rest = s["stuck_xz"] - len(names)
    if rest > 0:
        d.text((x0, y), fmt(S["SAY_MORE"], rest), font=small, fill=SUBTLE, anchor="ls")
    elif not names:
        d.text((x0, y), S["SAY_NONE"], font=small, fill=SUBTLE, anchor="ls")

    # tiles
    vals = [s["flips"], s["signals"], s["scopes"], s["stamps"], s["stuck_xz"], s["ends_xz"]]
    n = len(vals)
    gap = 12
    tw = (W - 96 - gap * (n - 1)) / n
    ty = 470
    for i, v in enumerate(vals):
        tx = 48 + i * (tw + gap)
        bad = i >= 4 and v > 0
        d.rectangle([tx, ty, tx + tw, ty + 92], outline=RED if bad else LINE, width=2)
        d.text((tx + 16, ty + 50), num(v), font=font(38, True), fill=RED if bad else GREEN, anchor="ls")
        d.text((tx + 16, ty + 76), S["SAY_TILE_NAMES"][i], font=font(15), fill=MUTED, anchor="ls")

    # footer
    tool = (s.get("version") or "").strip()
    foot = data["name"] + ("  |  " + fmt(S["SAY_VERSION"], tool) if tool else "")
    d.text((48, H - 30), foot, font=font(16), fill=SUBTLE, anchor="lm")
    d.text((W - 48, H - 30), S["SAY_DROP"], font=font(16, True), fill=GOLD, anchor="rm")

    img.save(OUT, optimize=True)
    size = os.path.getsize(OUT)
    if size > 1024 * 1024:
        sys.exit("vcd-wrapped-card: card.png is %d bytes, over 1 MB" % size)
    print("vcd-wrapped-card: %s %dx%d %d bytes, from sample %s" % (os.path.relpath(OUT, SITE), W, H, size, data["sample"]["id"]))


if __name__ == "__main__":
    main()
