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

# Zig has no block comments, so a line comment runs from // to end of line --
# except inside a string, where // is just two characters. Stripping naively
# would break `@import("https://…")`; not stripping at all counts imports that
# somebody has commented out, which is how this checker reported eight blocking
# files in a repository whose CI is green. A false positive is the fastest way
# to turn a gate into furniture, so comments come out, carefully.
def strip_comments(text: str) -> str:
    out = []
    for line in text.splitlines():
        in_str = False
        esc = False
        cut = len(line)
        i = 0
        while i < len(line) - 1:
            c = line[i]
            if esc:
                esc = False
            elif c == "\\" and in_str:
                esc = True
            elif c == '"':
                in_str = not in_str
            elif c == "/" and line[i + 1] == "/" and not in_str:
                cut = i
                break
            i += 1
        out.append(line[:cut])
    return "\n".join(out)


# Which trees to check imports in. Scanning everything found 242 unresolvable
# imports, nearly all of them in archive/ and in vendored deploy/ copies that no
# build target roots -- code nobody is going to repair, in a gate that would
# therefore be red forever. A gate red for reasons nobody will act on stops being
# read, which is the failure this whole file exists to prevent, so the scope is
# the tree the build actually roots its modules in. Widen it deliberately, never
# by accident.
DEFAULT_IMPORT_ROOTS = ["src"]


# `const name = @import("x.zig")` in its several spellings. The name is what
# decides whether the import is a fault: Zig analyses top-level declarations
# lazily, so an import bound to a name nothing uses is never loaded.
BINDING = re.compile(
    r'^\s*(pub\s+)?(?:const|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*@import\(\s*"([^"]*\.zig)"\s*\)',
    re.M)


def classify(root: str, importer: str, target_rel: str) -> str:
    """CONFIRMED, EXPORTED or LATENT for one missing import.

    The three are genuinely different and collapsing them is what made the
    earlier figure an upper bound:

      LIKELY     the name appears elsewhere in the same file, so the compiler
                 would load the missing file and fail. "Appears" is the honest
                 word: matching is textual, and it cannot tell an import alias
                 from an enum field of the same name. Measured in zig-hdc, where
                 `arm64` is both -- four occurrences that are field declarations,
                 not uses of the import.
      EXPORTED   `pub`, and unused locally. Whether it is loaded depends on
                 whoever imports this module, which is outside this file.
      LATENT     private and unused. Never loaded, never an error, and still
                 worth knowing about because the next reference makes it one.
    """
    path = os.path.join(root, importer)
    try:
        text = strip_comments(open(path, encoding="utf-8", errors="replace").read())
    except OSError:
        return "LIKELY"  # cannot read it: assume the worse of the two
    want = os.path.normpath(target_rel)
    for is_pub, name, target in BINDING.findall(text):
        if os.path.normpath(os.path.join(os.path.dirname(importer), target)) != want:
            continue
        # Uses of the name that are not its own declaration.
        uses = [m for m in re.finditer(r'\b' + re.escape(name) + r'\b', text)]
        decls = len(re.findall(r'(?:const|var)\s+' + re.escape(name) + r'\s*=\s*@import', text))
        if len(uses) - decls > 0:
            return "LIKELY"
        return "EXPORTED" if is_pub else "LATENT"
    return "LATENT"


def build_roots(root: str) -> list[str]:
    """Every file build.zig roots a module or target at, that exists."""
    text = open(os.path.join(root, "build.zig"), encoding="utf-8", errors="replace").read()
    return sorted({r for r in re.findall(r'root_source_file = b\.path\("([^"]+)"\)', text)
                   if os.path.isfile(os.path.join(root, r))})


def live_imports(root: str, f: str) -> list[str]:
    """The imports of `f` the compiler will actually follow, as paths.

    Zig analyses a top-level declaration only when something references it, and
    that is transitive: a file reached through a binding nobody uses is not
    analysed, and neither is anything it imports. Treating every import as
    followed is what made an earlier figure read worse than the build was --
    two "faults" in a repository whose CI is green, both of them bound to names
    nothing mentions.

    An import that is not bound to a name at all -- @import("x.zig").Foo used
    inline -- is always followed, so it counts.
    """
    path = os.path.join(root, f)
    try:
        text = strip_comments(open(path, encoding="utf-8", errors="replace").read())
    except OSError:
        return []
    out: list[str] = []
    bound: set[str] = set()
    for is_pub, name, target in BINDING.findall(text):
        bound.add(target)
        uses = len(re.findall(r'\b' + re.escape(name) + r'\b', text))
        decls = len(re.findall(r'(?:const|var)\s+' + re.escape(name) + r'\s*=\s*@import', text))
        if uses - decls > 0 or is_pub:
            # `pub` counts: it is part of this module's surface, and whether a
            # consumer touches it is not decidable from here. Erring towards
            # following it keeps a real fault from being filed as harmless.
            out.append(os.path.join(os.path.dirname(f), target))
    for target in ZIMPORT.findall(text):
        if target not in bound:
            out.append(os.path.join(os.path.dirname(f), target))
    return out


