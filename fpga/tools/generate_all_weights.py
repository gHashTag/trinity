#!/usr/bin/env python3
"""
Generate all weight files for the HSLM full inference pipeline.

Files generated:
  1. fpga/weights/embedding_weights.mem       — 256 x 243 x 20-bit signed (hex)
  2. fpga/weights/lm_head_weights.mem         — 256 x 243 x 2-bit ternary (binary)
  3. fpga/openxc7-synth/ternary_matvec_*      — 4 blocks x 2 matrices (binary)

Weight patterns:
  - Embedding: deterministic signed integers based on token_id and dim index
  - LM Head: ternary {-1, 0, +1} encoded as 2-bit binary
  - Block weights: ternary patterns (already generated, regenerated for consistency)

Memory rules:
  - All BRAM arrays use power-of-2 depth
  - Embedding: $readmemh (hex format, 20-bit signed)
  - Ternary: $readmemb (binary format, 2-bit)
"""

import os
import struct

# Paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
WEIGHTS_DIR = os.path.join(PROJECT_ROOT, "fpga", "weights")
SYNTH_DIR = os.path.join(PROJECT_ROOT, "fpga", "openxc7-synth")

os.makedirs(WEIGHTS_DIR, exist_ok=True)

# =========================================================================
# 1. EMBEDDING WEIGHTS — 256 x 243, 20-bit signed, hex format
# =========================================================================
def generate_embedding_weights():
    VOCAB = 128
    DIM = 243
    MEM_DEPTH = 32768  # 2^15
    filepath = os.path.join(WEIGHTS_DIR, "embedding_weights.mem")

    print(f"Generating embedding weights (ternary 2-bit): {VOCAB}x{DIM} -> {filepath}")

    with open(filepath, "w") as f:
        for token_id in range(VOCAB):
            for d in range(DIM):
                # Deterministic ternary pattern
                code = (token_id * 17 + d * 31 + 7) % 3
                if code == 0:
                    f.write("01\n")   # +1
                elif code == 1:
                    f.write("10\n")   # -1
                else:
                    f.write("00\n")   # 0

        # Pad to power-of-2 depth with zeros
        remaining = MEM_DEPTH - VOCAB * DIM
        for _ in range(remaining):
            f.write("00\n")

    print(f"  -> {VOCAB * DIM} entries + {remaining} padding = {MEM_DEPTH} total")


# =========================================================================
# 2. LM HEAD WEIGHTS — 256 x 243, 2-bit ternary, binary format
# =========================================================================
def generate_lm_head_weights():
    DIM = 243
    VOCAB = 128
    MEM_DEPTH = 32768  # 2^15
    filepath = os.path.join(WEIGHTS_DIR, "lm_head_weights.mem")

    print(f"Generating LM head weights: {DIM}x{VOCAB} -> {filepath}")

    with open(filepath, "w") as f:
        for v in range(VOCAB):
            for d in range(DIM):
                # Deterministic ternary pattern
                code = (v * 13 + d * 23 + 3) % 3  # 0, 1, 2
                if code == 0:
                    f.write("01\n")   # +1
                elif code == 1:
                    f.write("10\n")   # -1
                else:
                    f.write("00\n")   # 0

        # Pad to power-of-2
        remaining = MEM_DEPTH - VOCAB * DIM
        for _ in range(remaining):
            f.write("00\n")

    print(f"  -> {VOCAB * DIM} entries + {remaining} padding = {MEM_DEPTH} total")


# =========================================================================
# 3. BLOCK WEIGHTS — 4 blocks x 2 matrices, 2-bit ternary, binary format
# =========================================================================
def generate_block_weights(block_num, suffix):
    """Generate ternary weight file for one matrix of one block."""
    if "243x729" in suffix:
        N_IN, N_OUT = 243, 729
    else:
        N_IN, N_OUT = 729, 243

    ADDR_WIDTH = 18
    MEM_DEPTH = 1 << ADDR_WIDTH  # 262144
    num_weights = N_IN * N_OUT   # 177147

    if block_num == 1:
        prefix = ""
    else:
        prefix = f"_b{block_num}"

    filename = f"ternary_matvec{prefix}_{suffix}_weights.mem"
    filepath = os.path.join(SYNTH_DIR, filename)

    print(f"  Block {block_num} {suffix}: {N_IN}x{N_OUT} -> {filename}")

    with open(filepath, "w") as f:
        for j in range(N_OUT):
            for i in range(N_IN):
                # Different pattern per block for variety
                code = (block_num * 5 + 2 * i + j) % 3
                if code == 0:
                    f.write("01\n")   # +1
                elif code == 1:
                    f.write("10\n")   # -1
                else:
                    f.write("00\n")   # 0

        # Pad to power-of-2
        remaining = MEM_DEPTH - num_weights
        for _ in range(remaining):
            f.write("00\n")


def generate_all_block_weights():
    print(f"Generating block weights (4 blocks x 2 matrices):")
    for block in range(1, 5):
        generate_block_weights(block, "243x729")
        generate_block_weights(block, "729x243")


# =========================================================================
# MAIN
# =========================================================================
if __name__ == "__main__":
    print("=" * 60)
    print("HSLM Full Pipeline — Weight Generation")
    print("=" * 60)

    generate_embedding_weights()
    print()
    generate_lm_head_weights()
    print()
    generate_all_block_weights()

    print()
    print("=" * 60)
    print("All weight files generated successfully!")
    print(f"  Embedding: {WEIGHTS_DIR}/embedding_weights.mem")
    print(f"  LM Head:   {WEIGHTS_DIR}/lm_head_weights.mem")
    print(f"  Blocks:    {SYNTH_DIR}/ternary_matvec_*.mem")
    print("=" * 60)
