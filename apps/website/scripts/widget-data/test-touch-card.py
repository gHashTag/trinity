#!/usr/bin/env python3
"""test-touch-card.py -- draw public/widgets/test-touch/card.png from data.json.

Every number on the card is read from the snapshot (scripts/widget-data/test-touch.mjs). The card's
alt text and the page's HOOK live in specs/widgets/test-touch.t27 and quote those numbers, so this
script refuses to draw a card the alt text does not describe: refresh the snapshot, then update
IMAGE_ALT and HOOK, then draw.

The card names the bee pull request the HOOK quotes by title, and the file it left with no test
block. "None left" is not in data.json; it is counted here from
the same shallow clone the data script used (git show <merge>:<path>, read-only), and the script
stops if the clone or the cached pull-request list is missing.

Usage: python3 scripts/widget-data/test-touch-card.py [--git DIR]   (default $TMPDIR/test-touch-t27.git)
"""
import json
import os
import re
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DATA = os.path.join(SITE, "public/widgets/test-touch/data.json")
SPEC = os.path.join(SITE, "specs/widgets/test-touch.t27")
OUT = os.path.join(SITE, "public/widgets/test-touch/card.png")

W, H = 1200, 630
BLACK, GREEN, GOLD, RED, TEXT, MUTED, LINE = "#000000", "#00ff88", "#ffd700", "#ff4d6d", "#e8fff7", "#8fa9a0", "#16382a"
BRAND = "Trinity S\u00b3AI"
TEST_HEAD = re.compile(r"^\s*(test|invariant|bench)\b")


def font(size, bold=False):
    for path, index in (("/System/Library/Fonts/Menlo.ttc", 1 if bold else 0),
                        ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf" if bold else
                         "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 0)):
        if os.path.exists(path):
            return ImageFont.truetype(path, size, index=index)
    return ImageFont.load_default()


def blocks_in(git_dir, rev, path):
    """Test/invariant/bench block headers in <rev>:<path>; 0 when the file is gone."""
    r = subprocess.run(["git", "--git-dir", git_dir, "show", f"{rev}:{path}"], capture_output=True, text=True)
    if r.returncode != 0:
        return 0
    return sum(1 for line in r.stdout.splitlines() if TEST_HEAD.match(line))


def emptied_file(d, git_dir, quoted):
    """The bee pull request the HOOK quotes, and the .t27 file it emptied of test blocks."""
    cache = os.path.join(git_dir, "test-touch-prs.json")
    if not os.path.exists(cache):
        sys.exit(f"test-touch-card: {cache} is missing; run scripts/widget-data/test-touch.mjs first")
    oid = {p["number"]: p["mergeCommit"]["oid"] for p in json.load(open(cache))["prs"]}
    hits = [p for p in d["prs"] if p["lane"] == "bee" and p["badge"] == 3 and p["title"].startswith(quoted)]
    if len(hits) != 1:
        sys.exit(f"test-touch-card: {len(hits)} bee pull requests titled '{quoted}...' removed tests; the HOOK must name one")
    p = hits[0]
    for f in p["files"]:
        if f["k"] != "t27" or f["d"] == 0:
            continue
        before = blocks_in(git_dir, oid[p["n"]] + "^1", f["p"])
        after = blocks_in(git_dir, oid[p["n"]], f["p"])
        if before > 0 and after == 0:
            return p, before, f["p"]
    sys.exit(f"test-touch-card: #{p['n']} left test blocks in every file it touched; redraw the bottom line")


def main():
    git_dir = sys.argv[sys.argv.index("--git") + 1] if "--git" in sys.argv else os.path.join(tempfile.gettempdir(), "test-touch-t27.git")
    d = json.load(open(DATA))
    bee, hum = d["lanes"]["bee"]["vector"], d["lanes"]["human"]["vector"]
    day = d["snapshotAt"][:10]
    spec = open(SPEC).read()
    alt = re.search(r'pub const IMAGE_ALT : str = "(.*)";', spec).group(1)
    hook = re.search(r'pub const HOOK : str = "(.*)";', spec).group(1)
    quoted = re.search(r"'([^']+)'", hook).group(1)
    pr, before, path = emptied_file(d, git_dir, quoted)
    print(f"test-touch-card: #{pr['n']} took {path} from {before} test blocks to 0")
    need_alt = [day, f"over {d['days']} days", f"bees merged {bee[0]}", f"{bee[4]} removed tests or asserts",
                f"{bee[3]} changed tests", f"{bee[2]} added tests", f"{bee[1]} left them untouched",
                f"People merged {hum[0]}", f"{hum[4]} removed tests or asserts", quoted, f"all {before} tests"]
    need_hook = [f"{bee[0]} PRs", f"{d['days']} days", f"{bee[4]} deleted", f"all {before} tests"]
    missing = [n for n in need_alt if n not in alt] + [f"HOOK: {n}" for n in need_hook if n not in hook]
    if missing:
        sys.exit(f"test-touch-card: {SPEC} does not say {missing}; update IMAGE_ALT and HOOK to the snapshot first")

    img = Image.new("RGB", (W, H), BLACK)
    g = ImageDraw.Draw(img)
    g.polygon([(60, 52), (84, 52), (72, 72)], fill=GREEN)
    g.text((98, 46), BRAND, font=font(26, True), fill=GREEN)
    g.text((W - 60, 50), f"snapshot {day}", font=font(22), fill=GOLD, anchor="ra")

    g.text((60, 104), "Did the agent touch its own tests?", font=font(52, True), fill=GREEN)
    g.text((60, 176), f"{d['repo']}, last {d['days']} days: every merged pull request, read from git",
           font=font(22), fill=TEXT)

    def lane(x, name, colour, v):
        g.rounded_rectangle([x, 226, x + 520, 446], radius=16, outline=colour, width=2)
        g.text((x + 28, 244), name, font=font(26, True), fill=colour)
        big = font(72, True)
        g.text((x + 28, 280), str(v[4]), font=big, fill=RED)
        w = g.textlength(str(v[4]), font=big)
        g.text((x + 28 + w, 280), f" / {v[0]}", font=big, fill=TEXT)
        g.text((x + 28, 364), "removed tests or asserts / merged", font=font(19), fill=MUTED)
        # Stacked bar: removed, changed, added, untouched.
        bx, by, bw = x + 28, 396, 464
        parts = [(v[4], RED), (v[3], GOLD), (v[2], GREEN), (v[1], MUTED)]
        at = bx
        for i, (n, c) in enumerate(parts):
            seg = round(bw * n / v[0]) if i < 3 else bx + bw - at
            g.rectangle([at, by, at + max(seg, 2), by + 14], fill=c)
            at += seg
        g.text((bx, 418), f"changed {v[3]}  added {v[2]}  untouched {v[1]}", font=font(17), fill=MUTED)

    lane(60, "BEE  (branch queen-<N>)", GOLD, bee)
    lane(620, "HUMAN  (any other branch)", GREEN, hum)

    g.text((60, 470), f"#{pr['n']} \"{pr['title']}\"", font=font(24, True), fill=GOLD)
    g.text((60, 506), f"deleted all {before} tests in that file: {before} test blocks before, 0 after", font=font(24, True), fill=RED)
    g.text((60, 580), "A dated snapshot. A heuristic; every flagged line is on the page.", font=font(19), fill=MUTED)
    g.text((W - 60, 580), "t27.ai/widgets/test-touch/", font=font(20), fill=GREEN, anchor="ra")

    img.save(OUT, optimize=True)
    print(f"test-touch-card: wrote {OUT} ({os.path.getsize(OUT)} bytes)")


if __name__ == "__main__":
    main()
