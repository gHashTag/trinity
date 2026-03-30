#!/usr/bin/env python3
"""Compare frame data between reference and forge bitstreams."""
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

    print(f"Reference FDRI: {ref_words} words @ offset {ref_start}")
    print(f"Forge FDRI:     {forge_words} words @ offset {forge_start}")

    if ref_words != forge_words:
        print("ERROR: word counts don't match!")
        return

    # Compare word by word
    total = ref_words
    diffs = 0
    first_diffs = []
    for i in range(total):
        ref_word = struct.unpack('>I', ref_data[ref_start + i*4:ref_start + i*4 + 4])[0]
        forge_word = struct.unpack('>I', forge_data[forge_start + i*4:forge_start + i*4 + 4])[0]
        if ref_word != forge_word:
            diffs += 1
            frame_num = i // 101
            word_in_frame = i % 101
            if len(first_diffs) < 30:
                first_diffs.append((i, frame_num, word_in_frame, ref_word, forge_word))

    print(f"\nDiffering words: {diffs} / {total}")

    if diffs > 0:
        print("\nFirst differences:")
        for idx, frame, word, ref_w, forge_w in first_diffs:
            print(f"  word[{idx}] (frame {frame}, w{word}): ref={ref_w:#010x} forge={forge_w:#010x}")
    else:
        print("FRAME DATA IS IDENTICAL!")

    # Count non-zero frames
    ref_nz = 0
    forge_nz = 0
    for i in range(total // 101):
        ref_frame_nz = False
        forge_frame_nz = False
        for w in range(101):
            idx = i * 101 + w
            rw = struct.unpack('>I', ref_data[ref_start + idx*4:ref_start + idx*4 + 4])[0]
            fw = struct.unpack('>I', forge_data[forge_start + idx*4:forge_start + idx*4 + 4])[0]
            if rw != 0: ref_frame_nz = True
            if fw != 0: forge_frame_nz = True
        if ref_frame_nz: ref_nz += 1
        if forge_frame_nz: forge_nz += 1

    print(f"\nNon-zero frames: ref={ref_nz}, forge={forge_nz}")

if __name__ == "__main__":
    main()
