#!/usr/bin/env python3
"""The Trinity project manifest: what gHashTag/trinity ships, from a pinned tree, checked
against the capability cards in specs/trinity/.

WHY THIS EXISTS
---------------
Epic gHashTag/trinity#988 (S01, gHashTag/t27#3563): the Queen catalog is a discovery
snapshot, not proof that Trinity can be recreated from specifications, and nothing tied a
capability to its owner, its spec, its implementation, its build target and its evidence.
This tool derives the inventory from a clean pinned checkout of gHashTag/trinity and holds
the cards in specs/trinity/capabilities/ to it: every build artifact and every build step
of build.zig must be owned by exactly one card, every path a card names must exist in the
pinned tree, and every claim of evidence must name where it was measured.

WHAT IT CHECKS, AND WHAT IT DELIBERATELY DOES NOT
-------------------------------------------------
Checked (exit 1 on any finding, each with an exact path or name):
  * the project spec pins the revision the inventory was taken from, and the inventory was
    taken from a tree with no modified tracked file (a dirty inventory is refused);
  * the dialect counts the project spec states equal the counts in the inventory, and neither
    the website mirror (apps/website/public/t27/files/) nor the consumer's vendored copies of
    this repository's contracts (external/t27/, locked by its specs/reproduce/contracts.t27)
    is ever counted as canonical -- each is counted apart;
  * every executable, library, test and step of build.zig is assigned to exactly one card
    (patterns are allowed, `test:src/trinity_node/*`); a card cannot own a target that the
    build does not define;
  * a target installed by default (`zig build -Dci=true`) belongs to a headless card, a
    target guarded by `!ci_mode` does not;
  * every `trinity:` path a card names is a tracked file or directory of the pinned tree;
    a t27 path it names exists in this repository; a mirror or vendored path is never
    canonical;
  * DIALECT agrees with the extension of CANONICAL_SPEC; BACKEND is one of the compiler's
    targets or "none", and only executable, adapter and research cards may claim one;
  * two cards cannot claim the same canonical spec under different owners, and no two
    cards share an ID;
  * EVIDENCE "measured" needs an ACCEPTANCE command and an EVIDENCE_SOURCE; the other four
    tags are the ones docs/system/project.md defines;
  * every work package of the epic has at least one card, and no card names a package the
    project spec does not list.
NOT checked: whether an ACCEPTANCE command passes. The inventory records what the tree
declares and what a public CI log measured; running the build belongs to S03 and S12.
The constants are read here with a line grammar (`pub const NAME : TYPE = VALUE;`); the
compiler remains the authority on the files themselves -- t27c parses, typechecks and
seals them in the other gates, and this tool refuses a card the grammar cannot read.

HOW THE ZIG SOURCES ARE READ
----------------------------
build.zig and every .zig file the reachability walk opens are read with their `//`
comments blanked first (`///` and `//!` included), byte for byte, so every offset and line
number is the file's own. String literals, character literals and multiline string lines
(the ones opened by two backslashes) are kept whole: a `//` inside them is text, not a
comment. A step, an install, a path or an @import that exists only in a comment is
therefore not counted. Until 2026-10-01 they were: at gHashTag/trinity@976df517 the steps
needle-mcp and trinity-mcp, the installs of trinity-canvas and trinity-canvas-wasm-check, and
one reachable file (src/background_agent/db/issue_bindings.zig, through a commented @import)
existed only in comments, and two cards owned the steps and named `zig build needle-mcp` /
`zig build trinity-mcp` as their acceptance -- commands that answer "no step named"
(gHashTag/trinity#989). Not done: the content of a multiline string is still text the
patterns can match; build.zig carries no multiline string at the pin, and blanking those
lines as well changes no reachability there (measured).

Usage:
  python3 tools/trinity_manifest.py inventory --trinity-root DIR [--out conformance/trinity/inventory.json]
  python3 tools/trinity_manifest.py check [--inventory PATH] [--specs specs/trinity] [--report conformance/trinity/report.json]
  python3 tools/trinity_manifest.py --self-check

Exit codes:
  0  no finding
  1  findings (listed, one per line, with a code)
  2  could not run: no inventory, no such tree, dirty tree, unreadable card
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
INVENTORY = "conformance/trinity/inventory.json"
REPORT = "conformance/trinity/report.json"
SPECS = "specs/trinity"
MIRROR = "apps/website/public/t27/files/"
# The consumer's byte-identical copies of this repository's contracts (specs/trinity/**, the
# canonical specs the cards name and this checker), locked by its specs/reproduce/contracts.t27
# (S12). They are t27's files, not the consumer's own specs: counted apart, never canonical.
VENDORED = "external/t27/"
NEVER_CANONICAL = (MIRROR, VENDORED)
CONSUMER = "gHashTag/trinity"

DISPOSITIONS = ("executable", "declared", "adapter", "external", "deprecated", "out-of-scope", "research", "catalog-only")
PROFILES = ("headless", "web", "native", "fpga", "training", "network", "research")
EVIDENCE = ("measured", "declared", "specified", "external", "not-claimed")
BACKENDS = ("none", "zig", "c", "rust", "verilog", "wasm", "ts", "swift", "python")
BACKEND_ALLOWED_FOR = ("executable", "adapter", "research")
DIALECTS = ("t27", "tri", "vibee", "none")
PROJECT_REQUIRED = {
    "KIND": "str", "ID": "str", "NAME": "str", "CONSUMER_REPO": "str", "PINNED_REVISION": "str",
    "PINNED_AT": "str", "T27_REVISION": "str", "PROFILES": "arr", "INITIAL_PROFILE": "str",
    "DISPOSITIONS": "arr", "EVIDENCE_TAGS": "arr", "DIALECTS": "arr",
    "T27_CANONICAL_FILES": "u16", "T27_MIRROR_FILES": "u16", "T27_VENDORED_FILES": "u16", "TRI_FILES": "u16", "VIBEE_FILES": "u16",
    "ZIG_FILES": "u16", "ZIG_UNREACHABLE_FILES": "u16",
    "BUILD_EXECUTABLES": "u8", "BUILD_LIBRARIES": "u8", "BUILD_TESTS": "u8", "BUILD_STEPS": "u8",
    "INSTALLED_BY_DEFAULT": "u8", "INSTALLED_GUARDED": "u8",
    "DEPENDENCIES": "arr", "DEPENDENCY_PINS": "arr", "SUBMODULES": "arr",
    "REGISTRY_COMMANDS": "u16", "CATALOG_SPECS": "u16", "CATALOG_REPOSITORIES": "u8",
    "WORK_PACKAGES": "arr", "WORK_PACKAGE_ISSUES": "arr", "WORK_PACKAGE_CURRENT_ISSUES": "arr", "ENABLED": "bool",
}
CARD_REQUIRED = {
    "KIND": "str", "ID": "str", "TITLE": "str", "OWNER_REPO": "str", "DISPOSITION": "str", "PROFILE": "str",
    "CANONICAL_SPEC": "str", "DIALECT": "str", "IMPLEMENTATION": "arr", "GENERATED": "arr", "BACKEND": "str",
    "TARGETS": "arr", "ACCEPTANCE": "str", "EVIDENCE": "str", "EVIDENCE_SOURCE": "str", "WORK_PACKAGE": "str",
    "NOTE": "str", "ENABLED": "bool",
}
REPO_RE = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?/[A-Za-z0-9_.-]{1,100}$")
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
WP_RE = re.compile(r"^S(0[1-9]|1[0-2])$")
ISSUE_URL_RE = re.compile(r"^https://github\.com/[A-Za-z0-9-]+/[A-Za-z0-9_.-]+/issues/[1-9][0-9]*$")


# ---------------------------------------------------------------------------
# Inventory of a pinned gHashTag/trinity tree.
# ---------------------------------------------------------------------------
def git(root: pathlib.Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True, text=True).stdout


def balanced(src: str, start: int, open_ch: str, close_ch: str) -> int:
    """Index just past the bracket that closes the one at `start` (which must be open_ch)."""
    depth = 0
    i = start
    in_str = False
    while i < len(src):
        c = src[i]
        if in_str:
            if c == "\\":
                i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError("unbalanced bracket")


def depth1_fields(init: str) -> dict:
    """Fields of a `.{ ... }` initializer at depth 1: `.name = <text up to the next depth-1 comma>`."""
    body = init[init.index("{") + 1: init.rindex("}")]
    fields, depth, cur, in_str = {}, 0, [], False
    parts = []
    for c in body:
        if in_str:
            cur.append(c)
            if c == '"' and (len(cur) < 2 or cur[-2] != "\\"):
                in_str = False
            continue
        if c == '"':
            in_str = True
        elif c in "{([":
            depth += 1
        elif c in "})]":
            depth -= 1
        if c == "," and depth == 0:
            parts.append("".join(cur)); cur = []
        else:
            cur.append(c)
    parts.append("".join(cur))
    for p in parts:
        m = re.match(r"\s*\.(\w+)\s*=\s*(.*)$", p.strip(), re.S)
        if m:
            fields[m.group(1)] = m.group(2).strip()
    return fields


def root_source(fields: dict) -> str | None:
    if "root_source_file" in fields:
        m = re.search(r'b\.path\("([^"]+)"\)', fields["root_source_file"])
        return m.group(1) if m else None
    if "root_module" in fields:
        m = re.search(r'\.root_source_file\s*=\s*b\.path\("([^"]+)"\)', fields["root_module"])
        return m.group(1) if m else None
    return None


def blank_comments(src: str) -> str:
    """Zig source with every `//` comment (`///` and `//!` included) replaced by spaces, one
    for one, so every offset and line number of the result is the source's own.

    A `//` is a comment only outside a literal. String and character literals are skipped
    with their escapes (a quote held in '"' must not open a string); a multiline string
    line -- opened by two backslashes, running to the end of its line -- is skipped whole."""
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            end = src.find("\n", i)
            end = n if end < 0 else end
            for k in range(i, end):
                out[k] = " "
            i = end
        elif src.startswith("\\\\", i):
            end = src.find("\n", i)
            i = n if end < 0 else end
        elif c in "\"'":
            i += 1
            while i < n and src[i] != c:
                i += 2 if src[i] == "\\" else 1
            i += 1
        else:
            i += 1
    return "".join(out)


def parse_build_zig(text: str) -> dict:
    # A step, an artifact, an install, an option or a path written only in a comment is not
    # declared by the build: read the code, with the comments blanked in place.
    text = blank_comments(text)
    lines = text.split("\n")
    artifacts, seen = [], set()
    for m in re.finditer(r"(?:const|var)\s+(\w+)\s*=\s*b\.(addExecutable|addTest|addLibrary|addStaticLibrary|addSharedLibrary|addObject)\(", text):
        end = balanced(text, m.end() - 1, "(", ")")
        call = text[m.end(): end - 1].strip()
        if not call.startswith(".{"):
            continue
        fields = depth1_fields(call)
        name = re.match(r'"([^"]*)"', fields.get("name", "")).group(1) if re.match(r'"([^"]*)"', fields.get("name", "")) else None
        root = root_source(fields)
        kind = {"addExecutable": "exe", "addTest": "test"}.get(m.group(2), "lib")
        key = f"{kind}:{root if kind == 'test' else name}"
        rec = {"key": key, "kind": kind, "var": m.group(1), "name": name, "root": root, "line": text[: m.start()].count("\n") + 1}
        if key in seen:
            rec["duplicate_of"] = key
        seen.add(key)
        artifacts.append(rec)
    steps = [{"key": f"step:{m.group(1)}", "name": m.group(1), "description": m.group(2), "line": text[: m.start()].count("\n") + 1}
             for m in re.finditer(r'b\.step\("([^"]+)",\s*"([^"]*)"\)', text)]
    options = [{"name": m.group(2), "type": m.group(1), "description": m.group(3)}
               for m in re.finditer(r'b\.option\(\s*(\w+),\s*"([^"]+)",\s*"([^"]*)"', text)]

    def guards(line_idx: int) -> list[str]:
        depth, out = 0, []
        for i in range(line_idx, -1, -1):
            depth += lines[i].count("}") - lines[i].count("{")
            if depth < 0:
                g = re.search(r"if\s*\((.*)\)\s*\{", lines[i])
                if g:
                    out.append(g.group(1).strip())
                depth = 0
        return out

    by_var = {a["var"]: a for a in artifacts}
    installs = []
    for m in re.finditer(r"b\.installArtifact\((\w+)\)", text):
        line = text[: m.start()].count("\n") + 1
        art = by_var.get(m.group(1))
        g = guards(line - 1)
        installs.append({"var": m.group(1), "key": art["key"] if art else None, "name": art["name"] if art else m.group(1), "line": line,
                         "guards": g, "default": not g})
    # Every .zig file build.zig names: artifact roots and the roots of named modules
    # (`b.createModule(.{ .root_source_file = b.path("...") })`) that reach an artifact
    # through `.imports` rather than through a relative @import.
    zig_paths = sorted({m.group(1) for m in re.finditer(r'b\.path\("([^"]+\.zig)"\)', text)})
    return {"artifacts": artifacts, "steps": steps, "options": options, "installs": installs, "zig_paths": zig_paths}


def parse_zon(text: str) -> dict:
    deps = []
    for m in re.finditer(r"\.(\w+)\s*=\s*\.\{\s*\.url\s*=\s*\"([^\"]+)\"\s*,\s*\.hash\s*=\s*\"([^\"]+)\"", text):
        deps.append({"name": m.group(1), "url": m.group(2), "hash": m.group(3)})
    name = re.search(r"\.name\s*=\s*\.?(\w+)", text)
    version = re.search(r'\.version\s*=\s*"([^"]+)"', text)
    return {"name": name.group(1) if name else None, "version": version.group(1) if version else None, "dependencies": deps}


def parse_gitmodules(text: str) -> list[dict]:
    out = []
    for m in re.finditer(r'\[submodule "([^"]+)"\]\s*\n\s*path\s*=\s*(\S+)\s*\n\s*url\s*=\s*(\S+)', text):
        out.append({"name": m.group(1), "path": m.group(2), "url": m.group(3)})
    return out


def zig_reachability(root: pathlib.Path, files: list[str], roots: list[str]) -> dict:
    """Files reachable from the roots build.zig names through relative @import("x.zig");
    package/module imports (no .zig suffix) are recorded by name, not followed. An @import
    in a comment imports nothing: each file is read with its comments blanked."""
    tracked = set(files)
    cache: dict[str, list[str]] = {}
    modules: set[str] = set()

    def imports_of(path: str) -> list[str]:
        if path in cache:
            return cache[path]
        out = []
        try:
            text = blank_comments((root / path).read_text(encoding="utf-8", errors="replace"))
        except OSError:
            cache[path] = out
            return out
        for m in re.finditer(r'@import\("([^"]+)"\)', text):
            target = m.group(1)
            if target.endswith(".zig"):
                resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
                if resolved in tracked:
                    out.append(resolved)
            else:
                modules.add(target)
        cache[path] = out
        return out

    reachable: set[str] = set()
    stack = [r for r in roots if r in tracked]
    while stack:
        p = stack.pop()
        if p in reachable:
            continue
        reachable.add(p)
        stack.extend(imports_of(p))
    zig_files = sorted(f for f in files if f.endswith(".zig"))
    unreachable = [f for f in zig_files if f not in reachable]
    by_dir: dict[str, int] = {}
    for f in unreachable:
        top = "/".join(f.split("/")[:2]) if f.startswith("src/") else f.split("/")[0]
        by_dir[top] = by_dir.get(top, 0) + 1
    return {"zig_files": len(zig_files), "reachable": len(reachable & set(zig_files)), "unreachable": len(unreachable),
            "unreachable_by_dir": dict(sorted(by_dir.items(), key=lambda kv: (-kv[1], kv[0]))),
            "unreachable_files": unreachable, "module_imports": sorted(modules)}


def tree_of(files: list[str]) -> dict:
    tree: dict[str, list[str]] = {}
    for f in files:
        d, _, name = f.rpartition("/")
        tree.setdefault(d, []).append(name)
    return {d: sorted(names) for d, names in sorted(tree.items())}


def files_of(inv: dict) -> set[str]:
    """Every tracked path of the inventory, expanded once from its tree and cached."""
    if "_file_set" not in inv:
        inv["_file_set"] = {(d + "/" + n) if d else n for d, names in inv["tree"].items() for n in names}
    return inv["_file_set"]


def read_json(path: pathlib.Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def dialects_of(files: list[str]) -> dict:
    """The dialect counts of a tracked file list. A .t27 file under the website mirror or under
    the vendored copies of t27's contracts is counted apart, and is never canonical."""
    ext = lambda e: [f for f in files if f.endswith("." + e)]
    t27_all = ext("t27")
    t27_canonical = [f for f in t27_all if not f.startswith(NEVER_CANONICAL)]
    return {
        "t27_canonical": len(t27_canonical), "t27_mirror": len([f for f in t27_all if f.startswith(MIRROR)]),
        "t27_vendored": len([f for f in t27_all if f.startswith(VENDORED)]),
        "tri": len(ext("tri")), "vibee": len(ext("vibee")), "zig": len(ext("zig")),
        "mirror_prefix": MIRROR, "vendored_prefix": VENDORED, "t27_canonical_files": t27_canonical,
    }


