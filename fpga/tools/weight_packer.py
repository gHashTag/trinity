#!/usr/bin/env python3
"""
TMU Weight Packer — Interleave column-major .mem into K bank files.

Original layout: addr = j * N_IN + i (single file, column-major)
Banked layout:   bank b = i % K, addr_in_bank = j * ceil(N_IN/K) + (i // K)

Usage:
    python3 fpga/tools/weight_packer.py \\
        fpga/openxc7-synth/ternary_matvec_243x729_weights.mem \\
        --k 16 --n_in 243 --n_out 729 --prefix tmu_w_up

Outputs: {prefix}_b00.mem ... {prefix}_b{K-1}.mem
Round-trip verification: reconstructs from banks, diffs with original.
"""

import argparse
import math
import sys
import os


def read_mem_file(path):
    """Read a .mem file with binary weight entries (one per line)."""
    entries = []
    with open(path, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('//'):
                entries.append(line)
    return entries


def pack_weights(entries, n_in, n_out, k):
    """Interleave flat column-major weights into K banks."""
    steps_per_out = math.ceil(n_in / k)
    bank_depth = steps_per_out * n_out
    banks = [['00'] * bank_depth for _ in range(k)]

    for j in range(n_out):
        for i in range(n_in):
            flat_idx = j * n_in + i
            if flat_idx < len(entries):
                b = i % k
                addr = j * steps_per_out + (i // k)
                banks[b][addr] = entries[flat_idx]

    return banks


def verify_roundtrip(entries, banks, n_in, n_out, k):
    """Reconstruct from banks and verify against original."""
    steps_per_out = math.ceil(n_in / k)
    errors = 0

    for j in range(n_out):
        for i in range(n_in):
            flat_idx = j * n_in + i
            if flat_idx < len(entries):
                b = i % k
                addr = j * steps_per_out + (i // k)
                original = entries[flat_idx]
                reconstructed = banks[b][addr]
                if original != reconstructed:
                    errors += 1
                    if errors <= 10:
                        print(f"  MISMATCH at j={j}, i={i}: "
                              f"original={original}, bank[{b}][{addr}]={reconstructed}")

    return errors


def write_bank_files(banks, prefix, output_dir):
    """Write K bank .mem files."""
    paths = []
    for b, bank_data in enumerate(banks):
        filename = f"{prefix}_b{b:02d}.mem"
        filepath = os.path.join(output_dir, filename)
        with open(filepath, 'w') as f:
            for entry in bank_data:
                f.write(entry + '\n')
        paths.append(filepath)
    return paths


def main():
    parser = argparse.ArgumentParser(description='TMU Weight Packer')
    parser.add_argument('input_mem', help='Input .mem file (column-major)')
    parser.add_argument('--k', type=int, default=16, help='Parallelism (banks)')
    parser.add_argument('--n_in', type=int, required=True, help='Input dimension')
    parser.add_argument('--n_out', type=int, required=True, help='Output dimension')
    parser.add_argument('--prefix', required=True, help='Output file prefix')
    parser.add_argument('--output_dir', default=None, help='Output directory (default: same as input)')
    args = parser.parse_args()

    if args.output_dir is None:
        args.output_dir = os.path.dirname(args.input_mem) or '.'

    print(f"Reading {args.input_mem}...")
    entries = read_mem_file(args.input_mem)
    expected = args.n_in * args.n_out
    print(f"  Entries: {len(entries)} (expected {expected})")

    if len(entries) < expected:
        print(f"  WARNING: file has fewer entries than N_IN*N_OUT")

    print(f"Packing into {args.k} banks (steps_per_out={math.ceil(args.n_in/args.k)})...")
    banks = pack_weights(entries, args.n_in, args.n_out, args.k)

    print("Verifying round-trip...")
    errors = verify_roundtrip(entries, banks, args.n_in, args.n_out, args.k)
    if errors == 0:
        print("  Round-trip PASSED: 0 mismatches")
    else:
        print(f"  Round-trip FAILED: {errors} mismatches")
        sys.exit(1)

    print(f"Writing bank files to {args.output_dir}/...")
    paths = write_bank_files(banks, args.prefix, args.output_dir)
    for p in paths:
        print(f"  {p}")

    bank_depth = math.ceil(args.n_in / args.k) * args.n_out
    bram18_est = args.k  # 1 BRAM18 per bank (2-bit * depth)
    print(f"\nSummary:")
    print(f"  Banks: {args.k}")
    print(f"  Bank depth: {bank_depth}")
    print(f"  BRAM18 estimate: {bram18_est} ({bram18_est // 2} BRAM36)")
    print(f"  Total weights: {expected}")


if __name__ == '__main__':
    main()
