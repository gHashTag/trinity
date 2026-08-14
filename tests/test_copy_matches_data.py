#!/usr/bin/env python3
"""Numbers written in prose must equal the numbers in the data.

Twice now the site has told a reader something the same page disproved further
down. Once it was a block gated on the wrong array, saying the page was empty
above ten published runs. Once it was a sentence: "delivered: eight designs,
three of them other people's", written when that was true and left alone when
two more runs were published.

Both are the same failure. A hand-counted number sitting beside a generated list
drifts the moment the list grows, and nothing announces it -- the sentence still
reads confidently, in the same voice as everything true around it.

So the counts are asserted against the file the gallery actually renders. This
cannot catch every stale sentence, only the ones that carry a number, and it
says so rather than implying the prose is now verified.

Run: python3 tests/test_copy_matches_data.py
"""
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
WEB = os.path.join(ROOT, "apps", "website", "src")

runs = json.load(open(os.path.join(WEB, "data", "runs.json"), encoding="utf-8"))["runs"]
mine = [r for r in runs if str(r.get("repo", "")).lower().startswith("ghashtag/")]
others = [r for r in runs if not str(r.get("repo", "")).lower().startswith("ghashtag/")]

WORDS = {
    "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
    "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12,
    "один": 1, "одна": 1, "два": 2, "две": 2, "три": 3, "четыре": 4, "пять": 5,
    "шесть": 6, "семь": 7, "восемь": 8, "девять": 9, "десять": 10,
    "одиннадцать": 11, "двенадцать": 12,
}

tiers = open(os.path.join(WEB, "data", "verificationTiers.ts"), encoding="utf-8").read()

bad = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    global bad
    print(f"  {'PASS' if ok else 'FAIL'} {name}")
    if not ok:
        print(f"       {detail}")
        bad += 1


def numbers_in(sentence: str) -> list[int]:
    found = []
    for tok in re.findall(r"[A-Za-zА-Яа-яЁё]+|\d+", sentence):
        low = tok.lower()
        if low in WORDS:
            found.append(WORDS[low])
        elif tok.isdigit():
            found.append(int(tok))
    return found


# The structural tier's track record is the one that counts designs. Both
# languages, because a fix applied to one and not the other is how a page ends
# up disagreeing with itself in translation.
for lang in ("en", "ru"):
    m = re.search(r"^\s*" + lang + r": '(Delivered: |Сделано: )(?:[^'\\]|\\.)*',", tiers, re.M)
    check(f"the structural track record exists in {lang}", bool(m))
    if not m:
        continue
    sentence = m.group(0)
    nums = numbers_in(sentence)
    check(f"{lang}: total designs claimed == runs.json",
          len(runs) in nums, f"claimed {nums}, runs.json has {len(runs)}")
    check(f"{lang}: third-party designs claimed == runs.json",
          len(others) in nums, f"claimed {nums}, runs.json has {len(others)} not mine")

print()
print(f"  runs.json: {len(runs)} runs, {len(mine)} mine, {len(others)} not mine")
print(f"  {'' if bad else 'every counted claim matches the data. '}"
      f"This checks sentences that carry a number; a stale sentence without one")
print(f"  still needs reading.")
raise SystemExit(1 if bad else 0)