def inventory(root: pathlib.Path) -> dict:
    if not (root / ".git").exists() and not (root / ".git").is_file():
        raise SystemExit(f"trinity_manifest: {root} is not a git checkout")
    sha = git(root, "rev-parse", "HEAD").strip()
    dirty = git(root, "status", "--porcelain", "--untracked-files=no").strip()
    if dirty:
        raise SystemExit("trinity_manifest: the tree has modified tracked files; an inventory of a dirty tree is not an inventory:\n" + dirty)
    files = git(root, "ls-files", "-z").split("\0")
    files = [f for f in files if f]
    build = parse_build_zig((root / "build.zig").read_text(encoding="utf-8"))
    zon = parse_zon((root / "build.zig.zon").read_text(encoding="utf-8"))
    gitmodules = (root / ".gitmodules")
    submodules = parse_gitmodules(gitmodules.read_text(encoding="utf-8")) if gitmodules.exists() else []
    # Every file build.zig names is part of the declared build graph: artifact roots and the
    # roots of named modules, read from the code of build.zig and never from its comments.
    roots = sorted({a["root"] for a in build["artifacts"] if a["root"]} | set(build["zig_paths"]))
    reach = zig_reachability(root, files, roots)
    reach["roots_named_by_build_zig"] = len(roots)
    registry = read_json(root / ".trinity/registry.json") or {}
    manifest = read_json(root / MIRROR.replace("files/", "manifest.json")) or {}
    atlas = read_json(root / MIRROR.replace("files/", "universe-atlas.json")) or {}
    top: dict[str, int] = {}
    for f in files:
        top[f.split("/")[0]] = top.get(f.split("/")[0], 0) + 1
    return {
        "version": 1,
        "generated_by": "tools/trinity_manifest.py inventory",
        "repo": CONSUMER,
        "sha": sha,
        "dirty": False,
        "committed_at": git(root, "log", "-1", "--format=%cI", "HEAD").strip(),
        "tracked_files": len(files),
        "top_level": dict(sorted(top.items(), key=lambda kv: (-kv[1], kv[0]))),
        "dialects": dialects_of(files),
        "build": {
            "options": build["options"],
            "executables": [a for a in build["artifacts"] if a["kind"] == "exe"],
            "libraries": [a for a in build["artifacts"] if a["kind"] == "lib"],
            "tests": [a for a in build["artifacts"] if a["kind"] == "test"],
            "steps": build["steps"],
            "installs": build["installs"],
            "installed_by_default": sorted({i["key"] for i in build["installs"] if i["default"] and i["key"]}),
            "installed_guarded": sorted({i["key"] for i in build["installs"] if not i["default"] and i["key"]}),
        },
        "dependencies": zon,
        "submodules": submodules,
        "zig_reachability": reach,
        "registry": {"path": ".trinity/registry.json", "version": registry.get("version"), "commands": len(registry.get("commands", []))},
        "catalog_snapshot": {
            "note": "counts of the vendored website catalog at this revision; a snapshot, never implementation coverage",
            "manifest_specs": manifest.get("specCount"),
            "manifest_repos": [{"repo": r.get("repo"), "specs": r.get("specs")} for r in manifest.get("repos", [])],
            "atlas_at": atlas.get("at"), "atlas_worlds": len(atlas.get("worlds", [])) if atlas else None,
            "atlas_specs": len(atlas.get("specs", [])) if atlas else None, "atlas_issues": len(atlas.get("issues", [])) if atlas else None,
        },
        # The tracked tree, one entry per directory with its file names. Kept in this shape
        # rather than as full paths so that the record is greppable by name but never reads as
        # an instruction: a full path such as `<dir>/scripts/tri-<x>.sh` of the consumer would
        # otherwise be taken for a `scripts/tri-<name>` reference by check_documented_commands_exist.
        "tree": tree_of(files),
    }


