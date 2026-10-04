#!/usr/bin/env python3
"""The capability index: every S01 capability card, held to this tree and to a run of the headless
profile -- measured, blocked, or excluded with its reason.

WHY THIS EXISTS
---------------
S12 of gHashTag/trinity#988 (gHashTag/trinity#989) asks for a machine-readable capability -> spec ->
artifact -> build/test -> evidence index, for every capability measured complete, explicitly blocked or
intentionally excluded with a reason, and for no coverage figure that counts catalog entries as code.
The S01 cards say "measured" when a CI run once built the tree; nothing yet held each card to what a
clean run of this tree builds, installs, tests and runs.

WHAT IT READS
-------------
  * the cards and the S01 checker, external/t27 -- verified first against specs/reproduce/contracts.t27
    (tools/contracts.py check); an index built on unverified cards is not built;
  * the S01 checker's own inventory and check of this tree (external/t27/tools/trinity_manifest.py,
    imported): target ownership, paths and dialects are judged by the canonical code, not a copy;
  * the record of a headless run (python3 tools/reproduce.py headless --out R): the installs with their
    sha256, the compiled test roots, the test verdict;
  * specs/reproduce/capabilities.t27: which acceptance commands to run, which not and why, and the
    capabilities known to be blocked.

WHAT IT DECIDES, PER CARD
-------------------------
  excluded  its disposition excludes it (deprecated, out-of-scope, catalog-only, external), or its
            profile is not headless, or it names nothing to measure -- with the reason;
  measured  every exe and lib it owns that the profile installs is in the record with its sha256, every
            test root it owns compiled in a test step with no failure, and its acceptance is the
            profile's own command, or ran and exited 0, or is declined with a reason;
  blocked   anything of that failed -- with what failed.
A blocked capability must be in KNOWN_BLOCKED, and one there must still be blocked. The S01 checker's
findings fail the index, except DRIFT_CODES (the pin and the counts), which are reported.

Usage (from the repository root, on a clean tree):
  python3 tools/capabilities.py index --record R.json [--out capabilities.json] [--summary FILE]
  python3 tools/capabilities.py --self-check
Exit codes: 0 every capability is what the index says and nothing unexpected is blocked; 1 a violation
(each printed); 2 could not run. Standard library only.
"""
from __future__ import annotations

import argparse
import fnmatch
import importlib.util
import json
import os
import pathlib
import re
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
PLAN = "specs/reproduce/capabilities.t27"
PROFILE_SPEC = "specs/reproduce/headless.t27"
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import contracts  # noqa: E402  (the lock, its reader and its check)

CARDS = "specs/trinity/capabilities"


def load_checker(root: pathlib.Path, vendor_dir: str):
    """The S01 checker as t27 holds it -- the vendored file, imported, never a copy of its logic."""
    path = root / vendor_dir / "tools/trinity_manifest.py"
    spec = importlib.util.spec_from_file_location("trinity_manifest", path)
    module = importlib.util.module_from_spec(spec)
    # No __pycache__ beside it: a .pyc in external/t27 is a file the lock does not hold, and the
    # next check of the vendored copy would rightly refuse it.
    saved, sys.dont_write_bytecode = sys.dont_write_bytecode, True
    try:
        spec.loader.exec_module(module)
    finally:
        sys.dont_write_bytecode = saved
    return module


def with_ci(command: str) -> str:
    """Each `zig build` in the command gains -Dci=true unless it has it: the cards are headless."""
    return re.sub(r"\bzig build\b(?![^&;|]*-Dci=true)([^&;|]*)", lambda m: f"zig build{m.group(1).rstrip()} -Dci=true ", command).strip()


