#!/usr/bin/env python3
"""Compute total frame count from part.json and verify against reference FDRI."""
import json

def main():
    with open("/tmp/xc7a100tfgg676_part.json") as f:
        part = json.load(f)

    total_frames = 0
    transitions = 0
    prev_section = None

    # Xilinx 7-series FAR encoding:
    # CLB_IO_CLK = block_type 0
    # BLOCK_RAM = block_type 1
    bus_to_bt = {"CLB_IO_CLK": 0, "BLOCK_RAM": 1}

    # Iterate in FAR auto-increment order:
    # bt ascending, then half (top=0 first, bottom=1), then row, then col, then minor
    # But in the YAML, "top" is the top half and "bottom" is the bottom half.
    # In FAR encoding, bit 22 = 0 for top, 1 for bottom.

    all_sections = []  # (bt, half, row, bus_name, columns_dict)

    for half_name in ["top", "bottom"]:
        half_bit = 0 if half_name == "top" else 1
        half_data = part["global_clock_regions"].get(half_name)
        if not half_data:
            continue
        for row_str, row_data in sorted(half_data["rows"].items(), key=lambda x: int(x[0])):
            row = int(row_str)
            for bus_name in ["CLB_IO_CLK", "BLOCK_RAM"]:
                bt = bus_to_bt[bus_name]
                bus_data = row_data["configuration_buses"].get(bus_name)
                if not bus_data:
                    continue
                cols = bus_data["configuration_columns"]
                all_sections.append((bt, half_bit, row, bus_name, cols))

    # Sort by (bt, half, row) to match FAR auto-increment order
    all_sections.sort(key=lambda x: (x[0], x[1], x[2]))

    print("=== Complete frame address space (FAR order) ===")
    section_list = []
    for bt, half, row, bus_name, cols in all_sections:
        cols_sorted = sorted(cols.items(), key=lambda x: int(x[0]))
        section_frames = sum(v["frame_count"] for _, v in cols_sorted)
        section_list.append((bt, half, row, section_frames, len(cols_sorted)))
        print(f"  bt={bt} h={half} r={row} ({bus_name}): {len(cols_sorted)} cols, {section_frames} frames")
        for col_str, col_data in cols_sorted:
            col = int(col_str)
            fc = col_data["frame_count"]
            # print(f"    col={col:3d}: {fc} minors")
        total_frames += section_frames

    print(f"\nTotal valid frames: {total_frames}")

    # Count section transitions
    for i in range(1, len(section_list)):
        bt_p, h_p, r_p, _, _ = section_list[i-1]
        bt_c, h_c, r_c, _, _ = section_list[i]
        if bt_p != bt_c or h_p != h_c or r_p != r_c:
            transitions += 1

    # xc7frames2bit adds:
    # - 2 zero frames after each section transition (when next has different bt/half/row)
    # - 2 zero frames at the very end
    padding = transitions * 2 + 2

    print(f"Section transitions: {transitions}")
    print(f"Padding frames: {padding}")
    print(f"Total FDRI frames: {total_frames + padding}")
    print(f"Reference FDRI: 9464")
    print(f"Match: {total_frames + padding == 9464}")

    # Now compare with our far_table to find missing entries
    print("\n=== Missing columns in our far_table ===")
    # Our far_table column structure (from check_far_gaps.py):
    # bt=0 h=0 r=0: cols 0-11, 18-57 (missing 12-17)
    # bt=0 h=0 r=1: cols 0-51 (no gap)
    # bt=0 h=1 r=0: cols 0-11, 18-57 (missing 12-17)
    # bt=0 h=1 r=1: cols 0-51 (no gap)
    # bt=1: all present

    # From part.yaml, the complete column sets:
    for bt, half, row, bus_name, cols in all_sections:
        if bt == 0:  # CLB_IO_CLK
            cols_in_part = sorted([int(k) for k in cols.keys()])
            # Our far_table columns for this section
            if half == 0 and row == 0:
                our_cols = list(range(0, 12)) + list(range(18, 58))
            elif half == 0 and row == 1:
                our_cols = list(range(0, 52))
            elif half == 1 and row == 0:
                our_cols = list(range(0, 12)) + list(range(18, 58))
            elif half == 1 and row == 1:
                our_cols = list(range(0, 52))
            else:
                our_cols = []

            missing = [c for c in cols_in_part if c not in our_cols]
            extra = [c for c in our_cols if c not in cols_in_part]

            if missing or extra:
                print(f"  bt={bt} h={half} r={row}:")
                if missing:
                    missing_frames = sum(cols[str(c)]["frame_count"] for c in missing)
                    print(f"    Missing cols: {missing} ({missing_frames} frames)")
                if extra:
                    print(f"    Extra cols: {extra}")

    # What's the total of missing frames?
    total_missing = 0
    for bt, half, row, bus_name, cols in all_sections:
        if bt == 0 and row == 0:
            for c in [12, 13, 14, 15, 16, 17]:
                if str(c) in cols:
                    total_missing += cols[str(c)]["frame_count"]
    print(f"\nTotal missing frames: {total_missing}")
    print(f"9012 + {total_missing} = {9012 + total_missing}")

if __name__ == "__main__":
    main()
