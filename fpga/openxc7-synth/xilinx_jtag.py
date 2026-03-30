#!/usr/bin/env python3
"""
Xilinx Platform Cable USB II JTAG Programmer
Uses pyusb to communicate directly with Xilinx cable

VID:PID = 0x03fd:0x0013 (Platform Cable USB II)
"""

import usb.core
import usb.util
import sys
import struct

# Xilinx USB Vendor/Product IDs
XILINX_VID = 0x03fd
PLATFORM_CABLE_PID = 0x0013

# USB endpoints
EP_OUT = 0x02
EP_IN = 0x82

def find_device():
    """Find Xilinx Platform Cable USB II"""
    dev = usb.core.find(idVendor=XILINX_VID, idProduct=PLATFORM_CABLE_PID)
    if dev is None:
        print(f"Error: Xilinx Platform Cable not found (VID:PID={XILINX_VID:04x}:{PLATFORM_CABLE_PID:04x})")
        sys.exit(1)
    return dev

def init_device(dev):
    """Initialize USB device"""
    try:
        # Detach kernel driver if active
        if dev.is_kernel_driver_active(0):
            dev.detach_kernel_driver(0)

        # Set configuration
        dev.set_configuration()

        # Claim interface
        usb.util.claim_interface(dev, 0)

        print(f"Found Xilinx Platform Cable USB II")
        print(f"  Manufacturer: {dev.iManufacturer}")
        print(f"  Product: {dev.iProduct}")
        return True
    except usb.core.USBError as e:
        print(f"USB Error: {e}")
        return False

def read_bitstream(filename):
    """Read Xilinx .bit file"""
    with open(filename, 'rb') as f:
        data = f.read()

    # Parse .bit format
    # .bit files start with the sync word and have length info
    # The actual bitstream starts after the header

    # Find the sync word (0xAA995566)
    sync = bytes([0xAA, 0x99, 0x55, 0x66])

    idx = data.find(sync)
    if idx == -1:
        print("Error: Invalid .bit file (no sync word found)")
        sys.exit(1)

    # Extract bitstream (skip header)
    bitstream = data[idx:]

    # Verify it starts with sync
    if bitstream[:4] != sync:
        print("Error: Bitstream doesn't start with sync word")
        sys.exit(1)

    # Get length from byte 4-7 (little endian)
    length = struct.unpack('<I', bitstream[4:8])[0]

    print(f"Bitstream info:")
    print(f"  Sync word found at offset: {idx}")
    print(f"  Bitstream length: {length} words")

    # Return the full bitstream including sync
    return bitstream

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <bitfile>")
        sys.exit(1)

    bitfile = sys.argv[1]

    # Find and initialize device
    dev = find_device()
    if not init_device(dev):
        sys.exit(1)

    # Read bitstream
    print(f"\nReading bitstream: {bitfile}")
    bitstream = read_bitstream(bitfile)
    print(f"  Total size: {len(bitstream)} bytes")

    # TODO: Implement JTAG programming
    # This requires:
    # 1. JTAG reset (TRST, TMS sequence)
    # 2. Go to IDLE state
    # 3. Go to SHIFT-IR, load BYPASS instruction
    # 4. Go to SHIFT-DR
    # 5. Send CFG_IN instruction
    # 6. Send bitstream data
    # 7. Check JSTART status
    # 8. Go to RUN-TEST-IDLE

    print("\nNote: Full JTAG programming not yet implemented")
    print("The cable is detected and accessible via pyusb")
    print("For now, we need to use xc3sprog or Vivado for actual programming")

if __name__ == '__main__':
    main()