# ===========================================================================================
# The decision, pure: cards, ownership, the record, the plan and the runs in; rows and violations out
# ===========================================================================================
def classify(cards: dict, owned: dict, installed: set, record: dict, plan: dict, runs: dict, profile_cmds: set, test_roots: set, head: str) -> tuple:
    rows, v = [], []

    def bad(code, text):
        v.append(f"{code}: {text}")
    known = set(cards)
    for name in ("RUN", "NOT_RUN", "KNOWN_BLOCKED"):
        for cid in sorted(set(plan[name]) - known):
            bad("PLAN_UNKNOWN", f"{PLAN} {name} names {cid}, which is no card")
    for cid in sorted(set(plan["RUN"]) & set(plan["NOT_RUN"])):
        bad("PLAN_CONFLICT", f"{cid} is both run and not run")
    if record.get("violations"):
        bad("RECORD", f"the headless record it reads has violations, so the profile itself did not hold: {record['violations'][:3]}")
    if record.get("head") != head:
        bad("RECORD", f"the headless record is of {record.get('head')}, the tree indexed is {head}: its installs and tests are another revision's")
    t = record["test"]
    roots_compiled = t.get("compiled_roots")
    test_clean = t.get("rc") == 0 and not t.get("failed_tests") and not t["summary"].get("tests_failed")
    declined = dict(zip(plan["NOT_RUN"], plan["NOT_RUN_REASONS"]))
    for cid in sorted(cards):
        c = cards[cid]
        row = {"id": cid, "title": c.get("TITLE", ""), "disposition": c.get("DISPOSITION"), "profile": c.get("PROFILE"),
               "work_package": c.get("WORK_PACKAGE"), "card_evidence": c.get("EVIDENCE"), "spec": c.get("CANONICAL_SPEC", ""),
               "targets": [], "acceptance": None}
        acceptance = c.get("ACCEPTANCE", "")
        if c.get("DISPOSITION") in plan["EXCLUDED_DISPOSITIONS"]:
            row.update(status="excluded", reason=f"disposition {c['DISPOSITION']}: {c.get('EVIDENCE_SOURCE') or c.get('NOTE', '')}"[:400])
            rows.append(row)
            continue
        if c.get("PROFILE") != "headless":
            row.update(status="excluded", reason=f"profile {c.get('PROFILE')}: S12 reproduces the approved headless profile only")
            rows.append(row)
            continue
        if not owned.get(cid) and not acceptance:
            row.update(status="excluded", reason="the card owns no build target and names no acceptance command: nothing to measure")
            rows.append(row)
            continue
        problems = []
        for key in owned.get(cid, []):
            kind, name = key.split(":", 1)
            entry = {"target": key}
            if kind in ("exe", "lib") and key in installed:
                path = f"bin/{name}" if kind == "exe" else f"lib/lib{name}.a"
                digest = record.get("installs", {}).get(path)
                entry.update(artifact=path, sha256=digest)
                if not digest:
                    problems.append(f"{key}: the profile installs {path} by default and the record has no such file")
            elif kind in ("exe", "lib"):
                entry.update(note="not installed by the profile; built by a named step")
            elif kind == "test" and name in test_roots:
                compiled = roots_compiled is None or name in roots_compiled
                entry.update(compiled=compiled if roots_compiled is not None else "not read (reused caches)", passed=test_clean)
                if not compiled:
                    problems.append(f"{key}: a root of the profile's test step that the step did not compile")
                if not test_clean:
                    problems.append(f"{key}: the test step had failures ({t['summary'].get('line')})")
            elif kind == "test":
                entry.update(note="a test root of another step, outside the profile's test step")
            else:
                entry.update(note="a named step; measured only through an acceptance command")
            row["targets"].append(entry)
        if acceptance:
            if acceptance.replace(" --summary all", "") in profile_cmds:
                row["acceptance"] = {"command": acceptance, "measured_by": "the headless record", "rc": t.get("rc") if "test" in acceptance else record.get("build", {}).get("rc")}
                if row["acceptance"]["rc"] != 0:
                    problems.append(f"acceptance {acceptance!r} is the profile's own command, and it exited {row['acceptance']['rc']}")
            elif cid in plan["RUN"]:
                r = runs.get(cid)
                row["acceptance"] = r
                if r is None:
                    problems.append("planned to run, and no run is recorded")
                elif r["rc"] != 0:
                    problems.append(f"acceptance {r['command']!r} exited {r['rc']}: {r.get('tail', '')[-300:]}")
            elif cid in declined:
                row["acceptance"] = {"command": acceptance, "not_run": declined[cid]}
            else:
                bad("UNPLANNED", f"{cid}: its acceptance {acceptance!r} is neither the profile's, nor run, nor declined with a reason")
        # Measured means something was: an install hashed, a root of the profile's test step passed,
        # or an acceptance that exited 0. A card that owns only named steps, or roots of other steps,
        # and declines or lacks a command has nothing measured, and says so.
        evidence = [e for e in row["targets"] if e.get("sha256") or e.get("passed") is True]
        acc = row["acceptance"] or {}
        if acc.get("rc") == 0:
            evidence.append(acc)
        if problems:
            row.update(status="blocked", problems=problems)
        elif evidence:
            row.update(status="measured", problems=[])
        else:
            row.update(status="excluded", problems=[], reason="nothing the profile builds, tests or runs measures it: it owns "
                       + (", ".join(e["target"] for e in row["targets"]) or "no target") + (f", and its acceptance is not run: {acc['not_run']}" if acc.get("not_run") else ", and names no acceptance"))
        rows.append(row)
    blocked = {r["id"] for r in rows if r["status"] == "blocked"}
    ledger = dict(zip(plan["KNOWN_BLOCKED"], plan["KNOWN_BLOCKED_REASONS"]))
    for cid in sorted(blocked - set(ledger)):
        bad("NEW_BLOCKED", f"{cid} is blocked and {PLAN} does not know it: {[r for r in rows if r['id'] == cid][0]['problems'][:2]}")
    for cid in sorted(set(ledger) - blocked):
        if cid in known:
            bad("BLOCKED_NOW_MEASURED", f"{cid} is in KNOWN_BLOCKED and measured complete; remove its line")
    for r in rows:
        if r["id"] in ledger and r["status"] == "blocked":
            r["reason"] = ledger[r["id"]]
    return rows, v


