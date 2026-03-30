#!/usr/bin/env python3
"""Analyze reference bitstream FDRI padding and FAR table transitions."""
import struct
import sys

def skip_header(data, pos):
    if pos + 13 > len(data): return pos
    if data[pos:pos+2] == b'\x00\x09':
        pos += 13
        for tag in [b'a', b'b', b'c', b'd']:
            if pos < len(data) and data[pos:pos+1] == tag:
                pos += 1
                length = struct.unpack('>H', data[pos:pos+2])[0]
                pos += 2 + length
        if pos < len(data) and data[pos:pos+1] == b'e':
            pos += 1
            pos += 4
    return pos

def find_fdri_data(data):
    """Find the monolithic FDRI data in reference bitstream."""
    pos = skip_header(data, 0)

    # Find sync word
    while pos + 4 <= len(data):
        word = struct.unpack('>I', data[pos:pos+4])[0]
        if word == 0xAA995566:
            pos += 4
            break
        pos += 4

    last_reg = None
    while pos + 4 <= len(data):
        word = struct.unpack('>I', data[pos:pos+4])[0]
        pkt_type = (word >> 29) & 0x7

        if word == 0x20000000:
            pos += 4
            continue

        if pkt_type == 1:
            reg = (word >> 13) & 0x1F
            wc = word & 0x7FF
            last_reg = reg
            pos += 4 + wc * 4
            continue

        if pkt_type == 2:
            wc = word & 0x7FFFFFF
            if last_reg == 2:  # FDRI
                fdri_start = pos + 4
                fdri_words = wc
                return fdri_start, fdri_words
            pos += 4 + wc * 4
            continue

        pos += 4

    return None, None

def parse_far_table_zig(path):
    """Parse FAR addresses from far_table.zig."""
    fars = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith('0x'):
                # Parse hex values from the line
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
    # Parse FAR table
    far_path = "/Users/playra/trinity-w1/src/forge/far_table.zig"
    fars = parse_far_table_zig(far_path)
    print(f"FAR table: {len(fars)} entries")

    # Count (bt, half, row) transitions
    transitions = 0
    transition_details = []
    for i in range(1, len(fars)):
        bt_prev, half_prev, row_prev, col_prev, _ = far_fields(fars[i-1])
        bt_curr, half_curr, row_curr, col_curr, _ = far_fields(fars[i])
        if bt_prev != bt_curr or half_prev != half_curr or row_prev != row_curr:
            transitions += 1
            transition_details.append({
                'at': i,
                'from': f"bt={bt_prev} half={half_prev} row={row_prev} col={col_prev}",
                'to': f"bt={bt_curr} half={half_curr} row={row_curr} col={col_curr}",
                'far_prev': fars[i-1],
                'far_curr': fars[i],
            })

    print(f"Section transitions: {transitions}")
    print(f"Expected total frames: {len(fars)} + {transitions}*2 = {len(fars) + transitions*2}")
    print(f"Reference FDRI frames: 9464 (955864 words / 101)")
    print()

    # Show all transitions
    for t in transition_details:
        print(f"  @far[{t['at']}]: {t['from']} -> {t['to']}")
        print(f"    FAR: {t['far_prev']:#010x} -> {t['far_curr']:#010x}")

    # Count unique sections
    sections = set()
    for far in fars:
        bt, half, row, _, _ = far_fields(far)
        sections.add((bt, half, row))
    print(f"\nUnique (bt, half, row) sections: {len(sections)}")
    for s in sorted(sections):
        count = sum(1 for f in fars if far_fields(f)[:3] == s)
        bt, half, row = s
        # Count columns in this section
        cols = set()
        for f in fars:
            if far_fields(f)[:3] == s:
                cols.add(far_fields(f)[3])
        print(f"  bt={bt} half={half} row={row}: {count} frames, {len(cols)} columns")

    # Now analyze reference bitstream
    ref_path = "/Users/playra/trinity-w1/build/blinker_t23_ref.bit"
    try:
        with open(ref_path, 'rb') as f:
            ref_data = f.read()

        fdri_start, fdri_words = find_fdri_data(ref_data)
        if fdri_start is None:
            print("\nCould not find FDRI data in reference!")
            return

        total_frames = fdri_words // 101
        print(f"\nReference FDRI: {fdri_words} words = {total_frames} frames")
        print(f"Padding frames: {total_frames - len(fars)}")

        # Find zero-frame positions (padding)
        zero_frames = []
        nonzero_frames = []
        for i in range(total_frames):
            frame_offset = fdri_start + i * 101 * 4
            all_zero = True
            for w in range(101):
                word = struct.unpack('>I', ref_data[frame_offset + w*4:frame_offset + w*4 + 4])[0]
                if word != 0:
                    all_zero = False
                    break
            if all_zero:
                zero_frames.append(i)

        print(f"Zero frames: {len(zero_frames)}")
        print(f"Non-zero frames: {total_frames - len(zero_frames)}")

        # Find contiguous runs of zero frames
        if zero_frames:
            runs = []
            run_start = zero_frames[0]
            run_len = 1
            for i in range(1, len(zero_frames)):
                if zero_frames[i] == zero_frames[i-1] + 1:
                    run_len += 1
                else:
                    runs.append((run_start, run_len))
                    run_start = zero_frames[i]
                    run_len = 1
            runs.append((run_start, run_len))

            # Show padding locations (only runs that could be separators)
            # In xc7frames2bit, separators are exactly 2 frames
            separator_runs = [(s, l) for s, l in runs if l >= 2]
            print(f"\nZero-frame runs of length >= 2: {len(separator_runs)}")
            for start, length in separator_runs[:30]:
                print(f"  frames {start}-{start+length-1} ({length} frames)")
            if len(separator_runs) > 30:
                print(f"  ... {len(separator_runs) - 30} more")

    except FileNotFoundError:
        print(f"\nReference file not found: {ref_path}")

if __name__ == "__main__":
    main()
