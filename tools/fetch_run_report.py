#!/usr/bin/env python3
"""Put a real report on the page, taken from a real run.

The site could describe what the free check reports and could link to a sample
written by hand. Neither is the thing. A visitor deciding whether to spend six
lines of YAML on this wants to see the actual output, with the actual numbers,
from a run they can open and read for themselves.

So this pulls the latest successful run of the check out of GitHub, extracts the
lines it wrote, and hands them to the page. Hand-written samples drift from what
the tool actually says; this cannot, because it is what the tool actually said.

T13 is why the floor exists. If an extraction pattern stops matching — a log
format change, a renamed step — the honest failure is an empty report, and an
empty report rendered as a card is a service that appears to have said nothing
rather than one that failed to read. So: a minimum number of verdict lines per
job, a minimum number of jobs, and no file written when either is missed.

Usage:
  python3 tools/fetch_run_report.py --repo gHashTag/trinity-fpga \\
      --workflow rtl-check.yml --min-jobs 2 --min-lines 4
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys

ANSI = re.compile(r"\x1b\[[0-9;]*m")
STAMP = re.compile(r"^[0-9T:.Z\-]+ ")


def gh(args: list[str]) -> str:
    out = subprocess.run(["gh", *args], capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args[:3])} failed: {out.stderr.strip()[:300]}")
    return out.stdout


def latest_success(repo: str, workflow: str) -> dict:
    data = json.loads(gh(["run", "list", "--repo", repo, "--workflow", workflow,
                          "--limit", "20", "--json",
                          "databaseId,conclusion,createdAt,headSha,url"]))
    for r in data:
        if r.get("conclusion") == "success":
            return r
    raise RuntimeError(f"no successful run of {workflow} in {repo} in the last 20")


def verdict_lines(repo: str, run_id: int) -> dict[str, list[str]]:
    log = gh(["run", "view", "--repo", repo, str(run_id), "--log"])
    found: dict[str, list[str]] = {}
    for raw in log.splitlines():
        parts = raw.split("\t")
        job = parts[0].strip() if parts else ""
        text = STAMP.sub("", ANSI.sub("", parts[-1] if parts else raw)).rstrip()
        # The step's own shell source is echoed into the log before it runs, so
        # the same sentence appears twice: once with $VAR unexpanded and once
        # with the measurement in it. Only the second is a result.
        if text.startswith("- **") and "$" not in text:
            lines = found.setdefault(job, [])
            if text not in lines:
                lines.append(text)
    return found


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--workflow", required=True)
    ap.add_argument("--min-jobs", type=int, default=1)
    ap.add_argument("--min-lines", type=int, default=4)
    ap.add_argument("--out", default="apps/website/src/data/exampleReport.json")
    args = ap.parse_args()

    run = latest_success(args.repo, args.workflow)
    jobs = verdict_lines(args.repo, run["databaseId"])

    print(f"  run {run['databaseId']} of {args.repo} / {args.workflow}")
    for job, lines in jobs.items():
        print(f"    {job}: {len(lines)} lines")

    # The floor. A green here has to mean "read a full report", not "read a log".
    if len(jobs) < args.min_jobs:
        print(f"  FAIL {len(jobs)} job(s) with verdict lines, expected at least "
              f"{args.min_jobs}. Nothing written — the page keeps its last real report.",
              file=sys.stderr)
        return 1
    thin = {j: len(ls) for j, ls in jobs.items() if len(ls) < args.min_lines}
    if thin:
        print(f"  FAIL these jobs reported fewer than {args.min_lines} lines: {thin}. "
              f"Nothing written.", file=sys.stderr)
        return 1

    payload = {
        "repo": args.repo,
        "workflow": args.workflow,
        "runUrl": run.get("url"),
        "sha": (run.get("headSha") or "")[:8],
        "at": run.get("createdAt"),
        "note": ("Extracted from the run's own log, not written by hand. A sample written "
                 "by hand drifts from what the tool says; this cannot."),
        "jobs": [{"name": j, "lines": ls} for j, ls in jobs.items()],
    }
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"  wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
