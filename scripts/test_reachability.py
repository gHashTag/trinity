"""How many declared Zig tests can `zig build test` actually reach?

A test declaration that no build target can reach is a green status produced by
absence of checking.  This walks the @import graph from every root_source_file
mentioned in build.zig and counts reachable test declarations.

Import edges counted: @import("relative/path.zig") only -- module imports by
name (@import("golden_float")) are resolved through build.zig dependencies and
are followed only when the name matches a path in the repo.
"""
import os
import re
import sys

REPO = '/home/user/workspace/corpus/trinity'


def test_count(path):
    try:
        t = open(path, errors='ignore').read()
    except OSError:
        return 0, ''
    return len(re.findall(r'(?m)^\s*test\s+"', t)), t


MODULES = {}


def imports(path, text):
    out = []
    for m in re.findall(r'@import\("([^"]+)"\)', text):
        if m.endswith('.zig'):
            p = os.path.normpath(os.path.join(os.path.dirname(path), m))
        elif m in MODULES:
            p = MODULES[m]
        else:
            continue
        if os.path.isfile(p):
            out.append(p)
    return out


build = open(os.path.join(REPO, 'build.zig'), errors='ignore').read()

# module names declared in build.zig, so that @import("name") is followed too.
# Two steps, because modules are created into variables and then wired by name:
#   const trinity_mod = b.createModule(.{ .root_source_file = b.path("X") ...
#   .imports = &.{ .{ .name = "trinity", .module = trinity_mod } }
VARS = {}
for var_name, rel in re.findall(
        r'const\s+([A-Za-z0-9_]+)\s*=\s*b\.(?:createModule|addModule)\('
        r'[^;]*?root_source_file\s*=\s*b\.path\("([^"]+)"\)', build, re.S):
    p = os.path.normpath(os.path.join(REPO, rel))
    if os.path.isfile(p):
        VARS[var_name] = p
for name, var_name in re.findall(
        r'\.name\s*=\s*"([A-Za-z0-9_\-]+)"\s*,\s*\.module\s*=\s*([A-Za-z0-9_]+)', build):
    if var_name in VARS:
        MODULES.setdefault(name, VARS[var_name])
for name, var_name in re.findall(
        r'addImport\(\s*"([A-Za-z0-9_\-]+)"\s*,\s*([A-Za-z0-9_]+)\s*\)', build):
    if var_name in VARS:
        MODULES.setdefault(name, VARS[var_name])
print('modules resolved from build.zig: %d %s' % (len(MODULES), sorted(MODULES)[:12]))

roots = set()
for m in re.findall(r'root_source_file\s*=\s*b\.path\("([^"]+)"\)', build):
    p = os.path.join(REPO, m)
    if os.path.isfile(p):
        roots.add(os.path.normpath(p))

seen = set()
stack = list(roots)
while stack:
    p = stack.pop()
    if p in seen:
        continue
    seen.add(p)
    _, t = test_count(p)
    for q in imports(p, t):
        if q not in seen:
            stack.append(q)

all_files = []
for root, d, fs in os.walk(REPO):
    if any(x in root for x in ['.git', 'zig-out', '.zig-cache']):
        continue
    for f in fs:
        if f.endswith('.zig'):
            all_files.append(os.path.normpath(os.path.join(root, f)))

reach_tests = sum(test_count(p)[0] for p in seen)
all_tests = sum(test_count(p)[0] for p in all_files)
orphan = [(test_count(p)[0], p) for p in all_files if p not in seen and test_count(p)[0] > 0]
orphan.sort(reverse=True)

print('roots in build.zig:        %d' % len(roots))
print('files reachable:           %d of %d' % (len(seen), len(all_files)))
print('test decls reachable:      %d of %d  (%.1f%%)'
      % (reach_tests, all_tests, 100.0 * reach_tests / all_tests))
print('files with unreachable tests: %d' % len(orphan))
print('\ntop unreachable-by-import files:')
for n, p in orphan[:20]:
    print('  %6d  %s' % (n, os.path.relpath(p, REPO)))

# self-test: a root file's own tests must be counted as reachable
probe = os.path.normpath(os.path.join(REPO, 'src/sacred/zeta_spacing.zig'))
if probe in seen:
    print('\nself-test: ok   an edited root-reachable file is counted reachable')
else:
    print('\nself-test: FAIL zeta_spacing.zig not reachable -- graph walk is broken')
    sys.exit(1)
