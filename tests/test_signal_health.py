#!/usr/bin/env python3
"""Assert signal_health's numbers on sequences whose answers are known.

Values, not verdicts. The structural check's flop counter returned zero for
every design on earth and stayed green for weeks because the only thing its
self-test asserted was pass-or-fail.

Run: python3 tests/test_signal_health.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from signal_health import analyse  # noqa: E402

F, S = "failure", "success"

CASES = [
    # (name, newest-first conclusions, streak, failures, p_red, bits)
    ("all green",            [S] * 10,               0, 0,  0.0,  math.inf),
    ("all red",              [F] * 10,              10, 10,  1.0,  0.0),
    ("red streak then green", [F, F, F, S, S, S],    3,  3,  0.5,  1.0),
    ("green on top of reds",  [S, F, F, F, F],       0,  4,  0.8,  math.log2(1 / 0.8)),
    ("single run, red",       [F],                   1,  1,  1.0,  0.0),
    # The real shape this was written for: corona, four reds then a green,
    # measured from the API before the fix landed.
    ("corona before the fix", [F, F, F, F, S, S, S, S], 4, 4, 0.5, 1.0),
]

bad = 0
for name, seq, e_streak, e_fail, e_p, e_bits in CASES:
    streak, failures, p_red, bits = analyse(seq)
    ok = (streak == e_streak and failures == e_fail
          and abs(p_red - e_p) < 1e-12
          and (bits == e_bits if math.isinf(e_bits) else abs(bits - e_bits) < 1e-12))
    print(f"  {'PASS' if ok else 'FAIL'} {name:<24} streak={streak} failures={failures} "
          f"p={p_red:.3f} bits={bits}")
    if not ok:
        print(f"       expected streak={e_streak} failures={e_fail} p={e_p} bits={e_bits}")
        bad += 1

print()
print(f"  {len(CASES) - bad}/{len(CASES)} sequences match their known answers")
raise SystemExit(1 if bad else 0)
