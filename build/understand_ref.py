#!/usr/bin/env python3
"""
Understand reference bitstream structure by reading xc7frames2bit source code logic.

The key question: how does xc7frames2bit compute the auto-increment sequence?

From prjxray source: xc7frames2bit reads a .frames file, then iterates through
ALL valid frame addresses using GetNextFrameAddress(). For each pair of consecutive
addresses, if block_type/half/row changes, it inserts 2 zero frames.

The total FDRI size = total_valid_frames + 2 * section_transitions

But we got: 9012 + 2*7 = 9026, not 9464. Delta = 438.

So either:
1. xc7frames2bit writes MORE frames than just the valid ones (including frames
   at addresses not in our far_table)
2. Or there's additional padding we're not accounting for

Let's check: does the .frames file contain MORE addresses than our far_table?
"""
import struct

def parse_frames_file(path):
    """Parse .frames file -> list of (FAR, [101 words])"""
    frames = []
    with open(path, 'rb') as f:
        data = f.read()
    pos = 0
    while pos + 4 <= len(data):
        far = struct.unpack('<I', data[pos:pos+4])[0]
        pos += 4
        if pos + 101*4 > len(data):
            break
        words = []
        for i in range(101):
            w = struct.unpack('<I', data[pos:pos+4])[0]
            pos += 4
            words.append(w)
        frames.append((far, words))
    return frames

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

def far_fields(far):
    bt = (far >> 23) & 0x7
    half = (far >> 22) & 0x1
    row = (far >> 17) & 0x1F
    col = (far >> 7) & 0x3FF
    minor = far & 0x7F
    return bt, half, row, col, minor

def main():
    # Parse our FAR table
    our_fars = parse_far_table_zig("/Users/playra/trinity-w1/src/forge/far_table.zig")
    our_far_set = set(our_fars)

    # Parse .frames file
    frames = parse_frames_file("/Users/playra/trinity-w1/build/blinker_t23_ref.frames")
    frames_fars = [f[0] for f in frames]
    frames_far_set = set(frames_fars)

    print(f"Our FAR table: {len(our_fars)} entries")
    print(f".frames file: {len(frames)} entries")

    # Check if they match
    in_frames_not_ours = frames_far_set - our_far_set
    in_ours_not_frames = our_far_set - frames_far_set

    print(f"\nIn .frames but not our table: {len(in_frames_not_ours)}")
    print(f"In our table but not .frames: {len(in_ours_not_frames)}")

    if in_frames_not_ours:
        print("\nExtra FAR addresses in .frames:")
        for far in sorted(in_frames_not_ours)[:20]:
            bt, half, row, col, minor = far_fields(far)
            print(f"  {far:#010x} bt={bt} h={half} r={row} c={col} m={minor}")
        if len(in_frames_not_ours) > 20:
            print(f"  ... {len(in_frames_not_ours) - 20} more")

    if in_ours_not_frames:
        print("\nMissing FAR addresses from .frames:")
        for far in sorted(in_ours_not_frames)[:20]:
            bt, half, row, col, minor = far_fields(far)
            print(f"  {far:#010x} bt={bt} h={half} r={row} c={col} m={minor}")

    # The .frames file is the GROUND TRUTH for what xc7frames2bit writes.
    # Count section transitions in .frames file (which is sorted by FAR)
    transitions = 0
    for i in range(1, len(frames_fars)):
        bt_p, h_p, r_p, _, _ = far_fields(frames_fars[i-1])
        bt_c, h_c, r_c, _, _ = far_fields(frames_fars[i])
        if bt_p != bt_c or h_p != h_c or r_p != r_c:
            transitions += 1

    print(f"\n.frames section transitions: {transitions}")
    print(f"{len(frames)} + {transitions}*2 = {len(frames) + transitions*2}")
    print(f"Reference FDRI has: 9464 frames")
    print(f"Delta: {9464 - len(frames) - transitions*2}")

    # Count columns in .frames
    col_groups = {}
    for far in frames_fars:
        bt, half, row, col, minor = far_fields(far)
        key = (bt, half, row, col)
        if key not in col_groups:
            col_groups[key] = 0
        col_groups[key] += 1

    print(f"\nTotal columns in .frames: {len(col_groups)}")

    # Show column counts per section
    sections = {}
    for (bt, half, row, col), count in col_groups.items():
        key = (bt, half, row)
        if key not in sections:
            sections[key] = []
        sections[key].append((col, count))

    for key in sorted(sections.keys()):
        bt, half, row = key
        cols = sections[key]
        total = sum(c for _, c in cols)
        print(f"  bt={bt} h={half} r={row}: {len(cols)} cols, {total} frames")
        # Show column details
        for col, count in sorted(cols):
            print(f"    col={col:3d}: {count} minor frames")

if __name__ == "__main__":
    main()
