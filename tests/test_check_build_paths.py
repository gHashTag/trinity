#!/usr/bin/env python3
"""Assert the reachability walk on trees whose answers are known.

The first version of this walk answered "no build root reaches src/vsa.zig" and
was wrong: it skipped unreadable files BEFORE recording them, so a missing file
could never enter the visited set and a walker looking for missing files found
none. The conclusion drawn from it — that eleven consumers were dead code and
the repair was two lines — survived until CI disagreed.

So the case that broke it is the first fixture here, and it asserts the count
rather than the verdict: a walker returning the empty set for everything passes
any test that only asks "did it run".

Run: python3 tests/test_check_build_paths.py
"""
import os
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from check_build_paths import reaches  # noqa: E402


def tree(files: dict[str, str]) -> str:
    d = tempfile.mkdtemp()
    for rel, body in files.items():
        p = os.path.join(d, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as f:
            f.write(body)
    return d


CASES = []

# 1. The regression. root -> mid -> missing.zig, where missing.zig is absent.
#    The whole point: a file that cannot be opened is still REACHED.
CASES.append((
    "missing file is reached through a present one",
    {"src/root.zig": 'const m = @import("mid.zig");\n',
     "src/mid.zig": 'const g = @import("gone.zig");\n'},
    "src/root.zig", {"src/gone.zig"}, {"src/gone.zig"},
))

# 2. Directly imported and missing.
CASES.append((
    "missing file imported straight from the root",
    {"src/root.zig": 'const g = @import("gone.zig");\n'},
    "src/root.zig", {"src/gone.zig"}, {"src/gone.zig"},
))

# 3. Present everywhere: nothing to report.
CASES.append((
    "nothing missing",
    {"src/root.zig": 'const m = @import("mid.zig");\n', "src/mid.zig": "// end\n"},
    "src/root.zig", {"src/gone.zig"}, set(),
))

# 4. Missing, but only from a file the root never imports.
CASES.append((
    "missing file behind an unreferenced sibling",
    {"src/root.zig": "// imports nothing\n",
     "src/orphan.zig": 'const g = @import("gone.zig");\n'},
    "src/root.zig", {"src/gone.zig"}, set(),
))

# 5. Relative traversal out of a subdirectory, and a cycle to prove termination.
CASES.append((
    "resolves ../ and survives an import cycle",
    {"src/a/one.zig": 'const b = @import("../b/two.zig");\n',
     "src/b/two.zig": 'const a = @import("../a/one.zig");\nconst g = @import("../gone.zig");\n'},
    "src/a/one.zig", {"src/gone.zig"}, {"src/gone.zig"},
))

bad = 0
for name, files, start, wanted, expected in CASES:
    root = tree(files)
    got = reaches(root, start, wanted)
    ok = got == expected
    print(f"  {'PASS' if ok else 'FAIL'} {name}")
    if not ok:
        print(f"       expected {sorted(expected)}, got {sorted(got)}")
        bad += 1

print()
print(f"  {len(CASES) - bad}/{len(CASES)} trees match their known answers")
raise SystemExit(1 if bad else 0)