def checker_verdict(findings: list, drift_codes: list) -> tuple:
    """The S01 checker's findings on this tree: drift since its pinned inventory is reported, anything
    else -- an unowned target, an absent path, a dialect, a duplicate -- fails the index."""
    v = []

    def bad(code, text):
        v.append(f"{code}: {text}")
    drift = [f"{c}: {m}" for c, m in findings if c in drift_codes]
    for c, m in findings:
        if c not in drift_codes:
            bad("CHECKER", f"{c}: {m}")
    return drift, v


# ===========================================================================================
# The measuring: the lock, the checker on this tree, the cards, the runs
# ===========================================================================================
def run_acceptance(command: str, timeout: int) -> dict:
    t0 = time.time()
    try:
        p = subprocess.run(["bash", "-c", command], cwd=str(ROOT), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, timeout=timeout)
        rc, out = p.returncode, p.stdout
    except subprocess.TimeoutExpired as e:
        rc, out = None, (e.stdout.decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or ""))
    changed = [x[3:] for x in subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain", "--untracked-files=no"],
                                             capture_output=True, text=True).stdout.split("\n") if x]
    if changed:
        subprocess.run(["git", "-C", str(ROOT), "checkout", "--"] + changed, capture_output=True)
    return {"command": command, "rc": rc, "seconds": round(time.time() - t0, 1), "changed_tracked_files": changed, "tail": out[-1500:]}


