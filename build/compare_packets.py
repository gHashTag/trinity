#!/usr/bin/env python3
"""Decode Xilinx 7-series bitstream packets and compare two .bit files."""
import struct
import sys

REG_NAMES = {
    0: "CRC", 1: "FAR", 2: "FDRI", 3: "FDRO", 4: "CMD", 5: "CTL0",
    6: "MASK", 7: "STAT", 8: "LOUT", 9: "COR0", 10: "MFWR", 11: "CBC",
    12: "IDCODE", 13: "AXSS", 14: "COR1", 15: "CSOB", 16: "WBSTAR",
    17: "TIMER", 24: "CTL1",
}
CMD_NAMES = {
    0: "NULL", 1: "WCFG", 2: "MFW", 3: "DGHIGH", 4: "RCFG",
    5: "START", 6: "RCAP", 7: "RCRC", 8: "AGHIGH", 9: "SWITCH",
    10: "GRESTORE", 11: "SHUTDOWN", 12: "GCAPTURE", 13: "DESYNC",
}
OP_NAMES = {0: "NOP", 1: "READ", 2: "WRITE"}

def skip_header(data, pos):
    """Skip .bit file ASCII header, return position after header."""
    if pos + 13 > len(data):
        return pos
    # Check for header magic
    if data[pos:pos+2] == b'\x00\x09':
        pos += 13  # skip magic
        # Skip fields a, b, c, d
        for tag in [b'a', b'b', b'c', b'd']:
            if pos < len(data) and data[pos:pos+1] == tag:
                pos += 1
                length = struct.unpack('>H', data[pos:pos+2])[0]
                pos += 2 + length
        # Field 'e' with 4-byte length
        if pos < len(data) and data[pos:pos+1] == b'e':
            pos += 1
            pos += 4  # skip the 4-byte data length
    return pos

def decode_packets(data):
    """Decode all configuration packets from bitstream data."""
    pos = skip_header(data, 0)
    packets = []

    # Scan for sync word
    while pos + 4 <= len(data):
        word = struct.unpack('>I', data[pos:pos+4])[0]
        if word == 0xAA995566:
            packets.append(("SYNC", pos, 0xAA995566, None, None))
            pos += 4
            break
        pos += 4

    last_reg = None
    while pos + 4 <= len(data):
        word = struct.unpack('>I', data[pos:pos+4])[0]
        pkt_type = (word >> 29) & 0x7

        if word == 0x20000000:
            packets.append(("NOOP", pos, word, None, None))
            pos += 4
            continue

        if pkt_type == 1:
            opcode = (word >> 27) & 0x3
            reg = (word >> 13) & 0x1F
            wc = word & 0x7FF
            last_reg = reg
            reg_name = REG_NAMES.get(reg, f"REG_{reg:#x}")
            op_name = OP_NAMES.get(opcode, f"OP_{opcode}")

            if wc > 0 and pos + 4 + wc * 4 <= len(data):
                values = []
                for i in range(wc):
                    v = struct.unpack('>I', data[pos+4+i*4:pos+8+i*4])[0]
                    values.append(v)

                if reg == 4 and wc == 1:  # CMD register
                    cmd_name = CMD_NAMES.get(values[0], f"CMD_{values[0]:#x}")
                    packets.append(("TYPE1_WRITE", pos, word, reg_name, f"{cmd_name} ({values[0]:#010x})"))
                elif wc == 1:
                    packets.append(("TYPE1_WRITE", pos, word, reg_name, f"{values[0]:#010x}"))
                else:
                    packets.append(("TYPE1_WRITE", pos, word, reg_name, f"{wc} words"))
                pos += 4 + wc * 4
            else:
                packets.append(("TYPE1", pos, word, reg_name, f"op={op_name} wc={wc}"))
                pos += 4
            continue

        if pkt_type == 2:
            opcode = (word >> 27) & 0x3
            wc = word & 0x7FFFFFF
            reg_name = REG_NAMES.get(last_reg, f"REG_{last_reg}") if last_reg is not None else "?"
            packets.append(("TYPE2", pos, word, reg_name, f"op={(word>>27)&3} wc={wc} ({wc} words = {wc//101} frames)"))
            pos += 4 + wc * 4
            continue

        if word == 0xFFFFFFFF or word == 0x000000BB or word == 0x11220044:
            packets.append(("SPECIAL", pos, word, None, None))
            pos += 4
            continue

        packets.append(("UNKNOWN", pos, word, None, None))
        pos += 4

    return packets

def print_packets(packets, label, collapse_noops=True):
    print(f"\n{'='*70}")
    print(f" {label}")
    print(f"{'='*70}")

    noop_count = 0
    for pkt_type, offset, word, reg, detail in packets:
        if pkt_type == "NOOP":
            noop_count += 1
            continue
        if noop_count > 0:
            print(f"  [{noop_count}x NOOP]")
            noop_count = 0

        if pkt_type == "SYNC":
            print(f"  @{offset:06x}: SYNC 0xAA995566")
        elif pkt_type == "TYPE1_WRITE":
            print(f"  @{offset:06x}: {reg} = {detail}")
        elif pkt_type == "TYPE1":
            print(f"  @{offset:06x}: TYPE1 {reg} {detail}")
        elif pkt_type == "TYPE2":
            print(f"  @{offset:06x}: TYPE2 FDRI {detail}")
        elif pkt_type == "SPECIAL":
            names = {0xFFFFFFFF: "DUMMY", 0x000000BB: "BUS_WIDTH_DETECT", 0x11220044: "BUS_WIDTH_SYNC"}
            print(f"  @{offset:06x}: {names.get(word, f'{word:#010x}')}")
        else:
            print(f"  @{offset:06x}: ??? {word:#010x}")
    if noop_count > 0:
        print(f"  [{noop_count}x NOOP]")

def main():
    ref_path = "/Users/playra/trinity-w1/build/blinker_t23_ref.bit"
    forge_path = "/Users/playra/trinity-w1/build/blinker_t23.bit"

    with open(ref_path, 'rb') as f:
        ref_data = f.read()
    with open(forge_path, 'rb') as f:
        forge_data = f.read()

    print(f"Reference: {len(ref_data)} bytes")
    print(f"Forge:     {len(forge_data)} bytes")
    print(f"Diff:      {len(ref_data) - len(forge_data)} bytes")

    ref_packets = decode_packets(ref_data)
    forge_packets = decode_packets(forge_data)

    print_packets(ref_packets, "REFERENCE (xc7frames2bit)")
    print_packets(forge_packets, "FORGE (Zig)")

    # Count FDRI writes
    ref_fdri = [p for p in ref_packets if "FDRI" in str(p[3] or "")]
    forge_fdri = [p for p in forge_packets if "FDRI" in str(p[3] or "")]
    print(f"\n{'='*70}")
    print(f" FDRI COMPARISON")
    print(f"{'='*70}")
    print(f"Reference FDRI writes: {len(ref_fdri)}")
    print(f"Forge FDRI writes:     {len(forge_fdri)}")

    for i, p in enumerate(ref_fdri[:5]):
        print(f"  Ref FDRI[{i}]: {p[4]}")
    for i, p in enumerate(forge_fdri[:5]):
        print(f"  Forge FDRI[{i}]: {p[4]}")

if __name__ == "__main__":
    main()