def reaches(root: str, start: str, wanted: set[str], live_only: bool = False) -> set[str]:
    """Which of `wanted` is reachable from `start` by following relative imports.

    The subtle part, and it cost a wrong conclusion once: a node must be RECORDED
    before it is tested for readability. An earlier version skipped unreadable
    files first, so a missing file could never enter the visited set -- and a
    walker looking for missing files reported none, every time. The instrument
    and the assumption agreed with each other, which is T9 wearing a different
    hat.
    """
    seen: set[str] = set()
    hits: set[str] = set()
    stack = [start]
    while stack:
        f = os.path.normpath(stack.pop())
        if f in seen:
            continue
        seen.add(f)
        if f in wanted:
            hits.add(f)
        abs_f = os.path.join(root, f)
        if not os.path.isfile(abs_f):
            continue  # reached and counted; simply cannot be read further
        try:
            text = open(abs_f, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        if live_only:
            stack.extend(live_imports(root, f))
        else:
            for target in ZIMPORT.findall(strip_comments(text)):
                stack.append(os.path.join(os.path.dirname(f), target))
    return hits


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
            for target in sorted(set(ZIMPORT.findall(strip_comments(text)))):
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

    # Which missing files actually block a build, and which are only referenced
    # by code no target roots. Both are worth fixing; only the first stops the
    # build, and telling them apart is the difference between an afternoon and a
    # fortnight. Computed by walking imports from every build root.
    missing_names = {os.path.normpath(rel) for rel, _ in dangling}
    for imp, tgt, res in []:
        pass
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

    # Everything the compiler would actually try to load: the missing files
    # build.zig names, plus every missing file reachable from a build root.
    blockers: dict[str, list[str]] = {}
    all_missing = set(missing_names) | {os.path.normpath(r) for _, _, r in missing}
    for br in build_roots(root):
        for hit in reaches(root, br, all_missing, live_only=True):
            blockers.setdefault(hit, []).append(br)
    # Who imports each missing file, so the binding can be classified.
    importers: dict[str, list[str]] = {}
    for imp, tgt, res in missing:
        importers.setdefault(os.path.normpath(res), []).append(imp)

    if blockers:
        verdicts: dict[str, str] = {}
        for f in blockers:
            vs = {classify(root, i, f) for i in importers.get(f, [])}
            verdicts[f] = ("LIKELY" if "LIKELY" in vs
                           else "EXPORTED" if "EXPORTED" in vs
                           else "LATENT")
        confirmed = sorted(f for f, v in verdicts.items() if v == "LIKELY")
        exported = sorted(f for f, v in verdicts.items() if v == "EXPORTED")
        latent = sorted(f for f, v in verdicts.items() if v == "LATENT")

        print()
        print(f"  {len(blockers)} missing file(s) reachable from a build root:")
        for label, group, note in (
            ("LIKELY   ", confirmed, "the name appears to be used, so the compiler would load the file"),
            ("EXPORTED ", exported, "pub and unused here; depends on whoever imports this module"),
            ("LATENT   ", latent, "private and unused, so never loaded -- until the next reference"),
        ):
            if not group:
                continue
            print(f"    {label} ({len(group)}) — {note}")
            for f in group:
                rs = blockers[f]
                print(f"      {f}  — reached from {len(rs)} root(s): "
                      f"{', '.join(sorted(rs)[:3])}{' …' if len(rs) > 3 else ''}")
        unreached = sorted(all_missing - set(blockers))
        if unreached:
            print(f"  {len(unreached)} more are referenced only by code no build root reaches, "
                  f"so the compiler never visits them.")
        print()
        print("  Only LIKELY can be a fault today. Zig analyses top-level declarations")
        print("  lazily, so an import bound to a name nothing uses is never loaded --")
        print("  which is why a plain count of reachable missing files reads as worse")
        print("  than the build is. That count was two for a repository whose CI is")
        print("  green, and both were unused. LIKELY narrows that and does not close it:")
        print("  the match is on a name, and a name can belong to something else. Both")
        print("  remaining entries in that green repository are enum fields that happen")
        print("  to share a spelling with an import. Refining a textual analysis moves")
        print("  the boundary; it never removes it.")

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
