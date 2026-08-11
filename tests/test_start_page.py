#!/usr/bin/env python3
"""The start page must describe every check, and every check must show a verdict.

The page is the service's front door: four checks, each with a badge saying its
own self-test is currently green. Two ways that decays silently, and neither
shows up as an error:

  * a check is added to the offering and not to the page, so the page quietly
    describes less than exists;
  * a check loses its badge, and the missing verdict reads as "no claim made"
    rather than "we stopped checking".

Both are absences, and an absence is exactly what nobody notices — which is why
this asserts the counts and the identifiers rather than that the files parse.

Run: python3 tests/test_start_page.py
"""
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
WEB = os.path.join(ROOT, "apps", "website", "src")

checks_ts = open(os.path.join(WEB, "data", "checks.ts"), encoding="utf-8").read()
status = json.load(open(os.path.join(WEB, "data", "checkStatus.json"), encoding="utf-8"))

check_ids = re.findall(r"^\s*id: '([a-z]+)',", checks_ts, re.M)
status_ids = [e["id"] for e in status.get("entries", [])]

bad = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    global bad
    print(f"  {'PASS' if ok else 'FAIL'} {name}")
    if not ok:
        print(f"       {detail}")
        bad += 1


check("the page describes four checks", len(check_ids) == 4, f"found {len(check_ids)}: {check_ids}")
check("every check has a verdict", sorted(check_ids) == sorted(status_ids),
      f"described {sorted(check_ids)} vs attested {sorted(status_ids)}")
check("no verdict is missing its conclusion",
      all(e.get("conclusion") for e in status["entries"]),
      str([e for e in status["entries"] if not e.get("conclusion")]))
check("every check names the workflow a reader can copy",
      all(f"{cid}" in checks_ts for cid in check_ids) and checks_ts.count("uses: gHashTag/trinity") == 4,
      f"{checks_ts.count('uses: gHashTag/trinity')} snippets for {len(check_ids)} checks")
# Counted at the data indentation, not anywhere: the type declaration above the
# array also says `refuses:`, and matching it made this assert 5 for 4 checks --
# an off-by-one that a laxer test would have absorbed by asserting ">= 4".
refusals = len(re.findall(r"^    refuses: \{", checks_ts, re.M))
check("every check states what it refuses to claim", refusals == 4,
      f"{refusals} refusals for {len(check_ids)} checks")
check("the order is 1..4 with no gaps",
      sorted(int(n) for n in re.findall(r"^\s*order: (\d+),", checks_ts, re.M)) == [1, 2, 3, 4],
      str(re.findall(r"^\s*order: (\d+),", checks_ts, re.M)))

print()
print(f"  {6 - bad}/6 invariants hold")
raise SystemExit(1 if bad else 0)