# ---------------------------------------------------------------------------
# The cards: a line grammar over `pub const`, refused when it cannot read a line.
# ---------------------------------------------------------------------------
CONST_RE = re.compile(r"^pub const (\w+) : ([^=]+?) = (.*);\s*$")


def parse_value(raw: str, typ: str):
    raw = raw.strip()
    if typ == "bool":
        if raw in ("true", "false"):
            return raw == "true"
        raise ValueError(f"bool literal expected, got {raw}")
    if typ in ("u8", "u16", "u32", "u64", "i32", "i64"):
        if re.fullmatch(r"-?\d+", raw):
            return int(raw)
        raise ValueError(f"integer literal expected, got {raw}")
    if typ == "str":
        if raw.startswith('"') and raw.endswith('"'):
            return json.loads(raw)
        raise ValueError(f"string literal expected, got {raw[:40]}")
    m = re.fullmatch(r"\[(\d+)\](\w+)", typ)
    if m:
        n, inner = int(m.group(1)), m.group(2)
        if not (raw.startswith("[") and raw.endswith("]")):
            raise ValueError(f"array literal expected, got {raw[:40]}")
        items = json.loads("[" + raw[1:-1] + "]") if inner == "str" else [int(x) for x in raw[1:-1].split(",") if x.strip()]
        if len(items) != n:
            raise ValueError(f"annotated [{n}]{inner}, holds {len(items)}")
        return items
    raise ValueError(f"unsupported type {typ}")


