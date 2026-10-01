#!/usr/bin/env python3
"""Consume the canonical t27 contracts of gHashTag/trinity byte for byte, at a pinned revision.

WHY THIS EXISTS
---------------
S12 of gHashTag/trinity#988 (gHashTag/trinity#989) asks the consumer to take the canonical t27
manifest and specifications byte-identically, with a pinned revision and compiler hashes. The
project manifest of S01 (gHashTag/t27 specs/trinity/project.t27) says the same from the other side:
the consumer vendors a byte-identical copy and generates its manifest from these files, and nothing
in the consumer is a second authored registry.

Until this tool trinity met t27 only through the website mirror, apps/website/public/t27/files/. That
is a catalog snapshot, not a lock: it is read from a tarball of t27 master with nine files of a second
branch laid over it (manifest.json, generatedFrom.overlayRefs), it records no hash per file, and its
compiler is "the copy already vendored here" (generatedFrom.wasmSource). Nothing could say whether a
contract trinity reads is the one t27 holds.

WHAT IT CHECKS
--------------
specs/reproduce/contracts.t27 is the lock: the t27 revision, the git ids of the compiler's sources at
that revision (t27c, the package bootstrap/ of t27's Cargo workspace), and every vendored file with
its sha256. The
files are external/t27/<the same path as in t27>, and the set is not chosen here: it is every file of
t27's specs/trinity/, every t27 path a capability card names as CANONICAL_SPEC, IMPLEMENTATION or
GENERATED (the fields tools/trinity_manifest.py checks as paths), and that checker itself.

  check                       offline: every locked file is there with its sha256, nothing else is
                              under external/t27, and the lock holds exactly what the cards ask for
  check --upstream            also fetches t27 at the revision and compares every file and every
                              compiler id with what t27 holds there
  check --t27c BIN            also runs the pinned compiler over the vendored tree: parse-complete
                              says what it cannot read, and test-report runs every spec's tests with
                              the Zig the lock names (T27_TEST_ZIG). What the compiler cannot read or
                              build is a ledger in the lock with its reason, as BLOCKED_ROOTS is in
                              specs/reproduce/headless.t27: a new entry fails, a vanished one fails,
                              a failing contract test fails, and fewer tests than TESTS_RUN_MIN fail.
                              `t27c typecheck` is not run: at the pin it reports ok for a string
                              assigned to a u32 and for `pub const A : u32 = ;`, so it cannot fail.
  revision, test-zig          print the pinned revision and the Zig of its spec tests (for a workflow)
  vendor --t27 DIR --revision REV
                              maintenance: rewrites external/t27 and the lock from a clone of t27
  --self-check                plants each defect and shows it caught

Usage (from the repository root):
  python3 tools/contracts.py check [--upstream] [--t27 DIR] [--t27c BIN [--zig-dir DIR]]
  python3 tools/contracts.py vendor --t27 DIR --revision REV
  python3 tools/contracts.py revision
  python3 tools/contracts.py --self-check
Exit codes: 0 the consumed contracts are what the lock says; 1 they are not (every finding printed);
2 could not run. Standard library only.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
LOCK = "specs/reproduce/contracts.t27"
CARDS = "specs/trinity/capabilities"
CHECKER = "tools/trinity_manifest.py"
PATH_FIELDS = ("CANONICAL_SPEC", "IMPLEMENTATION", "GENERATED")
# t27c is built from the workspace root (bootstrap/ is a member), so cargo resolves it with the root
# Cargo.lock; bootstrap/Cargo.lock is not read by that build and is not part of what it compiles.
COMPILER_PATHS = ("Cargo.lock", "Cargo.toml", "bootstrap/Cargo.toml", "bootstrap/build.rs", "bootstrap/src")
T27_ZIG_SOURCE = ".github/workflows/oracle-nightly.yml"
CONST_RE = re.compile(r"^pub const (\w+) : ([^=]+?) = (.*);\s*$")


# ===========================================================================================
# The lock and the cards, read with the line grammar the other consumers of .t27 constants use
# ===========================================================================================
def constants(text: str, where: str) -> dict:
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
            out[m.group(1)] = value_of(m.group(3).strip(), m.group(2).strip(), where)
        elif line.startswith("pub const"):
            raise ValueError(f"{where}:{n}: cannot read constant line")
    return out


def value_of(raw: str, typ: str, where: str):
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
            raise ValueError(f"{where}: annotated {typ}, holds {len(items)}")
        return items
    raise ValueError(f"{where}: unknown type {typ}")


def read_lock(root: pathlib.Path) -> dict:
    text = (root / LOCK).read_text(encoding="utf-8")
    if re.search(r"[^\x00-\x7f]", text):
        raise ValueError(f"{LOCK}: non-ASCII byte (L3)")
    return constants(text, LOCK)


def asked_for(files: dict) -> list:
    """What the cards ask for, from {t27 path: bytes} of specs/trinity/: the directory itself, the
    t27 paths in the card fields the S01 checker treats as paths, and the checker. A path with a
    `<repo>:` prefix lives elsewhere and is not vendored."""
    want = {p for p in files if p.startswith("specs/trinity/")} | {CHECKER}
    for path, data in files.items():
        if not path.startswith(CARDS + "/") or not path.endswith(".t27"):
            continue
        card = constants(data.decode("utf-8"), path)
        for field in PATH_FIELDS:
            value = card.get(field, [])
            for ref in ([value] if isinstance(value, str) else value):
                if ref and not re.match(r"^[\w.-]+:", ref):
                    want.add(ref.rstrip("/"))
    return sorted(want)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


# ===========================================================================================
# t27 at a revision: an existing clone, or a shallow, blobless fetch of just the locked paths
# ===========================================================================================
class T27:
    def __init__(self, repo: str, revision: str, clone: pathlib.Path | None = None):
        self.revision, self.tmp = revision, None
        if clone is None:
            self.tmp = clone = pathlib.Path(tempfile.mkdtemp(prefix="t27-"))
        self.clone = clone
        if self.tmp is not None:
            self.git("init", "-q")
            self.git("remote", "add", "origin", repo)
            self.git("fetch", "-q", "--depth", "1", "--filter=blob:none", "origin", revision)

    def git(self, *args, check=True, binary=False):
        p = subprocess.run(["git", "-C", str(self.clone)] + list(args), capture_output=True)
        if check and p.returncode != 0:
            raise RuntimeError(f"git {' '.join(args)} exited {p.returncode}: {p.stderr.decode(errors='replace').strip()}")
        return p.stdout if binary else p.stdout.decode(errors="replace").strip()

    def object_id(self, path: str) -> str | None:
        p = subprocess.run(["git", "-C", str(self.clone), "rev-parse", "--verify", "-q", f"{self.revision}:{path}"], capture_output=True, text=True)
        return p.stdout.strip() if p.returncode == 0 else None

    def kind(self, path: str) -> str | None:
        p = subprocess.run(["git", "-C", str(self.clone), "cat-file", "-t", f"{self.revision}:{path}"], capture_output=True, text=True)
        return p.stdout.strip() if p.returncode == 0 else None

    def files_under(self, path: str) -> list:
        return [x for x in self.git("ls-tree", "-r", "--name-only", self.revision, "--", path).split("\n") if x]

    def read(self, paths: list) -> dict:
        """The bytes of each path at the revision, fetched in one batch when the clone is blobless."""
        out = {}
        spec = "".join(f"{self.revision}:{p}\n" for p in paths).encode()
        p = subprocess.run(["git", "-C", str(self.clone), "cat-file", "--batch"], input=spec, capture_output=True)
        if p.returncode != 0:
            raise RuntimeError(f"git cat-file --batch exited {p.returncode}: {p.stderr.decode(errors='replace').strip()}")
        buf, i = p.stdout, 0
        for path in paths:
            nl = buf.index(b"\n", i)
            header = buf[i:nl].decode()
            i = nl + 1
            if header.endswith("missing") or " " not in header:
                out[path] = None
                continue
            _, typ, size = header.split(" ")
            data = buf[i:i + int(size)]
            i += int(size) + 1
            out[path] = data if typ == "blob" else None
        return out

    def date(self) -> str:
        return self.git("show", "-s", "--format=%cI", self.revision)

    def close(self):
        if self.tmp is not None:
            shutil.rmtree(self.tmp, ignore_errors=True)


# ===========================================================================================
# The check
# ===========================================================================================
def vendored(root: pathlib.Path, vendor_dir: str) -> dict:
    base = root / vendor_dir
    return {p.relative_to(base).as_posix(): p.read_bytes() for p in sorted(base.rglob("*")) if p.is_file()} if base.is_dir() else {}


def check(root: pathlib.Path, upstream: "T27 | None" = None, t27c: str | None = None, zig_dir: str | None = None) -> list:
    v = []

    def bad(code, text):
        v.append(f"{code}: {text}")
    lock = read_lock(root)
    files, hashes = lock["FILES"], lock["SHA256"]
    if len(files) != len(hashes):
        bad("LOCK_SHAPE", f"{len(files)} files, {len(hashes)} hashes")
    if files != sorted(set(files)):
        bad("LOCK_SHAPE", "FILES is not sorted and unique")
    have = vendored(root, lock["VENDOR_DIR"])
    for path, want in zip(files, hashes):
        if path not in have:
            bad("MISSING", f"{lock['VENDOR_DIR']}/{path} is locked and absent")
        elif sha256(have[path]) != want:
            bad("DRIFT", f"{lock['VENDOR_DIR']}/{path} is not the locked bytes (sha256 {sha256(have[path])[:16]}, locked {want[:16]})")
    for path in sorted(set(have) - set(files)):
        bad("UNLOCKED", f"{lock['VENDOR_DIR']}/{path} is vendored and not in the lock")
    # A copy on disk is not a copy in the commit: a .gitignore rule (`*.md`, `mcp/`) would leave
    # a locked file out of every clone while this check, run in the working tree, still passed.
    if (root / ".git").exists():
        p = subprocess.run(["git", "-C", str(root), "check-ignore", "--no-index", "--stdin"], capture_output=True, text=True,
                           input="".join(f"{lock['VENDOR_DIR']}/{x}\n" for x in files))
        for path in [x for x in p.stdout.split("\n") if x]:
            bad("IGNORED", f"{path} is ignored by git, so a commit leaves it out; re-include {lock['VENDOR_DIR']}/** in .gitignore")
    asked = asked_for({p: b for p, b in have.items() if p.startswith("specs/trinity/")})
    # A card may name a directory; the lock then holds the files under it.
    under = lambda f, a: f == a or f.startswith(a + "/")
    for path in asked:
        if not any(under(f, path) for f in files):
            bad("NOT_VENDORED", f"the cards ask for {path} and the lock does not hold it")
    for path in files:
        if not any(under(path, a) for a in asked):
            bad("NOT_ASKED", f"{path} is locked and no card, and not specs/trinity/, asks for it")
    if upstream is not None:
        if upstream.revision != lock["T27_REVISION"]:
            bad("UPSTREAM_REVISION", f"compared with {upstream.revision}, the lock pins {lock['T27_REVISION']}")
        theirs = upstream.read(files)
        for path, want in zip(files, hashes):
            if theirs.get(path) is None:
                bad("UPSTREAM_ABSENT", f"{path} is not a file of t27 at {lock['T27_REVISION'][:12]}")
            elif sha256(theirs[path]) != want:
                bad("UPSTREAM_DIFFERS", f"{path} differs from t27 at {lock['T27_REVISION'][:12]} (sha256 {sha256(theirs[path])[:16]}, locked {want[:16]})")
        for path, want in zip(lock["COMPILER_PATHS"], lock["COMPILER_IDS"]):
            got = upstream.object_id(path)
            if got != want:
                bad("COMPILER_DRIFT", f"{path} is {got} at {lock['T27_REVISION'][:12]}, the lock says {want}")
        flow = upstream.read([T27_ZIG_SOURCE]).get(T27_ZIG_SOURCE)
        m = re.search(rb'ZIG_VERSION:\s*"([^"]+)"', flow or b"")
        if not m or m.group(1).decode() != lock["T27_TEST_ZIG"]:
            bad("TEST_TOOLCHAIN_DRIFT", f"{T27_ZIG_SOURCE} at {lock['T27_REVISION'][:12]} says ZIG_VERSION {m.group(1).decode() if m else 'nothing'}, the lock says {lock['T27_TEST_ZIG']}")
    if t27c:
        v += [f"{c}: {t}" for c, t in compiler_findings(root, lock, t27c, zig_dir)]
    return v


# ===========================================================================================
# The pinned compiler over the vendored contracts: what it cannot read, and what their tests do
# ===========================================================================================
def run(cmd: list, env_path: str | None = None) -> tuple:
    import os
    env = dict(os.environ)
    if env_path:
        env["PATH"] = env_path + os.pathsep + env.get("PATH", "")
    p = subprocess.run(cmd, capture_output=True, text=True, env=env)
    return p.returncode, p.stdout + p.stderr


def count(text: str, label: str):
    m = re.search(rf"^\s*{re.escape(label)}\s+(\d+)", text, re.M)
    return int(m.group(1)) if m else None


def compiler_findings(root: pathlib.Path, lock: dict, t27c: str, zig_dir: str | None = None) -> list:
    """t27c parse-complete over external/t27, then t27c test-report over its specs. Both exit 0
    whatever they find, so every verdict here is read from what they print -- and a run whose
    output cannot be read is a finding, never a pass."""
    out = []
    base = root / lock["VENDOR_DIR"]
    rel = lambda p: pathlib.Path(p).resolve().relative_to(base.resolve()).as_posix() if pathlib.Path(p).is_absolute() else p
    specs = sorted(p for p in lock["FILES"] if p.endswith(".t27"))
    rc, zv = run(["zig", "version"], zig_dir)
    if rc != 0 or zv.strip() != lock["T27_TEST_ZIG"]:
        out.append(("TOOLCHAIN", f"zig on PATH is {zv.strip()[:40]!r}; t27c test-report writes code for {lock['T27_TEST_ZIG']}, the Zig t27 runs its spec tests with"))
        return out
    rc, text = run([t27c, "parse-complete", "--specs-dir", str(base)], zig_dir)
    scanned, whole = count(text, "specs scanned"), count(text, "parse and consume all")
    trunc, noparse = count(text, "parse but TRUNCATE"), count(text, "do not parse")
    if rc != 0 or None in (scanned, whole, trunc, noparse):
        out.append(("COMPILER_RUN", f"t27c parse-complete exited {rc} and printed no readable summary:\n{text.strip()[:2000]}"))
    else:
        if scanned != len(specs):
            out.append(("PARSE_SCOPE", f"parse-complete read {scanned} specs, {len(specs)} are vendored"))
        if trunc or noparse:
            out.append(("PARSE_INCOMPLETE", f"{trunc} spec(s) truncated and {noparse} not parsed by the pinned compiler (it does not name the latter):\n{text.strip()[:2000]}"))
        dropped = {rel(m.group(1)): int(m.group(2)) for m in re.finditer(r"^(.+?): DISCARDED (\d+) top-level token", text, re.M)}
        known = dict(zip(lock["PARSE_DISCARDS"], lock["PARSE_DISCARD_TOKENS"]))
        if dropped != known:
            out.append(("PARSE_DISCARD", f"the pinned compiler drops {dropped}; the lock knows {known} -- a new drop is unread contract, a vanished one is a ledger line to remove"))
    rc, text = run([t27c, "test-report", "--all", "--specs-dir", str(base / "specs")], zig_dir)
    rows = {rel(m.group(3)): (int(m.group(1)), int(m.group(2))) for m in re.finditer(r"^\s+(\d+)/(\d+)\s+[\d.]+%\s+(\S+\.t27)\s*$", text, re.M)}
    ran, passed, failed = count(text, "tests run"), count(text, "pass"), count(text, "FAIL")
    if rc != 0 or None in (ran, passed, failed):
        out.append(("COMPILER_RUN", f"t27c test-report --all exited {rc} and printed no readable summary:\n{text.strip()[:2000]}"))
        return out
    for spec, (ok, total) in sorted(rows.items()):
        if ok != total:
            _, one = run([t27c, "test-report", str(base / spec), "--specs-dir", str(base / "specs")], zig_dir)
            out.append(("CONTRACT_TEST_FAILED", f"{spec}: {ok}/{total} tests pass with the pinned compiler; {re.findall(r'FAIL  (\S+)', one)}"))
    blocked, none = {}, []
    for spec in sorted(set(specs) - set(rows)):
        _, one = run([t27c, "test-report", str(base / spec), "--specs-dir", str(base / "specs")], zig_dir)
        m = re.search(r"BLOCKED\s+does not compile: \S*?([^/\s]+\.zig:\d+:\d+: error: .*)$", one, re.M)
        if m:
            blocked[spec] = m.group(1).strip()
        elif count(one, "tests") == 0:
            none.append(spec)
        else:
            out.append(("COMPILER_RUN", f"{spec}: test-report --all did not list it, and alone it printed:\n{one.strip()[:1500]}"))
    if sorted(blocked) != sorted(lock["TEST_BLOCKED"]):
        out.append(("CONTRACT_TEST_BLOCKED", f"specs whose tests the pinned compiler cannot build: newly {sorted(set(blocked) - set(lock['TEST_BLOCKED']))}, "
                                             f"no longer {sorted(set(lock['TEST_BLOCKED']) - set(blocked))}; now: {blocked}"))
    if sorted(none) != sorted(lock["TEST_NONE"]):
        out.append(("CONTRACT_NO_TESTS", f"specs that declare no test: {none}; the lock knows {lock['TEST_NONE']}"))
    if ran < lock["TESTS_RUN_MIN"]:
        out.append(("CONTRACT_TESTS_FEWER", f"{ran} contract tests ran, the floor is {lock['TESTS_RUN_MIN']}"))
    return out


# ===========================================================================================
# vendor: the only writer of external/t27 and of the lock's data
# ===========================================================================================
def set_const(text: str, name: str, typ: str, value) -> str:
    """Replace one `pub const` statement (one line or several) and keep everything around it."""
    if isinstance(value, list):
        body = "[\n" + ",\n".join(f"    {json.dumps(x)}" for x in value) + "\n]" if value else "[]"
    else:
        body = json.dumps(value)
    new = f"pub const {name} : {typ} = {body};"
    pat = re.compile(rf"^pub const {name} : [^=]+= .*?;[ \t]*$", re.M | re.S)
    if not pat.search(text):
        raise ValueError(f"{LOCK}: no constant {name}")
    return pat.sub(lambda _: new, text, count=1)


def vendor(root: pathlib.Path, t27: T27) -> dict:
    lock_text = (root / LOCK).read_text(encoding="utf-8")
    lock = constants(lock_text, LOCK)
    cards_dir = t27.read(t27.files_under("specs/trinity"))
    asked = asked_for(cards_dir)
    paths = []
    for p in asked:
        k = t27.kind(p)
        if k == "tree":
            paths += t27.files_under(p)
        elif k == "blob":
            paths.append(p)
        else:
            raise RuntimeError(f"the cards ask for {p}, which t27 does not have at {t27.revision}")
    paths = sorted(set(paths))
    data = t27.read(paths)
    base = root / lock["VENDOR_DIR"]
    if base.exists():
        shutil.rmtree(base)
    for p in paths:
        out = base / p
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(data[p])
    ids = [t27.object_id(p) for p in COMPILER_PATHS]
    if None in ids:
        raise RuntimeError(f"no compiler source {COMPILER_PATHS[ids.index(None)]} at {t27.revision}")
    for name, typ, value in (("T27_REVISION", "str", t27.revision), ("T27_REVISION_AT", "str", t27.date()),
                             ("COMPILER_PATHS", f"[{len(COMPILER_PATHS)}]str", list(COMPILER_PATHS)),
                             ("COMPILER_IDS", f"[{len(ids)}]str", ids),
                             ("FILES", f"[{len(paths)}]str", paths), ("SHA256", f"[{len(paths)}]str", [sha256(data[p]) for p in paths])):
        lock_text = set_const(lock_text, name, typ, value)
    (root / LOCK).write_text(lock_text, encoding="utf-8")
    return {"revision": t27.revision, "files": len(paths), "compiler": dict(zip(COMPILER_PATHS, ids))}


# ===========================================================================================
# --self-check: a toy t27 and a toy consumer, each defect planted once
# ===========================================================================================
TOY_LOCK = """; toy lock
module toy_lock;

