# JTAG Cable Troubleshooting Guide

**Problem:** Xilinx Platform Cable USB II fails to connect for FPGA programming.

**Root Cause:** Cable requires firmware load to transition from PID 0x0013 (uninitialized) → PID 0x0008 (ready).

---

## ⚡ QUICK FIX (60 seconds)

```bash
# Step 1: Check current PID
python3 -c "import usb.core; dev = usb.core.find(idVendor=0x03fd); print(f'PID: {hex(dev.idProduct)}' if dev else 'Not found')"

# Step 2: If PID = 0x0013, load firmware
sudo /Users/playra/trinity-w1/fpga/tools/fxload -v -t fx2 -d 03fd:0013 -i /Users/playra/trinity-w1/fpga/tools/xusb_xp2.hex

# Step 3: Verify PID changed to 0x0008
python3 -c "import usb.core; dev = usb.core.find(idVendor=0x03fd); print(f'PID: {hex(dev.idProduct)}' if dev else 'Not found')"

# Step 4: Flash bitstream
sudo /Users/playra/trinity-w1/fpga/tools/jtag_program /Users/playra/trinity-w1/fpga/openxc7-synth/quantum_bridge_violation.bit
```

**Or use the auto-script:**
```bash
sudo /Users/playra/trinity-w1/fpga/tools/flash_quantum.sh /Users/playra/trinity-w1/fpga/openxc7-synth/quantum_bridge_violation.bit
```

---

## SYMPTOMS & SOLUTIONS

| Symptom | Cause | Solution |
|---------|--------|----------|
| `Failed to connect. Is cable at PID 0x0008?` | jtag_program compiled for wrong PID | Recompile: `cd /Users/playra/trinity-w1/fpga/tools && gcc -o jtag_program jtag_program.c xpc.c -I/opt/homebrew/Cellar/libusb/1.0.29/include -L/opt/homebrew/Cellar/libusb/1.0.29/lib -lusb-1.0 -O2 -Wall` |
| `libusb_open() failed` | Cable in bad state or PID mismatch | Check PID with python, if 0x0013 run fxload first |
| `No USB probe found` | Wrong PID in xpc.h | xpc.h must have `PRODUCT_ID 0x0008` (cable AFTER fxload) |
| `system_profiler` shows no PID | macOS USB driver issue | Use python/lsusb to check actual PID |
| `LIBUSB_ERROR_TIMEOUT` (openocd) | Cable not initialized (PID 0x0013) | Run fxload first |

---

## CRITICAL PID MAPPING

| State | PID | Tool | Notes |
|-------|-----|------|-------|
| **Uninitialized** | **0x0013** | fxload | Cable fresh from boot/unplug |
| **Ready** | **0x0008** | jtag_program | After fxload firmware load |

**xpc.h must use PRODUCT_ID 0x0008** — jtag_program talks to INITIALIZED cable!

---

## FAILED ATTEMPTS (Don't repeat)

1. ❌ **Patch xpc.h to PID 0x0013** — WRONG! jtag_program needs cable AFTER fxload (0x0008)
2. ❌ **Use openocd without fxload** — openocd cannot initialize raw FTDI 0x0013
3. ❌ **Docker openXC7 for flashing** — Docker image has no openocd/jtag tools
4. ❌ **Native jtag_program without sudo** — requires root for USB access

---

## SUCCESS PATTERNS

✅ **fxload → jtag_program** (works every time)
✅ **python3 libusb for PID checking** (more reliable than system_profiler)
✅ **xpc.h with PRODUCT_ID 0x0008** (after fxload, cable becomes 0x0008)
✅ **Recompile jtag_program after xpc.h changes**

---

## ONE-LINER FIX

```bash
sudo /Users/playra/trinity-w1/fpga/tools/fxload -t fx2 -d 03fd:0013 -i /Users/playra/trinity-w1/fpga/tools/xusb_xp2.hex && sudo /Users/playra/trinity-w1/fpga/tools/jtag_program /Users/playra/trinity-w1/fpga/openxc7-synth/quantum_bridge_violation.bit
```

---

## REFERENCE FILES

```
fpga/tools/
├── fxload           # FTDI firmware loader
├── xusb_xp2.hex     # Xilinx cable firmware
├── xpc.h            # MUST have PRODUCT_ID 0x0008
├── jtag_program     # Compiled binary (must match xpc.h)
└── flash_quantum.sh # Auto script (fxload + flash)
```

---

## LAST UPDATED: 2026-03-03

**φ² + 1/φ² = 3 = TRINITY**
