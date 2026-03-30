#!/usr/bin/env python3
"""Map reference FDRI positions to FAR addresses using .frames file as ground truth."""
import struct

def far_fields(far):
    bt = (far >> 23) & 0x7
    half = (far >> 22) & 0x1
    row = (far >> 17) & 0x1F
    col = (far >> 7) & 0x3FF
    minor = far & 0x7F
    return bt, half, row, col, minor

def parse_frames_file(path):
    """Parse .frames file -> dict of FAR -> [101 words]"""
    frames = {}
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
        frames[far] = words
    return frames

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
    pos = skip_header(data, 0)
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
                return pos + 4, wc
            pos += 4 + wc * 4
            continue
        pos += 4
    return None, None

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
    # Parse FAR table
    fars = parse_far_table_zig("/Users/playra/trinity-w1/src/forge/far_table.zig")
    print(f"FAR table: {len(fars)} entries")

    # Read .frames file to get non-zero frames and their FAR addresses
    frames_data = parse_frames_file("/Users/playra/trinity-w1/build/blinker_t23_ref.frames")
    nonzero_fars = {}
    for far, words in frames_data.items():
        if any(w != 0 for w in words):
            nonzero_fars[far] = words
    print(f"Non-zero frames in .frames: {len(nonzero_fars)}")

    # Read reference bitstream FDRI data
    with open("/Users/playra/trinity-w1/build/blinker_t23_ref.bit", 'rb') as f:
        bit_data = f.read()
    fdri_start, fdri_words = find_fdri_data(bit_data)
    total_frames = fdri_words // 101
    print(f"FDRI: {total_frames} frames")

    # Extract FDRI frames (big-endian in bitstream)
    fdri_frames = []
    for i in range(total_frames):
        offset = fdri_start + i * 101 * 4
        words = []
        for w in range(101):
            val = struct.unpack('>I', bit_data[offset + w*4:offset + w*4 + 4])[0]
            words.append(val)
        fdri_frames.append(words)

    # Find non-zero FDRI frames and match to FAR addresses
    print("\n=== Non-zero FDRI frames ===")
    fdri_nonzero = []
    for i, frame_words in enumerate(fdri_frames):
        if any(w != 0 for w in frame_words):
            fdri_nonzero.append(i)

    print(f"Non-zero frames in FDRI: {len(fdri_nonzero)}")

    # Match each non-zero FDRI frame to its FAR by comparing frame content
    print("\n=== Matching FDRI positions to FAR addresses ===")
    matches = []
    for fdri_pos in fdri_nonzero:
        fdri_words_arr = fdri_frames[fdri_pos]
        # Find matching FAR in .frames data
        matched_far = None
        for far, words in nonzero_fars.items():
            if words == fdri_words_arr:
                matched_far = far
                break
        if matched_far is not None:
            # Find FAR table index
            far_idx = fars.index(matched_far) if matched_far in fars else -1
            bt, half, row, col, minor = far_fields(matched_far)
            offset = fdri_pos - far_idx if far_idx >= 0 else "?"
            matches.append((fdri_pos, matched_far, far_idx, offset))
            print(f"  FDRI[{fdri_pos:5d}] = FAR {matched_far:#010x} (bt={bt} h={half} r={row} col={col:2d} m={minor:2d}) far_idx={far_idx:5d} offset={offset}")
        else:
            print(f"  FDRI[{fdri_pos:5d}] = NO MATCH (unique content)")

    if matches:
        # Verify offset pattern
        offsets = [m[3] for m in matches if isinstance(m[3], int)]
        unique_offsets = set(offsets)
        print(f"\nUnique offsets: {sorted(unique_offsets)}")

        # Use offset to compute total expected FDRI size
        if len(unique_offsets) > 0:
            # For each far_idx, compute expected fdri_pos = far_idx + padding_before(far_idx)
            # We need to figure out the padding function
            print("\n=== Padding analysis ===")
            for fdri_pos, far, far_idx, offset in matches:
                # Count how many section transitions occur before far_idx
                transitions_before = 0
                for i in range(1, far_idx + 1):
                    bt_p, h_p, r_p, _, _ = far_fields(fars[i-1])
                    bt_c, h_c, r_c, _, _ = far_fields(fars[i])
                    if bt_p != bt_c or h_p != h_c or r_p != r_c:
                        transitions_before += 1
                model_offset = transitions_before * 2
                print(f"  far_idx={far_idx:5d}: offset={offset:3d}, transitions_before={transitions_before}, model(2*trans)={model_offset}, delta={offset - model_offset}")

    # Now let's compute what the right formula is
    # The auto-increment in FDRI goes through ALL frames including "holes" in the address space
    # Hardware auto-increments minor, and when minor wraps, goes to next col
    # But different columns have different numbers of minor frames!
    # So there may be "wasted" auto-increment steps for columns that have fewer minor frames
    print("\n=== Column minor frame counts ===")
    # Group FAR entries by (bt, half, row, col) and count minor frames
    col_minor_counts = {}
    for far in fars:
        bt, half, row, col, minor = far_fields(far)
        key = (bt, half, row, col)
        if key not in col_minor_counts:
            col_minor_counts[key] = []
        col_minor_counts[key].append(minor)

    # Show unique minor counts per column type
    minor_count_hist = {}
    for key, minors in col_minor_counts.items():
        n = len(minors)
        max_minor = max(minors)
        minor_count_hist.setdefault(n, []).append(key)

    for count in sorted(minor_count_hist.keys()):
        cols = minor_count_hist[count]
        example = cols[0]
        bt, half, row, col = example
        print(f"  {count} minor frames: {len(cols)} columns (example: bt={bt} h={half} r={row} col={col})")
        # Check max minor value
        max_m = max(col_minor_counts[example])
        print(f"    max minor = {max_m}")

    # Key insight: the hardware auto-increment may go through more minor addresses
    # than we have frames for. For example, if col 0 has 42 minor frames (0-41)
    # but col 1 has 36 minor frames (0-35), the hardware auto-increments past
    # minor 35 up to some maximum before moving to the next column.
    #
    # Actually, for Artix-7, ALL columns in a given type have the same number of
    # minor frames. The auto-increment wraps at a fixed boundary.
    #
    # Let me check: what is the maximum minor value across all entries?
    max_minor_all = max(far_fields(f)[4] for f in fars)
    print(f"\n  Max minor across all FAR entries: {max_minor_all}")

    # Check if auto-increment wraps at max_minor+1 for all columns
    # If so, the total FDRI size = total_columns * (max_minor+1) + section_padding
    total_cols = len(col_minor_counts)
    expected_with_uniform = total_cols * (max_minor_all + 1)
    print(f"  Total columns: {total_cols}")
    print(f"  If all cols had {max_minor_all+1} minor frames: {expected_with_uniform}")
    print(f"  Actual FDRI frames: {total_frames}")
    print(f"  Difference: {total_frames - expected_with_uniform}")

if __name__ == "__main__":
    main()