pub const KIND : str = "contract-lock";
pub const T27_REPO : str = "file://toy";
pub const T27_REVISION : str = "";
pub const T27_REVISION_AT : str = "";
pub const VENDOR_DIR : str = "external/t27";
pub const COMPILER_PATHS : [0]str = [];
pub const COMPILER_IDS : [0]str = [];
pub const T27_TEST_ZIG : str = "0.16.0";
pub const PARSE_DISCARDS : [1]str = ["specs/toy/contract.t27"];
pub const PARSE_DISCARD_TOKENS : [1]u32 = [7];
pub const PARSE_DISCARD_REASONS : [1]str = ["planted"];
pub const TEST_BLOCKED : [1]str = ["specs/trinity/project.t27"];
pub const TEST_BLOCKED_ERRORS : [1]str = ["spec.zig:1:1: error: planted"];
pub const TEST_NONE : [0]str = [];
pub const TESTS_RUN_MIN : u32 = 2;
pub const FILES : [0]str = [];
pub const SHA256 : [0]str = [];
pub const ENABLED : bool = true;
"""
TOY_CARD = """module toy_card;
pub const KIND : str = "capability";
pub const ID : str = "trinity/toy";
pub const CANONICAL_SPEC : str = "specs/toy/contract.t27";
pub const IMPLEMENTATION : [2]str = ["trinity:src/toy.zig", "tools/toy_adapter.py"];
pub const GENERATED : [1]str = ["conformance/toy/"];
pub const ENABLED : bool = true;
"""


FAKE_T27C = r"""#!/usr/bin/env python3
import os, pathlib, sys
env = lambda k, d="": os.environ.get(k, d)
listed = lambda k: [x for x in env(k).split(",") if x]
if env("FAKE_GARBLE"):
    sys.exit(0)
