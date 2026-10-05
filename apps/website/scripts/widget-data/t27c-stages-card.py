#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""t27c-stages-card.py -- public/widgets/t27c-stages/card.png, drawn from a real compile.

Every number comes from public/widgets/t27c-stages/examples.json, which
scripts/widget-data/t27c-stages.mjs wrote by running public/t27/t27_compiler.wasm on the spec's
first example: the bytes, lines, tokens (with their kinds, lines and columns, which colour the
source on the left), nodes, depth, the type check, the HIR's lines and every backend's bytes.
Every word comes from specs/widgets/t27c-stages.t27, read through the same wasm by a one-line node
call, so this script holds no English of its own. Token colours are the site's highlighter palette
(src/lib/highlight.ts CLS_COLOR, as vendored in public/play/site.js). 1200x630 PNG, under 1 MB;
drawn at 2x and scaled down.

Run (from apps/website):  node scripts/widget-data/t27c-stages.mjs && python3 scripts/widget-data/t27c-stages-card.py
Needs Pillow and node; uses Menlo (macOS) or DejaVu Sans Mono when present.
"""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DIR = os.path.join(SITE, "public/widgets/t27c-stages")
OUT = os.path.join(DIR, "card.png")
W, H = 1200, 630
S = 2
BG = (0, 0, 0)
PANEL = (5, 8, 7)
GREEN = (0, 255, 136)
GOLD = (255, 215, 0)
TEXT = (232, 255, 247)
MUTED = (173, 201, 192)
SUBTLE = (143, 169, 160)
LINE = (0, 70, 40)
CLS = {"kw": (0xFF, 0xD7, 0x00), "num": (0x5A, 0xD4, 0xFF), "str": (0xC9, 0xA2, 0xFF), "ident": (0x00, 0xFF, 0x88),
       "op": (0xFF, 0x9E, 0xC4), "punct": (0x7C, 0x87, 0x94), "comment": (0x6B, 0x74, 0x80), "plain": (0xD6, 0xDD, 0xE4)}
PUNCT = {"Colon", "Comma", "LParen", "RParen", "LBrace", "RBrace", "LBracket", "RBracket", "Dot", "Semicolon"}
FONTS = ["/System/Library/Fonts/Menlo.ttc", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"]

READ_SPEC = (
    "import { readFileSync } from 'node:fs';"
    "import { loadCompiler, constsOf } from './scripts/agents-from-specs.mjs';"
    "const a = await loadCompiler(readFileSync('public/t27/t27_compiler.wasm'));"
    "const k = constsOf(a(readFileSync('specs/widgets/t27c-stages.t27', 'utf8')));"
    "process.stdout.write(JSON.stringify(Object.fromEntries(Object.entries(k).map(([n, v]) => [n, v.value]))));"
)


def font(size, bold=False):
    for f in FONTS:
        if os.path.exists(f):
            return ImageFont.truetype(f, round(size * S), index=1 if bold and f.endswith(".ttc") else 0)
    sys.exit("t27c-stages-card: no monospace font found")


def fmt(t, *v):
    out = str(t)
    for i, x in enumerate(v):
        out = out.replace("{%d}" % i, str(x))
    return out


def cls_of(kind):
    if kind.startswith("Kw"):
        return "kw"
    if kind == "Ident":
        return "ident"
    if kind == "Number":
        return "num"
    if kind in ("String", "CharLiteral"):
        return "str"
    if kind in PUNCT:
        return "punct"
    return "op"


def main():
    K = json.loads(subprocess.run(["node", "--input-type=module", "-e", READ_SPEC], cwd=SITE, check=True, capture_output=True, text=True).stdout)
    doc = json.load(open(os.path.join(DIR, "examples.json")))
    ex = doc["examples"][0]
    src = K["SAY_EXAMPLE_SOURCES"][0]

    img = Image.new("RGB", (W * S, H * S), BG)
    d = ImageDraw.Draw(img)
    P = lambda *xy: tuple(round(v * S) for v in xy)  # noqa: E731

    # Head.
    d.text(P(48, 36), K["SAY_CARD_KICKER"].upper(), font=font(15, True), fill=GREEN)
    d.text(P(48, 60), K["TITLE"], font=font(27, True), fill=(255, 255, 255))

    # Left: the source, coloured by the compiler's own tokens.
    x0, y0, lh = 48, 128, 30
    d.rounded_rectangle(P(36, 112, 532, 112 + 13 * lh + 16), radius=10 * S, fill=PANEL, outline=LINE, width=S)
    f_src = font(14)
    cw = d.textlength("M", font=f_src) / S
    by_line = {}
    for lex, kind, line, col in ex["tokens"]:
        by_line.setdefault(line, []).append((col, lex, kind))
    for i, text in enumerate(src.rstrip("\n").split("\n")):
        y = y0 + i * lh
        d.text(P(x0, y), f"{i + 1:>2}", font=f_src, fill=(60, 70, 66))
        tx = x0 + 3.2 * cw
        if text.startswith(";"):
            d.text(P(tx, y), text, font=f_src, fill=CLS["comment"])
            continue
        d.text(P(tx, y), text, font=f_src, fill=CLS["plain"])
        for col, lex, kind in by_line.get(i + 1, []):
            if text[col - 1:col - 1 + len(lex)] == lex:
                d.text(P(tx + (col - 1) * cw, y), lex, font=f_src, fill=CLS[cls_of(kind)])

    # Right: the six stages with the compiler's counts.
    names = K["SAY_STAGE_NAMES"]
    tc = ex["typecheck"]
    counts = [
        fmt(K["SAY_CHIP_BYTES"], ex["sourceBytes"]),
        fmt(K["SAY_CHIP_TOKENS"], ex["tokenCount"]),
        fmt(K["SAY_CHIP_NODES"], ex["nodeCount"]),
        K["SAY_CHIP_PASSED"] if tc["ok"] and not tc["errors"] else fmt(K["SAY_CHIP_ERRORS"], tc.get("errorCount", 0)),
        fmt(K["SAY_CHIP_LINES"], ex["hir"]["lines"]),
        fmt(K["SAY_CHIP_BACKENDS"], ex["targetsOk"], len(ex["targets"])),
    ]
    cx, cy, cwid, chei, gap = 568, 112, 186, 66, 12
    f_name, f_cnt = font(16, True), font(15)
    for i, (n, c) in enumerate(zip(names, counts)):
        col, row = i % 3, i // 3
        x, y = cx + col * (cwid + gap), cy + row * (chei + gap)
        d.rounded_rectangle(P(x, y, x + cwid, y + chei), radius=9 * S, fill=BG, outline=LINE, width=S)
        d.ellipse(P(x + 14, y + 19, x + 22, y + 27), fill=GREEN)
        d.text(P(x + 30, y + 12), f"{i + 1} {n}", font=f_name, fill=(255, 255, 255))
        d.text(P(x + 14, y + 38), c, font=f_cnt, fill=MUTED)
        if col < 2:
            d.text(P(x + cwid + 1, y + 22), ">", font=font(13), fill=SUBTLE)

    # Bytes per backend, as the compiler counted them.
    by = cy + 2 * (chei + gap) + 14
    d.text(P(cx, by), K["SAY_CARD_TARGETS"], font=font(14), fill=SUBTLE)
    ids, tnames = K["SAY_TARGET_IDS"], K["SAY_TARGET_NAMES"]
    top = max(ex["targets"][t]["bytes"] for t in ids)
    f_bar = font(13.5)
    bar_x, bar_w = cx + 170, 330
    for i, (tid, tn) in enumerate(zip(ids, tnames)):
        y = by + 30 + i * 29
        b = ex["targets"][tid]["bytes"]
        d.text(P(cx, y), tn, font=f_bar, fill=TEXT)
        d.rectangle(P(bar_x, y + 4, bar_x + bar_w * b / top, y + 16), fill=(30, 52, 44))
        d.rectangle(P(bar_x, y + 4, bar_x + 3, y + 16), fill=GREEN)
        d.text(P(bar_x + bar_w * b / top + 8, y), fmt(K["SAY_TARGET_BYTES"], f"{b:,}"), font=f_bar, fill=MUTED)

    # Foot.
    d.line(P(36, 566, W - 36, 566), fill=LINE, width=S)
    d.text(P(48, 582), K["SAY_CARD_FOOT"], font=font(16), fill=TEXT)
    img = img.resize((W, H), Image.LANCZOS)
    img.save(OUT, optimize=True)
    size = os.path.getsize(OUT)
    if size > 1024 * 1024:
        sys.exit(f"t27c-stages-card: {size} bytes, over 1 MB")
    print(f"wrote {os.path.relpath(OUT, SITE)} ({size} bytes)")


if __name__ == "__main__":
    main()
