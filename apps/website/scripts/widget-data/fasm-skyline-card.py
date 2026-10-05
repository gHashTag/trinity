#!/usr/bin/env python3
"""fasm-skyline-card.py -- draw public/widgets/fasm-skyline/card.png, the link-preview card.

The card is sample one (node.fasm, ALINX AX7203) standing on the XC7A200T die. This script does not
trust the widget's own data files for the drawing: it places every tile from prjxray-db's
tilegrid.json directly (grid_x, grid_y, type, bits) and takes the per-tile counts from
samples.json, then checks its own totals against the spec's K_NODE_* numbers and checks that
IMAGE_ALT in specs/widgets/fasm-skyline.t27 states them. It refuses to draw a card the alt text
does not describe.

Usage: python3 scripts/widget-data/fasm-skyline-card.py
       PRJXRAY_DB=/path/to/prjxray-db/artix7 overrides the default database path.
"""
import hashlib
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SPEC = os.path.join(SITE, "specs/widgets/fasm-skyline.t27")
SAMPLES = os.path.join(SITE, "public/widgets/fasm-skyline/samples.json")
OUT = os.path.join(SITE, "public/widgets/fasm-skyline/card.png")
DB = os.environ.get("PRJXRAY_DB", os.path.expanduser("~/.cache/openxc7/prjxray-db-ab1fc60/artix7"))
TILEGRID = os.path.join(DB, "xc7a200t", "tilegrid.json")

W, H, SS = 1200, 630, 2
BLACK, GREEN, GOLD, TEXT, MUTED, SUBTLE = "#000000", "#00ff88", "#ffd700", "#e8fff7", "#adc9c0", "#8fa9a0"
BRAND = "Trinity S\u00b3AI"


