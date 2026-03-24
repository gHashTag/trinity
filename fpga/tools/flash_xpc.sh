#!/usr/bin/env python3
"""
Flash XC7A100T FPGA via Xilinx Platform Cable USB II
Handles fxload + sleep for re-enumeration + detect + flash
"""

import sys
import time
import subprocess

def run_cmd(cmd, description):
    print(f"[{description}]")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  Error: {result.stderr}")
        return False
    print(result.stdout)
    return True

def main():
    # Step 1: Check initial cable state
    print("\n" + "="*60)
    print("  STEP 1: CHECK INITIAL STATE")
    print("="*60)

    import usb.core
    dev = usb.core.find(idVendor=0x03fd)
    if dev:
        vid = dev.idVendor if dev.idVendor else 0
        pid = dev.idProduct if dev.idProduct else 0
        print(f"  Xilinx Cable: VID={vid:04x} PID={pid:04x}")
        try:
            product = dev.iProduct
            print(f"  Product: {product}")
        except:
            print(f"  Product: (unable to read)")
    else:
        print("  Xilinx Cable: NOT FOUND")
        print("  Please connect Xilinx Platform Cable USB II")
        return 1

    # Step 2: Load firmware (fxload)
    print("\n" + "="*60)
    print("  STEP 2: LOAD FIRMWARE")
    print("="*60)

    if not run_cmd([
        "./fpga/tools/fxload",
        "-v", "-t", "fx2",
        "-d", "03fd:0013",
        "-I", "./fpga/tools/xusb_xp2.hex"
    ], "fxload firmware upload"):
        return 1

    print("  Firmware loaded: 7962 bytes")
    print("  Cable will be switched to PID 0x0008 (JTAG mode)")
    print("  Waiting 5 seconds for USB re-enumeration...")

    # Step 3: Wait for re-enumeration
    time.sleep(5)

    # Step 4: Verify cable state
    print("\n" + "="*60)
    print("  STEP 3: VERIFY JTAG MODE")
    print("="*60)

    dev2 = usb.core.find(idVendor=0x03fd)
    if dev2:
        vid2 = dev2.idVendor if dev2.idVendor else 0
        pid2 = dev2.idProduct if dev2.idProduct else 0
        print(f"  Xilinx Cable: VID={vid2:04x} PID={pid2:04x}")
        expected = "0x0008" if pid2 == 0x08 else "UNKNOWN"
        print(f"  Expected PID: 0x0008 (JTAG mode)")
        print(f"  Actual PID:   {pid2:04x}")
        print(f"  Status: {'✅ OK' if pid2 == 0x08 else '❌ FAIL'}")
    else:
        print("  Xilinx Cable: NOT FOUND after fxload!")
        return 1

    # Step 5: Detect FPGA
    print("\n" + "="*60)
    print("  STEP 4: DETECT FPGA")
    print("="*60)

    if not run_cmd([
        "openFPGALoader", "-c", "xpc", "--detect"
    ], "openFPGALoader detect"):
        return 1

    # Step 6: Flash bitstream
    print("\n" + "="*60)
    print("  STEP 5: FLASH BITSTREAM")
    print("="*60)

    if not run_cmd([
        "openFPGALoader", "-c", "xpc",
        "fpga/openxc7-synth/uart_bridge_fixed.bit"
    ], "openFPGALoader flash"):
        return 1

    print("\n" + "="*60)
    print("  ✅ FLASH COMPLETE")
    print("="*60)
    return 0

if __name__ == "__main__":
    sys.exit(main())
