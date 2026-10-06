#!/usr/bin/env python3
"""Write specs/queen/memory_issue_proof.t27 from a checkout of dmitrii-f-t27/trinity-memory.

Usage: python3 scripts/memory-proof-pins.py <trinity-memory checkout> > specs/queen/memory_issue_proof.t27

The policy pins, by sha256, every file the Memory proof reads at the repository head:
the shared files (Makefile, workflow, gate script, compiler pin), and for each group
its spec, seal, vectors and the files that bind its evidence. A group is one sealed
spec; the table at the end says which closed issue needs which groups. Re-run this
after any change to a pinned file, then regenerate the TypeScript with
`node scripts/issue-proof-from-spec.mjs`.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

REPO = 'dmitrii-f-t27/trinity-memory'

# Closed issues delivered by a sealed spec whose header names them (trinity-memory#125).
SEALED = [
    ('types', 'specs/memory/types.t27', [3, 4]),
    ('bridge', 'specs/memory/bridge.t27', [3, 5]),
    ('tensorpack', 'specs/memory/tensorpack.t27', [3, 6]),
    ('stream_compute', 'specs/memory/stream_compute.t27', [3, 7, 15]),
    ('conformance', 'specs/memory/conformance.t27', [3, 8]),
    ('edge_demo', 'specs/memory/edge_demo.t27', [3, 9]),
    ('formats_bitnet_cpp', 'specs/formats/bitnet_cpp.t27', [29, 30, 34]),
    ('formats_hf_bitnet', 'specs/formats/hf_bitnet.t27', [29, 30, 34]),
    ('formats_llama_cpp', 'specs/formats/llama_cpp.t27', [29, 30, 34]),
    ('formats_mlx', 'specs/formats/mlx.t27', [29, 30, 34]),
    ('formats_onnx', 'specs/formats/onnx.t27', [29, 30, 34]),
    ('formats_prismml', 'specs/formats/prismml.t27', [29, 30, 34]),
]
SHARED = ['tools/check-specs.sh', 'native/compiler.lock']
ATTENTION_PATHS = [
    'reports/fpga/attn-2026-10-03/evidence-manifest.json', 'reports/fpga/attn-2026-10-03/verify-evidence.py',
    'reports/fpga/attn-2026-10-03/physical-results.json', 'tools/verify_gf16_attn_board.py',
    'tools/gf16_attn_vectors.py', 'tools/ffn_vectors.py', 'tools/uart_loader_protocol.py',
    't27/rtl/gf16_attn.t27', 'rtl/t27/gf16_attn.v', 'tools/attention-proof.py',
]


def sha(root, path):
    return hashlib.sha256((root / path).read_bytes()).hexdigest()


def seal_of(root, spec):
    for path in sorted((root / '.trinity/seals').glob('*.json')):
        if json.loads(path.read_text()).get('spec_path') == spec:
            return str(path.relative_to(root))
    raise SystemExit('no seal for ' + spec)


def vector_count(root, vectors):
    return len(json.loads((root / vectors).read_text())['vectors'])


def claims(root):
    code = ('import importlib.util,json,sys;from pathlib import Path;'
            "s=importlib.util.spec_from_file_location('ep','tools/evidence-proof.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m);"
            "print(json.dumps([{k:v for k,v in c.items() if k in('name','issues','spec','vectors','manifest')} for c in m.load_claims().values()]))")
    return json.loads(subprocess.check_output([sys.executable, '-c', code], cwd=root, text=True))


def q(s):
    return json.dumps(s)


def strs(name, values):
    return f'pub const {name} : [{len(values)}]str = [' + ', '.join(q(v) for v in values) + '];'


def nums(name, values, kind='u32'):
    return f'pub const {name} : [{len(values)}]{kind} = [' + ', '.join(str(v) for v in values) + '];'


def main():
    root = Path(sys.argv[1]).resolve()
    groups = []  # name, spec, seal, vectors, evidence, extras, issues
    groups.append(('attention', 'specs/memory/attention_evidence.t27', seal_of(root, 'specs/memory/attention_evidence.t27'),
                   'conformance/memory_attention_evidence.json', 'reports/fpga/attn-2026-10-03/evidence-manifest.json',
                   ATTENTION_PATHS, [115, 122]))
    for name, spec, issues in SEALED:
        groups.append((name, spec, seal_of(root, spec), spec.replace('specs/memory/', 'conformance/memory_').replace('specs/formats/', 'conformance/formats_').replace('.t27', '.json'), '', [], issues))
    for c in claims(root):
        extras = ['tools/evidence-proof.py', f'tools/evidence/{c["name"]}.py', c['manifest']]
        groups.append((c['name'], c['spec'], seal_of(root, c['spec']), c['vectors'], c['manifest'], extras, c['issues']))
    out = []
    w = out.append
    w('// SPDX-License-Identifier: Apache-2.0')
    w('; Issue: https://github.com/gHashTag/trinity/issues/1368')
    w('; Source proof: https://github.com/dmitrii-f-t27/trinity-memory/issues/122')
    w('; A closed Memory issue is covered only when every sealed spec that names it passes:')
    w('; exact pinned files, a native seal, committed vectors, and a successful canonical')
    w('; push CI at the repository head. A failing group leaves only its own issues unknown.')
    w('; Retained-board claims replay stored measurements; no claim here is a new board run.')
    w('; Generated pins: scripts/memory-proof-pins.py over a trinity-memory checkout.')
    w('module queen_memory_issue_proof;')
    w('')
    w(f'pub const REPO : str = {q(REPO)};')
    w(f'pub const WORKFLOW : str = ".github/workflows/ci.yml";')
    w(f'pub const WORKFLOW_HASH : str = {q(sha(root, ".github/workflows/ci.yml"))};')
    w(f'pub const MAKEFILE : str = "Makefile";')
    w(f'pub const MAKEFILE_HASH : str = {q(sha(root, "Makefile"))};')
    w(strs('GLOBAL_PATHS', SHARED))
    w(strs('GLOBAL_HASHES', [sha(root, p) for p in SHARED]))
    w(strs('GROUP_NAMES', [g[0] for g in groups]))
    w(strs('GROUP_SPEC', [g[1] for g in groups]))
    w(strs('GROUP_SPEC_HASH', [sha(root, g[1]) for g in groups]))
    w(strs('GROUP_SEAL', [g[2] for g in groups]))
    w(strs('GROUP_SEAL_HASH', [sha(root, g[2]) for g in groups]))
    w(strs('GROUP_VECTORS', [g[3] for g in groups]))
    w(strs('GROUP_VECTORS_HASH', [sha(root, g[3]) for g in groups]))
    w(nums('GROUP_VECTOR_COUNT', [vector_count(root, g[3]) for g in groups]))
    w(strs('GROUP_EVIDENCE', [g[4] for g in groups]))
    paths, owners = [], []
    for index, g in enumerate(groups):
        for path in g[5]:
            paths.append(path)
            owners.append(index)
    w(strs('GROUP_PATHS', paths))
    w(strs('GROUP_PATH_HASHES', [sha(root, p) for p in paths]))
    w(nums('GROUP_PATH_OWNER', owners))
    numbers, which = [], []
    for index, g in enumerate(groups):
        for issue in g[6]:
            numbers.append(issue)
            which.append(index)
    w(nums('ISSUE_NUMBERS', numbers))
    w(nums('ISSUE_GROUPS', which))
    w('pub const CACHE_MS : u32 = 60000;')
    w('; closed + allowlisted exact source + native evidence + canonical successful CI.')
    accept = [0] * 15 + [1]
    w(nums('ACCEPT', accept, 'u8'))
    w('test missing_evidence_is_never_honey {')
    for i in range(15):
        w(f'    assert ACCEPT[{i}] == 0;')
    w('}')
    w('test complete_proof_is_honey {')
    w('    assert ACCEPT[15] == 1;')
    w('    assert CACHE_MS == 60000;')
    w('    assert ISSUE_NUMBERS[0] == 115;')
    w('    assert ISSUE_NUMBERS[1] == 122;')
    w('}')
    sys.stdout.write('\n'.join(out) + '\n')


if __name__ == '__main__':
    main()
