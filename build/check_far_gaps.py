#!/usr/bin/env python3
"""
Check if there are gaps in the FAR table that auto-increment would fill.

The FAR auto-increment goes: minor->col->row->half->block_type.
GetNextFrameAddress returns the next VALID frame address.

But maybe there are frame addresses between our far_table entries
that are also valid? Let's check for gaps.
"""

def far_fields(far):
    bt = (far >> 23) & 0x7
    half = (far >> 22) & 0x1
    row = (far >> 17) & 0x1F
    col = (far >> 7) & 0x3FF
    minor = far & 0x7F
    return bt, half, row, col, minor

def make_far(bt, half, row, col, minor):
    return (bt << 23) | (half << 22) | (row << 17) | (col << 7) | minor

def parse_far_table_zig(path):
    fars = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith('0x'):
                parts = line.rstrip(',').split(',')
                for part in parts:
                    part = part.strip()
                    if part.startswith('0x'):
                        fars.append(int(part, 16))
    return fars

def main():
    fars = parse_far_table_zig("/Users/playra/trinity-w1/src/forge/far_table.zig")
    far_set = set(fars)
    print(f"FAR table: {len(fars)} entries")

    # Group by (bt, half, row, col)
    col_groups = {}
    for far in fars:
        bt, half, row, col, minor = far_fields(far)
        key = (bt, half, row, col)
        if key not in col_groups:
            col_groups[key] = []
        col_groups[key].append(minor)

    # Check consecutive addressing
    # Auto-increment within a column: minor 0, 1, 2, ..., N
    # Then jump to next column
    # But what if there are "missing" minor addresses within a column?
    print("\n=== Checking for minor gaps within columns ===")
    gaps_found = 0
    for key in sorted(col_groups.keys()):
        bt, half, row, col = key
        minors = sorted(col_groups[key])
        # Check that minors are contiguous from 0
        expected = list(range(minors[-1] + 1))
        if minors != expected:
            print(f"  GAP: bt={bt} h={half} r={row} c={col}: {minors} vs expected {expected}")
            gaps_found += 1

    if gaps_found == 0:
        print("  No minor gaps found - all columns have contiguous minor frames 0..N")

    # Check column ordering
    # Within each (bt, half, row), columns should be contiguous
    print("\n=== Checking for column gaps within sections ===")
    sections = {}
    for key in col_groups:
        bt, half, row, col = key
        skey = (bt, half, row)
        if skey not in sections:
            sections[skey] = []
        sections[skey].append(col)

    for skey in sorted(sections.keys()):
        bt, half, row = skey
        cols = sorted(sections[skey])
        # Are there column gaps?
        for i in range(1, len(cols)):
            if cols[i] != cols[i-1] + 1:
                # There's a gap between cols[i-1] and cols[i]
                gap_size = cols[i] - cols[i-1] - 1
                print(f"  bt={bt} h={half} r={row}: gap between col {cols[i-1]} and {cols[i]} ({gap_size} missing cols)")

    # NOW THE KEY: compute what auto-increment would do
    # Auto-increment: minor wraps at minor_max+1, then col increments
    # But the HARDWARE auto-increment wraps minor at a FIXED value
    # for each column type. If col0 has 42 minors (0-41) and col1 has 36,
    # the hardware knows the max minor for each column.
    #
    # Actually, in the Xilinx architecture, auto-increment goes through
    # ALL columns consecutively, and each column may have different number
    # of minor frames. GetNextFrameAddress handles this by looking up
    # the valid addresses from the part definition.
    #
    # Let me count the total: for each column, how many minor frames does
    # the hardware see? It sees exactly the valid ones.
    # So total auto-increment steps = sum of minor frames per column = len(fars)
    # With padding at section boundaries: + 2*transitions + 2(final)
    # This should give 9012 + 16 = 9028. But FDRI has 9464.
    # So there's something else going on.

    # Let me check the LAST FAR address and what comes after
    last_far = fars[-1]
    bt, half, row, col, minor = far_fields(last_far)
    print(f"\nLast FAR: {last_far:#010x} bt={bt} h={half} r={row} c={col} m={minor}")

    # What's the FIRST FAR after the last row transition?
    # Section 1 (bt=0, h=0, r=0): cols 0-51
    # Section 2 (bt=0, h=0, r=1): cols 0-51
    # etc.
    # Between section boundaries, xc7frames2bit adds 2 zero frames.
    # But maybe it also adds padding at the END of each row
    # (after the last column's last minor frame)?

    # Let's compute what the Frames2Data map would look like
    # after addMissingFrames. The map is ordered by FAR value.
    # Since FAR value encodes bt(MSB)>half>row>col>minor(LSB),
    # the map iteration order IS the auto-increment order.
    # So the frames in the map are EXACTLY our far_table (sorted).

    # Total FDRI words = 955864
    # 955864 / 101 = 9464 frames
    # Our far_table has 9012 frames
    # Delta = 452 frames of padding

    # According to the code:
    # - 2 frames after each section transition: 7 transitions * 2 = 14
    # - 2 frames at the very end: 2
    # Total padding from code: 16
    # But we need 452!

    # WAIT - let me re-read the code more carefully.
    # The check is: if NEXT address has different (bt, half, row).
    # GetNextFrameAddress returns the next address in the PART's full
    # address space, not in the frames map. Maybe the PART has MORE
    # addresses than the frames map?

    # In other words, addMissingFrames iterates using GetNextFrameAddress
    # starting from address 0. This populates ALL valid addresses.
    # But maybe the PART definition includes addresses that our far_table
    # doesn't?

    # Let me check the prjxray-db part definition for xc7a100t

    print("\n=== Computing auto-increment frame count ===")
    # From the column analysis:
    for skey in sorted(sections.keys()):
        bt, half, row = skey
        cols = sorted(sections[skey])
        total = sum(len(col_groups[(bt,half,row,c)]) for c in cols)
        col_range = f"{cols[0]}-{cols[-1]}"
        print(f"  bt={bt} h={half} r={row}: cols {col_range} ({len(cols)} cols), {total} frames")

    # The answer might be in the part.yaml for xc7a100t
    # which defines the complete set of valid frame addresses
    # Let me check if there are more frame addresses in the prjxray-db

    print(f"\nTotal from our table: {len(fars)}")
    print(f"Padding needed: {9464 - len(fars)} = 452")
    print(f"Section transitions: 7 -> 14 padding")
    print(f"Final padding: 2")
    print(f"Code padding total: 16")
    print(f"UNACCOUNTED: {452 - 16} = 436")

    # Let's check: does the xc7a100t prjxray-db part definition
    # have more addresses? Let me count based on the full address space.
    # GetNextFrameAddress goes through addresses for columns that exist
    # in the device, including ones that might not be in our far_table.

    # Our far_table was generated from prjxray-db "reference frame ordering"
    # BUT maybe it's incomplete?

if __name__ == "__main__":
    main()