def parse_spec(path: pathlib.Path) -> dict:
    text = path.read_text(encoding="utf-8")
    if re.search(r"[^\x00-\x7f]", text):
        raise ValueError(f"{path}: non-ASCII byte (L3)")
    consts, module, tests = {}, None, 0
    for n, line in enumerate(text.split("\n"), 1):
        m = re.match(r"^module (\w+);", line)
        if m:
            module = m.group(1)
        if re.match(r"^\s*test\s+", line):
            tests += 1
        m = CONST_RE.match(line)
        if m:
            name, typ, raw = m.group(1), m.group(2).strip(), m.group(3)
            if name in consts:
                raise ValueError(f"{path}:{n}: duplicate constant {name}")
            consts[name] = {"type": typ, "value": parse_value(raw, typ), "line": n}
        elif line.startswith("pub const"):
            raise ValueError(f"{path}:{n}: cannot read constant line: {line[:60]}")
    return {"path": str(path), "module": module, "consts": consts, "tests": tests}


def shape_ok(decl: dict, shape: str) -> str | None:
    typ, value = decl["type"], decl["value"]
    if shape == "arr":
        return None if re.fullmatch(r"\[\d+\]str", typ) and isinstance(value, list) else f"annotated {typ}, must be [N]str"
    if shape in ("u8", "u16", "u32"):
        limit = {"u8": 255, "u16": 65535, "u32": 4294967295}[shape]
        return None if typ == shape and isinstance(value, int) and 0 <= value <= limit else f"annotated {typ}, must be {shape}"
    return None if typ == shape else f"annotated {typ}, must be {shape}"


def fields_of(spec: dict, required: dict, findings: list, label: str) -> dict:
    out = {}
    for name, shape in required.items():
        decl = spec["consts"].get(name)
        if decl is None:
            findings.append(("SCHEMA", f"{label}: missing {name}"))
            continue
        bad = shape_ok(decl, shape)
        if bad:
            findings.append(("SCHEMA", f"{label}: {name}: {bad}"))
        out[name] = decl["value"]
    for name in spec["consts"]:
        if name not in required:
            findings.append(("SCHEMA", f"{label}: unknown constant {name}"))
    return out


# ---------------------------------------------------------------------------
# The check.
# ---------------------------------------------------------------------------
def path_exists(inv: dict, ref: str, t27_root: pathlib.Path) -> bool:
    """`trinity:<path>` is a tracked file, or a directory some tracked file lives under; a bare
    path is a file of this repository; any other `<repo>:` prefix is external and not checked."""
    if ref.startswith("trinity:"):
        p = ref[len("trinity:"):].rstrip("/")
        files = files_of(inv)
        if p in files:
            return True
        return p in inv["tree"] or any(d.startswith(p + "/") for d in inv["tree"])
    if re.match(r"^[a-z0-9-]+:", ref):
        return True
    return (t27_root / ref).exists()


