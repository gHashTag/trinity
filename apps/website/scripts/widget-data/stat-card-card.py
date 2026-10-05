#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""stat-card-card.py -- public/widgets/stat-card/card.png, drawn from the real yosys sample.

Every number comes from public/widgets/stat-card/sample.json, which scripts/widget-data/stat-card.mjs
wrote from one yosys 0.67 run (types and groups as statparse.js -- the page's own parser -- read
them from sample.stat.json). Every word comes from specs/widgets/stat-card.t27, read through
public/t27/t27_compiler.wasm by a one-line node call, so this script holds no English of its own.
The layout is the one tool.js draws in the reader's browser, so the shared card and the page agree.
1200x630 PNG, under 1 MB.

Run (from apps/website):  python3 scripts/widget-data/stat-card-card.py
Needs Pillow and node; uses Menlo (macOS) or DejaVu Sans Mono when present.
"""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DIR = os.path.join(SITE, "public/widgets/stat-card")
OUT = os.path.join(DIR, "card.png")
BG = (0, 0, 0)
PANEL = (5, 8, 7)
GREEN = (0, 255, 136)
GOLD = (255, 215, 0)
RED = (255, 77, 109)
TEXT = (232, 255, 247)
MUTED = (173, 201, 192)
SUBTLE = (143, 169, 160)
LINE = (0, 70, 40)

FONTS = ["/System/Library/Fonts/Menlo.ttc", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"]

READ_SPEC = (
    "import { readFileSync } from 'node:fs';"
    "import { loadCompiler, constsOf } from './scripts/agents-from-specs.mjs';"
    "const a = await loadCompiler(readFileSync('public/t27/t27_compiler.wasm'));"
    "const k = constsOf(a(readFileSync('specs/widgets/stat-card.t27', 'utf8')));"
    "process.stdout.write(JSON.stringify(Object.fromEntries(Object.entries(k).map(([n, v]) => [n, v.value]))));"
)


def font(size, bold=False):
    for f in FONTS:
        if os.path.exists(f):
            return ImageFont.truetype(f, size, index=1 if bold and f.endswith(".ttc") else 0)
    sys.exit("stat-card-card: no monospace font found")


def fmt(t, *v):
    out = str(t)
    for i, x in enumerate(v):
        out = out.replace("{%d}" % i, str(x))
    return out


def num(n):
    return f"{n:,}"


def fit(d, text, f, width):
    t = str(text)
    if d.textlength(t, font=f) <= width:
        return t
    while len(t) > 1 and d.textlength(t + "...", font=f) > width:
        t = t[:-1]
    return t + "..."


def wrap_items(d, items, f, width, max_lines):
    lines = [""]
    for it in items:
        cur = lines[-1]
        nxt = f"{cur}   {it}" if cur else it
        if d.textlength(nxt, font=f) <= width or not cur:
            lines[-1] = nxt
        elif len(lines) < max_lines:
            lines.append(it)
        else:
            lines[-1] = fit(d, f"{cur}   {it}", f, width)
            break
    return [l for l in lines if l]


def main():
    K = json.loads(subprocess.run(["node", "--input-type=module", "-e", READ_SPEC], cwd=SITE, check=True, capture_output=True, text=True).stdout)
    data = json.load(open(os.path.join(DIR, K["K_SAMPLE_JSON"])))
    W, H = K["K_CARD_W"], K["K_CARD_H"]
    groups, types = data["groups"], data["types"]

    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([14, 14, W - 15, H - 15], outline=LINE, width=2)

    # Text is placed by its baseline ("ls"), as the canvas in tool.js does.
    def text(xy, s, f, fill, anchor="ls"):
        d.text(xy, s, font=f, fill=fill, anchor=anchor)

    text((40, 56), K["SAY_CARD_BRAND"], font(20, True), GREEN)
    ver = fmt(K["SAY_VERSION"], data["version"]) if data.get("version") else K["SAY_NO_VERSION"]
    text((W - 40, 56), ver, font(18), SUBTLE, "rs")
    text((40, 104), K["SAY_TOP"] if data.get("top") else K["SAY_NO_TOP"], font(18), MUTED)
    text((40, 156), fit(d, data.get("top") or "", font(46, True), W - 80), font(46, True), GOLD)
    text((40, 192), K["SAY_CARD_KIND"], font(20, True), RED)

    gap = 20
    tw = (W - 80 - gap * 3) / 4
    for i, g in enumerate(K["SAY_GROUP_IDS"]):
        x = 40 + i * (tw + gap)
        y = 218
        d.rectangle([x, y, x + tw, y + 210], fill=PANEL, outline=LINE, width=2)
        text((x + 18, y + 40), K["SAY_GROUP_NAMES"][i], font(24, True), GREEN)
        n = groups[g]
        text((x + 18, y + 118), fit(d, num(n), font(64, True), tw - 36), font(64, True), TEXT if n else SUBTLE)
        text((x + 18, y + 150), fit(d, K["SAY_GROUP_RULES"][i], font(14), tw - 36), font(14), SUBTLE)
        items = [f"{t['type']} {num(t['n'])}" for t in types if t["group"] == g]
        for k, line in enumerate(wrap_items(d, items, font(15), tw - 36, 2)):
            text((x + 18, y + 176 + k * 20), line, font(15), MUTED)

    others = sorted([t for t in types if t["group"] == "other"], key=lambda t: -t["n"])
    cap = K["K_CARD_OTHER_MAX"]
    shown = [f"{t['type']} {num(t['n'])}" for t in others[:cap]]
    if len(others) > cap:
        shown.append(fmt(K["SAY_OTHER_MORE"], len(others) - cap))
    head = f"{K['SAY_OTHER']} {num(groups['other'])}"
    text((40, 474), head, font(22, True), GREEN)
    hx = 40 + d.textlength(head, font=font(22, True)) + 24
    lines = wrap_items(d, shown, font(18), W - 40 - hx, 2) if shown else [K["SAY_OTHER_NONE"]]
    for k, line in enumerate(lines):
        text((hx, 474 + k * 26), line, font(18), MUTED)

    d.line([40, 548, W - 40, 548], fill=LINE, width=2)
    text((40, 586), K["SAY_CARD_URL"], font(20, True), GREEN)
    text((W - 40, 586), fmt(K["SAY_CELLS"], num(data["cells"])), font(18), SUBTLE, "rs")

    img.save(OUT, optimize=True)
    size = os.path.getsize(OUT)
    if size > 1024 * 1024:
        sys.exit(f"stat-card-card: {OUT} is {size} bytes, over 1 MB")
    print(f"stat-card-card: wrote {os.path.relpath(OUT, SITE)} ({W}x{H}, {size} bytes) from {K['K_SAMPLE_JSON']}: {groups}")


if __name__ == "__main__":
    main()