def font(size, bold=False):
    for path, index in (("/System/Library/Fonts/Menlo.ttc", 1 if bold else 0),
                        ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf" if bold else
                         "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 0)):
        if os.path.exists(path):
            return ImageFont.truetype(path, size * SS, index=index)
    return ImageFont.load_default()


def const(spec, name):
    m = re.search(r"pub const %s : [^=]+= (.*);" % name, spec)
    if not m:
        sys.exit(f"fasm-skyline-card: {name} not found in {SPEC}")
    return json.loads(m.group(1))


def rgb(hexs, f=1.0):
    n = int(hexs[1:], 16)
    return tuple(round(((n >> s) & 255) * f) for s in (16, 8, 0))


def main():
    spec = open(SPEC).read()
    fams, cols, floors = const(spec, "K_FAMILIES"), const(spec, "K_FAMILY_COLORS"), const(spec, "K_FLOOR_COLORS")
    prefixes, pfam = const(spec, "K_TYPE_PREFIX"), const(spec, "K_TYPE_FAMILY")

    def fam_of(t):
        for p, f in zip(prefixes, pfam):
            if t.startswith(p):
                return fams.index(f)
        return len(fams) - 1

    raw = open(TILEGRID, "rb").read()
    sha = hashlib.sha256(raw).hexdigest()
    if sha != const(spec, "K_TILEGRID_SHA256"):
        sys.exit(f"fasm-skyline-card: {TILEGRID} sha256 {sha} is not K_TILEGRID_SHA256")
    grid = json.loads(raw)
    gw = max(t["grid_x"] for t in grid.values()) + 1
    gh = max(t["grid_y"] for t in grid.values()) + 1
    config = sum(1 for t in grid.values() if t.get("bits"))

    node = next(s for s in json.load(open(SAMPLES))["samples"] if s["id"] == "node")
    placed, fam_tiles = [], [0] * len(fams)
    for name, n in node["tiles"]:
        t = grid.get(name)
        if t is None:
            sys.exit(f"fasm-skyline-card: {name} is not a tile of tilegrid.json")
        f = fam_of(t["type"])
        fam_tiles[f] += 1
        placed.append((t["grid_x"], t["grid_y"], f, n, name))
    tiles, feats = len(placed), sum(p[3] for p in placed)
    tall = max(placed, key=lambda p: p[3])
    share = (tiles * 10000 + config // 2) // config
    got = {"K_GRID_W": gw, "K_GRID_H": gh, "K_CONFIG_TILES": config, "K_NODE_TILES": tiles,
           "K_NODE_FEATURES": feats, "K_NODE_TALLEST": tall[3], "K_NODE_TALLEST_TILE": tall[4],
           "K_NODE_SHARE_BP": share, "K_NODE_SHA256": node["sha256"], "K_NODE_FAMILY_TILES": fam_tiles}
    bad = {k: (v, const(spec, k)) for k, v in got.items() if const(spec, k) != v}
    if bad:
        sys.exit(f"fasm-skyline-card: the tilegrid and samples.json disagree with the spec: {bad}")

    pct = f"{share // 100}.{share % 100:02d}%"
    alt = const(spec, "IMAGE_ALT")
    need = [f"{gw} x {gh}", f"{feats} features", f"{tiles} tiles", pct, f"{config} tiles", tall[4], f"{tall[3]} features", "AX7203"]
    missing = [n for n in need if n not in alt]
    if missing:
        sys.exit(f"fasm-skyline-card: IMAGE_ALT does not say {missing}; update it first")

    img = Image.new("RGB", (W * SS, H * SS), BLACK)
    g = ImageDraw.Draw(img)

    # The die: same projection as tool.js, (u, v, z) -> (u - v, (u + v) / 2 - z), heights
    # relative to the tallest column, K_HEIGHT_PCT percent of the mean grid side.
    hk = const(spec, "K_HEIGHT_PCT") / 100 * ((gw + gh) / 2) / tall[3]
    ax0, ay0, aw, ah = 410, 30, W - 430, H - 60
    zmax = tall[3] * hk
    s = min(aw / (gw + gh), ah / ((gw + gh) / 2 + zmax)) * SS
    ox = (ax0 + aw / 2) * SS - s * (gw - gh) / 2
    oy = (ay0 + ah) * SS - s * ((gw + gh) / 2)

    def P(u, v, z=0.0):
        return (ox + s * (u - v), oy + s * ((u + v) / 2 - z))

    for t in grid.values():
        u, v = t["grid_x"], t["grid_y"]
        g.polygon([P(u, v), P(u + 1, v), P(u + 1, v + 1), P(u, v + 1)], fill=rgb(floors[fam_of(t["type"])]))
    for u, v, f, n, _ in sorted(placed, key=lambda p: (p[0] + p[1], p[0])):
        z = n * hk
        c = cols[f]
        g.polygon([P(u, v + 1, z), P(u + 1, v + 1, z), P(u + 1, v + 1), P(u, v + 1)], fill=rgb(c, 0.55))
        g.polygon([P(u + 1, v, z), P(u + 1, v + 1, z), P(u + 1, v + 1), P(u + 1, v)], fill=rgb(c, 0.38))
        g.polygon([P(u, v, z), P(u + 1, v, z), P(u + 1, v + 1, z), P(u, v + 1, z)], fill=rgb(c))

    k = SS
    g.polygon([(60 * k, 52 * k), (84 * k, 52 * k), (72 * k, 72 * k)], fill=GREEN)
    g.text((98 * k, 46 * k), BRAND, font=font(26, True), fill=GREEN)
    g.text((60 * k, 100 * k), "FASM", font=font(60, True), fill=GREEN)
    g.text((60 * k, 166 * k), "skyline", font=font(60, True), fill=GREEN)
    g.text((60 * k, 246 * k), f"{feats:,} features", font=font(28, True), fill=TEXT)
    g.text((60 * k, 284 * k), f"{tiles:,} tiles, {pct} of the die", font=font(22), fill=TEXT)
    g.text((60 * k, 318 * k), f"tallest {tall[4]}: {tall[3]}", font=font(18), fill=MUTED)
    y = 360
    for i, f in enumerate(fams):
        if not fam_tiles[i]:
            continue
        g.rectangle([60 * k, (y + 3) * k, 74 * k, (y + 17) * k], fill=cols[i])
        g.text((84 * k, y * k), f"{f} {fam_tiles[i]:,}", font=font(18), fill=MUTED)
        y += 26
    g.text((60 * k, 540 * k), f"ALINX AX7203, {node['part']}", font=font(17), fill=SUBTLE)
    g.text((60 * k, 566 * k), "t27.ai/widgets/fasm-skyline/", font=font(18), fill=GOLD)

    img = img.resize((W, H), Image.LANCZOS)
    img.save(OUT, optimize=True)
    size = os.path.getsize(OUT)
    if size > 1024 * 1024:
        sys.exit(f"fasm-skyline-card: {OUT} is {size} bytes, over 1 MB")
    print(f"fasm-skyline-card: {tiles} tiles, {feats} features, tallest {tall[4]} {tall[3]}, share {pct}; wrote {OUT} ({size} bytes)")


if __name__ == "__main__":
    main()
