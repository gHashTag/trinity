#!/usr/bin/env python3
"""Generate complete FAR table for XC7A100T from part.json.

This generates ALL valid frame addresses in auto-increment order,
including columns 12-17 that were missing from the previous table.

FAR format: [25:23]=block_type, [22]=top/bot, [21:17]=row, [16:7]=col, [6:0]=minor
"""
import json

def make_far(bt, half, row, col, minor):
    return (bt << 23) | (half << 22) | (row << 17) | (col << 7) | minor

def main():
    with open("/tmp/xc7a100tfgg676_part.json") as f:
        part = json.load(f)

    bus_to_bt = {"CLB_IO_CLK": 0, "BLOCK_RAM": 1}

    # Collect all sections in FAR auto-increment order
    all_sections = []
    for half_name in ["top", "bottom"]:
        half_bit = 0 if half_name == "top" else 1
        half_data = part["global_clock_regions"].get(half_name)
        if not half_data:
            continue
        for row_str in sorted(half_data["rows"].keys(), key=int):
            row = int(row_str)
            for bus_name in ["CLB_IO_CLK", "BLOCK_RAM"]:
                bt = bus_to_bt[bus_name]
                bus_data = half_data["rows"][row_str]["configuration_buses"].get(bus_name)
                if not bus_data:
                    continue
                cols = bus_data["configuration_columns"]
                all_sections.append((bt, half_bit, row, cols))

    # Sort by (bt, half, row) — FAR numeric order
    all_sections.sort(key=lambda x: (x[0], x[1], x[2]))

    # Generate all FAR addresses
    far_addresses = []
    for bt, half, row, cols in all_sections:
        for col_str in sorted(cols.keys(), key=int):
            col = int(col_str)
            frame_count = cols[col_str]["frame_count"]
            for minor in range(frame_count):
                far = make_far(bt, half, row, col, minor)
                far_addresses.append(far)

    # Verify they're sorted (they should be since we iterate in order)
    for i in range(1, len(far_addresses)):
        if far_addresses[i] <= far_addresses[i-1]:
            print(f"WARNING: not sorted at index {i}: {far_addresses[i-1]:#010x} >= {far_addresses[i]:#010x}")

    print(f"Total FAR addresses: {len(far_addresses)}")

    # Count section transitions
    transitions = 0
    for i in range(1, len(far_addresses)):
        bt_p = (far_addresses[i-1] >> 23) & 0x7
        h_p = (far_addresses[i-1] >> 22) & 0x1
        r_p = (far_addresses[i-1] >> 17) & 0x1F
        bt_c = (far_addresses[i] >> 23) & 0x7
        h_c = (far_addresses[i] >> 22) & 0x1
        r_c = (far_addresses[i] >> 17) & 0x1F
        if bt_p != bt_c or h_p != h_c or r_p != r_c:
            transitions += 1

    padding = transitions * 2 + 2
    print(f"Section transitions: {transitions}")
    print(f"Total FDRI frames: {len(far_addresses)} + {padding} = {len(far_addresses) + padding}")
    print(f"Reference: 9464")

    # Generate Zig source
    output = """// =============================================================================
// FORGE OF KOSCHEI v2.0 — XC7A100T Frame Address Table
// =============================================================================
//
// Auto-generated from prjxray-db part.json for xc7a100tfgg676.
// Maps FAR (Frame Address Register) values to linear frame indices.
//
// XC7A100T has {total} configuration frames.
// FAR format: [25:23]=block_type, [22]=top/bot, [21:17]=row, [16:7]=col, [6:0]=minor
//
// This table is sorted — use binary search for O(log n) lookup.
//
// Generated from: prjxray-db/artix7/xc7a100tfgg676-1/part.json
// Includes ALL valid frame addresses (including cols 12-17 in CLB_IO_CLK row 0).
//
// =============================================================================

const std = @import("std");

/// Total number of configuration frames for XC7A100T.
pub const frame_count: u32 = {total};

/// Sorted FAR addresses in linear frame order.
/// Index i in this array = linear frame index i.
/// Binary search for a FAR value gives its linear frame index.
pub const far_table = [_]u32{{
""".format(total=len(far_addresses))

    # Write 16 values per line
    for i in range(0, len(far_addresses), 16):
        chunk = far_addresses[i:i+16]
        line = "    " + ", ".join(f"0x{v:08X}" for v in chunk) + ","
        output += line + "\n"

    output += "};\n"

    # Write output
    out_path = "/Users/playra/trinity-w1/src/forge/far_table.zig"
    with open(out_path, "w") as f:
        f.write(output)

    print(f"\nWritten to {out_path}")
    print(f"Old: 9012 entries")
    print(f"New: {len(far_addresses)} entries (+{len(far_addresses) - 9012})")

if __name__ == "__main__":
    main()
