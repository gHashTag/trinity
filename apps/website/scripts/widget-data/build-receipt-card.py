#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""build-receipt-card.py -- public/widgets/build-receipt/card.png, the receipt itself.

Reads public/widgets/build-receipt/receipt.json (written by scripts/widget-data/build-receipt.mjs
run) for every number and sha, and specs/widgets/build-receipt.t27 for every word, then draws the
same thermal-paper receipt the widget shows, with the barcode drawn from the .bit sha256 by the
same rule as tool.js (each hex digit: one bar of width 1-4, one gap of width 1-4). 1200x630 PNG.

Run (from apps/website):  python3 scripts/widget-data/build-receipt-card.py
Needs Pillow; uses Menlo (macOS) or DejaVu Sans Mono when present.
"""
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DATA = os.path.join(SITE, "public/widgets/build-receipt/receipt.json")
SPEC = os.path.join(SITE, "specs/widgets/build-receipt.t27")
OUT = os.path.join(SITE, "public/widgets/build-receipt/card.png")
W, H = 1200, 630
BG = (0, 0, 0)
GREEN = (0, 255, 136)
GOLD = (255, 215, 0)
MUTED = (173, 201, 192)
PAPER = (243, 240, 230)
INK = (0, 0, 0)
FAINT = (93, 90, 82)
RED = (200, 30, 60)

FONTS = ["/System/Library/Fonts/Menlo.ttc", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"]


def font(size, bold=False):
    for f in FONTS:
        if os.path.exists(f):
            return ImageFont.truetype(f, size, index=1 if bold and f.endswith(".ttc") else 0)
    sys.exit("build-receipt-card: no monospace font found")


def words(path):
    """SAY_* and TITLE strings and string arrays from the spec: the card says what the page says."""
    src = open(path, encoding="ascii").read()
    out = {}
    for m in re.finditer(r'^pub const (\w+) : str = "((?:[^"\\]|\\.)*)";', src, re.M):
        out[m.group(1)] = m.group(2)
    for m in re.finditer(r'^pub const (\w+) : \[\d+\]str = \[(.*)\];', src, re.M):
        out[m.group(1)] = re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(2))
    return out


def fill(tpl, **vals):
    return re.sub(r"\{(\w+)\}", lambda m: str(vals.get(m.group(1), m.group(0))), tpl)


def bars(hexstr):
    digits = [int(c, 16) for c in hexstr.lower() if c in "0123456789abcdef"]
    parts = [1, 1, 1, 1]
    for d in digits:
        parts += [(d >> 2) + 1, (d & 3) + 1]
    parts += [1, 1, 1, 1]
    return parts


def tool_line(s):
    """The tool and its version, without saying the tool's name twice (tool.js does the same)."""
    v = s.get("version") or ""
    return v if s["tool"].split(" ")[0].lower() in v.lower() else f"{s['tool']} | {v}"


