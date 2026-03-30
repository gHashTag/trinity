#!/usr/bin/env python3
"""
Generate weight .mem file and expected results for 243x729 ternary matvec.

Weight pattern: W[i][j] = +1 if (i+j)%3==0, -1 if (i+j)%3==1, 0 if (i+j)%3==2
Input pattern:  x[i] = i + 1
Layout:         Column-major: addr = j * N_IN + i

Encoding: 00=0, 01=+1, 10=-1 (matches Verilog decode)

Usage:
  python3 gen_matvec_weights.py           # Generate default 243x729
  python3 gen_matvec_weights.py 64 64     # Generate 64x64 (for testing)
"""
import sys

N_IN  = int(sys.argv[1]) if len(sys.argv) > 1 else 243
N_OUT = int(sys.argv[2]) if len(sys.argv) > 2 else 729

mem_file = f"ternary_matvec_{N_IN}x{N_OUT}_weights.mem"

# Generate .mem file (column-major: addr = j * N_IN + i)
print(f"Generating {mem_file}: {N_IN}x{N_OUT} = {N_IN * N_OUT} weights...")

with open(mem_file, "w") as f:
    for j in range(N_OUT):
        for i in range(N_IN):
            mod3 = (i + j) % 3
            if mod3 == 0:
                f.write("01\n")   # +1
            elif mod3 == 1:
                f.write("10\n")   # -1
            else:
                f.write("00\n")   # 0

print(f"Written: {mem_file} ({N_IN * N_OUT} lines)")

# Compute expected outputs: y[j] = sum_i W[i][j] * x[i], x[i] = i+1
expected = []
for j in range(N_OUT):
    acc = 0
    for i in range(N_IN):
        x_val = i + 1
        mod3 = (i + j) % 3
        if mod3 == 0:
            acc += x_val
        elif mod3 == 1:
            acc -= x_val
    expected.append(acc)

# Verify repeating pattern
pattern = expected[:3]
all_match = all(expected[j] == pattern[j % 3] for j in range(N_OUT))

print(f"\nExpected output pattern (first 9):")
for j in range(min(9, N_OUT)):
    print(f"  y[{j}] = {expected[j]}")

print(f"\nRepeating {pattern}: {'YES' if all_match else 'NO'}")
print(f"Sum check: {sum(pattern)} (should be 0)")

# Summary for Verilog
print(f"\n--- Verilog constants ---")
print(f"  N_IN  = {N_IN}")
print(f"  N_OUT = {N_OUT}")
print(f"  Total weights = {N_IN * N_OUT}")
print(f"  ADDR_WIDTH = {(N_IN * N_OUT - 1).bit_length()}")
print(f"  I_WIDTH = {(N_IN - 1).bit_length()}")
print(f"  J_WIDTH = {(N_OUT - 1).bit_length()}")
print(f"  ACC_WIDTH = 20 (covers max abs = {max(abs(v) for v in expected)})")
print(f"  Expected values: y[j%3==0] = {pattern[0]}")
print(f"                   y[j%3==1] = {pattern[1]}")
print(f"                   y[j%3==2] = {pattern[2]}")
