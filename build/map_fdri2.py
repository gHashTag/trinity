#!/usr/bin/env python3
"""Map reference FDRI positions to FAR addresses — fix endianness."""
import struct

def far_fields(far):
    bt = (far >> 23) & 0x7
    half = (far >> 22) & 0x1
    row = (far >> 17) & 0x1F
    col = (far >> 7) & 0x3FF
    minor = far & 0x7F
    return bt, half, row, col, minor

def parse_frames_file(path):
    """Parse .frames file -> dict of FAR -> [101 words] (in big-endian order for comparison)."""
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
            # .frames file stores words in little-endian, but we want to compare
            # with bitstream (big-endian). Just read the raw value.
            w = struct.unpack('<I', data[pos:pos+4])[0]
            pos += 4
            words.append(w)
        frames[far] = tuple(words)
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
    fars = parse_far_table_zig("/Users/playra/trinity-w1/src/forge/far_table.zig")
    print(f"FAR table: {len(fars)} entries")

    # Read .frames file (little-endian words)
    frames_data = parse_frames_file("/Users/playra/trinity-w1/build/blinker_t23_ref.frames")
    nonzero_frames = {far: words for far, words in frames_data.items() if any(w != 0 for w in words)}
    print(f"Non-zero frames in .frames: {len(nonzero_frames)}")

    # Read reference bitstream FDRI data (big-endian words)
    with open("/Users/playra/trinity-w1/build/blinker_t23_ref.bit", 'rb') as f:
        bit_data = f.read()
    fdri_start, fdri_words = find_fdri_data(bit_data)
    total_frames = fdri_words // 101

    # Extract FDRI frames as tuples of words (big-endian read)
    fdri_frames = []
    for i in range(total_frames):
        offset = fdri_start + i * 101 * 4
        words = tuple(struct.unpack('>I', bit_data[offset + w*4:offset + w*4 + 4])[0] for w in range(101))
        fdri_frames.append(words)

    # Build lookup: frame content -> list of FAR addresses with that content
    content_to_far = {}
    for far, words in frames_data.items():
        if words not in content_to_far:
            content_to_far[words] = []
        content_to_far[words].append(far)

    # Find non-zero FDRI frames and match to FAR
    fdri_nonzero_positions = [i for i, f in enumerate(fdri_frames) if any(w != 0 for w in f)]
    print(f"Non-zero FDRI frames: {len(fdri_nonzero_positions)}")

    print("\n=== Matching non-zero FDRI frames to FAR ===")
    matches = []
    for fdri_pos in fdri_nonzero_positions:
        content = fdri_frames[fdri_pos]
        far_candidates = content_to_far.get(content, [])
        if len(far_candidates) == 1:
            far = far_candidates[0]
            far_idx = fars.index(far) if far in fars else -1
            offset = fdri_pos - far_idx if far_idx >= 0 else "?"
            bt, half, row, col, minor = far_fields(far)
            matches.append((fdri_pos, far, far_idx, offset))
            print(f"  FDRI[{fdri_pos:5d}] = FAR {far:#010x} (bt={bt} h={half} r={row} c={col:2d} m={minor:2d}) far_idx={far_idx:5d} offset={offset}")
        elif len(far_candidates) > 1:
            print(f"  FDRI[{fdri_pos:5d}] = AMBIGUOUS ({len(far_candidates)} candidates)")
        else:
            # Try matching with byte-swapped content (endianness issue)
            swapped = tuple(int.from_bytes(w.to_bytes(4, 'big'), 'little') for w in content)
            far_candidates = content_to_far.get(swapped, [])
            if len(far_candidates) == 1:
                far = far_candidates[0]
                far_idx = fars.index(far) if far in fars else -1
                offset = fdri_pos - far_idx if far_idx >= 0 else "?"
                bt, half, row, col, minor = far_fields(far)
                matches.append((fdri_pos, far, far_idx, offset))
                print(f"  FDRI[{fdri_pos:5d}] = FAR {far:#010x} (bt={bt} h={half} r={row} c={col:2d} m={minor:2d}) far_idx={far_idx:5d} offset={offset} [byte-swapped]")
            elif len(far_candidates) > 1:
                print(f"  FDRI[{fdri_pos:5d}] = AMBIGUOUS byte-swapped ({len(far_candidates)} candidates)")
            else:
                # Show first non-zero word for debugging
                first_nz = next((w for w in content if w != 0), None)
                first_nz_idx = next((i for i, w in enumerate(content) if w != 0), None)
                print(f"  FDRI[{fdri_pos:5d}] = NO MATCH (word[{first_nz_idx}]={first_nz:#010x})")

    if matches:
        offsets = [m[3] for m in matches if isinstance(m[3], int)]
        print(f"\nUnique offsets: {sorted(set(offsets))}")

        # Analyze offset function
        print("\n=== Offset analysis ===")
        for fdri_pos, far, far_idx, offset in sorted(matches, key=lambda m: m[2]):
            # Count transitions before this far_idx
            transitions = 0
            for i in range(1, far_idx + 1):
                bt_p, h_p, r_p, _, _ = far_fields(fars[i-1])
                bt_c, h_c, r_c, _, _ = far_fields(fars[i])
                if bt_p != bt_c or h_p != h_c or r_p != r_c:
                    transitions += 1
            model = transitions * 2
            bt, half, row, col, minor = far_fields(far)
            print(f"  far_idx={far_idx:5d} offset={offset:3d} trans={transitions} model_2t={model:3d} delta={offset-model:3d}  (bt={bt} h={half} r={row} c={col} m={minor})")

    # Also compute total with just section transitions
    total_transitions = 0
    for i in range(1, len(fars)):
        bt_p, h_p, r_p, _, _ = far_fields(fars[i-1])
        bt_c, h_c, r_c, _, _ = far_fields(fars[i])
        if bt_p != bt_c or h_p != h_c or r_p != r_c:
            total_transitions += 1
    print(f"\nTotal section transitions: {total_transitions}")
    print(f"9012 + {total_transitions}*2 = {9012 + total_transitions*2}")
    print(f"Need: 9464, delta: {9464 - 9012 - total_transitions*2}")

if __name__ == "__main__":
    main()
