#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""test-waves-card.py -- public/widgets/test-waves/card.png, drawn from the real demo run.

Reads public/widgets/test-waves/demo.vcd (as vvp dumped it) and demo.json (written by
scripts/widget-data/test-waves.mjs) and draws the timing diagram the widget shows: every edge,
bus value and pass mark on the card is from that simulation. 1200x630 PNG, under 1 MB.

Run (from apps/website):  python3 scripts/widget-data/test-waves-card.py
Needs Pillow; uses Menlo (macOS) or DejaVu Sans Mono when present.
"""
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DIR = os.path.join(SITE, "public/widgets/test-waves")
OUT = os.path.join(DIR, "card.png")
W, H = 1200, 630
BG = (0, 0, 0)
GREEN = (0, 255, 136)
GOLD = (255, 215, 0)
TEXT = (232, 255, 247)
MUTED = (173, 201, 192)
SUBTLE = (143, 169, 160)
LINE = (0, 70, 40)
GRID = (0, 32, 20)
ROLE = {"clock": SUBTLE, "in": GREEN, "out": GOLD, "tb": MUTED}

FONTS = ["/System/Library/Fonts/Menlo.ttc", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"]


def font(size, bold=False):
    for f in FONTS:
        if os.path.exists(f):
            return ImageFont.truetype(f, size, index=1 if bold and f.endswith(".ttc") else 0)
    sys.exit("test-waves-card: no monospace font found")


def parse_vcd(text):
    """The same subset tool.js reads: scalars and vectors, by id code."""
    tok = text.split()
    i, scope, sigs, by_id = 0, [], [], {}
    while i < len(tok):
        t = tok[i]
        i += 1
        if t == "$scope":
            scope.append(tok[i + 1])
            i += 2
        elif t == "$upscope":
            scope.pop()
        elif t == "$var":
            width, code, ref = int(tok[i + 1]), tok[i + 2], tok[i + 3]
            name = ".".join(scope + [ref])
            if code not in by_id:
                by_id[code] = {"name": name, "width": width, "ch": []}
                sigs.append(by_id[code])
            i += 4
        elif t == "$enddefinitions":
            break
        if t.startswith("$"):
            while i < len(tok) and tok[i - 1] != "$end":
                i += 1
    time, end = 0, 0
    while i < len(tok):
        t = tok[i]
        i += 1
        if t.startswith("#"):
            time = int(t[1:])
            end = max(end, time)
        elif t[0] in "01xzXZ":
            add(by_id, t[1:], time, t[0].lower())
        elif t[0] in "bB":
            add(by_id, tok[i], time, t[1:].lower())
            i += 1
    return {s["name"]: s for s in sigs}, end


def add(by_id, code, time, v):
    s = by_id.get(code)
    if not s:
        return
    if s["ch"] and s["ch"][-1][0] == time:
        s["ch"][-1] = (time, v)
    elif not s["ch"] or s["ch"][-1][1] != v:
        s["ch"].append((time, v))


def hexof(v, width):
    if re.search("[xz]", v):
        return "x"
    return format(int(v, 2), "x").zfill((width + 3) // 4)


def main():
    demo = json.load(open(os.path.join(DIR, "demo.json")))
    sigs, end = parse_vcd(open(os.path.join(DIR, "demo.vcd")).read())
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    # brand: a small point-down triangle, then the name
    d.polygon([(48, 40), (66, 40), (57, 55)], fill=GREEN)
    d.text((78, 34), "Trinity S³AI", font=font(22, True), fill=GREEN)
    d.text((W - 48, 36), "t27.ai/widgets/test-waves", font=font(17), fill=SUBTLE, anchor="ra")
    d.text((48, 78), "Test waves", font=font(46, True), fill=TEXT)
    sub = "%s -> Verilog -> Icarus Verilog" % demo["spec"]["path"]
    d.text((48, 136), sub, font=font(19), fill=MUTED)

    # the diagram
    top, row = 178, 44
    gx, xr = 212, W - 48
    rows = [s for s in demo["signals"] if s["name"] in sigs]
    scale = (xr - gx) / end
    x_of = lambda t: gx + t * scale
    for c in demo["checks"]:
        x = x_of(c["t"])
        for y in range(top, top + row * len(rows), 6):
            d.line([(x, y), (x, y + 2)], fill=(0, 90, 50) if c["pass"] else (140, 40, 60))
    small, label = font(15), font(19, True)
    for r, meta in enumerate(rows):
        s = sigs[meta["name"]]
        col = ROLE.get(meta["role"], GREEN)
        y0 = top + r * row
        d.line([(48, y0 + row), (xr, y0 + row)], fill=GRID)
        name = meta["name"].split(".")[-1]
        d.text((48, y0 + row / 2), name, font=label, fill=col, anchor="lm")
        if s["width"] > 1:
            d.text((48 + d.textlength(name, font=label) + 6, y0 + row / 2 + 1), "[%d]" % s["width"], font=small, fill=SUBTLE, anchor="lm")
        hi, lo = y0 + 9, y0 + row - 9
        mid = (hi + lo) / 2
        ch = s["ch"]
        for k, (t, v) in enumerate(ch):
            a = x_of(t)
            b = x_of(ch[k + 1][0]) if k + 1 < len(ch) else xr
            if s["width"] == 1:
                y = hi if v == "1" else lo if v == "0" else mid
                if k:
                    py = hi if ch[k - 1][1] == "1" else lo if ch[k - 1][1] == "0" else mid
                    d.line([(a, py), (a, y)], fill=col, width=2)
                d.line([(a, y), (b, y)], fill=col, width=2)
                if v == "1" and meta["role"] != "clock":
                    d.rectangle([a, hi, b, lo], fill=(0, 30, 18))
                    d.line([(a, y), (b, y)], fill=col, width=2)
            else:
                kk = min(6, (b - a) / 2)
                pts = [(a, mid), (a + kk, hi), (b - kk, hi), (b, mid), (b - kk, lo), (a + kk, lo)]
                d.polygon(pts, fill=(0, 14, 8), outline=col)
                txt = hexof(v, s["width"]).lstrip("0") or "0"
                if meta["role"] in ("out", "tb") and not re.search("[xz]", v) and s["width"] <= 32:
                    n = int(v, 2)
                    n = n - (1 << s["width"]) if n >> (s["width"] - 1) else n
                    txt = str(n)
                room = b - a - 2 * kk - 6
                f = small
                if d.textlength(txt, font=f) > room:
                    while len(txt) > 1 and d.textlength("…" + txt, font=f) > room:
                        txt = txt[1:]
                    txt = "…" + txt
                if d.textlength(txt, font=f) <= room:
                    d.text(((a + b) / 2, mid), txt, font=f, fill=TEXT, anchor="mm")
    # checks row
    yc = top + row * len(rows) + 22
    d.text((48, yc), "checks", font=label, fill=MUTED, anchor="lm")
    for c in demo["checks"]:
        x = x_of(c["t"])
        if c["pass"]:
            d.polygon([(x - 9, yc - 6), (x + 9, yc - 6), (x, yc + 8)], fill=GREEN)
        else:
            d.line([(x - 8, yc - 8), (x + 8, yc + 8)], fill=(255, 77, 109), width=3)
            d.line([(x + 8, yc - 8), (x - 8, yc + 8)], fill=(255, 77, 109), width=3)
        if c["source"] == "testbench":
            d.ellipse([x - 13, yc - 12, x + 13, yc + 14], outline=GOLD, width=2)

    s = demo["summary"]
    foot = "%d/%d checks pass  |  %d/%d spec tests  |  %s" % (s["pass"], s["total"], s["spec_pass"], s["spec_total"], demo["tools"]["iverilog"].replace(" (stable) ()", ""))
    d.text((48, H - 34), foot, font=font(17), fill=GREEN if s["pass"] == s["total"] else (255, 77, 109), anchor="lm")
    d.text((W - 48, H - 34), "drop your .vcd", font=font(17), fill=GOLD, anchor="rm")
    img.save(OUT, optimize=True)
    size = os.path.getsize(OUT)
    if size > 1024 * 1024:
        sys.exit("test-waves-card: card.png is %d bytes, over 1 MB" % size)
    print("test-waves-card: %s %dx%d %d bytes" % (os.path.relpath(OUT, SITE), W, H, size))


if __name__ == "__main__":
    main()
