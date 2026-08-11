#!/usr/bin/env python3
"""Measure the signal health of my own repositories and write it for the site.

The service sells the idea that a check is worth having only if somebody reads
it. It would be indefensible to publish that while keeping my own number in a
terminal, so this writes it into the page.

The number is not flattering and that is the point: trinity's own CI has been
red for hundreds of consecutive runs. Publishing it is cheaper than being asked.
"""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
from signal_health import runs, analyse  # noqa: E402

REPOS = [
    ("gHashTag/trinity", "ci.yml", "the repository this service is built in"),
    ("gHashTag/trinity", "conformance-selftest.yml", "the conformance check's own self-test"),
    ("gHashTag/trinity", "rtl-check-selftest.yml", "the structural check's own self-test"),
    ("gHashTag/tt-trinity-corona", "ci.yml", "my chip, where the six-week red was"),
]

out = []
for repo, wf, note in REPOS:
    try:
        rs = runs(repo, wf, 200)
    except Exception as e:
        out.append({"repo": repo, "workflow": wf, "note": note, "error": str(e)[:200]})
        print(f"  {repo} {wf}: ERROR {e}", file=sys.stderr)
        continue
    if not rs:
        out.append({"repo": repo, "workflow": wf, "note": note, "window": 0})
        continue
    streak, failures, p_red, bits = analyse([r["conclusion"] for r in rs])
    saturated = streak == len(rs)
    out.append({
        "repo": repo, "workflow": wf, "note": note,
        "window": len(rs), "failures": failures, "pRed": round(p_red, 4),
        "streak": streak, "streakIsLowerBound": saturated,
        "bitsPerRed": None if p_red in (0.0, 1.0) else round(bits, 3),
        "lastGreen": next((r["createdAt"] for r in rs if r["conclusion"] == "success"), None),
    })
    print(f"  {repo} {wf}: streak {'>=' if saturated else ''}{streak}, "
          f"{failures}/{len(rs)} failed", file=sys.stderr)

# T13: a pass carries evidence only alongside a floor on how much was checked.
# Without this, one repository failing to answer shortens the published table and
# the page shows fewer instruments without saying that it does -- a smaller
# measurement wearing the same green. The floor is the whole list, and an entry
# that errored still counts as measured because it is written out as an error.
if len(out) != len(REPOS):
    print(f"FAIL: {len(out)} entries for {len(REPOS)} instruments; something was "
          f"dropped silently and the page would have shown a shorter table",
          file=sys.stderr)
    raise SystemExit(1)

errored = [e for e in out if e.get("error")]
if errored:
    for e in errored:
        print(f"FAIL: could not measure {e['repo']} {e['workflow']}: {e['error']}", file=sys.stderr)
    raise SystemExit(1)

dest = sys.argv[1] if len(sys.argv) > 1 else "apps/website/src/data/signalHealth.json"
with open(dest, "w", encoding="utf-8") as f:
    json.dump({
        "method": "gh run list per workflow, up to 200 completed runs; cancelled and skipped "
                  "are dropped because counting them as passes shortens a red streak",
        "measure": "self-information of the next red, -log2 P(red). At P = 1 it is 0 bits.",
        "entries": out,
    }, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"wrote {dest}", file=sys.stderr)