def measure(record_path: pathlib.Path) -> dict:
    lock = contracts.read_lock(ROOT)
    findings = contracts.check(ROOT)
    if findings:
        raise RuntimeError(f"the vendored contracts are not what the lock says, so no index is built on them: {findings[:3]}")
    plan = contracts.constants((ROOT / PLAN).read_text(encoding="utf-8"), PLAN)
    profile = contracts.constants((ROOT / PROFILE_SPEC).read_text(encoding="utf-8"), PROFILE_SPEC)
    record = json.loads(record_path.read_text(encoding="utf-8"))
    tm = load_checker(ROOT, lock["VENDOR_DIR"])
    inv = tm.inventory(ROOT)  # before any command can touch the tree: it refuses a dirty one
    checker_findings, _ = tm.check(inv, ROOT / lock["VENDOR_DIR"] / "specs/trinity", ROOT / lock["VENDOR_DIR"])
    cards = {}
    for path in sorted((ROOT / lock["VENDOR_DIR"] / CARDS).glob("*.t27")):
        consts = {k: d["value"] for k, d in tm.parse_spec(path)["consts"].items()}
        cards[consts["ID"]] = consts
    targets = sorted({a["key"] for kind in ("executables", "libraries", "tests", "steps") for a in inv["build"][kind]})
    owned = {cid: sorted({t for p in c.get("TARGETS", []) for t in targets if fnmatch.fnmatchcase(t, p)}) for cid, c in cards.items()}
    installed = set(inv["build"]["installed_by_default"])
    runs = {}
    for cid in plan["RUN"]:
        if cid in cards and cards[cid].get("ACCEPTANCE"):
            runs[cid] = run_acceptance(with_ci(cards[cid]["ACCEPTANCE"]), plan["RUN_TIMEOUT_S"])
    rows, violations = classify(cards, owned, installed, record, plan, runs, {c.replace(" --summary all", "") for c in (profile["BUILD"], profile["TEST"])},
                                set(profile["TEST_ROOTS"]), inv["sha"])
    # The spec link of each row, from the lock: where the contract lives, its bytes, and what the
    # pinned compiler made of it (tools/contracts.py check --t27c, run by contracts.yml).
    locked = dict(zip(lock["FILES"], lock["SHA256"]))
    test_blocked = dict(zip(lock["TEST_BLOCKED"], lock["TEST_BLOCKED_ERRORS"]))
    dropped = dict(zip(lock["PARSE_DISCARDS"], lock["PARSE_DISCARD_TOKENS"]))
    for r in rows:
        ref = r["spec"]
        if not ref:
            r["spec"] = {"ref": "", "note": "the card names no canonical spec"}
        elif re.match(r"^[\w.-]+:", ref):
            repo, path = ref.split(":", 1)
            r["spec"] = {"ref": ref, "in": "this repository" if repo == "trinity" else repo,
                         "exists": (ROOT / path).is_file() if repo == "trinity" else "not checked here"}
        else:
            r["spec"] = {"ref": ref, "in": f"gHashTag/t27@{lock['T27_REVISION']}", "sha256": locked.get(ref),
                         "contract_tests": f"do not build: {test_blocked[ref]}" if ref in test_blocked else
                         "declares no test" if ref in lock["TEST_NONE"] else "run with the pinned compiler (contracts.yml)",
                         **({"parser_drops_tokens": dropped[ref]} if ref in dropped else {})}
    drift, checker_violations = checker_verdict(checker_findings, plan["DRIFT_CODES"])
    violations += checker_violations
    counts = {s: sum(1 for r in rows if r["status"] == s) for s in ("measured", "blocked", "excluded")}
    return {"tool": "tools/capabilities.py", "head": inv["sha"], "host": record.get("host"),
            "t27": {"revision": lock["T27_REVISION"], "lock": contracts.LOCK},
            "record": {"path": str(record_path), "head": record.get("head"), "fresh_caches": record.get("fresh_caches"), "zig": record.get("zig")},
            "checker": {"drift": drift, "findings": [f"{c}: {m}" for c, m in checker_findings if c not in plan["DRIFT_CODES"]]},
            "counts": dict(counts, total=len(rows)), "capabilities": rows, "violations": violations}


def summary_markdown(doc: dict) -> str:
    c = doc["counts"]
    out = [f"## Capability index at {doc['head'][:12]} ({doc['host']})", "",
           f"{c['total']} capability cards of gHashTag/t27@{doc['t27']['revision'][:12]}: **{c['measured']} measured, {c['blocked']} blocked, "
           f"{c['excluded']} excluded with a reason.** No figure here counts catalog entries.", "",
           "| capability | status | evidence or reason |", "|---|---|---|"]
    for r in doc["capabilities"]:
        if r["status"] == "measured":
            arts = [t["artifact"] for t in r["targets"] if t.get("artifact")]
            tests = [t["target"][5:] for t in r["targets"] if t["target"].startswith("test:")]
            acc = r["acceptance"]
            how = (f"{len(arts)} install(s) hashed" if arts else "") + (f"; {len(tests)} test root(s) passed" if tests else "")
            if acc and acc.get("rc") == 0 and "measured_by" not in acc:
                how += f"; `{acc['command']}` exited 0"
            elif acc and acc.get("rc") == 0:
                how += f"; `{acc['command']}` is the profile's own command, exit 0 in the record"
            elif acc and acc.get("not_run"):
                how += "; acceptance not run (reason in the record)"
            text = how.strip("; ") or "measured"
        else:
            text = r.get("reason") or "; ".join(r.get("problems", []))
        out.append(f"| `{r['id']}` | {r['status']} | {text.replace('|', '/')[:220]} |")
    if doc["violations"]:
        out += ["", "### Violations", ""] + [f"- {x}" for x in doc["violations"]]
    return "\n".join(out) + "\n"


