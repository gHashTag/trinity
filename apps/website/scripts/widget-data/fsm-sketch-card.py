#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""fsm-sketch-card.py -- public/widgets/fsm-sketch/card.png, drawn from the real yosys samples.

Every number and every box and curve comes from public/widgets/fsm-sketch/sample.json, which
scripts/widget-data/fsm-sketch.mjs wrote from four yosys 0.67 runs: the graph is the layout
fsmparse.js (the page's own parser and layout) made of the uart_rx sample at the card's size and
font, so the card and the page draw the same thing. The refusal and its reason are the fsm_simple
log's own words as sample.json carries them. Every other word comes from
specs/widgets/fsm-sketch.t27, read through public/t27/t27_compiler.wasm by a one-line node call,
so this script holds no English of its own. 1200x630 PNG, under 1 MB; drawn at 2x and scaled down.

Run (from apps/website):  python3 scripts/widget-data/fsm-sketch-card.py
Needs Pillow and node; uses Menlo (macOS) or DejaVu Sans Mono when present.
"""
import json
import math
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DIR = os.path.join(SITE, "public/widgets/fsm-sketch")
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
S = 2  # drawn at 2x, then scaled to the card size

FONTS = ["/System/Library/Fonts/Menlo.ttc", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"]

READ_SPEC = (
    "import { readFileSync } from 'node:fs';"
    "import { loadCompiler, constsOf } from './scripts/agents-from-specs.mjs';"
    "const a = await loadCompiler(readFileSync('public/t27/t27_compiler.wasm'));"
    "const k = constsOf(a(readFileSync('specs/widgets/fsm-sketch.t27', 'utf8')));"
    "process.stdout.write(JSON.stringify(Object.fromEntries(Object.entries(k).map(([n, v]) => [n, v.value]))));"
)


def font(size, bold=False):
    for f in FONTS:
        if os.path.exists(f):
            return ImageFont.truetype(f, round(size * S), index=1 if bold and f.endswith(".ttc") else 0)
    sys.exit("fsm-sketch-card: no monospace font found")


def fmt(t, *v):
    out = str(t)
    for i, x in enumerate(v):
        out = out.replace("{%d}" % i, str(x))
    return out


def wrap(d, text, f, width):
    lines = []
    cur = ""
    for word in str(text).split():
        nxt = f"{cur} {word}" if cur else word
        if d.textlength(nxt, font=f) <= width * S or not cur:
            cur = nxt
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def P(x, y):
    return (x * S, y * S)


def text(d, xy, t, f, fill, anchor="ls", halo=False):
    kw = {"stroke_width": 3 * S, "stroke_fill": BG} if halo else {}
    d.text(P(*xy), str(t), font=f, fill=fill, anchor=anchor, **kw)


def quad(p0, c, p1, n=40):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p1[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p1[1]) for t in (i / n for i in range(n + 1))]


def cubic(p0, c1, c2, p1, n=48):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c, e = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
        out.append((a * p0[0] + b * c1[0] + c * c2[0] + e * p1[0], a * p0[1] + b * c1[1] + c * c2[1] + e * p1[1]))
    return out


def draw_graph(d, lay, ox, oy, words):
    off = lambda p: (ox + p[0], oy + p[1])
    ef = font(lay["edgeFont"])
    nf = font(lay["font"], True)
    sf = font(lay["font"] - 2)
    for e in lay["edges"]:
        pts = [off(p) for p in e["pts"]]
        path = cubic(*pts) if e["self"] else quad(*pts)
        d.line([P(*p) for p in path], fill=MUTED, width=round(1.6 * S), joint="curve")
        x, y, a = ox + e["arrow"]["x"], oy + e["arrow"]["y"], e["arrow"]["angle"]
        bx, by = x - 11 * math.cos(a), y - 11 * math.sin(a)
        nx, ny = -math.sin(a) * 5.5, math.cos(a) * 5.5
        d.polygon([P(x, y), P(bx + nx, by + ny), P(bx - nx, by - ny)], fill=MUTED)
    for e in lay["edges"]:
        lab = e["label"]
        lines = [t or words["SAY_ANY"] for t in lab["lines"]] + ([fmt(words["SAY_EDGE_MORE"], lab["more"])] if lab["more"] else [])
        lh = lay["edgeFont"] * 1.15
        total = len(lines) * lh
        y0 = lab["y"] - total + lh * 0.8 if lab["valign"] == "bottom" else lab["y"] + lh * 0.8 if lab["valign"] == "top" else lab["y"] - total / 2 + lh * 0.8
        anchor = {"start": "ls", "middle": "ms", "end": "rs"}[lab["anchor"]]
        for k, t in enumerate(lines):
            text(d, (ox + lab["x"], oy + y0 + k * lh), t, ef, SUBTLE if k >= len(lab["lines"]) else GOLD, anchor, halo=True)
    for n in lay["nodes"]:
        reset = n["i"] == lay["reset"]
        x0, y0 = ox + n["x"] - n["w"] / 2, oy + n["y"] - n["h"] / 2
        if reset:
            d.rounded_rectangle([P(x0 - 5, y0 - 5), P(x0 + n["w"] + 5, y0 + n["h"] + 5)], radius=13 * S, outline=GOLD, width=round(1.6 * S))
        d.rounded_rectangle([P(x0, y0), P(x0 + n["w"], y0 + n["h"])], radius=9 * S, fill=PANEL, outline=GOLD if reset else GREEN, width=round(1.8 * S))
        top = oy + n["y"] - len(n["lines"]) * lay["lineH"] / 2 + lay["lineH"] * 0.78
        for k, t in enumerate(n["lines"]):
            text(d, (ox + n["x"], top + k * lay["lineH"]), t, sf if k else nf, SUBTLE if k else (GOLD if reset else TEXT), "ms")


def main():
    words = json.loads(subprocess.run(["node", "--input-type=module", "-e", READ_SPEC], cwd=SITE, check=True, capture_output=True, text=True).stdout)
    data = json.load(open(os.path.join(DIR, words["K_SAMPLE_JSON"])))
    W, H = words["K_CARD_W"], words["K_CARD_H"]
    lay = data["card"]
    samples = {s["id"]: s for s in data["samples"]}
    ids = words["K_SAMPLE_IDS"]
    main_s = samples[ids[words["K_CARD_SAMPLE"]]]
    refused = next(s for s in data["samples"] if s["rejected"])
    silent = next(s for s in data["samples"] if not s["fsms"] and not s["rejected"] and not s["found"])

    img = Image.new("RGB", (W * S, H * S), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([P(15, 15), P(W - 15, H - 15)], outline=LINE, width=2 * S)
    text(d, (40, 56), words["SAY_CARD_BRAND"], font(20, True), GREEN)
    text(d, (W - 40, 56), fmt(words["SAY_VERSION"], main_s["version"]), font(18), SUBTLE, "rs")
    text(d, (40, 104), fmt(words["SAY_CARD_TITLE"], main_s["version"]), font(32, True), GOLD)

    gx, gy = 40, 128
    gw, gh = lay["w"], lay["h"]
    d.rounded_rectangle([P(gx, gy), P(gx + gw, gy + gh)], radius=12 * S, fill=BG, outline=LINE, width=2 * S)
    draw_graph(d, lay, gx, gy, words)

    rx = gx + gw + 32
    rw = W - 40 - rx
    y = 162
    text(d, (rx, y), main_s["design"], font(17), MUTED)
    y += 50
    c = lay["counts"]
    vals = [c["states"], c["transitions"], c["inputs"], c["outputs"]]
    for i, v in enumerate(vals):
        cx = rx + (i % 2) * (rw / 2)
        cy = y + (i // 2) * 70
        text(d, (cx, cy), str(v), font(44, True), GOLD)
        text(d, (cx, cy + 24), words["SAY_STAT_NAMES"][i], font(17), MUTED)
    y += 70 * 2 + 14
    d.line([P(rx, y), P(W - 40, y)], fill=LINE, width=2 * S)
    y += 36
    f18 = font(18, True)
    f16 = font(16)
    for line in wrap(d, fmt(words["SAY_CARD_REFUSED"], refused["rejected"][0]["reg"]), f18, rw):
        text(d, (rx, y), line, f18, RED)
        y += 24
    for line in wrap(d, refused["rejected"][0]["reasons"][0], f16, rw):
        text(d, (rx, y), line, f16, GOLD)
        y += 22
    y += 18
    for line in wrap(d, fmt(words["SAY_CARD_SILENT"], os.path.basename(silent["design"])), f18, rw):
        text(d, (rx, y), line, f18, RED)
        y += 24
    text(d, (W - 40, H - 40), words["SAY_CARD_URL"], font(18, True), GREEN, "rs")

    img = img.resize((W, H), Image.LANCZOS)
    img.save(OUT, optimize=True)
    size = os.path.getsize(OUT)
    if size > 1024 * 1024:
        sys.exit(f"fsm-sketch-card: {OUT} is {size} bytes, over 1 MB")
    print(f"fsm-sketch-card: wrote {os.path.relpath(OUT, SITE)} ({W}x{H}, {size} bytes) from {main_s['id']}: {vals}")


if __name__ == "__main__":
    main()
