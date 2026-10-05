#!/usr/bin/env python3
"""gatle-card.py -- draw public/widgets/gatle/card.png from pool.json.

The card is a finished sample board of puzzle #1. Nothing on it is typed in here: the module, its
source lines, yosys's counts and the guesses with their colours all come from pool.json, where
scripts/widget-data/gatle.mjs wrote them (the guesses are played by a fixed rule -- each one the
geometric middle of the range the feedback still allows -- and graded by the page's own rule.js).
The alt text lives in specs/widgets/gatle.t27 as IMAGE_ALT and quotes those numbers, so this
script refuses to draw a card the alt text does not describe.

Usage (from apps/website): python3 scripts/widget-data/gatle-card.py
"""
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DATA = os.path.join(SITE, "public/widgets/gatle/pool.json")
SPEC = os.path.join(SITE, "specs/widgets/gatle.t27")
OUT = os.path.join(SITE, "public/widgets/gatle/card.png")

W, H = 1200, 630
BLACK, PANEL, LINE = "#000000", "#050807", "#0f3a28"
GREEN, GOLD, RED, TEXT, MUTED = "#00ff88", "#ffd700", "#ff4d6d", "#e8fff7", "#8fa9a0"
HEAT = {"close": GREEN, "warm": GOLD, "cold": RED}
BRAND = "Trinity S\u00b3AI"


def font(size, bold=False):
    for path, index in (("/System/Library/Fonts/Menlo.ttc", 1 if bold else 0),
                        ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf" if bold else
                         "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 0)):
        if os.path.exists(path):
            return ImageFont.truetype(path, size, index=index)
    return ImageFont.load_default()


def const(spec, name):
    m = re.search(r'pub const %s : str = "(.*)";' % name, spec)
    if not m:
        sys.exit(f"gatle-card: {name} not found in {SPEC}")
    return m.group(1)


def main():
    d = json.load(open(DATA))
    s = d.get("sample")
    if not s:
        sys.exit("gatle-card: pool.json has no sample game; run scripts/widget-data/gatle.mjs first")
    spec = open(SPEC).read()
    alt = const(spec, "IMAGE_ALT")
    synth = const(spec, "K_SYNTH")
    guesses = int(re.search(r"pub const K_GUESSES : u8 = (\d+);", spec).group(1))
    close = int(re.search(r"pub const K_CLOSE_PCT : u8 = (\d+);", spec).group(1))
    if synth != d["yosys"]["answer"]:
        sys.exit("gatle-card: K_SYNTH and pool.json disagree; run scripts/widget-data/gatle.mjs")
    won = s["rows"][-1]["heat"] == "close"
    need = [f"#{s['puzzle']}", s["id"], f"{s['lut']} LUTs", f"{len(d['pool'])} real t27 modules"]
    need += [str(r["guess"]) for r in s["rows"]]
    missing = [n for n in need if n not in alt]
    if missing:
        sys.exit(f"gatle-card: IMAGE_ALT in {SPEC} does not say {missing}; update it to pool.json first")

    entry = next(p for p in d["pool"] if p["id"] == s["id"])
    src = open(os.path.join(SITE, "public", entry["src"])).read().split("\n")
    code = [l.rstrip() for l in src if l.strip() and not re.match(r"^\s*(;|//)", l)]

    img = Image.new("RGB", (W, H), BLACK)
    g = ImageDraw.Draw(img)
    g.polygon([(60, 52), (84, 52), (72, 72)], fill=GREEN)
    g.text((98, 46), BRAND, font=font(26, True), fill=GREEN)
    g.text((W - 60, 50), f"Gatle #{s['puzzle']}  {s['date']}", font=font(22), fill=GOLD, anchor="ra")

    g.text((60, 100), "Can you out-guess yosys?", font=font(50, True), fill=GREEN)
    g.text((60, 166), f"How many LUTs does a real t27 module cost? {guesses} guesses, close = within {close}%.",
           font=font(21), fill=TEXT)

    # The board: one tile per guess, coloured by heat, a triangle pointing to the truth.
    x0, y = 60, 222
    g.text((x0, y), "sample game", font=font(18), fill=MUTED)
    y += 32
    for r in s["rows"]:
        c = HEAT[r["heat"]]
        g.rounded_rectangle([x0, y, x0 + 150, y + 46], radius=8, fill=c)
        g.text((x0 + 75, y + 23), str(r["guess"]), font=font(28, True), fill=BLACK, anchor="mm")
        ax = x0 + 182
        if r["dir"] == "up":
            g.polygon([(ax, y + 34), (ax + 24, y + 34), (ax + 12, y + 12)], fill=c)
            word = "more"
        elif r["dir"] == "down":
            g.polygon([(ax, y + 12), (ax + 24, y + 12), (ax + 12, y + 34)], fill=c)
            word = "fewer"
        else:
            word = "close"
        g.text((ax + 40, y + 23), word, font=font(22), fill=c if r["dir"] == "hit" else MUTED, anchor="lm")
        y += 56

    # The module: its id, its first code lines, and what yosys said.
    px, py, pw = 470, 222, W - 60 - 470
    g.rounded_rectangle([px, py, px + pw, py + 300], radius=14, fill=PANEL, outline=LINE, width=2)
    g.text((px + 22, py + 16), s["id"], font=font(22, True), fill=GREEN)
    f = font(16)
    ly = py + 54
    shown = code[:9]
    for line in shown:
        while g.textlength(line, font=f) > pw - 44 and len(line) > 4:
            line = line[:-2]
        g.text((px + 22, ly), line, font=f, fill=TEXT)
        ly += 22
    if len(code) > len(shown):
        g.text((px + 22, ly), f"... {len(code) - len(shown)} more code lines", font=f, fill=MUTED)

    verdict = f"yosys: {s['lut']} LUTs"
    g.text((60, 560), verdict, font=font(34, True), fill=GREEN if won else GOLD)
    g.text((60 + g.textlength(verdict, font=font(34, True)) + 24, 572),
           f"{s['ff']} FFs, {s['cells']} cells   {synth}", font=font(18), fill=MUTED)
    g.text((W - 60, 600), f"{len(d['pool'])} real modules, one a day   t27.ai/widgets/gatle/", font=font(18), fill=MUTED, anchor="ra")

    img.save(OUT, optimize=True)
    size = os.path.getsize(OUT)
    if size > 1024 * 1024:
        sys.exit(f"gatle-card: {OUT} is {size} bytes, over 1 MB")
    print(f"gatle-card: wrote {os.path.relpath(OUT, SITE)} ({size} bytes): #{s['puzzle']} {s['id']}, "
          f"{s['lut']} LUTs, guesses {[r['guess'] for r in s['rows']]}")


if __name__ == "__main__":
    main()
