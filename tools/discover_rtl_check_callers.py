#!/usr/bin/env python3
"""Find every public repository that calls the RTL check, and record how it went.

The gallery on t27.ai was hand-written. That makes it a portfolio: it shows what
I chose to show. A service has to show what happened, including the runs I did
not pick — so this discovers callers instead of listing them.

It is only possible because the check runs in the customer's repository. Their
workflow file is public, their run conclusions are public, and nothing has to be
uploaded to me for any of it. The same property that makes the check acceptable
to a chip designer is what makes the gallery self-maintaining.

Deliberately narrow about what it claims:

  * A repository appears only if a file under .github/workflows/ actually names
    the reusable workflow. A README mentioning it is not a user.
  * The conclusion is the run's own conclusion, read from the API, never
    inferred from the presence of a workflow file.
  * The repo that DEFINES the workflow is excluded. Otherwise the gallery's
    first entry is me calling myself, which is the exact thing it exists to stop.
  * Nothing is written for a repository whose workflow has never run. "Has the
    file" and "has been checked" are different facts and the second is the one
    being claimed.

Usage:  GH_TOKEN=... python3 tools/discover_rtl_check_callers.py [--out FILE]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from typing import Any

# The repository that defines the workflow. Hits inside it are the definition
# itself, the self-test, and the snippet shown on the website -- not users.
HOME = "gHashTag/trinity"
NEEDLE = "gHashTag/trinity/.github/workflows/rtl-check.yml"


def gh(path: str, **params: str) -> Any:
    """One GitHub API call. Fails loudly: a silent {} here becomes an empty
    gallery that looks exactly like "nobody uses it"."""
    cmd = ["gh", "api", "-X", "GET", path]
    for k, v in params.items():
        cmd += ["-f", f"{k}={v}"]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(f"gh api {path} failed: {out.stderr.strip()[:400]}")
    return json.loads(out.stdout)


def find_caller_repos() -> list[tuple[str, str]]:
    """(repo, path) for every workflow file that names the reusable workflow."""
    found: list[tuple[str, str]] = []
    page = 1
    while page <= 10:
        res = gh("search/code", q=f'"{NEEDLE}" in:file', per_page="100", page=str(page))
        items = res.get("items", [])
        if not items:
            break
        for it in items:
            repo = it["repository"]["full_name"]
            path = it["path"]
            if repo == HOME:
                continue
            if not path.startswith(".github/workflows/"):
                continue
            found.append((repo, path))
        if len(items) < 100:
            break
        page += 1
    return sorted(set(found))


def workflow_id_for(repo: str, path: str) -> int | None:
    """The workflow id for a path. Paginated on purpose: one of these repos has
    ninety workflows and the default page of thirty silently omitted the one
    being looked for."""
    page = 1
    while page <= 10:
        res = gh(f"repos/{repo}/actions/workflows", per_page="100", page=str(page))
        wfs = res.get("workflows", [])
        for w in wfs:
            if w.get("path") == path:
                return w["id"]
        if len(wfs) < 100:
            break
        page += 1
    return None


def tops_declared(repo: str, path: str) -> list[str]:
    """The top modules the caller asks for, read out of its own workflow file."""
    try:
        res = gh(f"repos/{repo}/contents/{path}")
    except RuntimeError:
        return []
    import base64

    body = base64.b64decode(res.get("content", "")).decode("utf-8", "replace")
    return re.findall(r"^\s*top:\s*['\"]?([A-Za-z_][A-Za-z0-9_$]*)", body, re.M)


def latest_run(repo: str, wf_id: int) -> dict[str, Any] | None:
    res = gh(f"repos/{repo}/actions/workflows/{wf_id}/runs", per_page="10")
    for r in res.get("workflow_runs", []):
        if r.get("status") == "completed":
            return r
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="apps/website/src/data/communityRuns.json")
    args = ap.parse_args()

    if not (os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")):
        print("note: no GH_TOKEN in the environment; relying on gh auth", file=sys.stderr)

    callers = find_caller_repos()
    print(f"callers found: {len(callers)}", file=sys.stderr)

    entries = []
    for repo, path in callers:
        wf_id = workflow_id_for(repo, path)
        if wf_id is None:
            print(f"  {repo}: workflow file present but not registered, skipped", file=sys.stderr)
            continue
        run = latest_run(repo, wf_id)
        if run is None:
            print(f"  {repo}: never run, skipped", file=sys.stderr)
            continue
        entries.append(
            {
                "repo": repo,
                "workflow": path,
                "tops": tops_declared(repo, path),
                "conclusion": run.get("conclusion"),
                "runUrl": run.get("html_url"),
                "sha": (run.get("head_sha") or "")[:8],
                "at": run.get("updated_at"),
            }
        )
        print(f"  {repo}: {run.get('conclusion')} {run.get('html_url')}", file=sys.stderr)

    entries.sort(key=lambda e: e["at"] or "", reverse=True)
    payload = {
        "discoveredBy": "tools/discover_rtl_check_callers.py",
        "method": (
            "GitHub code search for repositories whose .github/workflows/ names the "
            "reusable workflow, then that workflow's own latest completed run. "
            "Conclusions are read from the API, never inferred."
        ),
        "excludes": (
            f"{HOME}, which defines the workflow — its hits are the definition, the "
            "self-test and the snippet on this site, not users of it."
        ),
        "entries": entries,
    }
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"wrote {args.out}: {len(entries)} entr{'y' if len(entries)==1 else 'ies'}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
