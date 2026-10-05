#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""lut-treemap-card.py -- public/widgets/lut-treemap/card.png, drawn from the real yosys sample.

Every number comes from public/widgets/lut-treemap/sample.json, which scripts/widget-data/lut-treemap.mjs
wrote from two yosys 0.67 runs (the per-module rows and edges as treemap.js -- the page's own code --
read them from sample.stat.json; the flattened total from sample.flat.stat.json). Every word, the
hues and the tile budget come from specs/widgets/lut-treemap.t27, read through
public/t27/t27_compiler.wasm by a one-line node call, so this script holds no English of its own.
The treemap is laid out the way treemap.js lays it out (one tile per instance while the parent is
one instance and the count is at most K_EXPAND_MAX; squarified), and the script stops if its tile
count or its leaf sum disagrees with sample.json. 1200x630 PNG, under 1 MB.

Run (from apps/website):  python3 scripts/widget-data/lut-treemap-card.py
Needs Pillow and node; uses Menlo (macOS) or DejaVu Sans Mono when present.
"""
import colorsys
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DIR = os.path.join(SITE, "public/widgets/lut-treemap")
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
    "const k = constsOf(a(readFileSync('specs/widgets/lut-treemap.t27', 'utf8')));"
    "process.stdout.write(JSON.stringify(Object.fromEntries(Object.entries(k).map(([n, v]) => [n, v.value]))));"
)


def font(size, bold=False):
    for f in FONTS:
        if os.path.exists(f):
            return ImageFont.truetype(f, size, index=1 if bold and f.endswith(".ttc") else 0)
    sys.exit("lut-treemap-card: no monospace font found")


def fmt(t, *v):
    out = str(t)
    for i, x in enumerate(v):
        out = out.replace("{%d}" % i, str(x))
    return out


def num(n):
    return f"{n:,}"


def pct(a, b):
    return f"{100 * a / b:.1f}%" if b else "-"


def hsl(h, s, l):
    r, g, b = colorsys.hls_to_rgb(h / 360, l / 100, s / 100)
    return (round(r * 255), round(g * 255), round(b * 255))


def fit(d, t, f, w):
    t = str(t)
    if d.textlength(t, font=f) <= w:
        return t
    while len(t) > 1 and d.textlength(t + "...", font=f) > w:
        t = t[:-1]
    return t + "..."


# --- the view tree and the squarified layout, as treemap.js builds them -------------------------
def view_tree(data, K, metric):
    mods = {m["name"]: m for m in data["modules"]}
    subs = {}
    for e in data["edges"]:
        subs.setdefault(e["parent"], []).append((e["child"], e["count"]))
    memo = {}

    def per(n):
        if n not in memo:
            memo[n] = mods[n]["each"][metric] + sum(c * per(ch) for ch, c in subs.get(n, []))
        return memo[n]

    expand = K["K_EXPAND_MAX"]

    def build(name, copies, index, of):
        node = {"name": name, "copies": copies, "index": index, "of": of, "own": False, "value": copies * per(name), "children": []}
        kids = sorted([(ch, c) for ch, c in subs.get(name, []) if c > 0 and per(ch) > 0], key=lambda x: -x[1] * per(x[0]))
        if not kids:
            return node
        if mods[name]["each"][metric] > 0:
            node["children"].append({"name": name, "copies": copies, "index": 0, "of": 0, "own": True, "value": copies * mods[name]["each"][metric], "children": []})
        for ch, c in kids:
            if copies == 1 and c <= expand:
                node["children"].extend(build(ch, 1, i, c) for i in range(1, c + 1))
            else:
                node["children"].append(build(ch, copies * c, 0, c))
        return node

    return build(data["top"], 1, 0, 0)


def leaves(n):
    return [n] if not n["children"] else [x for c in n["children"] for x in leaves(c)]


def worst(row, side):
    s = sum(a for _, a in row)
    return max(max(side * side * a / (s * s), s * s / (side * side * a)) for _, a in row)


def squarify(items, x, y, w, h):
    total = sum(i["value"] for i in items)
    if total <= 0 or w <= 0 or h <= 0:
        return []
    scale = w * h / total
    rest = sorted([(i, i["value"] * scale) for i in items if i["value"] > 0], key=lambda t: -t[1])
    out, row = [], []

    def place():
        nonlocal x, y, w, h, row
        s = sum(a for _, a in row)
        if w >= h:
            cw = s / h
            yy = y
            for it, a in row:
                out.append((it, x, yy, cw, a / cw))
                yy += a / cw
            x += cw
            w -= cw
        else:
            rh = s / w
            xx = x
            for it, a in row:
                out.append((it, xx, y, a / rh, rh))
                xx += a / rh
            y += rh
            h -= rh
        row = []

    while rest:
        side = min(w, h)
        if not row or worst(row + [rest[0]], side) <= worst(row, side):
            row.append(rest.pop(0))
        else:
            place()
    if row:
        place()
    return out


def main():
    try:
        K = json.loads(subprocess.run(["node", "--input-type=module", "-e", READ_SPEC], cwd=SITE, check=True, capture_output=True, text=True).stdout)
    except subprocess.CalledProcessError as e:
        sys.exit("lut-treemap-card: could not read the spec: " + e.stderr)
    data = json.load(open(os.path.join(DIR, K["K_SAMPLE_JSON"])))
    W, H = K["K_CARD_W"], K["K_CARD_H"]
    metric = "lut"
    tree = view_tree(data, K, metric)
    lv = leaves(tree)
    total = data["total"][metric]
    if sum(n["value"] for n in lv) != total or len(lv) != data["tiles"][metric]:
        sys.exit(f"lut-treemap-card: {len(lv)} tiles adding to {sum(n['value'] for n in lv)}; sample.json says {data['tiles'][metric]} tiles, {total}")
    hues = K["K_TILE_HUES"]
    hue = {m["name"]: hues[i % len(hues)] for i, m in enumerate(data["modules"])}
    disp = {m["name"]: m["display"] for m in data["modules"]}

    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([15, 15, W - 16, H - 16], outline=LINE, width=2)
    d.text((40, 56), K["SAY_CARD_BRAND"], font=font(20, True), fill=GREEN, anchor="ls")
    d.text((W - 40, 56), K["SAY_CARD_KIND"], font=font(18), fill=RED, anchor="rs")
    d.text((40, 104), K["SAY_CARD_TITLE"], font=font(38, True), fill=GOLD, anchor="ls")

    # The treemap, left.
    mx, my, mw, mh = 40, 128, 700, 420
    d.rectangle([mx, my, mx + mw, my + mh], fill=PANEL, outline=LINE)
    head, pad = 16, 2
    f_box, f_leaf, f_val = font(11, True), font(11), font(10)

    def draw(node, x, y, w, h, depth):
        kids = node["children"]
        hh = hue[node["name"]]
        if not kids:
            fill = hsl(hh, 50, 19) if node["own"] else hsl(hh, 62, 30)
            d.rectangle([x, y, x + w - 1, y + h - 1], fill=fill, outline=BG)
            if w >= 62 and h >= 22:
                d.text((x + 4, y + 3), fit(d, disp[node["name"]], f_leaf, w - 8), font=f_leaf, fill=TEXT)
                if h >= 38:
                    d.text((x + 4, y + 18), num(node["value"]), font=f_val, fill=MUTED)
            return
        has_head = depth > 0 and h >= head * 2.5 and w >= head * 3
        if depth > 0:
            d.rectangle([x, y, x + w - 1, y + h - 1], fill=hsl(hh, 40, 9), outline=hsl(hh, 60, 40))
            if has_head:
                label = fmt(K["SAY_TILE_COPY"], disp[node["name"]], node["index"], node["of"]) if node["index"] else disp[node["name"]]
                d.text((x + 4, y + 2), fit(d, label, f_box, w - 8), font=f_box, fill=hsl(hh, 80, 72))
        ix, iy = x + pad, y + (head if has_head else pad)
        iw, ih = w - 2 * pad, h - (head if has_head else pad) - pad
        if iw < 2 or ih < 2:
            return
        for it, cx, cy, cw, ch in squarify(kids, ix, iy, iw, ih):
            draw(it, cx, cy, cw, ch, depth + 1)

    draw(tree, mx, my, mw, mh, 0)

    # The numbers, right.
    rx, rw = 772, W - 40 - 772
    d.text((rx, 150), fit(d, disp[data["top"]], font(22, True), rw), font=font(22, True), fill=TEXT, anchor="ls")
    d.text((rx, 214), num(total), font=font(60, True), fill=GOLD, anchor="ls")
    d.text((rx + d.textlength(num(total), font=font(60, True)) + 12, 214), K["SAY_METRIC_NAMES"][0], font=font(26, True), fill=GREEN, anchor="ls")
    rows = sorted([m for m in data["modules"] if m["total"][metric] > 0], key=lambda m: -m["total"][metric])
    y = 270
    for m in rows:
        d.rectangle([rx, y - 15, rx + 15, y], fill=hsl(hue[m["name"]], 62, 30), outline=hsl(hue[m["name"]], 70, 50))
        d.text((rx + 26, y), fit(d, m["display"], font(22, True), rw - 26), font=font(22, True), fill=TEXT, anchor="ls")
        line = fmt(K["SAY_CARD_ROW"], m["instances"], num(m["each"][metric]), num(m["total"][metric]), pct(m["total"][metric], total))
        d.text((rx + 26, y + 28), fit(d, line, font(17), rw - 26), font=font(17), fill=MUTED, anchor="ls")
        y += 76
    flat = data["flat"][metric]
    delta = f"{'+' if flat >= total else ''}{100 * (flat - total) / total:.1f}%"
    d.text((rx, max(y + 6, 448)), fit(d, fmt(K["SAY_CARD_FLAT"], num(flat), delta), font(18, True), rw), font=font(18, True), fill=TEXT, anchor="ls")
    d.text((rx, max(y + 34, 476)), fit(d, fmt(K["SAY_CARD_TILES"], len(lv)), font(16), rw), font=font(16), fill=SUBTLE, anchor="ls")

    d.line([40, 572, W - 40, 572], fill=LINE, width=2)
    d.text((40, 604), K["SAY_CARD_URL"], font=font(20, True), fill=GREEN, anchor="ls")
    d.text((W - 40, 604), fmt(K["SAY_CARD_VERSION"], data["version"]), font=font(18), fill=SUBTLE, anchor="rs")

    img.save(OUT, "PNG", optimize=True)
    size = os.path.getsize(OUT)
    if size > 1024 * 1024:
        sys.exit(f"lut-treemap-card: {OUT} is {size} bytes, over 1 MB")
    print(f"lut-treemap-card: wrote {os.path.relpath(OUT, SITE)} ({W}x{H}, {size} bytes, {len(lv)} tiles, {num(total)} LUT)")


if __name__ == "__main__":
    main()
