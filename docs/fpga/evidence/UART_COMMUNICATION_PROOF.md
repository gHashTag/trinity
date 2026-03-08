# UART COMMUNICATION PROOF — VSA Coprocessor

**Date:** 2026-03-09
**Status:** ⏳ PENDING TEST EXECUTION
**FPGA Design:** vsa_uart_phi_top.bit
**Test Script:** `vsa_uart_test.py`

---

## Goal

Prove that the VSA Coprocessor on FPGA:
1. Accepts UART commands at 115200 baud
2. Parses frames correctly (SYNC + CMD + LEN + DATA + CRC)
3. Executes VSA operations (PING, PHI_BIND, BIND)
4. Returns correct responses via UART

---

## Hardware Setup

### FPGA Connections

| FPGA Pin | Signal | Connection |
|----------|--------|------------|
| L20 | UART_RX | USB-UART TX or ESP32 TX |
| K20 | UART_TX | USB-UART RX or ESP32 RX |
| T23 | LED | Status indicator |
| GND | GND | USB-UART GND or ESP32 GND |

### UART Parameters

| Parameter | Value |
|-----------|-------|
| Baud Rate | 115200 |
| Data Bits | 8 |
| Parity | None |
| Stop Bits | 1 |
| Logic Level | 3.3V LVCMOS |

---

## Protocol Frame Format

### Command Frame (Host → FPGA)

```
+------+--------+------+--------+----------+--------+------+
| SYNC | CMD    | LEN  | DATA   | ...      | CRC_L  | CRC_H|
+------+--------+------+--------+----------+--------+------+
| 0xAA | 0x05   | N    | payload| ...      | CCITT  | CCITT|
+------+--------+------+--------+----------+--------+------+
```

### Response Frame (FPGA → Host)

```
+------+--------+------+--------+----------+--------+------+
| SYNC | CMD    | STAT | LEN    | DATA     | CRC_L  | CRC_H|
+------+--------+------+--------+----------+--------+------+
| 0xAA | echo   | 0x00 | M      | result   | CCITT  | CCITT|
+------+--------+------+--------+----------+--------+------+
```

---

## Test Cases

### Test 1: PING

**Purpose:** Verify basic UART communication

**Command:**
```
SYNC: 0xAA
CMD:  0xFF
LEN:  0x00
CRC:  [calculated]
```

**Expected Response:**
```
0xAA (PONG)
```

**Status:** ⏳ PENDING

---

### Test 2: PHI_BIND

**Purpose:** Verify φ-arithmetic multiplication (0 DSP48!)

**Command:**
```
SYNC: 0xAA
CMD:  0x05
LEN:  0x04
DATA: 0x01 0x00 0x00 0x00  (input = 1)
CRC:  [calculated]
```

**Expected:**
```
FPGA computes: φ × 1 ≈ 1.618
Using: φ × x = x + x_prev (addition only!)
Result: non-zero value indicating φ-multiplication
```

**Status:** ⏳ PENDING

---

### Test 3: BIND (Standard)

**Purpose:** Verify standard trit BIND operation

**Command:**
```
SYNC: 0xAA
CMD:  0x02
LEN:  0x08
DATA: [32-bit vector A] [32-bit vector B]
CRC:  [calculated]
```

**Expected:**
```
Trit-wise multiplication result
(+1 × +1 = +1, 0 × anything = 0, etc.)
```

**Status:** ⏳ PENDING

---

## Test Execution

### Prerequisites

- [ ] FPGA running vsa_uart_phi_top.bit
- [ ] USB-UART adapter connected (3.3V logic!)
- [ ] TX/RX cross-connected (TX→RX, RX→TX)
- [ ] GND connected between devices
- [ ] Python 3 + pyserial installed

### Running Tests

```bash
cd /Users/playra/trinity-w1/fpga/openxc7-synth
python3 vsa_uart_test.py
```

### Expected Output

```
╔══════════════════════════════════════════════════════╗
║     VSA UART COPROCESSOR TEST                        ║
║     FPGA: vsa_uart_phi_top.bit                      ║
║     0 DSP48 — φ-arithmetic BIND                     ║
╚══════════════════════════════════════════════════════╝

🔌 Connecting to /dev/tty.usbserial-XXX @ 115200 baud...
✅ Connected!

============================================================
TEST 1: PING
============================================================
   TX: AA FF 00 [CRC]
   RX: AA
✅ PING PASSED: FPGA responded with PONG (0xAA)

============================================================
TEST 2: PHI_BIND (φ-arithmetic, 0 DSP48!)
============================================================
   Input: 0x01000000
   Expected: φ × 1 ≈ 1.618 → FPGA computes via addition
   TX: AA 05 04 01 00 00 00 [CRC]
   RX: [response]
✅ PHI_BIND PASSED: FPGA computed φ-multiplication

============================================================
TEST 3: BIND (standard trit multiplication)
============================================================
   Vector A: 0x55555555
   Vector B: 0x55555555
   Expected: +1 × +1 = +1 → 0x55555555
   TX: AA 02 08 55 55 55 55 55 55 55 55 [CRC]
   RX: [response]
✅ BIND PASSED: Correct trit multiplication

============================================================
RESULTS: 3/3 tests passed
============================================================
✅ ALL TESTS PASSED!

✅ UART communication confirmed
✅ FPGA accepts commands
✅ VSA operations working in hardware
✅ 0 DSP48 φ-arithmetic verified

φ² + 1/φ² = 3 = TRINITY
```

---

## Results

### Test Outcome Summary

| Test | Status | Notes |
|------|--------|-------|
| PING | ⏳ | - |
| PHI_BIND | ⏳ | - |
| BIND | ⏳ | - |

### Pass/Fail Criteria

- ✅ **PASS:** All 3 tests succeed
- ⚠️ **PARTIAL:** 1-2 tests succeed
- ❌ **FAIL:** 0 tests succeed

---

## Evidence

### Serial Log

*(To be filled after test execution)*

```
[Log output from vsa_uart_test.py]
```

### Oscilloscope Capture (Optional)

- [ ] TX waveform captured
- [ ] RX waveform captured
- [ ] Bit timing verified (8.68 µs per bit @ 115200)

---

## Troubleshooting

| Issue | Possible Cause | Solution |
|-------|----------------|----------|
| No response | FPGA not programmed | Flash vsa_uart_phi_top.bit |
| No response | TX/RX swapped | Cross-connect TX↔RX |
| No response | Wrong baud rate | Verify 115200 |
| No response | GND not connected | Connect GND |
| CRC errors | Frame format wrong | Check SYNC + CMD + LEN + CRC |
| Wrong response | Command not implemented | Check vsa_uart_phi_top.v |

---

## Conclusion

*(To be filled after test execution)*

**Status:** ⏳ PENDING

**When Complete:** This will prove that the VSA Coprocessor is a fully functional hardware accelerator that:
1. Communicates via UART
2. Accepts structured commands
3. Executes VSA operations with 0 DSP48
4. Returns computed results

**φ² + 1/φ² = 3 = TRINITY**

---

**Generated by:** Trinity VIBEE + FPGA Toolchain
**Last Updated:** 2026-03-09