# ===========================================================================================
# --self-check: the decision on toy cards, each defect planted once
# ===========================================================================================
def self_check() -> int:
    ok = True
    seen = set()

    def expect(cond, what):
        nonlocal ok
        print(f"  {'ok ' if cond else 'BAD'} {what}")
        ok = ok and bool(cond)
    card = lambda cid, **kw: {"ID": cid, "TITLE": cid, "DISPOSITION": "executable", "PROFILE": "headless", "EVIDENCE": "measured",
                              "ACCEPTANCE": "", "TARGETS": [], **kw}
    cards = {"t/lib": card("t/lib", ACCEPTANCE="zig build -Dci=true"), "t/cli": card("t/cli", ACCEPTANCE="zig build cli && ./zig-out/bin/cli --version"),
             "t/web": card("t/web", PROFILE="web"), "t/old": card("t/old", DISPOSITION="deprecated", EVIDENCE_SOURCE="kept for history"),
             "t/bot": card("t/bot", ACCEPTANCE="zig build bot"), "t/mcp": card("t/mcp", ACCEPTANCE="zig build mcp"), "t/corpus": card("t/corpus"),
             "t/steps": card("t/steps")}
    owned = {"t/lib": ["lib:core", "test:src/core.zig", "test:src/other_step.zig"], "t/cli": ["exe:cli"], "t/bot": ["exe:bot"], "t/mcp": ["exe:mcp"],
             "t/steps": ["step:release", "test:src/other_step.zig"]}
    installed = {"lib:core", "exe:cli", "exe:bot", "exe:mcp"}
    record = {"host": "Linux x86_64", "head": "f" * 40, "violations": [], "build": {"rc": 0},
              "installs": {"lib/libcore.a": "a" * 64, "bin/cli": "b" * 64, "bin/bot": "c" * 64, "bin/mcp": "d" * 64},
              "test": {"rc": 0, "summary": {"line": "Build Summary: 2/2 steps succeeded; 9/9 tests passed", "tests_failed": 0}, "failed_tests": [],
                       "compiled_roots": ["src/core.zig"]}}
    plan = {"RUN": ["t/cli", "t/mcp"], "NOT_RUN": ["t/bot"], "NOT_RUN_REASONS": ["needs a token"], "KNOWN_BLOCKED": ["t/mcp"],
            "KNOWN_BLOCKED_REASONS": ["no such step"], "EXCLUDED_DISPOSITIONS": ["deprecated", "out-of-scope", "catalog-only", "external"],
            "DRIFT_CODES": ["PIN_MISMATCH"]}
    runs = {"t/cli": {"command": "zig build cli -Dci=true && ./zig-out/bin/cli --version", "rc": 0},
            "t/mcp": {"command": "zig build mcp -Dci=true", "rc": 1, "tail": "no step named 'mcp'"}}
    prof = {"zig build -Dci=true", "zig build test -Dci=true"}

    def run(**changes):
        args = {"cards": cards, "owned": owned, "installed": installed, "record": record, "plan": plan, "runs": runs, "profile_cmds": prof,
                "test_roots": {"src/core.zig"}, "head": "f" * 40}
        args.update(changes)
        rows, v = classify(**args)
        got = {x.split(":")[0] for x in v}
        seen.update(got)
        return {r["id"]: r["status"] for r in rows}, got
    status, got = run()
    expect(not got and status == {"t/lib": "measured", "t/cli": "measured", "t/web": "excluded", "t/old": "excluded", "t/bot": "measured",
                                  "t/mcp": "blocked", "t/corpus": "excluded", "t/steps": "excluded"},
           f"a tree that is what the plan says: measured, excluded with reasons, the known block blocked, nothing else ({status}, {got})")
    _, got = run(record=dict(record, installs={k: v for k, v in record["installs"].items() if k != "bin/cli"}))
    expect("NEW_BLOCKED" in got, "planted: an install the profile makes is missing from the record")
    _, got = run(record=dict(record, test=dict(record["test"], rc=1, failed_tests=[{"test": "core.test.x"}])))
    expect("NEW_BLOCKED" in got and "RECORD" not in got, "planted: a failed test under an owned root")
    _, got = run(record=dict(record, test=dict(record["test"], compiled_roots=["src/elsewhere.zig"])))
    expect("NEW_BLOCKED" in got, "planted: an owned root of the test step that the step did not compile")
    _, got = run(runs=dict(runs, **{"t/cli": dict(runs["t/cli"], rc=2, tail="error")}))
    expect("NEW_BLOCKED" in got, "planted: an acceptance command that fails")
    _, got = run(runs=dict(runs, **{"t/mcp": dict(runs["t/mcp"], rc=0)}))
    expect("BLOCKED_NOW_MEASURED" in got, "planted: a known block that measures complete (the ledger would outlive it)")
    _, got = run(plan=dict(plan, RUN=["t/mcp"]))
    expect("UNPLANNED" in got, "planted: a headless acceptance nobody planned")
    _, got = run(plan=dict(plan, NOT_RUN=["t/bot", "t/cli"], NOT_RUN_REASONS=["needs a token", "x"]))
    expect("PLAN_CONFLICT" in got, "planted: a card both run and not run")
    _, got = run(plan=dict(plan, KNOWN_BLOCKED=["t/mcp", "t/gone"], KNOWN_BLOCKED_REASONS=["no such step", "x"]))
    expect("PLAN_UNKNOWN" in got, "planted: a plan line for a card that does not exist")
    _, got = run(record=dict(record, violations=["TEST_FAILED: ..."]))
    expect("RECORD" in got, "planted: a headless record whose profile did not hold")
    _, got = run(head="e" * 40)
    expect("RECORD" in got, "planted: a record of another revision than the tree indexed")
    _, got = run(runs={k: v for k, v in runs.items() if k != "t/cli"})
    expect("NEW_BLOCKED" in got, "planted: a planned run that did not happen")
    expect(with_ci("zig build tri && ./zig-out/bin/tri --version") == "zig build tri -Dci=true && ./zig-out/bin/tri --version"
           and with_ci("zig build examples && zig build e2e") == "zig build examples -Dci=true && zig build e2e -Dci=true"
           and with_ci("zig build -Dci=true") == "zig build -Dci=true", f"-Dci=true is added to each zig build, once ({with_ci('zig build examples && zig build e2e')!r})")
    drift, cv = checker_verdict([("PIN_MISMATCH", "pinned elsewhere"), ("UNOWNED_TARGET", "exe:new has no card")], plan["DRIFT_CODES"])
    seen.update(x.split(":")[0] for x in cv)
    expect(drift == ["PIN_MISMATCH: pinned elsewhere"] and [x.split(":")[0] for x in cv] == ["CHECKER"],
           "planted: a checker finding that is not drift fails, the pin is only reported")
    src = pathlib.Path(__file__).read_text(encoding="utf-8").split("def run_acceptance(", 1)[0]
    rules = set(re.findall(r'bad\("([A-Z_]+)"', src))
    expect(rules <= seen, f"every rule of the decision fired at least once ({len(rules & seen)}/{len(rules)}; never: {sorted(rules - seen)})")
    print("capabilities --self-check:", "ok" if ok else "FAILED")
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("command", nargs="?", choices=["index"])
    ap.add_argument("--record", help="the JSON record of python3 tools/reproduce.py headless")
    ap.add_argument("--out", default="capabilities.json")
    ap.add_argument("--summary", help="also write a Markdown table here (for $GITHUB_STEP_SUMMARY)")
    ap.add_argument("--self-check", action="store_true")
    a = ap.parse_args()
    if a.self_check:
        return self_check()
    if a.command != "index" or not a.record:
        ap.print_help()
        return 2
    try:
        doc = measure(pathlib.Path(a.record))
    except (OSError, ValueError, RuntimeError, SystemExit) as e:
        print(f"capabilities: could not run: {e}", file=sys.stderr)
        return 2
    pathlib.Path(a.out).write_text(json.dumps(doc, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    md = summary_markdown(doc)
    if a.summary:
        with open(a.summary, "a", encoding="utf-8") as fh:
            fh.write(md)
    c = doc["counts"]
    print(f"capabilities: {c['total']} cards at {doc['head'][:12]} ({doc['host']}): {c['measured']} measured, {c['blocked']} blocked, {c['excluded']} excluded")
    for r in doc["capabilities"]:
        if r["status"] != "measured":
            print(f"  {r['status']:8} {r['id']}: {(r.get('reason') or '; '.join(r.get('problems', [])))[:160]}")
    for x in doc["checker"]["drift"]:
        print("  drift since the S01 inventory:", x[:160])
    for x in doc["violations"]:
        print("VIOLATION:", x)
    print("capabilities:", "every capability is what the index says" if not doc["violations"] else f"{len(doc['violations'])} violation(s)")
    return 1 if doc["violations"] else 0


if __name__ == "__main__":
    sys.exit(main())
