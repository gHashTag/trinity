#!/usr/bin/env python3
"""What each offered check's own self-test says, right now.

The start page describes four checks and says each has been watched failing on a
design that deserves to fail. That is a claim about the present tense, and until
now the only way to test it was to go and read four workflow histories. A claim
a reader cannot check is a claim they have to take on trust, which is the thing
this whole service exists to avoid asking for.

So the page carries the verdicts, pulled from the jobs themselves. Each entry
names the job that attests it rather than the workflow around it, for two
reasons that are duller than the one first written here: three of the four
attesting jobs share a single workflow, so a workflow-level verdict would give
all three the same answer and none of them an address, and the badge links to
the job a reader should open, which a wrapper cannot name.

(The reason first written was that a green workflow can hold a red job. That is
true only where continue-on-error is set, and it is not set here. Correcting it
rather than leaving it is the cheaper half of the same discipline the page is
selling.)

T13 supplies the floor: nothing is written unless every check on the list
resolved. A shorter table is a smaller measurement wearing the same green.
"""
import json
import os
import subprocess
import sys

# (check id, workflow file, substring identifying the job that attests it)
CHECKS = [
    ("paths",       "conformance-selftest.yml", "build-paths-fixtures"),
    ("structural",  "rtl-check-selftest.yml",   "planted-latch-must-be-caught"),
    ("signal",      "conformance-selftest.yml", "signal-health-numbers"),
    ("conformance", "conformance-selftest.yml", "planted-defect-must-be-caught"),
]
REPO = "gHashTag/trinity"


def gh(args):
    out = subprocess.run(["gh", *args], capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args[:4])}: {out.stderr.strip()[:200]}")
    return json.loads(out.stdout)


runs_cache: dict[str, dict] = {}


def latest_run(workflow: str) -> dict:
    if workflow not in runs_cache:
        rs = gh(["run", "list", "--repo", REPO, "--workflow", workflow, "--branch", "main",
                 "--limit", "10", "--json", "databaseId,status,conclusion,createdAt,url"])
        done = [r for r in rs if r.get("status") == "completed"]
        if not done:
            raise RuntimeError(f"no completed run of {workflow} on main")
        runs_cache[workflow] = done[0]
    return runs_cache[workflow]


entries = []
for cid, workflow, job_sub in CHECKS:
    run = latest_run(workflow)
    jobs = gh(["run", "view", "--repo", REPO, str(run["databaseId"]), "--json", "jobs"])["jobs"]
    match = [j for j in jobs if job_sub in j.get("name", "")]
    if not match:
        print(f"FAIL: no job matching {job_sub!r} in the latest {workflow}", file=sys.stderr)
        raise SystemExit(1)
    j = match[0]
    entries.append({
        "id": cid,
        "job": j["name"],
        "conclusion": j.get("conclusion"),
        "at": run.get("createdAt"),
        "url": j.get("url") or run.get("url"),
    })
    print(f"  {cid:<12} {j.get('conclusion')}  {j['name']}", file=sys.stderr)

if len(entries) != len(CHECKS):
    print(f"FAIL: {len(entries)} of {len(CHECKS)} resolved; nothing written", file=sys.stderr)
    raise SystemExit(1)

dest = sys.argv[1] if len(sys.argv) > 1 else "apps/website/src/data/checkStatus.json"
with open(dest, "w", encoding="utf-8") as f:
    json.dump({
        "note": ("Each verdict is the conclusion of the job that attests that check, not of the "
                 "workflow containing it: a green workflow can hold a red job, and a badge for "
                 "the wrapper would say the opposite of the truth."),
        "entries": entries,
    }, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"wrote {dest}", file=sys.stderr)
