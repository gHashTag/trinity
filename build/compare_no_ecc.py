#!/usr/bin/env python3
"""Compare frame data excluding ECC word (word 50)."""
import struct

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
            if last_reg == 2:
                return pos + 4, wc
            pos += 4 + wc * 4
            continue
        pos += 4
    return None, None

def main():
    with open("/Users/playra/trinity-w1/build/blinker_t23_ref.bit", 'rb') as f:
        ref_data = f.read()
    with open("/Users/playra/trinity-w1/build/blinker_t23.bit", 'rb') as f:
        forge_data = f.read()

    ref_start, ref_words = find_fdri_data(ref_data)
    forge_start, forge_words = find_fdri_data(forge_data)

    total_frames = ref_words // 101
    diffs_data = 0
    diffs_ecc = 0

    for f in range(total_frames):
        for w in range(101):
            idx = f * 101 + w
            rw = struct.unpack('>I', ref_data[ref_start + idx*4:ref_start + idx*4 + 4])[0]
            fw = struct.unpack('>I', forge_data[forge_start + idx*4:forge_start + idx*4 + 4])[0]
            if rw != fw:
                if w == 50:
                    diffs_ecc += 1
                else:
                    diffs_data += 1
                    print(f"  DATA DIFF: frame {f} word {w}: ref={rw:#010x} forge={fw:#010x}")

    print(f"\nData word differences: {diffs_data}")
    print(f"ECC word differences: {diffs_ecc}")
    if diffs_data == 0:
        print("ALL FRAME DATA (excluding ECC) IS IDENTICAL!")

if __name__ == "__main__":
    main()
