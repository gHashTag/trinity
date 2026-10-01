#!/usr/bin/env python3
"""Reproduce the headless profile of gHashTag/trinity from a clean clone, and refuse to call a broken
graph green.

WHY THIS EXISTS
---------------
S12 of gHashTag/trinity#988 (gHashTag/trinity#989): a set of specifications is not a recreated project
until a clean checkout builds and tests the declared profile, and a failure anywhere fails the gate.
Until this tool, CI ran `zig build test -Dci=true 2>&1 | tee test-output.txt` under bash without
pipefail: the step's exit code was tee's, so five test binaries that do not compile -- among them the
library's own test root, src/trinity.zig -- were reported green on every push (gHashTag/trinity#616;
the tee fix alone is gHashTag/trinity#987). The summary line said it plainly, "124/135 steps
succeeded; 5 failed", and nothing read it.

WHAT IT CHECKS
--------------
specs/reproduce/headless.t27 is the declared profile: the toolchain, the two commands, the 46 artifacts
the build installs, the test roots the test step compiles, the floors the graph may not drop below, and
the test roots known not to compile, each with its reason and the capability card it blocks. The tool
runs the commands and judges what they did:

  * the exit code of each command is read from the process, never through a pipe;
  * a compile failure must be a BLOCKED root, and a BLOCKED root must still fail (a fixed one is
    reported, so the ledger cannot outlive the defect);
  * a failed test, a leak, or a failure the output does not name fails;
  * a missing install fails; every install is hashed into the evidence;
  * the number of run steps, of tests passed, and (with fresh caches) the set of compiled test roots
    may not drop below the spec -- a graph that shrank is a partial graph;
  * a run step that ran no test is counted, and their number may not grow (an empty step is not a
    passing one);
  * the four packages build.zig.zon pins are the spec's, url and hash.

Usage (from the repository root of a clean clone):
  python3 tools/reproduce.py headless [--out FILE] [--reuse-cache] [--zig ZIG]
  python3 tools/reproduce.py test     [--out FILE] [--reuse-cache] [--zig ZIG]   (the test step only)
  python3 tools/reproduce.py --self-check
headless runs both commands with fresh, empty zig caches (ZIG_GLOBAL_CACHE_DIR and ZIG_LOCAL_CACHE_DIR
in a new temporary directory) unless --reuse-cache is given, which the evidence then records.
Exit codes: 0 the profile is what the spec says; 1 it is not (every violation is printed); 2 could not run.
Standard library only.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import pathlib
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "specs/reproduce/headless.t27"
CONST_RE = re.compile(r"^pub const (\w+) : ([^=]+?) = (.*);\s*$")


# ===========================================================================================
# The spec, read the way the other consumers of .t27 constants read it: one `pub const` per
# statement, string arrays as JSON arrays. A constant this reader cannot read stops the tool.
# ===========================================================================================
def load_spec(path: pathlib.Path) -> dict:
    text = path.read_text(encoding="utf-8")
    if re.search(r"[^\x00-\x7f]", text):
        raise ValueError(f"{path}: non-ASCII byte (L3)")
    out, lines, n = {}, text.split("\n"), 0
    while n < len(lines):
        line = lines[n]
        n += 1
        if line.startswith("pub const") and not line.rstrip().endswith(";"):
            while n < len(lines):
                line += " " + lines[n].strip()
                n += 1
                if lines[n - 1].rstrip().endswith(";"):
                    break
        m = CONST_RE.match(line)
        if m:
            out[m.group(1)] = value_of(m.group(3).strip(), m.group(2).strip())
        elif line.startswith("pub const"):
            raise ValueError(f"{path}:{n}: cannot read constant line")
    return out


def value_of(raw: str, typ: str):
    if typ == "bool":
        return raw == "true"
    if re.fullmatch(r"[ui]\d+", typ):
        return int(raw)
    if typ == "str":
        return json.loads(raw)
    m = re.fullmatch(r"\[(\d+)\](\w+)", typ)
    if m:
        items = json.loads(raw) if m.group(2) == "str" else [int(x) for x in raw.strip("[]").split(",") if x.strip()]
        if len(items) != int(m.group(1)):
            raise ValueError(f"annotated {typ}, holds {len(items)}")
        return items
    raise ValueError(f"unknown type {typ}")


# ===========================================================================================
# Reading what zig printed
# ===========================================================================================
def parse_summary(text: str) -> dict:
    """'Build Summary: 124/135 steps succeeded; 5 failed; 2510/2510 tests passed' and its variants."""
    line = next((x for x in text.split("\n") if x.startswith("Build Summary:")), None)
    if line is None:
        return {"found": False}
    num = lambda pat: (lambda m: int(m.group(1)) if m else 0)(re.search(pat, line))
    steps = re.search(r"(\d+)/(\d+) steps succeeded", line)
    tests = re.search(r"(\d+)/(\d+) tests passed", line)
    return {"found": True, "line": line.strip(),
            "steps_succeeded": int(steps.group(1)) if steps else 0, "steps_total": int(steps.group(2)) if steps else 0,
            "steps_failed": num(r"steps succeeded; (\d+) failed"),
            "tests_passed": int(tests.group(1)) if tests else 0, "tests_total": int(tests.group(2)) if tests else 0,
            "tests_skipped": num(r"(\d+) skipped"), "tests_failed": num(r"tests passed(?:; \d+ skipped)?; (\d+) failed"),
            "tests_leaked": num(r"(\d+) leaked")}


def parse_run_steps(text: str) -> dict:
    """The run steps of the summary tree: how many, how many ran a test, how many ran none."""
    counted = [int(m.group(1)) for m in re.finditer(r"run test (\d+) passed", text)]
    empty = len(re.findall(r"run test success\b", text))
    failed = len(re.findall(r"run test (?:\d+/\d+ passed, )?\d+ failed", text))
    return {"with_tests": len(counted), "empty": empty, "with_failures": failed, "tests_in_run_steps": sum(counted)}


def rel(path: str, workspace: str) -> str:
    for prefix in (workspace.rstrip("/") + "/", "/work/"):
        if path.startswith(prefix):
            return path[len(prefix):]
    return path


def parse_compile_failures(text: str, workspace: str) -> list:
    """Every 'the following command failed with N compilation errors:' and the root it compiled."""
    out = []
    for m in re.finditer(r"error: the following command failed with (\d+) compilation errors?:\n(\S.*)", text):
        root = re.search(r"-Mroot=(\S+)", m.group(2))
        out.append({"root": rel(root.group(1), workspace) if root else None, "errors": int(m.group(1))})
    return out


def parse_compiled_roots(text: str, workspace: str) -> list:
    """With --verbose and an empty cache every compile command is printed; the test ones name their root."""
    roots = set()
    for line in text.split("\n"):
        if re.search(r"\bzig\S* test ", line):
            m = re.search(r"-Mroot=(\S+)", line)
            if m:
                roots.add(rel(m.group(1), workspace))
    return sorted(roots)


def read_pins(zon: str) -> dict:
    """build.zig.zon's dependencies: name -> [url, hash]."""
    return {n: [u, h] for n, u, h in re.findall(r'\.(\w+) = \.\{\s*\.url = "([^"]+)",\s*\.hash = "([^"]+)"', zon)}


