# UART TEST QUICKSTART — VSA Coprocessor

## Hardware Connection (Required!)

```
┌─────────────────┐              ┌─────────────────────┐
│  USB-UART       │              │   FPGA Artix-7      │
│  or ESP32       │              │   vsa_uart_phi_top  │
├─────────────────┤              ├─────────────────────┤
│ TX  ────────────┼─────────────>│ L20 (RX)           │
│ RX  <───────────┼──────────────┤ K20 (TX)           │
│ GND ────────────┼─────────────>│ GND                │
│ 3.3V           │              │                    │
└─────────────────┘              └─────────────────────┘
```

**CRITICAL:** Use 3.3V logic! NOT 5V!

## Running Tests

### Option 1: USB-UART Adapter (Simplest)

```bash
cd /Users/playra/trinity-w1/fpga/openxc7-synth
python3 vsa_uart_test.py
```

### Option 2: ESP32 with Arduino

Upload the code from `ESP32_CONNECTION_GUIDE.md` and use Serial Monitor.

## What to Expect

```
╔══════════════════════════════════════════════════════╗
║     VSA UART COPROCESSOR TEST                        ║
╚══════════════════════════════════════════════════════╝

🔌 Connecting to /dev/tty.usbserial-XXX @ 115200 baud...
✅ Connected!

============================================================
TEST 1: PING
============================================================
   TX: AA FF 00 CRC
   RX: AA
✅ PING PASSED

============================================================
TEST 2: PHI_BIND (φ-arithmetic, 0 DSP48!)
============================================================
✅ PHI_BIND PASSED

============================================================
TEST 3: BIND (trit multiplication)
============================================================
✅ BIND PASSED

RESULTS: 3/3 tests passed
✅ ALL TESTS PASSED!
φ² + 1/φ² = 3 = TRINITY
```

## Success Criteria

| Test | What it proves |
|------|----------------|
| PING | UART TX/RX working |
| PHI_BIND | φ-arithmetic in hardware (0 DSP48!) |
| BIND | Trit multiplication working |

## When Complete

The FPGA will be a **proven VSA hardware accelerator**:
- Accepts commands via UART
- Computes VSA operations with 0 DSP48
- Returns results to host

---

**Ready to test! Just connect the hardware and run:**
```bash
python3 vsa_uart_test.py
```
