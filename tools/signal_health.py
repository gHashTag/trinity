#!/usr/bin/env python3
"""How much information is your build still carrying?

T12 on <https://t27.ai/#/verification>: the self-information of an observed
event is −log₂ P. A build that is red on every run has P(red) = 1, so each new
red is worth zero bits — it cannot distinguish the state of the world before it
from the state after. Detection and information are different quantities, and a
verification programme measures only the first.

That is not an abstraction. A decoder in my own chip disagreed with its
specification on 8 of 64 code points; three tests in that repository reported it,
two of them exhaustive and one against a reference not derived from the RTL, and
continuous integration ran all three. Continuous integration had been red for six
weeks — four runs, four failures. An outside tool found the defect in five
minutes and what it contributed was not a better oracle, it was a reader. One
line of RTL then turned every job in that repository green for the first time in
six weeks, so the entire standing red had exactly one cause, named in the log on
every single run.

This measures the condition rather than waiting to be reminded of it, and when
the window is not saturated it reports the FIRST red in the streak, because that
is where the defect is. When every run in the window failed, the streak is
reported as a lower bound instead -- the oldest run is the edge of what was
looked at, not the start of anything, and printing it as a start would report
the limit of the instrument as if it were the measurement.

Usage:
  python3 tools/signal_health.py --repo OWNER/NAME [--workflow ci.yml]
                                 [--window 50] [--max-streak 3]
"""

from __future__ import annotations

import argparse
import json
import math
import subprocess
import sys


def runs(repo: str, workflow: str, window: int) -> list[dict]:
    cmd = ["gh", "run", "list", "--repo", repo, "--limit", str(window),
           "--json", "conclusion,createdAt,displayTitle,url,headBranch"]
    if workflow:
        cmd += ["--workflow", workflow]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(f"gh run list failed: {out.stderr.strip()[:400]}")
    data = json.loads(out.stdout)
    # Cancelled and skipped runs are neither evidence for nor against, and
    # counting them as passes is how a red streak gets to look shorter than it is.
    return [r for r in data if r.get("conclusion") in ("success", "failure")]


def analyse(conclusions: list[str]) -> tuple[int, int, float, float]:
    """(streak, failures, P(red), bits per red) for a newest-first list.

    Split out so it can be asserted against known sequences rather than only
    exercised. A checker whose verdict is the only thing ever asserted returns
    the same answer for every input and stays green -- which is T10, and which
    happened here in the structural check for weeks.
    """
    streak = 0
    for c in conclusions:
        if c == "failure":
            streak += 1
        else:
            break
    failures = sum(1 for c in conclusions if c == "failure")
    p_red = failures / len(conclusions) if conclusions else 0.0
    # Self-information of the next red, given the observed rate. At p = 1 this is
    # exactly zero: the event carries no information because it was certain.
    bits = -math.log2(p_red) if 0 < p_red < 1 else (0.0 if p_red == 1 else float("inf"))
    return streak, failures, p_red, bits


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--workflow", default="")
    ap.add_argument("--window", type=int, default=50)
    ap.add_argument("--max-streak", type=int, default=3,
                    help="fail above this many consecutive failures")
    ap.add_argument("--json", default="")
    args = ap.parse_args()

    rs = runs(args.repo, args.workflow, args.window)
    if not rs:
        print(f"  no completed runs found for {args.repo}"
              f"{' / ' + args.workflow if args.workflow else ''}")
        # Nothing observed is not the same as nothing wrong, and it is certainly
        # not a pass. It means the instrument has never been read at all.
        return 1

    streak, failures, p_red, bits = analyse([r["conclusion"] for r in rs])

    print(f"  window        {len(rs)} completed runs"
          f"{' of ' + args.workflow if args.workflow else ''}")
    print(f"  failures      {failures}  (P(red) = {p_red:.3f})")
    saturated = streak == len(rs)
    # When every run in the window failed, the streak is a LOWER BOUND and the
    # oldest run in the window is the edge of what was looked at, not the start
    # of anything. Printing it as the start reports the limit of the instrument
    # as if it were the measurement -- which is the exact error this whole file
    # exists to name, and it was in here first.
    print(f"  current streak {'>= ' if saturated else ''}{streak} consecutive failures"
          f"{' — the window is saturated, the real streak is longer' if saturated else ''}")
    if p_red == 1:
        print(f"  information   0.000 bits — every run in the window failed, so the next red")
        print(f"                cannot distinguish the world before it from the world after")
    elif p_red == 0:
        print(f"  information   a red would be maximally informative here; the window is all green")
    else:
        print(f"  information   {bits:.3f} bits per red")

    if streak and not saturated:
        first = rs[streak - 1]
        print()
        print(f"  the streak starts at {first.get('createdAt', '?')}")
        print(f"    {first.get('displayTitle', '')}")
        print(f"    {first.get('url', '')}")
        print(f"  read THAT one. A streak has a first cause and the later reds are echoes;")
        print(f"  in the case this check was written for, all four reds had one cause and it")
        print(f"  was named in the log every time.")

    if streak and saturated:
        print()
        print(f"  where the streak starts is outside this window. Re-run with a larger")
        print(f"  --window to find the first red; that is the one worth reading.")

    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump({"repo": args.repo, "workflow": args.workflow or "all",
                       "window": len(rs), "failures": failures, "pRed": p_red,
                       "streak": streak, "streakIsLowerBound": saturated,
                       "bitsPerRed": None if p_red in (0, 1) else bits,
                       "streakStart": None if saturated else (rs[streak - 1].get("createdAt") if streak else None),
                       "streakStartUrl": None if saturated else (rs[streak - 1].get("url") if streak else None)}, f, indent=2)
            f.write("\n")

    print()
    if streak > args.max_streak:
        print(f"  FAIL {streak} consecutive failures, above the limit of {args.max_streak}")
        return 1
    print(f"  PASS streak {streak} is within the limit of {args.max_streak}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
