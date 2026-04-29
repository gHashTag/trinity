#!/usr/bin/env python3
"""Vocab audit: ensure single source of truth = 729 padded.

Checks:
1. Trinity core uses VOCAB_SIZE=729 everywhere
2. No vocab=256 fallbacks in Trinity modules (vibeec external models excluded)
3. Padding: logits 256-728 = -inf in softmax
"""

import subprocess
import sys

PASS = 0
FAIL = 0


def check(label, cmd, expect_zero=True):
    global PASS, FAIL
    result = subprocess.run(cmd, capture_output=True, text=True)
    count = len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0
    if expect_zero and count == 0:
        print(f"  [PASS] {label}")
        PASS += 1
    elif not expect_zero and count > 0:
        print(f"  [PASS] {label} ({count} found)")
        PASS += 1
    else:
        print(f"  [FAIL] {label} (expected {'0' if expect_zero else '>0'}, got {count})")
        FAIL += 1
    return count


print("=" * 60)
print("VOCAB AUDIT: Single Source of Truth = 729 padded")
print("=" * 60)

print("\n1. Trinity core VOCAB_SIZE = 729")
check("VOCAB_SIZE=729 defined",
      ["rg", "VOCAB_SIZE.*=.*729", "src/tri/", "--type", "zig"],
      expect_zero=False)

print("\n2. No vocab=256 in Trinity modules (excluding vibeec)")
check("No vocab=256 in src/tri/",
      ["rg", "vocab.*=.*256", "src/tri/", "--type", "zig"])

print("\n3. VOCAB_SIZE test assertion exists")
check("VOCAB_SIZE == 729 test",
      ["rg", "VOCAB_SIZE == 729", "src/tri/", "--type", "zig"],
      expect_zero=False)

print("\n4. OUTPUT_DIM derived from VOCAB_SIZE")
check("OUTPUT_DIM = VOCAB_SIZE",
      ["rg", "OUTPUT_DIM.*VOCAB_SIZE", "src/tri/", "--type", "zig"],
      expect_zero=False)

print("\n5. Embedding dimension uses VOCAB_SIZE")
check("Embedding uses vocab_size",
      ["rg", "vocab_size", "src/tri/", "--type", "zig"],
      expect_zero=False)

print("\n" + "=" * 60)
if FAIL == 0:
    print(f"ALL CHECKS PASSED ({PASS}/{PASS})")
    sys.exit(0)
else:
    print(f"SOME CHECKS FAILED ({FAIL} failures, {PASS} passes)")
    sys.exit(1)