def check(inv: dict, specs_dir: pathlib.Path, t27_root: pathlib.Path) -> tuple[list, dict]:
    findings: list[tuple[str, str]] = []
    if "t27_vendored" not in inv.get("dialects", {}):
        # Written before the vendored copies were counted apart, so its canonical count may
        # include them: judging it by the current rules would compare two different populations.
        return [("UNREADABLE", "the inventory carries no dialects.t27_vendored: it was taken by a checker that counted the "
                 "vendored copies of t27 (external/t27/) as canonical; take it again with `inventory --trinity-root DIR`")], {}
    project_path = specs_dir / "project.t27"
    if not project_path.exists():
        return [("MISSING_PROJECT", f"{project_path} does not exist")], {}
    try:
        project = parse_spec(project_path)
    except ValueError as e:
        return [("UNREADABLE", str(e))], {}
    p = fields_of(project, PROJECT_REQUIRED, findings, "project.t27")
    if p.get("KIND") != "project":
        findings.append(("SCHEMA", "project.t27: KIND must be \"project\""))
    if inv.get("dirty"):
        findings.append(("DIRTY", "the inventory was taken from a tree with modified tracked files"))
    if p.get("PINNED_REVISION") != inv.get("sha"):
        findings.append(("PIN_MISMATCH", f"project.t27 pins {p.get('PINNED_REVISION')}, the inventory is of {inv.get('sha')}"))
    if p.get("CONSUMER_REPO") != inv.get("repo"):
        findings.append(("PIN_MISMATCH", f"project.t27 names {p.get('CONSUMER_REPO')}, the inventory is of {inv.get('repo')}"))
    d, b = inv["dialects"], inv["build"]
    counts = {
        "T27_CANONICAL_FILES": d["t27_canonical"], "T27_MIRROR_FILES": d["t27_mirror"], "T27_VENDORED_FILES": d["t27_vendored"],
        "TRI_FILES": d["tri"], "VIBEE_FILES": d["vibee"],
        "ZIG_FILES": d["zig"], "ZIG_UNREACHABLE_FILES": inv["zig_reachability"]["unreachable"],
        "BUILD_EXECUTABLES": len({a["key"] for a in b["executables"]}), "BUILD_LIBRARIES": len({a["key"] for a in b["libraries"]}),
        "BUILD_TESTS": len({a["key"] for a in b["tests"]}), "BUILD_STEPS": len(b["steps"]),
        "INSTALLED_BY_DEFAULT": len(b["installed_by_default"]), "INSTALLED_GUARDED": len(b["installed_guarded"]),
        "REGISTRY_COMMANDS": inv["registry"]["commands"], "CATALOG_SPECS": inv["catalog_snapshot"]["manifest_specs"] or 0,
        "CATALOG_REPOSITORIES": len(inv["catalog_snapshot"]["manifest_repos"]),
    }
    for name, expected in counts.items():
        if name in p and p[name] != expected:
            findings.append(("COUNT_MISMATCH", f"project.t27 {name} = {p[name]}, the inventory says {expected}"))
    for lst, allowed, label in ((p.get("PROFILES", []), PROFILES, "PROFILES"), (p.get("DISPOSITIONS", []), DISPOSITIONS, "DISPOSITIONS"),
                                (p.get("EVIDENCE_TAGS", []), EVIDENCE, "EVIDENCE_TAGS"), (p.get("DIALECTS", []), DIALECTS, "DIALECTS")):
        if sorted(lst) != sorted(allowed):
            findings.append(("ENUM", f"project.t27 {label} must list exactly {list(allowed)}"))
    if p.get("INITIAL_PROFILE") not in p.get("PROFILES", []):
        findings.append(("ENUM", "project.t27 INITIAL_PROFILE is not one of PROFILES"))
    dep_names = [x["name"] for x in inv["dependencies"]["dependencies"]]
    if sorted(p.get("DEPENDENCIES", [])) != sorted(dep_names):
        findings.append(("COUNT_MISMATCH", f"project.t27 DEPENDENCIES {p.get('DEPENDENCIES')} differ from build.zig.zon {dep_names}"))
    pins = {x["name"]: x["url"] for x in inv["dependencies"]["dependencies"]}
    for name, pin in zip(p.get("DEPENDENCIES", []), p.get("DEPENDENCY_PINS", [])):
        if pins.get(name) != pin:
            findings.append(("PIN_MISMATCH", f"project.t27 pins {name} at {pin}, build.zig.zon says {pins.get(name)}"))
    if sorted(p.get("SUBMODULES", [])) != sorted(s["path"] for s in inv["submodules"]):
        findings.append(("COUNT_MISMATCH", "project.t27 SUBMODULES differ from .gitmodules"))
    wps = p.get("WORK_PACKAGES", [])
    if len(wps) != len(p.get("WORK_PACKAGE_ISSUES", [])) or any(not WP_RE.match(w) for w in wps):
        findings.append(("SCHEMA", "project.t27 WORK_PACKAGES must be S01..S12 with one issue URL each"))
    # S10: the issue each package is tracked by now, by repository and number (a re-filed package names its new issue)
    current = p.get("WORK_PACKAGE_CURRENT_ISSUES", [])
    if len(current) != len(wps) or any(not ISSUE_URL_RE.match(u) for u in current):
        findings.append(("SCHEMA", "project.t27 WORK_PACKAGE_CURRENT_ISSUES must name one GitHub issue URL per work package"))

    # cards
    cards = []
    for path in sorted((specs_dir / "capabilities").glob("*.t27")):
        try:
            spec = parse_spec(path)
        except ValueError as e:
            findings.append(("UNREADABLE", str(e)))
            continue
        c = fields_of(spec, CARD_REQUIRED, findings, path.name)
        c["_file"] = path.name
        c["_module"] = spec["module"]
        c["_tests"] = spec["tests"]
        cards.append(c)
        if spec["module"] != "trinity_capability_" + path.stem.replace("-", "_").replace(".", "_"):
            findings.append(("SCHEMA", f"{path.name}: module must be trinity_capability_{path.stem.replace('-', '_').replace('.', '_')}, is {spec['module']}"))
        if spec["tests"] < 1:
            findings.append(("SCHEMA", f"{path.name}: a card carries at least one test block (L4)"))
    ids = {}
    owners_by_spec: dict[str, set] = {}
    all_targets = {a["key"] for a in b["executables"] + b["libraries"] + b["tests"]} | {s["key"] for s in b["steps"]}
    assigned: dict[str, list[str]] = {}
    default_set, guarded_set = set(b["installed_by_default"]), set(b["installed_guarded"])
    for c in cards:
        f = c["_file"]
        if c.get("KIND") != "capability":
            findings.append(("SCHEMA", f"{f}: KIND must be \"capability\""))
        cid = c.get("ID", "")
        if cid in ids:
            findings.append(("DUPLICATE_ID", f"{f}: ID {cid} is also {ids[cid]}"))
        ids[cid] = f
        if cid != "trinity/" + pathlib.Path(f).stem:
            findings.append(("SCHEMA", f"{f}: ID must be trinity/{pathlib.Path(f).stem}, is {cid}"))
        if not REPO_RE.match(c.get("OWNER_REPO", "")):
            findings.append(("SCHEMA", f"{f}: OWNER_REPO {c.get('OWNER_REPO')!r} is not owner/repo"))
        for key, allowed in (("DISPOSITION", DISPOSITIONS), ("PROFILE", PROFILES), ("EVIDENCE", EVIDENCE), ("BACKEND", BACKENDS), ("DIALECT", DIALECTS)):
            if c.get(key) not in allowed:
                findings.append(("ENUM", f"{f}: {key} {c.get(key)!r} is not one of {list(allowed)}"))
        if c.get("BACKEND", "none") != "none" and c.get("DISPOSITION") not in BACKEND_ALLOWED_FOR:
            findings.append(("UNSUPPORTED_BACKEND", f"{f}: a {c.get('DISPOSITION')} capability cannot claim backend {c.get('BACKEND')}"))
        spec_ref = c.get("CANONICAL_SPEC", "")
        if spec_ref:
            if spec_ref.startswith("trinity:" + MIRROR):
                findings.append(("MIRROR_AS_CANONICAL", f"{f}: CANONICAL_SPEC {spec_ref} is a mirrored copy, not a source"))
            if spec_ref.startswith("trinity:" + VENDORED):
                findings.append(("MIRROR_AS_CANONICAL", f"{f}: CANONICAL_SPEC {spec_ref} is the consumer's vendored copy of a t27 "
                                 "contract, not a source; name the path in this repository"))
            if not path_exists(inv, spec_ref, t27_root):
                findings.append(("ABSENT_PATH", f"{f}: CANONICAL_SPEC {spec_ref} does not exist"))
            ext_map = {".t27": "t27", ".tri": "tri", ".vibee": "vibee"}
            ext = pathlib.Path(spec_ref.split(":", 1)[-1]).suffix
            if ext in ext_map and c.get("DIALECT") != ext_map[ext]:
                findings.append(("AMBIGUOUS_DIALECT", f"{f}: CANONICAL_SPEC {spec_ref} is {ext_map[ext]}, DIALECT says {c.get('DIALECT')}"))
            if ext not in ext_map and not spec_ref.endswith("/") and c.get("DIALECT") not in ("none",) and ext:
                findings.append(("AMBIGUOUS_DIALECT", f"{f}: CANONICAL_SPEC {spec_ref} has no spec extension, DIALECT says {c.get('DIALECT')}"))
            owners_by_spec.setdefault(spec_ref, set()).add(c.get("OWNER_REPO"))
        elif c.get("DIALECT") != "none":
            findings.append(("AMBIGUOUS_DIALECT", f"{f}: no CANONICAL_SPEC but DIALECT {c.get('DIALECT')}"))
        for key in ("IMPLEMENTATION", "GENERATED"):
            for ref in c.get(key, []):
                if not path_exists(inv, ref, t27_root):
                    findings.append(("ABSENT_PATH", f"{f}: {key} {ref} does not exist in the pinned tree"))
        if c.get("EVIDENCE") == "measured" and (not c.get("ACCEPTANCE") or not c.get("EVIDENCE_SOURCE")):
            findings.append(("EVIDENCE_UNSUPPORTED", f"{f}: EVIDENCE measured needs ACCEPTANCE and EVIDENCE_SOURCE"))
        wp = c.get("WORK_PACKAGE", "")
        if wp and wp not in wps:
            findings.append(("ORPHAN_WORK_PACKAGE", f"{f}: WORK_PACKAGE {wp} is not listed in project.t27"))
        for pattern in c.get("TARGETS", []):
            matched = [t for t in all_targets if fnmatch.fnmatchcase(t, pattern)]
            if not matched:
                findings.append(("UNKNOWN_TARGET", f"{f}: TARGETS {pattern} matches nothing build.zig defines"))
            for t in matched:
                assigned.setdefault(t, []).append(f)
        for t in assigned:
            pass
        owned = [t for t, fs in assigned.items() if f in fs]
        for t in owned:
            if t in default_set and c.get("PROFILE") != "headless":
                findings.append(("PROFILE_MISMATCH", f"{f}: {t} is installed by default, the card says profile {c.get('PROFILE')}"))
            if t in guarded_set and c.get("PROFILE") == "headless":
                findings.append(("PROFILE_MISMATCH", f"{f}: {t} is guarded in build.zig, the card says profile headless"))
    for t in sorted(all_targets):
        owners = assigned.get(t, [])
        if not owners:
            findings.append(("UNASSIGNED_TARGET", f"build.zig defines {t} and no card owns it"))
        elif len(owners) > 1:
            findings.append(("DUPLICATE_TARGET", f"{t} is owned by {', '.join(sorted(set(owners)))}"))
    for spec_ref, owners in owners_by_spec.items():
        if len(owners) > 1:
            findings.append(("DUPLICATE_OWNERSHIP", f"{spec_ref} is claimed by owners {sorted(owners)}"))
    covered = {c.get("WORK_PACKAGE") for c in cards}
    for wp in wps:
        if wp not in covered:
            findings.append(("WORK_PACKAGE_UNCOVERED", f"work package {wp} has no capability card"))
    report = {
        "version": 1,
        "generated_by": "tools/trinity_manifest.py check",
        "consumer": {"repo": inv.get("repo"), "sha": inv.get("sha"), "committed_at": inv.get("committed_at")},
        "canonical_specs": {"t27_files_in_trinity_outside_the_mirror_and_the_vendored_contracts": d["t27_canonical"], "tri_files": d["tri"],
                            "vibee_files": d["vibee"],
                            "note": "files of three dialects; only .t27 is compiled by t27c, counts cannot be added into a generation claim"},
        "mirrored_files": {"t27_mirror": d["t27_mirror"], "prefix": MIRROR, "note": "vendored copies of other repositories' specs; never canonical"},
        "vendored_contracts": {"t27_vendored": d["t27_vendored"], "prefix": VENDORED,
                               "note": "byte-identical copies of this repository's contracts that the consumer locks (S12); never canonical"},
        "catalog_snapshot": inv["catalog_snapshot"],
        "build": {k: counts[k] for k in ("BUILD_EXECUTABLES", "BUILD_LIBRARIES", "BUILD_TESTS", "BUILD_STEPS", "INSTALLED_BY_DEFAULT", "INSTALLED_GUARDED")},
        "zig_unreachable": {"count": inv["zig_reachability"]["unreachable"], "by_dir": inv["zig_reachability"]["unreachable_by_dir"]},
        "capabilities": {
            "count": len(cards),
            "by_disposition": {k: sorted(c["ID"] for c in cards if c.get("DISPOSITION") == k) for k in DISPOSITIONS},
            "by_profile": {k: len([c for c in cards if c.get("PROFILE") == k]) for k in PROFILES},
            "by_evidence": {k: len([c for c in cards if c.get("EVIDENCE") == k]) for k in EVIDENCE},
            "by_work_package": {wp: sorted(c["ID"] for c in cards if c.get("WORK_PACKAGE") == wp) for wp in wps},
        },
        "findings": [{"code": code, "message": msg} for code, msg in findings],
    }
    return findings, report


