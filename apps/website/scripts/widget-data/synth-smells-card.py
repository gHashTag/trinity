#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""synth-smells-card.py -- public/widgets/synth-smells/card.png, drawn from the four real logs.

Reads public/widgets/synth-smells/samples.json (written by scripts/widget-data/synth-smells.mjs from
yosys 0.67 runs) for every number, and specs/widgets/synth-smells.t27 for every word: the spec's
constants are read through public/t27/t27_compiler.wasm by a one-line node call, so this script
holds no English of its own. Draws one panel per sample: its name, its verdict (the same rule the
page uses), each smell it has, the cells opt_clean removed and the cells of the last stat block.
1200x630 PNG, under 1 MB.

Run (from apps/website):  python3 scripts/widget-data/synth-smells-card.py
Needs Pillow and node; uses Menlo (macOS) or DejaVu Sans Mono when present.
"""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DIR = os.path.join(SITE, "public/widgets/synth-smells")
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
LEVEL_COLOUR = [SUBTLE, GOLD, RED]

FONTS = ["/System/Library/Fonts/Menlo.ttc", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"]

# The spec's constants, as the compiler reads them.
READ_SPEC = (
    "import { readFileSync } from 'node:fs';"
    "import { loadCompiler, constsOf } from './scripts/agents-from-specs.mjs';"
    "const a = await loadCompiler(readFileSync('public/t27/t27_compiler.wasm'));"
    "const k = constsOf(a(readFileSync('specs/widgets/synth-smells.t27', 'utf8')));"
    "process.stdout.write(JSON.stringify(Object.fromEntries(Object.entries(k).map(([n, v]) => [n, v.value]))));"
)


def font(size, bold=False):
    for f in FONTS:
        if os.path.exists(f):
            return ImageFont.truetype(f, size, index=1 if bold and f.endswith(".ttc") else 0)
    sys.exit("synth-smells-card: no monospace font found")


def fmt(t, *v):
    out = str(t)
    for i, x in enumerate(v):
        out = out.replace("{%d}" % i, str(x))
    return out


def num(n):
    return f"{n:,}"


def main():
    K = json.loads(subprocess.run(["node", "--input-type=module", "-e", READ_SPEC], cwd=SITE, check=True, capture_output=True, text=True).stdout)
    data = json.load(open(os.path.join(DIR, K["K_SAMPLES_JSON"])))
    W, H = K["K_CARD_W"], K["K_CARD_H"]
    smells = K["SAY_SMELL_IDS"]
    levels = K["K_SMELL_LEVELS"]
    groups = dict(zip(K["SAY_GROUP_IDS"], K["SAY_GROUP_NAMES"]))

    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([14, 14, W - 15, H - 15], outline=LINE, width=2)
    d.text((40, 30), K["SAY_CARD_BRAND"], font=font(20, True), fill=GREEN)
    d.text((40, 60), data["tools"]["yosys"].split(" (")[0] + "  " + data["synth"], font=font(16), fill=SUBTLE)

    def fit(text, f, width):
        s = str(text)
        while len(s) > 1 and d.textlength(s, font=f) > width:
            s = s[:-2] + "~"
        return s

    pw, ph = 548, 238
    spots = [(40, 92), (612, 92), (40, 338), (612, 338)]
    for idx, sid in enumerate(K["K_SAMPLE_IDS"]):
        s = next(x for x in data["samples"] if x["id"] == sid)
        c = s["counts"]
        x0, y0 = spots[idx]
        d.rounded_rectangle([x0, y0, x0 + pw, y0 + ph], radius=10, fill=PANEL, outline=LINE, width=1)
        d.text((x0 + 16, y0 + 12), fit(K["SAY_SAMPLE_NAMES"][idx], font(19, True), pw - 32), font=font(19, True), fill=GOLD)

        # The same verdict rule as tool.js: an error refuses; else count the kinds of smell that matter.
        values = {
            "error": (c["errors"], [c["errors"]]),
            "latch": (c["latches"], [c["latches"]]),
            "undriven": (c["undriven"], [c["undriven"], c["undriven_bits"]]),
            "conflict": (c["conflicts"], [c["conflicts"]]),
            "memory": (c["memories"], [c["memories"]]),
            "removed": (c["removed_cells"], [num(c["removed_cells"]), num(c["removed_wires"])]),
            "warnings": (c["warnings"], [num(c["warnings"]), num(c["warnings_unique"])]),
        }
        if c["errors"]:
            word, colour = K["SAY_VERDICT_REFUSED"], RED
        else:
            n = sum(1 for i, sid2 in enumerate(smells) if levels[i] > 0 and values[sid2][0])
            word, colour = (K["SAY_VERDICT_CLEAN"], GREEN) if n == 0 else (K["SAY_VERDICT_ONE"] if n == 1 else fmt(K["SAY_VERDICT_SMELLS"], n), RED)
        d.text((x0 + 16, y0 + 40), word, font=font(30, True), fill=colour)

        y = y0 + 82
        rows = []
        if s.get("refused"):
            r = s["refused"]
            rows.append((fmt(K["SAY_REFUSED_LINE"], r["file"], r["line"], r["message"]), None, RED))
            rows.append((r["text"], None, MUTED))
        for i, sid2 in enumerate(smells):
            n, v = values[sid2]
            if not n or sid2 == "error":
                continue
            rows.append((K["SAY_SMELL_NAMES"][i], fmt(K["SAY_SMELL_COUNT"][i], *v), LEVEL_COLOUR[levels[i]]))
        f = font(15)
        fb = font(15, True)
        for name, count, col in rows:
            if count is None:
                d.text((x0 + 16, y), fit(name, f, pw - 32), font=f, fill=col)
            else:
                cw = d.textlength(count, font=fb)
                d.ellipse([x0 + 18, y + 5, x0 + 26, y + 13], fill=col)
                d.text((x0 + 36, y), fit(name, f, pw - 64 - cw), font=f, fill=TEXT)
                d.text((x0 + pw - 16 - cw, y), count, font=fb, fill=col)
            y += 20
        if c["cells"] or c["submodules"]:
            parts = [(c["luts"], "lut"), (c["ffs"], "ff"), (c["latch_cells"], "latch"), (c["carry"], "carry")]
            line = fmt(K["SAY_CARD_CELLS"], num(c["cells"] + c["submodules"]), ", ".join(f"{num(n)} {groups[g]}" for n, g in parts if n))
            d.text((x0 + 16, max(y + 6, y0 + ph - 30)), fit(line, font(16), pw - 32), font=font(16), fill=GREEN)

    d.text((40, H - 40), K["SAY_CARD_URL"], font=font(16), fill=SUBTLE)
    img.save(OUT, optimize=True)
    size = os.path.getsize(OUT)
    if size > 1024 * 1024:
        sys.exit(f"synth-smells-card: {OUT} is {size} bytes, over 1 MB")
    print(f"synth-smells-card: wrote {os.path.relpath(OUT, SITE)} {W}x{H}, {size} bytes")


if __name__ == "__main__":
    main()
