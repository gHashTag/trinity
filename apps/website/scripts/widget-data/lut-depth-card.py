#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""lut-depth-card.py -- public/widgets/lut-depth/card.png, drawn from the real yosys sample.

Every number and every step comes from public/widgets/lut-depth/sample.json, which
scripts/widget-data/lut-depth.mjs wrote from one yosys 0.67 run (the paths as ltpparse.js -- the
page's own parser -- read them from sample.ltp.txt). Every word comes from
specs/widgets/lut-depth.t27, read through public/t27/t27_compiler.wasm by a one-line node call, so
this script holds no English of its own. The staircase is the one tool.js draws: one step per cell,
coloured by its class. 1200x630 PNG, under 1 MB. No delay and no Fmax appear on it.

Run (from apps/website):  python3 scripts/widget-data/lut-depth-card.py
Needs Pillow and node; uses Menlo (macOS) or DejaVu Sans Mono when present.
"""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DIR = os.path.join(SITE, "public/widgets/lut-depth")
OUT = os.path.join(DIR, "card.png")
BG = (0, 0, 0)
GREEN = (0, 255, 136)
GOLD = (255, 215, 0)
RED = (255, 77, 109)
TEXT = (232, 255, 247)
MUTED = (173, 201, 192)
SUBTLE = (143, 169, 160)
LINE = (0, 70, 40)
# The class colours of tool.css (.is-lut and kin).
CLASS = {"lut": GREEN, "carry": GOLD, "mux": TEXT, "io": MUTED, "other": SUBTLE, "unknown": LINE, "clocked": RED}

FONTS = ["/System/Library/Fonts/Menlo.ttc", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"]

READ_SPEC = (
    "import { readFileSync } from 'node:fs';"
    "import { loadCompiler, constsOf } from './scripts/agents-from-specs.mjs';"
    "const a = await loadCompiler(readFileSync('public/t27/t27_compiler.wasm'));"
    "const k = constsOf(a(readFileSync('specs/widgets/lut-depth.t27', 'utf8')));"
    "process.stdout.write(JSON.stringify(Object.fromEntries(Object.entries(k).map(([n, v]) => [n, v.value]))));"
)


def font(size, bold=False):
    for f in FONTS:
        if os.path.exists(f):
            return ImageFont.truetype(f, size, index=1 if bold and f.endswith(".ttc") else 0)
    sys.exit("lut-depth-card: no monospace font found")


def fmt(t, *v):
    out = str(t)
    for i, x in enumerate(v):
        out = out.replace("{%d}" % i, str(x))
    return out


def wrap(d, s, f, width):
    lines = [""]
    for w in str(s).split():
        nxt = f"{lines[-1]} {w}" if lines[-1] else w
        if d.textlength(nxt, font=f) <= width or not lines[-1]:
            lines[-1] = nxt
        else:
            lines.append(w)
    return lines


def main():
    K = json.loads(subprocess.run(["node", "--input-type=module", "-e", READ_SPEC], cwd=SITE, check=True, capture_output=True, text=True).stdout)
    data = json.load(open(os.path.join(DIR, K["K_SAMPLE_JSON"])))
    W, H = K["K_CARD_W"], K["K_CARD_H"]
    plain, fixed = data["paths"][0], data["paths"][-1]
    cells = [s for s in fixed["steps"] if s["cell"]]
    n = len(cells)
    if n != fixed["length"]:
        sys.exit(f"lut-depth-card: {n} cells listed, length {fixed['length']}")

    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([14, 14, W - 15, H - 15], outline=LINE, width=2)

    def text(xy, s, f, fill, anchor="ls"):
        d.text(xy, s, font=f, fill=fill, anchor=anchor)

    text((40, 56), K["SAY_CARD_BRAND"], font(20, True), GREEN)
    text((W - 40, 56), fmt(K["SAY_CARD_VERSION"], data["version"]), font(18), SUBTLE, "rs")

    # Left: the level count, the LUTs among them, and what plain -noff said.
    text((34, 250), str(fixed["length"]), font(190, True), GOLD)
    y = 290
    for line in wrap(d, K["SAY_LENGTH_LABEL"], font(19), 330):
        text((40, y), line, font(19), MUTED)
        y += 26
    text((40, y + 66), str(fixed["counts"]["lut"]), font(72, True), GREEN)
    text((40 + d.textlength(str(fixed["counts"]["lut"]), font=font(72, True)) + 16, y + 66), K["SAY_LUT_LABEL"], font(22), MUTED)
    tail = [s["type"] for s in plain["steps"] if s["cls"] == "clocked"]
    y += 112
    for line in wrap(d, fmt(K["SAY_CARD_PLAIN"], plain["length"], len(tail)), font(17, True), 380):
        text((40, y), line, font(17, True), RED)
        y += 26

    # Right: the staircase, step k one width right and one height up of step k-1.
    x0, x1, base, top = 430, W - 40, 432, 84
    sw = (x1 - x0) / n
    sh = (base - top) / n
    d.line([x0, base, x1, base], fill=LINE, width=2)
    lf = font(13, True)
    for k, s in enumerate(cells):
        c = CLASS.get(s["cls"], SUBTLE)
        bx = x0 + k * sw
        by = base - (k + 1) * sh
        d.rectangle([bx + 1, by + 1, bx + sw - 2, base - 1], fill=(0, 22, 13))
        d.rectangle([bx + 1, by + 1, bx + sw - 2, by + sh - 1], fill=c)
        label = s["type"] or ""
        tw = int(d.textlength(label, font=lf)) + 4
        tmp = Image.new("RGBA", (tw, 18), (0, 0, 0, 0))
        ImageDraw.Draw(tmp).text((2, 14), label, font=lf, fill=c, anchor="ls")
        rot = tmp.rotate(90, expand=True)
        img.paste(rot, (int(bx + sw / 2 - rot.width / 2), int(base + 8)), rot)

    # Legend under the labels: the classes on the path, with their counts.
    lx = x0
    for cls in ["lut", "carry", "mux", "io", "other", "unknown", "clocked"]:
        cnt = fixed["counts"].get(cls, 0)
        if not cnt:
            continue
        name = K["SAY_CLASS_NAMES"][K["SAY_CLASS_IDS"].index(cls)]
        item = f"{name} {cnt}"
        d.rectangle([lx, 514, lx + 11, 525], fill=CLASS[cls])
        text((lx + 18, 525), item, font(16), MUTED)
        lx += 18 + d.textlength(item, font=font(16)) + 24

    d.line([40, 548, W - 40, 548], fill=LINE, width=2)
    text((40, 582), K["SAY_CARD_URL"], font(20, True), GREEN)
    text((W - 40, 580), K["SAY_CARD_KIND"], font(18, True), GOLD, "rs")
    text((W - 40, 602), fixed["command"], font(14), SUBTLE, "rs")

    img.save(OUT, optimize=True)
    size = os.path.getsize(OUT)
    if size > 1024 * 1024:
        sys.exit(f"lut-depth-card: {OUT} is {size} bytes, over 1 MB")
    print(f"lut-depth-card: wrote {os.path.relpath(OUT, SITE)} ({W}x{H}, {size} bytes) from {K['K_SAMPLE_JSON']}: length {fixed['length']}, {fixed['counts']}")


if __name__ == "__main__":
    main()
