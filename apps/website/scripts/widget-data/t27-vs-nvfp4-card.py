#!/usr/bin/env python3
# t27-vs-nvfp4-card.py -- the 1200x630 share card for public/widgets/t27-vs-nvfp4/, drawn from data.json.
# Every number on the card is read from data.json, which scripts/widget-data/t27-vs-nvfp4.mjs writes
# from the trinity-fpga run; only the words of the layout are typed here.
# Run: python3 scripts/widget-data/t27-vs-nvfp4-card.py
import json
import os
from PIL import Image, ImageDraw, ImageFont

SITE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(SITE, "public", "widgets", "t27-vs-nvfp4")
BG, WHITE, GOLD, RED, MUTED, FAINT = "#000000", "#ffffff", "#ffd700", "#ff4d6d", "#a8a8a8", "#2a2a2a"
SHOWN = {"MXPLUS": "MX+"}


def font(size, bold=False):
    home = os.path.expanduser("~/Library/Fonts")
    for path in [os.path.join(home, "DejaVuSansMono-Bold.ttf" if bold else "DejaVuSansMono.ttf"),
                 "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
                 "/System/Library/Fonts/Menlo.ttc"]:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main():
    d = json.load(open(os.path.join(OUT_DIR, "data.json")))
    arms = d["arms"]
    P = d["protocol"]
    img = Image.new("RGB", (1200, 630), BG)
    g = ImageDraw.Draw(img)

    g.text((60, 40), "Trinity S\u00b3AI", font=font(22, True), fill=WHITE)
    g.text((1140, 44), "t27.ai/widgets/t27-vs-nvfp4", font=font(18), fill=MUTED, anchor="ra")
    g.text((60, 82), "T27 vs NVFP4", font=font(54, True), fill=WHITE)
    g.text((60, 150), f"SmolLM2-135M, wikitext-2 test, {P['windows']} x {P['seqlen']} tokens, weights only",
           font=font(21), fill=MUTED)

    # Left: test perplexity bars, lower is better.
    g.text((60, 200), "perplexity, lower is better", font=font(18, True), fill=WHITE)
    hi = max(a["test"] for a in arms)
    x0, x1, y = 200, 560, 236
    for a in arms:
        t27 = a["id"] == "T27_STAR"
        col = GOLD if t27 else WHITE
        name = SHOWN.get(a["name"], a["name"])
        g.text((60, y + 12), name, font=font(20, True), fill=col, anchor="lm")
        w = (x1 - x0) * a["test"] / hi
        if a["id"] == "BASE":
            g.rectangle((x0, y, x0 + w, y + 24), outline=WHITE, width=2)
        else:
            g.rectangle((x0, y, x0 + w, y + 24), fill=col)
        g.text((x1 + 10, y + 12), f"{a['test']:.2f}", font=font(19), fill=col, anchor="lm")
        y += 42

    # Right: r = 1000 * ppl(T27) / ppl(C), with the pre-registered bars.
    rx0, rx1 = 720, 1140
    g.text((rx0, 200), "T27 / C, per mille", font=font(18, True), fill=WHITE)
    rs = d["ratios"]["test"]
    vals = [q["r"] for q in rs] + [P["beat_permille"], P["tie_permille"]]
    lo = (min(vals) - 20) // 50 * 50
    top = -(-(max(vals) + 20) // 50) * 50
    span_x0, span_x1 = rx0 + 90, rx1 - 10
    X = lambda v: span_x0 + (span_x1 - span_x0) * (v - lo) / (top - lo)
    ry0, ry1 = 236, 236 + 42 * len(rs)
    for v, lab in ((P["beat_permille"], f"BEAT {P['beat_permille']}"), (P["tie_permille"], f"TIE {P['tie_permille']}")):
        xx = X(v)
        for yy in range(ry0 - 4, ry1, 8):
            g.line((xx, yy, xx, yy + 4), fill=MUTED, width=1)
        g.text((xx + (6 if v > 1000 else -6), ry1 + 6), lab, font=font(14), fill=MUTED, anchor="la" if v > 1000 else "ra")
    y = ry0
    for q in rs:
        lose = q["verdict"] == "lose"
        col = RED if lose else WHITE
        name = SHOWN.get(q["c"], q["c"])
        g.text((rx0, y + 12), name, font=font(20, True), fill=col, anchor="lm")
        a, b = sorted((q["r"], 1000))
        g.line((X(a), y + 12, X(b), y + 12), fill=col, width=3)
        g.ellipse((X(q["r"]) - 8, y + 4, X(q["r"]) + 8, y + 20), fill=col)
        tx = X(q["r"]) + (14 if lose else -14)
        g.text((tx, y + 12), f"{q['r']:.0f}", font=font(17), fill=col, anchor="lm" if lose else "rm")
        y += 42

    # Bottom: the one claim, and what it does not show.
    nv = next(q for q in rs if q["c"] == "NVFP4")
    t27 = next(a for a in arms if a["id"] == "T27_STAR")
    nva = next(a for a in arms if a["id"] == "NVFP4")
    g.line((60, 516, 1140, 516), fill=FAINT, width=1)
    g.text((60, 530), "Better than NVFP4 on a ternary substrate", font=font(26, True), fill=GOLD)
    g.text((60, 568), f"r {nv['r']:.1f} vs bar {P['beat_permille']}; {t27['trits32']} vs {nva['trits32']} trits, "
                      f"but {t27['bits32']} vs {nva['bits32']} bits per 32. Loses to E2M2.", font=font(18), fill=WHITE)
    g.text((60, 596), "One model, no confidence interval, NVFP4 and MX+ are our reimplementations.",
           font=font(18), fill=MUTED)

    out = os.path.join(OUT_DIR, "card.png")
    img.save(out, optimize=True)
    print(out, os.path.getsize(out), "bytes")


if __name__ == "__main__":
    main()