args = sys.argv[1:]
d = pathlib.Path(args[args.index("--specs-dir") + 1])
if args[0] == "parse-complete":
    specs = sorted(d.rglob("*.t27"))
    drops = dict(x.split(":") for x in listed("FAKE_DISCARDS"))
    for rel, n in drops.items():
        print(f"{d / rel}: DISCARDED {n} top-level token(s)")
    noparse = int(env("FAKE_NOPARSE", "0"))
    print("--- parse completeness ---")
    print(f"  specs scanned            {len(specs) + int(env('FAKE_EXTRA_SCANNED', '0'))}")
    print(f"  parse and consume all    {len(specs) - len(drops) - noparse}")
    print("  parse but TRUNCATE       0")
    print(f"  parse but DISCARD        {len(drops)} (0 token(s))")
    print(f"  do not parse             {noparse}")
    sys.exit(0)
root = d.parent
rel = lambda p: p.relative_to(root).as_posix()
blocked, none, failing = listed("FAKE_BLOCKED"), listed("FAKE_NONE"), listed("FAKE_FAILING")
if "--all" in args:
    ran = ok = 0
    for p in sorted(d.rglob("*.t27")):
        if rel(p) in blocked or rel(p) in none:
            continue
        good = 0 if rel(p) in failing else 1
        ran, ok = ran + 1, ok + good
        print(f"     {good}/1    {100.0 * good:.1f}%  {p}")
    fewer = int(env("FAKE_FEWER", "0"))
    ran, ok = ran - fewer, ok - fewer
    print("--- per-test measurement over the tree ---")
    print(f"  tests run                {ran}")
    print(f"  pass                     {ok}")
    print(f"  FAIL                     {ran - ok}")
    sys.exit(0)