# ---------------------------------------------------------------------------
# Self-check: a synthetic tree in which each defect the gate names is planted once.
# ---------------------------------------------------------------------------
GOOD_PROJECT = """module trinity_project;
pub const KIND : str = "project";
pub const ID : str = "trinity/project";
pub const NAME : str = "fixture";
pub const CONSUMER_REPO : str = "gHashTag/trinity";
pub const PINNED_REVISION : str = "{sha}";
pub const PINNED_AT : str = "2026-09-12T00:00:00Z";
pub const T27_REVISION : str = "{sha}";
pub const PROFILES : [7]str = ["headless", "web", "native", "fpga", "training", "network", "research"];
pub const INITIAL_PROFILE : str = "headless";
pub const DISPOSITIONS : [8]str = ["executable", "declared", "adapter", "external", "deprecated", "out-of-scope", "research", "catalog-only"];
pub const EVIDENCE_TAGS : [5]str = ["measured", "declared", "specified", "external", "not-claimed"];
pub const DIALECTS : [4]str = ["t27", "tri", "vibee", "none"];
pub const T27_CANONICAL_FILES : u16 = 1;
pub const T27_MIRROR_FILES : u16 = 1;
pub const T27_VENDORED_FILES : u16 = 0;
pub const TRI_FILES : u16 = 0;
pub const VIBEE_FILES : u16 = 0;
pub const ZIG_FILES : u16 = 2;
pub const ZIG_UNREACHABLE_FILES : u16 = 1;
pub const BUILD_EXECUTABLES : u8 = 1;
pub const BUILD_LIBRARIES : u8 = 0;
pub const BUILD_TESTS : u8 = 0;
pub const BUILD_STEPS : u8 = 1;
pub const INSTALLED_BY_DEFAULT : u8 = 1;
pub const INSTALLED_GUARDED : u8 = 0;
pub const DEPENDENCIES : [1]str = ["zig_hdc"];
pub const DEPENDENCY_PINS : [1]str = ["https://example.invalid/zig-hdc.tar.gz"];
pub const SUBMODULES : [0]str = [];
pub const REGISTRY_COMMANDS : u16 = 0;
pub const CATALOG_SPECS : u16 = 0;
pub const CATALOG_REPOSITORIES : u8 = 0;
pub const WORK_PACKAGES : [1]str = ["S01"];
pub const WORK_PACKAGE_ISSUES : [1]str = ["https://github.com/gHashTag/t27/issues/3563"];
pub const WORK_PACKAGE_CURRENT_ISSUES : [1]str = ["https://github.com/gHashTag/t27/issues/3563"];
pub const ENABLED : bool = true;
test pins { assert INITIAL_PROFILE == "headless"; }
"""
GOOD_CARD = """module trinity_capability_{mod};
pub const KIND : str = "capability";
pub const ID : str = "trinity/{id}";
pub const TITLE : str = "fixture";
pub const OWNER_REPO : str = "{owner}";
pub const DISPOSITION : str = "{disp}";
pub const PROFILE : str = "{profile}";
pub const CANONICAL_SPEC : str = "{spec}";
pub const DIALECT : str = "{dialect}";
pub const IMPLEMENTATION : [1]str = ["{impl}"];
pub const GENERATED : [0]str = [];
pub const BACKEND : str = "{backend}";
pub const TARGETS : [{n}]str = [{targets}];
pub const ACCEPTANCE : str = "{acceptance}";
pub const EVIDENCE : str = "{evidence}";
pub const EVIDENCE_SOURCE : str = "{source}";
pub const WORK_PACKAGE : str = "{wp}";
pub const NOTE : str = "";
pub const ENABLED : bool = true;
test owner { assert ENABLED == true; }
"""


def fixture_inventory(sha: str, dirty: bool = False, vendored: int = 0) -> dict:
    return {"version": 1, "repo": CONSUMER, "sha": sha, "dirty": dirty, "committed_at": "2026-09-12T00:00:00Z", "tracked_files": 4,
            "tree": tree_of(["build.zig", "src/main.zig", "src/lost.zig", "specs/a.t27", MIRROR + "x.t27", VENDORED + "specs/a.t27"]),
            "dialects": {"t27_canonical": 1, "t27_mirror": 1, "t27_vendored": vendored, "tri": 0, "vibee": 0, "zig": 2, "mirror_prefix": MIRROR,
                         "vendored_prefix": VENDORED, "t27_canonical_files": ["specs/a.t27"]},
            "build": {"options": [], "executables": [{"key": "exe:tri", "kind": "exe", "name": "tri", "root": "src/main.zig"}], "libraries": [], "tests": [],
                      "steps": [{"key": "step:tri", "name": "tri"}], "installs": [], "installed_by_default": ["exe:tri"], "installed_guarded": []},
            "dependencies": {"dependencies": [{"name": "zig_hdc", "url": "https://example.invalid/zig-hdc.tar.gz", "hash": "x"}]},
            "submodules": [], "zig_reachability": {"unreachable": 1, "unreachable_by_dir": {"src": 1}},
            "registry": {"commands": 0}, "catalog_snapshot": {"manifest_specs": 0, "manifest_repos": []}}


def fill(template: str, **kw) -> str:
    """Replace `{key}` tokens for the keys given; the test blocks' own braces stay as they are."""
    for k, v in kw.items():
        template = template.replace("{" + k + "}", str(v))
    return template


def card(**kw) -> str:
    base = dict(mod="cli_tri", id="cli.tri", owner=CONSUMER, disp="executable", profile="headless", spec="specs/a.t27", dialect="t27",
                impl="trinity:src/main.zig", backend="zig", targets='"exe:tri", "step:tri"', n=2, acceptance="zig build tri", evidence="measured",
                source="https://github.com/gHashTag/trinity/actions/runs/1", wp="S01")
    base.update(kw)
    return fill(GOOD_CARD, **base)