def first_errors(text: str, n=3) -> list:
    return [x.strip()[:200] for x in text.split("\n") if ": error:" in x][:n]


# ===========================================================================================
# Running it
# ===========================================================================================
def run(cmd: list, env: dict, timeout: int) -> dict:
    t0 = time.time()
    try:
        p = subprocess.run(cmd, cwd=str(ROOT), env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=timeout)
        rc, out = p.returncode, p.stdout
    except subprocess.TimeoutExpired as e:
        rc, out = None, (e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
    return {"command": " ".join(cmd), "rc": rc, "seconds": round(time.time() - t0, 1), "output": out}


def git(*args) -> str:
    try:
        p = subprocess.run(["git", "-C", str(ROOT)] + list(args), capture_output=True, text=True)
    except OSError:
        return ""
    return p.stdout.strip()


def sha256_file(p: pathlib.Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def measure(sp: dict, zig: str, reuse_cache: bool, build: bool) -> dict:
    env = dict(os.environ)
    scratch = None
    if not reuse_cache:
        scratch = tempfile.mkdtemp(prefix="reproduce-")
        env["ZIG_GLOBAL_CACHE_DIR"] = os.path.join(scratch, "global")
        env["ZIG_LOCAL_CACHE_DIR"] = os.path.join(scratch, "local")
    version = subprocess.run([zig, "version"], capture_output=True, text=True).stdout.strip()
    doc = {"tool": "tools/reproduce.py", "spec": str(SPEC.relative_to(ROOT)), "spec_sha256": sha256_file(SPEC),
           "at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
           "host": f"{platform.system()} {platform.machine()}", "zig": version, "head": git("rev-parse", "HEAD") or "unknown",
           "tracked_changes": [x for x in git("status", "--porcelain").split("\n") if x and not x.startswith("??")][:20],
           "fresh_caches": not reuse_cache, "workspace": str(ROOT)}
    doc["dependencies"] = read_pins((ROOT / "build.zig.zon").read_text(encoding="utf-8"))
    if build:
        b = run([zig] + sp["BUILD"].split()[1:], env, 7200)
        doc["build"] = {"command": b["command"], "rc": b["rc"], "seconds": b["seconds"], "summary": parse_summary(b["output"]),
                        "compile_failures": parse_compile_failures(b["output"], str(ROOT)), "errors": first_errors(b["output"])}
        installs = {}
        for rel_path in sp["INSTALLS"]:
            p = ROOT / "zig-out" / rel_path
            installs[rel_path] = sha256_file(p) if p.is_file() else None
        doc["installs"] = installs
    test_cmd = [zig] + sp["TEST"].split()[1:] + ([] if reuse_cache else ["--verbose"])
    t = run(test_cmd, env, 7200)
    doc["test"] = {"command": t["command"], "rc": t["rc"], "seconds": t["seconds"], "summary": parse_summary(t["output"]),
                   "run_steps": parse_run_steps(t["output"]), "compile_failures": parse_compile_failures(t["output"], str(ROOT)),
                   "compiled_roots": parse_compiled_roots(t["output"], str(ROOT)) if not reuse_cache else None,
                   "leak_lines": [x.strip()[:200] for x in t["output"].split("\n") if re.search(r"\bleak", x, re.I)][:5],
                   "errors": first_errors(t["output"])}
    if scratch:
        shutil.rmtree(scratch, ignore_errors=True)
    return doc


# ===========================================================================================
# Judging it: the whole contract, in one place
# ===========================================================================================
def judge(sp: dict, doc: dict) -> list:
    v = []

    def bad(code, text):
        v.append(f"{code}: {text}")
    if doc.get("head") in (None, "", "unknown"):
        bad("NO_REVISION", "git could not name the checkout's revision, so the record cannot say what it measured and the tree could not be checked for edits")
    if not doc["zig"].startswith(sp["ZIG"]):
        bad("TOOLCHAIN", f"zig {doc['zig']}, the profile is measured with {sp['ZIG']}")
    if doc.get("tracked_changes"):
        bad("DIRTY", f"tracked files differ from HEAD: {doc['tracked_changes'][:3]}")
    want = {n: [u, h] for n, u, h in zip(sp["DEPENDENCIES"], sp["DEPENDENCY_URLS"], sp["DEPENDENCY_HASHES"])}
    if doc.get("dependencies") != want:
        changed = sorted(n for n in set(want) | set(doc.get("dependencies") or {}) if want.get(n) != (doc.get("dependencies") or {}).get(n))
        bad("DEPENDENCY_DRIFT", f"build.zig.zon pins differ from the spec for {changed}")
    if "build" in doc:
        b = doc["build"]
        if b["rc"] != 0:
            bad("BUILD_FAILED", f"`{b['command']}` exited {b['rc']}: {b['errors'][:2]}")
        if not b["summary"].get("found"):
            bad("NO_SUMMARY", "the build printed no Build Summary")
        elif b["summary"]["steps_failed"] or b["compile_failures"]:
            bad("BUILD_STEP_FAILED", f"{b['summary']['line']} {[f['root'] for f in b['compile_failures']]}")
        if b["rc"] == 0 and (b["summary"].get("steps_failed") or b["compile_failures"]):
            bad("EXIT_SWALLOWED", "the build exited 0 while its output names failed steps")
        missing = sorted(k for k, h in doc["installs"].items() if h is None)
        if missing:
            bad("MISSING_OUTPUT", f"{len(missing)} declared install(s) absent from zig-out: {missing[:5]}")
    t = doc["test"]
    s, rs = t["summary"], t["run_steps"]
    failed_roots = sorted({f["root"] for f in t["compile_failures"] if f["root"]})
    blocked = sorted(sp["BLOCKED_ROOTS"])
    if not s.get("found"):
        bad("NO_SUMMARY", f"the test step printed no Build Summary (exit {t['rc']})")
    unknown = sorted(set(failed_roots) - set(blocked))
    fixed = sorted(set(blocked) - set(failed_roots))
    if unknown:
        bad("NEW_COMPILE_FAILURE", f"test roots that do not compile and that the spec does not name: {unknown}")
    if fixed:
        bad("BLOCKED_NOW_COMPILES", f"named as blocked but they compiled: {fixed}; remove them from BLOCKED_ROOTS")
    if any(f["root"] is None for f in t["compile_failures"]):
        bad("UNNAMED_FAILURE", "a compile failure whose root the output does not name")
    if s.get("found"):
        if s["tests_failed"] or rs["with_failures"]:
            bad("TEST_FAILED", f"{s['line']}")
        if s["tests_leaked"] or t["leak_lines"]:
            bad("LEAK", f"{s['tests_leaked']} leaked; {t['leak_lines'][:2]}")
        if s["steps_failed"] != len(t["compile_failures"]) + rs["with_failures"]:
            bad("UNEXPLAINED_STEP_FAILURE", f"{s['steps_failed']} failed step(s), {len(t['compile_failures'])} compile failure(s) and {rs['with_failures']} failed run step(s) named")
        if s["tests_passed"] < sp["TESTS_PASSED_MIN"]:
            bad("PARTIAL_GRAPH", f"{s['tests_passed']} tests passed, the floor is {sp['TESTS_PASSED_MIN']}")
        if s["steps_total"] < sp["TEST_STEPS_MIN"]:
            bad("PARTIAL_GRAPH", f"{s['steps_total']} steps in the test graph, the floor is {sp['TEST_STEPS_MIN']}")
    if rs["with_tests"] < sp["RUN_STEPS_WITH_TESTS_MIN"]:
        bad("PARTIAL_GRAPH", f"{rs['with_tests']} run steps ran a test, the floor is {sp['RUN_STEPS_WITH_TESTS_MIN']}")
    if rs["empty"] > sp["EMPTY_RUN_STEPS_MAX"]:
        bad("EMPTY_STEP", f"{rs['empty']} run step(s) ran no test, at most {sp['EMPTY_RUN_STEPS_MAX']} are known")
    if t["compiled_roots"] is not None:
        gone = sorted(set(sp["TEST_ROOTS"]) - set(t["compiled_roots"]))
        if gone:
            bad("PARTIAL_GRAPH", f"declared test roots the test step no longer compiles: {gone}")
    # The exit code, read from the process, must agree with what the output says happened.
    if t["rc"] == 0 and (failed_roots or (s.get("found") and (s["steps_failed"] or s["tests_failed"]))):
        bad("EXIT_SWALLOWED", "the test step exited 0 while its output names failures")
    if t["rc"] not in (0, None) and not failed_roots and not (s.get("found") and (s["tests_failed"] or s["tests_leaked"] or s["steps_failed"])):
        bad("UNEXPLAINED_EXIT", f"the test step exited {t['rc']} and its output names no failure")
    if t["rc"] is None:
        bad("TIMEOUT", "the test step did not finish")
    return v


# ===========================================================================================
# --self-check: every rule above has been seen to fire, and a conforming record stays silent
# ===========================================================================================
def self_check() -> int:
    ok = True

    def expect(cond, what):
        nonlocal ok
        print(f"  {'ok ' if cond else 'BAD'} {what}")
        ok = ok and bool(cond)
    sp = load_spec(SPEC)
    blocked = sp["BLOCKED_ROOTS"]
    fail_block = "".join(f"error: the following command failed with 1 compilation errors:\n/zig/zig test -ODebug -Mroot=/work/{r} --name test\n" for r in blocked)
    steps_total = sp["TEST_STEPS_MIN"]
    good_out = (fail_block + f"Build Summary: {steps_total - len(blocked)}/{steps_total} steps succeeded; {len(blocked)} failed; "
                f"{sp['TESTS_PASSED_MIN']}/{sp['TESTS_PASSED_MIN']} tests passed\n"
                + "".join("+- run test 7 passed 1ms MaxRSS:1M\n" for _ in range(sp["RUN_STEPS_WITH_TESTS_MIN"]))
                + "".join("+- run test success 1ms MaxRSS:1M\n" for _ in range(sp["EMPTY_RUN_STEPS_MAX"]))
                + "".join(f"/zig/zig test -ODebug -Mroot=/work/{r} --listen=-\n" for r in sp["TEST_ROOTS"]))
    good_build = f"Build Summary: {sp['BUILD_STEPS_MIN']}/{sp['BUILD_STEPS_MIN']} steps succeeded\n"

    good_deps = {n: [u, h] for n, u, h in zip(sp["DEPENDENCIES"], sp["DEPENDENCY_URLS"], sp["DEPENDENCY_HASHES"])}

    def record(test_out=good_out, test_rc=1, build_out=good_build, build_rc=0, installs=None, zig=sp["ZIG"], deps=None):
        return {"zig": zig, "head": "0" * 40, "tracked_changes": [], "dependencies": deps if deps is not None else good_deps,
                "build": {"command": sp["BUILD"], "rc": build_rc, "summary": parse_summary(build_out),
                          "compile_failures": parse_compile_failures(build_out, "/work"), "errors": []},
                "installs": installs if installs is not None else {k: "0" * 64 for k in sp["INSTALLS"]},
                "test": {"command": sp["TEST"], "rc": test_rc, "summary": parse_summary(test_out), "run_steps": parse_run_steps(test_out),
                         "compile_failures": parse_compile_failures(test_out, "/work"), "compiled_roots": parse_compiled_roots(test_out, "/work"),
                         "leak_lines": [x for x in test_out.split("\n") if re.search(r"\bleak", x, re.I)], "errors": []}}
    codes = lambda rec: {x.split(":")[0] for x in judge(sp, rec)}
    expect(not judge(sp, record()), f"a record that is what the spec says is silent ({judge(sp, record())[:2]})")
    expect("EXIT_SWALLOWED" in codes(record(test_rc=0)), "planted: the test step's failures with exit 0 (the tee of #616)")
    extra = "error: the following command failed with 2 compilation errors:\n/zig/zig test -ODebug -Mroot=/work/src/new_broken.zig --name test\n"
    out = good_out.replace(f"{len(blocked)} failed;", f"{len(blocked) + 1} failed;")
    expect("NEW_COMPILE_FAILURE" in codes(record(test_out=extra + out)), "planted: a test root that stops compiling")
    first = f"error: the following command failed with 1 compilation errors:\n/zig/zig test -ODebug -Mroot=/work/{blocked[0]} --name test\n"
    out = good_out.replace(first, "", 1).replace(f"{len(blocked)} failed;", f"{len(blocked) - 1} failed;")
    expect("BLOCKED_NOW_COMPILES" in codes(record(test_out=out)), "planted: a blocked root that compiles again (the ledger would outlive the defect)")
    out = good_out.replace(f"{sp['TESTS_PASSED_MIN']}/{sp['TESTS_PASSED_MIN']} tests passed", f"{sp['TESTS_PASSED_MIN'] - 1}/{sp['TESTS_PASSED_MIN']} tests passed; 1 failed")
    expect("TEST_FAILED" in codes(record(test_out=out)), "planted: a failed assertion")
    expect("LEAK" in codes(record(test_out=good_out + "error: 'x.test.y' leaked: [gpa] Memory leak detected\n")), "planted: a leak")
    out = good_out.replace(f"{sp['TESTS_PASSED_MIN']}/{sp['TESTS_PASSED_MIN']} tests passed", f"{sp['TESTS_PASSED_MIN'] - 400}/{sp['TESTS_PASSED_MIN'] - 400} tests passed")
    expect("PARTIAL_GRAPH" in codes(record(test_out=out)), "planted: 400 tests fewer (a partial graph)")
    out = good_out.replace(f"/zig/zig test -ODebug -Mroot=/work/{sp['TEST_ROOTS'][0]} --listen=-\n", "", 1)
    expect("PARTIAL_GRAPH" in codes(record(test_out=out)), "planted: a declared test root that is no longer compiled")
    expect("EMPTY_STEP" in codes(record(test_out=good_out + "+- run test success 1ms MaxRSS:1M\n")), "planted: one more run step that runs no test")
    inst = {k: "0" * 64 for k in sp["INSTALLS"]}
    inst[sp["INSTALLS"][0]] = None
    expect("MISSING_OUTPUT" in codes(record(installs=inst)), "planted: a declared install that is not there")
    expect("BUILD_FAILED" in codes(record(build_rc=1, build_out="Build Summary: 1/2 steps succeeded; 1 failed\n")), "planted: a build that fails")
    expect("UNEXPLAINED_EXIT" in codes(record(test_out=good_out.replace(fail_block, "").replace(f"{len(blocked)} failed;", "0 failed;"), test_rc=1)) or
           "BLOCKED_NOW_COMPILES" in codes(record(test_out=good_out.replace(fail_block, ""), test_rc=1)), "planted: a non-zero exit with no failure in the output")
    expect("TOOLCHAIN" in codes(record(zig="0.16.0")), "planted: another zig")
    rec = record()
    rec["head"] = "unknown"
    expect("NO_REVISION" in codes(rec), "planted: a checkout git cannot read (the dirty-tree check would be skipped)")
    rec = record()
    rec["tracked_changes"] = [" M build.zig"]
    expect("DIRTY" in codes(rec), "planted: a tracked file edited after the commit")
    zon = (ROOT / "build.zig.zon").read_text(encoding="utf-8")
    expect(read_pins(zon) == good_deps, "the pins build.zig.zon carries are the spec's")
    moved = zon.replace(sp["DEPENDENCY_URLS"][2], sp["DEPENDENCY_URLS"][2].replace("b73b2fa2", "0000fa2a"), 1)
    expect("DEPENDENCY_DRIFT" in codes(record(deps=read_pins(moved))), "planted: zig_hdc pinned to another revision")
    print("reproduce --self-check:", "ok" if ok else "FAILED")
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("command", nargs="?", choices=["headless", "test"])
    ap.add_argument("--out")
    ap.add_argument("--reuse-cache", action="store_true")
    ap.add_argument("--zig", default="zig")
    ap.add_argument("--self-check", action="store_true")
    a = ap.parse_args()
    if a.self_check:
        return self_check()
    if a.command is None:
        ap.print_help()
        return 2
    try:
        sp = load_spec(SPEC)
    except (OSError, ValueError) as e:
        print(f"could not read {SPEC}: {e}", file=sys.stderr)
        return 2
    if shutil.which(a.zig) is None and not pathlib.Path(a.zig).exists():
        print(f"no zig at {a.zig}", file=sys.stderr)
        return 2
    doc = measure(sp, a.zig, a.reuse_cache, build=(a.command == "headless"))
    doc["violations"] = judge(sp, doc)
    out = pathlib.Path(a.out) if a.out else ROOT / "zig-out" / "reproduce" / f"{a.command}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(doc, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    t = doc["test"]
    print(f"reproduce {a.command}: zig {doc['zig']}, {'fresh' if doc['fresh_caches'] else 'reused'} caches, head {doc['head'][:12]}")
    if "build" in doc:
        print(f"  build: exit {doc['build']['rc']}, {doc['build']['summary'].get('line', 'no summary')}, "
              f"{sum(1 for h in doc['installs'].values() if h)}/{len(doc['installs'])} installs")
    print(f"  test:  exit {t['rc']}, {t['summary'].get('line', 'no summary')}")
    print(f"         compile failures {[f['root'] for f in t['compile_failures']]}, run steps {t['run_steps']}")
    for x in doc["violations"]:
        print("VIOLATION:", x)
    print(f"  evidence: {out}")
    print("  the profile is what specs/reproduce/headless.t27 says" if not doc["violations"] else f"  {len(doc['violations'])} violation(s)")
    return 1 if doc["violations"] else 0


if __name__ == "__main__":
    sys.exit(main())
