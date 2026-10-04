#!/usr/bin/env python3
"""race-the-bee-card.py -- draw public/widgets/race-the-bee/card.png from data.json.

Every number on the card is read from the snapshot (scripts/widget-data/race-the-bee.mjs). The
card's alt text lives in specs/widgets/race-the-bee.t27 as IMAGE_ALT and quotes those numbers, so
this script refuses to draw a card the alt text does not describe: refresh the snapshot, then
update IMAGE_ALT, then draw.

Usage: python3 scripts/widget-data/race-the-bee-card.py
"""
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

SITE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DATA = os.path.join(SITE, "public/widgets/race-the-bee/data.json")
SPEC = os.path.join(SITE, "specs/widgets/race-the-bee.t27")
OUT = os.path.join(SITE, "public/widgets/race-the-bee/card.png")

W, H = 1200, 630
BLACK, GREEN, GOLD, TEXT, MUTED = "#000000", "#00ff88", "#ffd700", "#e8fff7", "#8fa9a0"
BRAND = "Trinity S\u00b3AI"


def font(size, bold=False):
    for path, index in (("/System/Library/Fonts/Menlo.ttc", 1 if bold else 0),
                        ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf" if bold else
                         "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 0)):
        if os.path.exists(path):
            return ImageFont.truetype(path, size, index=index)
    return ImageFont.load_default()


def main():
    d = json.load(open(DATA))
    bee, hum = d["lanes"]["bee"], d["lanes"]["human"]
    races = d["contested"]
    day = d["snapshotAt"][:10]
    human_first = sum(1 for c in races if c["openedFirstBy"] == "human")
    bee_merged_first = sum(1 for c in races if c["firstMergedBy"] == "bee")

    alt = re.search(r'pub const IMAGE_ALT : str = "(.*)";', open(SPEC).read()).group(1)
    need = [day, f"bees merged {bee['merged']}", f"{bee['portTasks']} of them port tasks",
            f"people merged {hum['merged']}", f"all {len(races)} issues"]
    if not (human_first == bee_merged_first == len(races)):
        need.append("UPDATE THE HEAD-TO-HEAD SENTENCE")
    missing = [n for n in need if n not in alt]
    if missing:
        sys.exit(f"race-the-bee-card: IMAGE_ALT in {SPEC} does not say {missing}; update it to the snapshot first")

    img = Image.new("RGB", (W, H), BLACK)
    g = ImageDraw.Draw(img)
    # Brand with a small point-down triangle.
    g.polygon([(60, 52), (84, 52), (72, 72)], fill=GREEN)
    g.text((98, 46), BRAND, font=font(26, True), fill=GREEN)
    g.text((W - 60, 50), f"snapshot {day}", font=font(22), fill=GOLD, anchor="ra")

    g.text((60, 110), "Race the bee", font=font(64, True), fill=GREEN)
    g.text((60, 190), f"{d['repo']}, last {d['days']} days: merged pull requests that close an issue",
           font=font(22), fill=TEXT)

    def lane(x, name, colour, L, line):
        g.rounded_rectangle([x, 245, x + 520, 462], radius=16, outline=colour, width=2)
        g.text((x + 28, 265), name, font=font(28, True), fill=colour)
        g.text((x + 28, 302), str(L["merged"]), font=font(80, True), fill=TEXT)
        g.text((x + 28, 398), line, font=font(20), fill=MUTED)
        g.text((x + 28, 424), f"median {L['medianHoursIssueToMerge']} h, issue opened to merge", font=font(20), fill=MUTED)

    lane(60, "BEE  (branch queen-<N>)", GOLD, bee,
         f"{bee['portTasks']} of them machine-filed port tasks")
    lane(620, "HUMAN  (any other branch)", GREEN, hum,
         f"{hum['portTasks']} of them machine-filed port tasks")

    g.text((60, 485), f"{len(races)} issues both lanes went for:", font=font(26, True), fill=TEXT)
    g.text((60, 522), f"the person opened first {human_first}/{len(races)}, "
                      f"the bee merged first {bee_merged_first}/{len(races)}",
           font=font(26, True), fill=GOLD)
    g.text((60, 580), "A dated snapshot, not a live race.", font=font(20), fill=MUTED)
    g.text((W - 60, 580), "t27.ai/widgets/race-the-bee/", font=font(20), fill=GREEN, anchor="ra")

    img.save(OUT, optimize=True)
    print(f"race-the-bee-card: wrote {OUT} ({os.path.getsize(OUT)} bytes)")


if __name__ == "__main__":
    main()