# A build.zig in which each shape the comment blanker must tell apart occurs once: a step, a
# path and an install that exist only in comments (`//`, `///`, `//!`); a `//` inside a string,
# inside a string after an escaped quote, and inside a multiline string line; a character
# literal that holds a quote, with a comment after it; and real code after all of them.
BUILD_FIXTURE = r'''const std = @import("std");
pub fn build(b: *std.Build) void {
    const ci_mode = b.option(bool, "ci", "CI mode") orelse false;
    const tri = b.addExecutable(.{ .name = "tri", .root_module = b.createModule(.{ .root_source_file = b.path("src/main.zig") }) });
    b.installArtifact(tri);
    const tri_step = b.step("tri", "Run tri; the manual is at https://example.invalid/tri");
    tri_step.dependOn(&b.addRunArtifact(tri).step);
    // const ghost_step = b.step("ghost", "a step that exists only in a comment");
    /// b.step("ghost-doc", "in a doc comment");
    //! b.step("ghost-top", "in a top-level doc comment");
    const quote = '"'; // b.step("ghost-char", "after a character literal that holds a quote");
    const said = "an escaped \" and then // which is still inside the string";
    const usage =
        \\zig build tri // a multiline string line, not a comment
    ;
    _ = .{ quote, said, usage };
    // _ = b.path("src/ghost.zig");
    if (!ci_mode) {
        const gui = b.addExecutable(.{ .name = "gui", .root_module = b.createModule(.{ .root_source_file = b.path("src/gui.zig") }) });
        // b.installArtifact(gui);
        _ = gui;
    }
}
'''
# The .zig files of that build: one real @import and one that exists only in a comment.
ZIG_FIXTURE = {
    "src/main.zig": 'const real = @import("real.zig");\n// const ghost = @import("ghost.zig");\npub fn main() void {}\n',
    "src/real.zig": "pub const x = 1;\n",
    "src/ghost.zig": "pub const y = 2;\n",
    "src/gui.zig": "pub fn main() void {}\n",
}


def parser_self_check() -> list[str]:
    """The comment blanker and parse_build_zig, on BUILD_FIXTURE: what is in a comment is gone,
    what is in a literal is kept, and every line stays where it was."""
    failures = []
    src = BUILD_FIXTURE
    blank = blank_comments(src)
    if len(blank) != len(src) or [i for i, c in enumerate(blank) if c == "\n"] != [i for i, c in enumerate(src) if c == "\n"]:
        failures.append("blanking comments must keep every offset and every line break of the source")
    kept = [ln for ln in src.split("\n") if "still inside the string" in ln or "a multiline string line" in ln]
    if len(kept) != 2:
        failures.append(f"the fixture must carry the two literal lines this control reads, found {len(kept)}")
    for ln in kept:
        if ln not in blank.split("\n"):
            failures.append(f"a `//` inside a literal is text, and this line was changed: {ln.strip()}")
    b = parse_build_zig(src)
    steps = [s["key"] for s in b["steps"]]
    if steps != ["step:tri"]:
        failures.append(f"a step in a comment (//, ///, //!, after a quote held in a character literal) is no step, got {steps}")
    tri = next((s for s in b["steps"] if s["name"] == "tri"), {})
    if tri.get("description") != "Run tri; the manual is at https://example.invalid/tri":
        failures.append(f"a `//` inside a string is not a comment: the step description reads {tri.get('description')!r}")
    if tri.get("line") != src[: src.index('b.step("tri"')].count("\n") + 1:
        failures.append(f"the step must keep the line it has in the source, got {tri.get('line')}")
    installs = [(i["key"], i["default"]) for i in b["installs"]]
    if installs != [("exe:tri", True)]:
        failures.append(f"an installArtifact in a comment installs nothing, got {installs}")
    artifacts = sorted(a["key"] for a in b["artifacts"])
    if artifacts != ["exe:gui", "exe:tri"]:
        failures.append(f"the code after the comments must still be read, got artifacts {artifacts}")
    if b["zig_paths"] != ["src/gui.zig", "src/main.zig"]:
        failures.append(f"a b.path in a comment names no file, got {b['zig_paths']}")
    return failures


def inventory_self_check(tmp: pathlib.Path) -> list[str]:
    """inventory() end to end over a planted consumer repository, so the wiring is held and not
    only the functions it calls: the comments of build.zig and of the sources are not read,
    and a .t27 file under the mirror or under the vendored copies is not canonical."""
    failures = []
    repo = tmp / "consumer"
    tree = dict(ZIG_FIXTURE)
    tree.update({
        "build.zig": BUILD_FIXTURE,
        "build.zig.zon": '.{ .name = .fixture, .version = "0.0.0", .dependencies = .{ .zig_hdc = .{ .url = "https://example.invalid/zig-hdc.tar.gz", .hash = "x" } } }\n',
        "specs/a.t27": "module a;\n", MIRROR + "x.t27": "module x;\n", VENDORED + "specs/trinity/project.t27": "module trinity_project;\n",
    })
    g = ["git", "-C", str(repo), "-c", "user.name=t27", "-c", "user.email=t27@example.invalid", "-c", "commit.gpgsign=false"]
    try:
        subprocess.run(["git", "init", "-q", str(repo)], check=True, capture_output=True)
        for path, text in tree.items():
            (repo / path).parent.mkdir(parents=True, exist_ok=True)
            (repo / path).write_text(text)
        subprocess.run(g + ["add", "-A"], check=True, capture_output=True)
        subprocess.run(g + ["commit", "-q", "-m", "fixture"], check=True, capture_output=True)
    except (OSError, subprocess.CalledProcessError) as e:
        return [f"the planted consumer repository could not be built ({e}); nothing about inventory() was checked"]
    inv = inventory(repo)
    b, r, d = inv["build"], inv["zig_reachability"], inv["dialects"]
    if [s["key"] for s in b["steps"]] != ["step:tri"] or b["installed_by_default"] != ["exe:tri"] or b["installed_guarded"]:
        failures.append(f"inventory() read build.zig's comments: steps {[s['key'] for s in b['steps']]}, "
                        f"installed {b['installed_by_default']}, guarded {b['installed_guarded']}")
    # build.zig is not a file build.zig names, so it is unreachable by this definition -- as it
    # is in the real inventory.
    if r["roots_named_by_build_zig"] != 2 or r["unreachable_files"] != ["build.zig", "src/ghost.zig"]:
        failures.append(f"inventory() followed a path or an @import that exists only in a comment: "
                        f"{r['roots_named_by_build_zig']} roots, unreachable {r['unreachable_files']}")
    if (d["t27_canonical"], d["t27_mirror"], d["t27_vendored"]) != (1, 1, 1):
        failures.append(f"inventory() must count the mirror and the vendored copies apart from the canonical .t27: {d}")
    return failures