spec = rel(pathlib.Path(args[1]))
print(f"--- test report: {args[1]} ---")
if spec in blocked:
    print(f"  BLOCKED  does not compile: /tmp/t27c-test-report-x/spec.zig:1:1: error: planted")
elif spec in none:
    print("  tests       0")
elif spec in failing:
    print("  FAIL  planted_test")
    print("  tests       1")
"""


def self_check() -> int:
    ok = True
    seen = set()

    def expect(cond, what):
        nonlocal ok
        print(f"  {'ok ' if cond else 'BAD'} {what}")
        ok = ok and bool(cond)
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="contracts-self-check-"))
    try:
        t27 = tmp / "t27"
        tree = {"specs/trinity/project.t27": "module p;\npub const KIND : str = \"project\";\n",
                "specs/trinity/README.md": "# toy\n", "specs/trinity/capabilities/toy.t27": TOY_CARD,
                "specs/toy/contract.t27": "module c;\npub const ENABLED : bool = true;\n", "specs/toy/unasked.t27": "module u;\n",
                "tools/toy_adapter.py": "print('toy')\n", "tools/trinity_manifest.py": "# checker\n",
                "conformance/toy/a.json": "{}\n", "conformance/toy/b.json": "[]\n",
                "Cargo.toml": "[workspace]\n", "Cargo.lock": "# lock\n", "bootstrap/Cargo.toml": "[package]\n", "bootstrap/build.rs": "fn main() {}\n",
                "bootstrap/src/main.rs": "fn main() {}\n", ".github/workflows/oracle-nightly.yml": 'env:\n  ZIG_VERSION: "0.16.0"\n'}
        for p, s in tree.items():
            (t27 / p).parent.mkdir(parents=True, exist_ok=True)
            (t27 / p).write_text(s)
        g = lambda *a: subprocess.run(["git", "-C", str(t27)] + list(a), capture_output=True, text=True, check=True).stdout.strip()
        g("init", "-q")
        g("add", "-A")
        g("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "toy")
        rev = g("rev-parse", "HEAD")
        consumer = tmp / "trinity"
        (consumer / LOCK).parent.mkdir(parents=True, exist_ok=True)
        (consumer / LOCK).write_text(TOY_LOCK)
        up = T27("unused", rev, t27)
        got = vendor(consumer, up)
        lock = read_lock(consumer)
        expect(lock["FILES"] == ["conformance/toy/a.json", "conformance/toy/b.json", "specs/toy/contract.t27", "specs/trinity/README.md",
                                 "specs/trinity/capabilities/toy.t27", "specs/trinity/project.t27", "tools/toy_adapter.py", "tools/trinity_manifest.py"],
               f"vendor takes specs/trinity/, the t27 paths the card names (a directory whole), the checker; not trinity: paths, not unasked files ({got['files']} files)")
        expect(not check(consumer, up), f"a consumer that is what its lock says is silent ({check(consumer, up)[:2]})")
        def codes():
            got = {x.split(":")[0] for x in check(consumer, up)}
            seen.update(got)
            return got
        f = consumer / "external/t27/specs/toy/contract.t27"
        original = f.read_bytes()
        f.write_bytes(original + b"; one more byte\n")
        expect("DRIFT" in codes(), "planted: a vendored byte changed")
        f.unlink()
        expect("MISSING" in codes(), "planted: a locked file removed")
        f.write_bytes(original)
        (consumer / "external/t27/specs/toy/extra.t27").write_text("module x;\n")
        expect("UNLOCKED" in codes(), "planted: a file vendored by hand, outside the lock")
        (consumer / "external/t27/specs/toy/extra.t27").unlink()
        text = (consumer / LOCK).read_text()
        (consumer / LOCK).write_text(text.replace(sha256(original), sha256(original + b"x")))
        c = codes()
        expect({"DRIFT", "UPSTREAM_DIFFERS"} <= c, "planted: a lock hash edited to match a change (the bytes and t27 both disagree)")
        (consumer / LOCK).write_text(text)
        card = consumer / "external/t27/specs/trinity/capabilities/toy.t27"
        card_bytes = card.read_bytes()
        card.write_bytes(card_bytes.replace(b'["conformance/toy/"]', b'["conformance/toy/", "specs/toy/unasked.t27"]').replace(b"GENERATED : [1]str", b"GENERATED : [2]str"))
        expect("NOT_VENDORED" in codes(), "planted: a card that names a t27 path the lock does not hold")
        card.write_bytes(card_bytes)
        (t27 / "specs/toy/contract.t27").write_text("module c;\npub const ENABLED : bool = false;\n")
        (t27 / "bootstrap/src/main.rs").write_text("fn main() { panic!() }\n")
        g("add", "-A")
        g("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "upstream moved")
        moved = T27("unused", g("rev-parse", "HEAD"), t27)
        c = {x.split(":")[0] for x in check(consumer, moved)}
        seen.update(c)
        expect({"UPSTREAM_REVISION", "UPSTREAM_DIFFERS", "COMPILER_DRIFT"} <= c, f"planted: t27 moved on (a contract and the compiler changed) ({sorted(c)})")
        lines = (consumer / LOCK).read_text().replace('    "tools/trinity_manifest.py"\n', '    "tools/trinity_manifest.py",\n    "tools/zzz_unasked.py"\n')
        lines = re.sub(r"FILES : \[(\d+)\]str", lambda m: f"FILES : [{int(m.group(1)) + 1}]str", lines)
        lines = re.sub(r"SHA256 : \[(\d+)\]str = \[\n", lambda m: f"SHA256 : [{int(m.group(1)) + 1}]str = [\n    \"{'0' * 64}\",\n", lines)
        (consumer / LOCK).write_text(lines)
        (consumer / "external/t27/tools/zzz_unasked.py").write_text("")
        c = codes()
        expect("NOT_ASKED" in c, f"planted: a locked file nothing asks for ({sorted(c)})")
        expect("LOCK_SHAPE" not in c, "the planted lock is still well formed, so the finding is about the set")
        (consumer / LOCK).write_text(text)
        (consumer / "external/t27/tools/zzz_unasked.py").unlink()
        import os
        bindir = tmp / "bin"
        bindir.mkdir()
        fake = tmp / "t27c"
        fake.write_text(FAKE_T27C)
        (bindir / "zig").write_text("#!/bin/sh\necho ${FAKE_ZIG:-0.16.0}\n")
        for x in (fake, bindir / "zig"):
            x.chmod(0o755)
        lock = read_lock(consumer)
        base_env = {"FAKE_DISCARDS": "specs/toy/contract.t27:7", "FAKE_BLOCKED": "specs/trinity/project.t27"}

        def ccodes(**planted):
            saved = dict(os.environ)
            os.environ.update({**base_env, **{k: str(v) for k, v in planted.items()}})
            try:
                got = {c for c, _ in compiler_findings(consumer, lock, str(fake), str(bindir))}
                seen.update(got)
                return got
            finally:
                os.environ.clear()
                os.environ.update(saved)
        expect(not ccodes(), f"compiler run: contracts that read and test as the lock says are silent ({ccodes()})")
        expect("TOOLCHAIN" in ccodes(FAKE_ZIG="0.15.2"), "planted: another Zig for the contract tests")
        expect("PARSE_DISCARD" in ccodes(FAKE_DISCARDS="specs/toy/contract.t27:7,specs/trinity/project.t27:3"), "planted: the compiler drops tokens of one more spec")
        expect("PARSE_DISCARD" in ccodes(FAKE_DISCARDS=""), "planted: a known drop that vanished (the ledger would outlive it)")
        expect("PARSE_INCOMPLETE" in ccodes(FAKE_NOPARSE=1), "planted: a spec the compiler does not parse")
        expect("PARSE_SCOPE" in ccodes(FAKE_EXTRA_SCANNED=1), "planted: the compiler read a different tree")
        expect("CONTRACT_TEST_FAILED" in ccodes(FAKE_FAILING="specs/trinity/capabilities/toy.t27"), "planted: a contract test that fails")
        expect("CONTRACT_TEST_BLOCKED" in ccodes(FAKE_BLOCKED="specs/trinity/project.t27,specs/toy/contract.t27"), "planted: one more spec whose tests do not build")
        expect("CONTRACT_TEST_BLOCKED" in ccodes(FAKE_BLOCKED=""), "planted: a blocked spec that builds again (take it off the list)")
        expect("CONTRACT_NO_TESTS" in ccodes(FAKE_NONE="specs/toy/contract.t27"), "planted: a spec that stopped declaring tests")
        expect("CONTRACT_TESTS_FEWER" in ccodes(FAKE_FEWER=1), "planted: fewer contract tests than the floor")
        expect("COMPILER_RUN" in ccodes(FAKE_GARBLE=1), "planted: a compiler run whose output says nothing (silence is not a pass)")
        (t27 / ".github/workflows").mkdir(parents=True, exist_ok=True)
        (t27 / ".github/workflows/oracle-nightly.yml").write_text('env:\n  ZIG_VERSION: "0.17.0"\n')
        g("add", "-A")
        g("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "zig moved")
        c = {x.split(":")[0] for x in check(consumer, T27("unused", g("rev-parse", "HEAD"), t27))}
        seen.update(c)
        expect("TEST_TOOLCHAIN_DRIFT" in c, "planted: t27 runs its spec tests with another Zig than the lock says")
        subprocess.run(["git", "-C", str(consumer), "init", "-q"], check=True)
        (consumer / ".gitignore").write_text("*.md\n")
        expect("IGNORED" in codes(), "planted: a .gitignore rule that would leave a locked file out of the commit")
        (consumer / ".gitignore").write_text("*.md\n!external/t27/**/\n!external/t27/**\n")
        expect("IGNORED" not in codes(), "the same rule with the vendored copy re-included is silent")
        good = (consumer / LOCK).read_text()
        files_block = re.search(r"pub const FILES : \[\d+\]str = \[\n(.*?)\n\];", good, re.S).group(1).split(",\n")
        swapped = good.replace(",\n".join(files_block), ",\n".join([files_block[1], files_block[0]] + files_block[2:]))
        (consumer / LOCK).write_text(swapped)
        expect("LOCK_SHAPE" in codes(), "planted: a lock whose FILES are out of order (a hand edit)")
        (consumer / LOCK).write_text(good)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    src = pathlib.Path(__file__).read_text(encoding="utf-8").split("def self_check(", 1)[0]
    rules = set(re.findall(r'bad\("([A-Z_]+)"', src)) | set(re.findall(r'out\.append\(\("([A-Z_]+)"', src))
    expect(rules <= seen, f"every rule fired at least once ({len(rules & seen)}/{len(rules)}; never: {sorted(rules - seen)})")
    real = read_lock(ROOT)
    expect(len(real["FILES"]) == len(real["SHA256"]) and real["FILES"] == sorted(set(real["FILES"])), f"the real lock is well formed ({len(real['FILES'])} files)")
    print("contracts --self-check:", "ok" if ok else "FAILED")
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("command", nargs="?", choices=["check", "vendor", "revision", "test-zig"])
    ap.add_argument("--upstream", action="store_true", help="compare with t27 at the pinned revision")
    ap.add_argument("--t27", help="an existing clone of t27 to compare with or vendor from (default: fetch)")
    ap.add_argument("--t27c", help="the pinned compiler, built from bootstrap/ at the revision")
    ap.add_argument("--revision", help="vendor: the t27 revision to vendor")
    ap.add_argument("--zig-dir", help="a directory to put first on PATH for the compiler run (the Zig of T27_TEST_ZIG)")
    ap.add_argument("--self-check", action="store_true")
    a = ap.parse_args()
    if a.self_check:
        return self_check()
    try:
        lock = read_lock(ROOT)
    except (OSError, ValueError) as e:
        print(f"could not read {LOCK}: {e}", file=sys.stderr)
        return 2
    if a.command == "revision":
        print(lock["T27_REVISION"])
        return 0
    if a.command == "test-zig":
        print(lock["T27_TEST_ZIG"])
        return 0
    if a.command == "vendor":
        if not (a.t27 and a.revision):
            print("vendor needs --t27 DIR and --revision REV", file=sys.stderr)
            return 2
        print(json.dumps(vendor(ROOT, T27(lock["T27_REPO"], a.revision, pathlib.Path(a.t27))), indent=1))
        return 0
    if a.command != "check":
        ap.print_help()
        return 2
    t27 = None
    try:
        if a.upstream or a.t27:
            t27 = T27(lock["T27_REPO"], lock["T27_REVISION"], pathlib.Path(a.t27) if a.t27 else None)
        findings = check(ROOT, t27, a.t27c, a.zig_dir)
    except (OSError, ValueError, RuntimeError) as e:
        print(f"contracts: could not run: {e}", file=sys.stderr)
        return 2
    finally:
        if t27 is not None:
            t27.close()
    print(f"contracts: {len(lock['FILES'])} files of {lock['T27_REPO']} at {lock['T27_REVISION'][:12]} ({lock['T27_REVISION_AT']}) in {lock['VENDOR_DIR']}; "
          f"compared with t27: {'yes' if t27 else 'no'}; compiler run: {'yes' if a.t27c else 'no'}")
    for x in findings:
        print("FINDING:", x)
    print("contracts:", "the consumed contracts are what the lock says" if not findings else f"{len(findings)} finding(s)")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
