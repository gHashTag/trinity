#!/usr/bin/env python3
"""Every path the build names, checked without a compiler.

This repository's build was broken for four months by a refactor that moved
sources out from under build.zig without moving the references. The failure
needed no cleverness to detect — the files simply were not there — and it went
unnoticed anyway, because the only instrument that reported it was a build whose
red had stopped carrying information (T12).

So the check is separated from the toolchain on purpose. It is text: a path in
build.zig either exists or does not, and an @import of a relative .zig file
either resolves or does not. No zig required, which matters here because the
version this project targets cannot even link its own build runner on the
machine this was written on — and a check you cannot run is a check you do not
have.

Two failure classes, both real, both taken from the actual outage:

  * b.path("src/vsa.zig") for a file that was migrated to another repository.
  * @import("bigint.zig") from a file whose directory no longer holds it.

Two design choices that matter more than the parsing:

  * It GATES on build.zig paths only, and merely SURVEYS relative imports. The
    survey finds 99 unresolvable targets under src/ where the compiler reports
    7, because the compiler only ever visits files some target actually roots.
    Gating on 99 findings nobody is going to repair would produce a check that
    is red forever, and a check that is red forever is furniture (T12) — the
    exact condition this file was written to prevent.

  * It is a RATCHET. Five build paths are dangling today and repairing them
    needs decisions about a deployment that are not mine to make. Failing on
    those five every run would be the same furniture. So the known set lives in
    a baseline and only paths OUTSIDE it fail — new breakage is caught the day
    it lands, which is the whole point, and the baseline can only shrink.

T13 supplies the floor. A scanner that silently walked zero files would report
zero problems and look identical to a clean tree, so the number of files
examined is asserted and printed.

Usage:  python3 tools/check_build_paths.py [--root .] [--min-files 200]
"""

from __future__ import annotations

import argparse
import os
import re
import sys

BPATH = re.compile(r'b\.path\(\s*"([^"]+)"\s*\)')
# Only relative-file imports resolve against the filesystem. Module imports --
# @import("std"), @import("raylib") and anything else without a .zig suffix --
# are resolved by the build graph and are none of this checker's business.
ZIMPORT = re.compile(r'@import\(\s*"([^"]*\.zig)"\s*\)')

SKIP_DIRS = {".git", ".zig-cache", "zig-out", "node_modules", "zig-pkg", "dist", ".venv"}

# Which trees to check imports in. Scanning everything found 242 unresolvable
# imports, nearly all of them in archive/ and in vendored deploy/ copies that no
# build target roots -- code nobody is going to repair, in a gate that would
# therefore be red forever. A gate red for reasons nobody will act on stops being
# read, which is the failure this whole file exists to prevent, so the scope is
# the tree the build actually roots its modules in. Widen it deliberately, never
# by accident.
DEFAULT_IMPORT_ROOTS = ["src"]


def scan_build_zig(root: str) -> list[tuple[str, str]]:
    """(path, why) for every b.path() reference that does not exist."""
    bad = []
    bz = os.path.join(root, "build.zig")
    if not os.path.isfile(bz):
        raise SystemExit("no build.zig at the root given")
    text = open(bz, encoding="utf-8", errors="replace").read()
    for rel in sorted(set(BPATH.findall(text))):
        if not rel.endswith(".zig"):
            continue
        if not os.path.isfile(os.path.join(root, rel)):
            bad.append((rel, "named by build.zig, not present"))
    return bad


def scan_imports(root: str, subdirs: list[str]) -> tuple[list[tuple[str, str, str]], int]:
    """(importer, target, resolved) for every relative import that misses, and
    the number of .zig files examined."""
    bad = []
    seen = 0
    walk_roots = [os.path.join(root, d) for d in subdirs] or [root]
    for base in walk_roots:
      for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if not fn.endswith(".zig"):
                continue
            seen += 1
            src = os.path.join(dirpath, fn)
            try:
                text = open(src, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            for target in sorted(set(ZIMPORT.findall(text))):
                resolved = os.path.normpath(os.path.join(dirpath, target))
                if not os.path.isfile(resolved):
                    bad.append((os.path.relpath(src, root), target,
                                os.path.relpath(resolved, root)))
    return bad, seen


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--import-roots", default=",".join(DEFAULT_IMPORT_ROOTS),
                    help="comma-separated subtrees to check imports in")
    ap.add_argument("--baseline", default="tools/build_paths_baseline.txt",
                    help="known-dangling paths, one per line. Only paths outside it fail, "
                         "and a path that has been repaired must leave the file.")
    ap.add_argument("--min-files", type=int, default=200,
                    help="floor on how many .zig files were examined (T13): a scanner "
                         "that walked nothing would report nothing and look clean")
    args = ap.parse_args()
    root = os.path.abspath(args.root)

    dangling = scan_build_zig(root)
    roots = [d for d in args.import_roots.split(",") if d]
    missing, seen = scan_imports(root, roots)

    print(f"  examined {seen} .zig files under {', '.join(roots)}/")

    if seen < args.min_files:
        print(f"  FAIL only {seen} files examined, floor is {args.min_files}. "
              f"The scan did not happen; this is not a clean tree.", file=sys.stderr)
        return 1

    if dangling:
        print()
        print(f"  {len(dangling)} path(s) named by build.zig that do not exist:")
        for rel, why in dangling:
            print(f"    {rel}")
    if missing:
        print()
        print(f"  {len(missing)} relative import(s) that do not resolve:")
        # Grouped by target: one moved file usually breaks many importers, and a
        # list of importers reads as many problems when it is one.
        by_target: dict[str, list[str]] = {}
        for importer, target, resolved in missing:
            by_target.setdefault(resolved, []).append(importer)
        for resolved, importers in sorted(by_target.items()):
            print(f"    {resolved}  — wanted by {len(importers)} file(s): "
                  f"{', '.join(sorted(importers)[:3])}"
                  f"{' …' if len(importers) > 3 else ''}")

    baseline: set[str] = set()
    if os.path.isfile(args.baseline):
        baseline = {ln.strip() for ln in open(args.baseline, encoding="utf-8")
                    if ln.strip() and not ln.startswith("#")}

    found = {rel for rel, _ in dangling}
    new = sorted(found - baseline)
    fixed = sorted(baseline - found)

    print()
    if fixed:
        # The ratchet only turns one way. A repaired path must leave the
        # baseline, or the file slowly becomes a list of things that used to be
        # wrong and stops meaning anything.
        print(f"  FAIL {len(fixed)} path(s) in the baseline now exist and must be removed from it:")
        for f in fixed:
            print(f"    {f}")
        return 1
    if new:
        print(f"  FAIL {len(new)} build path(s) that are new since the baseline:")
        for f in new:
            print(f"    {f}")
        print(f"  These were not broken before. Repair them, or if the breakage is")
        print(f"  deliberate, add them to {args.baseline} with a reason.")
        return 1

    print(f"  PASS no new dangling build paths ({len(found)} known, all in the baseline)")
    if missing:
        print(f"  NOTE {len(set(r for _, _, r in missing))} unresolvable import target(s) under "
              f"{', '.join(roots)}/ — surveyed, not gated: most are in subtrees no build")
        print(f"       target roots, so the compiler never visits them.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