def main():
    r = json.load(open(DATA))
    S = words(SPEC)
    secs = lambda ms: fill(S["SAY_SECONDS"], s=f"{ms / 1000:.3f}")

    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    # the paper, with torn top and bottom edges
    px0, px1, py0, py1 = 300, 900, 22, 608
    d.rectangle([px0, py0, px1, py1], fill=PAPER)
    tooth = 12
    for x in range(px0, px1, tooth):
        d.polygon([(x, py0), (x + tooth / 2, py0 - 8), (x + tooth, py0)], fill=PAPER)
        d.polygon([(x, py1), (x + tooth / 2, py1 + 8), (x + tooth, py1)], fill=PAPER)

    f_shop = font(20, True)
    f_b = font(17, True)
    f = font(15)
    f_s = font(12)
    f_tot = font(22, True)
    lx, rx = px0 + 26, px1 - 26

    def center(y, text, fnt, fill_=INK):
        w = d.textlength(text, font=fnt)
        d.text(((px0 + px1 - w) / 2, y), text, font=fnt, fill=fill_)

    def item(y, left, right, fnt, fill_=INK):
        d.text((lx, y), left, font=fnt, fill=fill_)
        rw = d.textlength(right, font=fnt)
        d.text((rx - rw, y), right, font=fnt, fill=fill_)
        lw = d.textlength(left, font=fnt)
        a, b = lx + lw + 8, rx - rw - 8
        yy = y + fnt.size - 3
        x = a
        while x < b:
            d.point((x, yy), fill=FAINT)
            x += 4

    def rule(y):
        x = lx
        while x < rx:
            d.line([(x, y), (min(x + 8, rx), y)], fill=FAINT, width=2)
            x += 14

    no = (r["bit"]["payload_sha256"] if r.get("bit") else "")[:8].upper()
    y = py0 + 16
    center(y, S["SAY_SHOP"], f_shop)
    y += 28
    center(y, fill(S["SAY_RECEIPT"], no=no) + "   " + fill(S["SAY_WHEN"], when=r["when_utc"].replace("T", " ").rstrip("Z")), f_s, FAINT)
    y += 18
    center(y, r["design"]["spec"] + "  ->  " + r["design"]["part"], f_s, FAINT)
    y += 24
    rule(y)
    y += 12

    names = S["SAY_STAGE_NAMES"]
    for i, s in enumerate(r["stages"]):
        left = f"{i + 1} {names[i] if i < len(names) else s['id']}"
        if s["status"] == "not run":
            item(y, left, S["SAY_NOT_RUN"], f_b, FAINT)
        else:
            item(y, left, secs(s.get("ms", 0)), f_b, INK if s["status"] == "ok" else RED)
        y += 22
        sub = tool_line(s)
        if s.get("output"):
            sub += f" | {s['output']['sha256'][:12]}"
        if s["status"] == "failed":
            sub = fill(S["SAY_FAILED"], exit=s.get("exit", ""))
        while d.textlength(sub, font=f_s) > rx - lx - 22:
            sub = sub[:-2]
        d.text((lx + 22, y), sub, font=f_s, fill=FAINT if s["status"] != "failed" else RED)
        y += 22

    y += 2
    rule(y)
    y += 12
    if r["complete"]:
        item(y, S["SAY_TOTAL"], secs(r["total_ms"]), f_tot)
    else:
        d.text((lx, y), fill(S["SAY_NO_TOTAL"], s=secs(r["total_ms"])), font=f_b, fill=RED)
    y += 32
    item(y, S["SAY_VIVADO"], str(r.get("vendor_tools_run", 0)), f_b)
    y += 28
    rule(y)
    y += 12

    if r.get("bit"):
        sha = r["bit"]["sha256"]
        parts = bars(sha)
        unit = (rx - lx) / sum(parts)
        x = lx
        for k, wd in enumerate(parts):
            if k % 2 == 0:
                d.rectangle([round(x), y, round(x + wd * unit) - 1, y + 56], fill=INK)
            x += wd * unit
        y += 62
        center(y, sha, f_s, FAINT)
        y += 26
    center(y, S["SAY_NOT_PROGRAMMED"], f_s, INK)

    # the black field around it: the tool's name and the one fact that makes it a receipt
    t = font(20, True)
    small = font(14)
    spec = r["design"]["spec"].split("/")[-1]
    d.text((34, 40), S["SAY_LABEL_SPEC"], font=small, fill=MUTED)
    d.text((34, 60), spec, font=font(16, True), fill=GREEN)
    d.text((34, 100), S["SAY_LABEL_PART"], font=small, fill=MUTED)
    d.text((34, 120), r["design"]["part"], font=font(15, True), fill=GREEN)
    d.text((34, 150), S["SAY_LABEL_BOARD"], font=small, fill=MUTED)
    for k, ln in enumerate(re.split(r" (?=\()", r["design"]["board"])):
        d.text((34, 170 + k * 20), ln, font=font(13), fill=MUTED)
    if r.get("fmax"):
        d.text((34, 460), fill(S["SAY_FMAX"], clock=r["fmax"]["clock"], mhz=r["fmax"]["mhz"], target=r["fmax"]["target_mhz"]).replace(", ", "\n"), font=font(13), fill=MUTED)
        d.text((34, 510), S["SAY_PASS"] if r["fmax"]["pass"] else S["SAY_FAIL"], font=font(20, True), fill=GREEN if r["fmax"]["pass"] else RED)
    big = font(64, True)
    d.text((960, 380), "0", font=big, fill=GOLD)
    for k, ln in enumerate([S["SAY_VIVADO"], S["SAY_VENDOR"]]):
        d.text((960, 460 + k * 20), ln, font=small, fill=MUTED)
    d.text((960, 40), secs(r["total_ms"]), font=font(24, True), fill=GREEN)
    d.text((960, 72), fill(S["SAY_ITEMS"], ok=r["stages_ok"], count=r["stage_count"]), font=small, fill=MUTED)

    img.save(OUT, optimize=True)
    print(f"build-receipt-card: {OUT} {os.path.getsize(OUT)} B")


if __name__ == "__main__":
    main()