def self_check() -> int:
    sha = "a" * 40
    failures = parser_self_check()
    d = dialects_of(["specs/a.t27", MIRROR + "x.t27", VENDORED + "specs/trinity/project.t27", "src/main.zig"])
    if (d["t27_canonical"], d["t27_mirror"], d["t27_vendored"], d["t27_canonical_files"]) != (1, 1, 1, ["specs/a.t27"]):
        failures.append(f"a mirrored or a vendored .t27 is never canonical, got {d}")
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        for path, text in ZIG_FIXTURE.items():
            (root / path).parent.mkdir(parents=True, exist_ok=True)
            (root / path).write_text(text)
        reach = zig_reachability(root, sorted(ZIG_FIXTURE), ["src/main.zig"])
        if reach["unreachable_files"] != ["src/ghost.zig", "src/gui.zig"]:
            failures.append(f"an @import in a comment imports nothing, got unreachable {reach['unreachable_files']}")
        # The planted repository is read by `git`; a GIT_DIR or GIT_INDEX_FILE inherited from a
        # hook would point every one of those commands at another repository.
        saved = {k: os.environ.pop(k) for k in [k for k in os.environ if k.startswith("GIT_")]}
        try:
            failures += inventory_self_check(root)
        finally:
            os.environ.update(saved)
        (root / "specs/a.t27").parent.mkdir(parents=True, exist_ok=True)
        (root / "specs/a.t27").write_text("module a;\n")

        def run(project_text: str, cards: dict[str, str], inv: dict) -> list[str]:
            specs = root / "specs/trinity"
            if specs.exists():
                for f in specs.rglob("*"):
                    if f.is_file():
                        f.unlink()
            (specs / "capabilities").mkdir(parents=True, exist_ok=True)
            (specs / "project.t27").write_text(project_text)
            for name, text in cards.items():
                (specs / "capabilities" / name).write_text(text)
            try:
                findings, _ = check(inv, specs, root)
            except Exception as e:  # a crash is not a verdict: name it, so the case says why it failed
                return [f"CRASH {type(e).__name__}: {e}"]
            return [code for code, _ in findings]

        good = run(fill(GOOD_PROJECT, sha=sha), {"cli.tri.t27": card()}, fixture_inventory(sha))
        if good:
            failures.append(f"the clean fixture must pass, got {good}")
        stale = fixture_inventory(sha)
        del stale["dialects"]["t27_vendored"]
        project = fill(GOOD_PROJECT, sha=sha)
        # (what is planted, the code that must report it, cards, inventory, project)
        cases = [
            ("two owners of one spec", "DUPLICATE_OWNERSHIP", {"cli.tri.t27": card(targets='"exe:tri"', n=1), "cli.other.t27": card(mod="cli_other", id="cli.other", owner="gHashTag/other", targets='"step:tri"', n=1)}, fixture_inventory(sha), project),
            ("an untracked path", "ABSENT_PATH", {"cli.tri.t27": card(impl="trinity:src/gone.zig")}, fixture_inventory(sha), project),
            ("a dialect the spec is not", "AMBIGUOUS_DIALECT", {"cli.tri.t27": card(dialect="tri")}, fixture_inventory(sha), project),
            ("a dirty inventory", "DIRTY", {"cli.tri.t27": card()}, fixture_inventory(sha, dirty=True), project),
            ("a backend on an external card", "UNSUPPORTED_BACKEND", {"cli.tri.t27": card(disp="external", backend="verilog")}, fixture_inventory(sha), project),
            ("a target nobody owns", "UNASSIGNED_TARGET", {"cli.tri.t27": card(targets='"exe:tri"', n=1)}, fixture_inventory(sha), project),
            ("another revision", "PIN_MISMATCH", {"cli.tri.t27": card()}, fixture_inventory("b" * 40), project),
            ("measured without a source", "EVIDENCE_UNSUPPORTED", {"cli.tri.t27": card(source="")}, fixture_inventory(sha), project),
            ("the website mirror as canonical", "MIRROR_AS_CANONICAL", {"cli.tri.t27": card(spec="trinity:" + MIRROR + "x.t27")}, fixture_inventory(sha), project),
            ("a vendored copy of a t27 contract as canonical", "MIRROR_AS_CANONICAL", {"cli.tri.t27": card(spec="trinity:" + VENDORED + "specs/a.t27")}, fixture_inventory(sha), project),
            ("a default install on a web card", "PROFILE_MISMATCH", {"cli.tri.t27": card(profile="web")}, fixture_inventory(sha), project),
            ("a package without a card", "WORK_PACKAGE_UNCOVERED", {"cli.tri.t27": card()}, fixture_inventory(sha), project.replace('WORK_PACKAGES : [1]str = ["S01"]', 'WORK_PACKAGES : [2]str = ["S01", "S02"]').replace('WORK_PACKAGE_ISSUES : [1]str = ["https://github.com/gHashTag/t27/issues/3563"]', 'WORK_PACKAGE_ISSUES : [2]str = ["https://github.com/gHashTag/t27/issues/3563", "https://github.com/gHashTag/t27/issues/3564"]')),
            ("a dialect count that differs", "COUNT_MISMATCH", {"cli.tri.t27": card()}, fixture_inventory(sha), project.replace("TRI_FILES : u16 = 0", "TRI_FILES : u16 = 7")),
            ("vendored copies the project does not state", "COUNT_MISMATCH", {"cli.tri.t27": card()}, fixture_inventory(sha, vendored=3), project),
            ("a target build.zig does not define", "UNKNOWN_TARGET", {"cli.tri.t27": card(targets='"exe:tri", "step:tri", "exe:ghost"', n=3)}, fixture_inventory(sha), project),
            ("an inventory without the vendored count", "UNREADABLE", {"cli.tri.t27": card()}, stale, project),
        ]
        for planted, code, cards, inv, project_text in cases:
            got = run(project_text, cards, inv)
            if code not in got:
                failures.append(f"planted {planted}: {code} expected, the gate reported {got}")
    if failures:
        print("trinity_manifest --self-check: FAIL")
        for f in failures:
            print("  " + f)
        return 1
    print(f"trinity_manifest --self-check: PASS (clean fixture passes; {len(cases)} planted defects each reported under their own code; "
          "a step, an install, a path and an @import that exist only in comments are not read, a `//` inside a literal is; "
          "the mirror and the vendored copies are counted apart, end to end through inventory())")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("command", nargs="?", choices=["inventory", "check"])
    ap.add_argument("--trinity-root")
    ap.add_argument("--out", default=INVENTORY)
    ap.add_argument("--inventory", default=INVENTORY)
    ap.add_argument("--specs", default=SPECS)
    ap.add_argument("--report", default=REPORT)
    ap.add_argument("--self-check", action="store_true")
    args = ap.parse_args()
    if args.self_check:
        return self_check()
    if args.command == "inventory":
        if not args.trinity_root:
            print("trinity_manifest: --trinity-root DIR is required", file=sys.stderr)
            return 2
        inv = inventory(pathlib.Path(args.trinity_root).resolve())
        out = ROOT / args.out
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(inv, indent=1, sort_keys=False) + "\n")
        b = inv["build"]
        print(f"trinity_manifest: {inv['repo']}@{inv['sha'][:9]} -> {args.out}: {len(b['executables'])} executables, {len(b['libraries'])} libraries, "
              f"{len(b['tests'])} tests, {len(b['steps'])} steps, {len(b['installed_by_default'])} installed by default, "
              f"{inv['dialects']['t27_canonical']} canonical .t27 / {inv['dialects']['t27_mirror']} mirrored / "
              f"{inv['dialects']['t27_vendored']} vendored from t27, {inv['dialects']['tri']} .tri, "
              f"{inv['dialects']['vibee']} .vibee, zig unreachable {inv['zig_reachability']['unreachable']}/{inv['zig_reachability']['zig_files']}")
        return 0
    if args.command == "check":
        inv_path = ROOT / args.inventory
        if not inv_path.exists():
            print(f"trinity_manifest: no inventory at {args.inventory}; run `inventory --trinity-root DIR` first", file=sys.stderr)
            return 2
        inv = json.loads(inv_path.read_text())
        findings, report = check(inv, ROOT / args.specs, ROOT)
        if report:
            out = ROOT / args.report
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(json.dumps(report, indent=1) + "\n")
        for code, msg in findings:
            print(f"  {code}: {msg}")
        if findings:
            print(f"trinity_manifest: {len(findings)} finding(s)")
            return 1 if all(code not in ("MISSING_PROJECT", "UNREADABLE") for code, _ in findings) else 2
        caps = report["capabilities"]
        print(f"trinity_manifest: OK -- {caps['count']} capabilities over {inv['repo']}@{inv['sha'][:9]}, "
              f"{report['build']['BUILD_EXECUTABLES']} executables / {report['build']['BUILD_LIBRARIES']} libraries / "
              f"{report['build']['BUILD_TESTS']} tests / {report['build']['BUILD_STEPS']} steps all owned; report -> {args.report}")
        return 0
    ap.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
