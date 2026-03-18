# TRINITY V1 — Pre-Flight Checklist

## φ² + 1/φ² = 3 = TRINITY

**Use this checklist before first UART cable test**

---

## Section 1: Hardware Verification

### 1.1 Board Power
- [ ] 5V power supply connected
- [ ] Power LED on board is lit
- [ ] No unusual heat from FPGA
- [ ] Fan (if present) is spinning

### 1.2 Clock Signal
- [ ] 50MHz oscillator connected to U22
- [ ] Clock signal present (oscilloscope check optional)

### 1.3 JTAG Connection
- [ ] Platform Cable USB II connected
- [ ] Green LED on cable is lit (not red)
- [ ] `lsusb` shows: `03fd:0008` (after fxload)

### 1.4 LED Indicator
- [ ] LED D6 (T23) is blinking after flash
- [ ] LED changes modes with commands

**Section 1 Status**: _____ / 6 checked

---

## Section 2: FPGA Flashing

### 2.1 Bitstream File
- [ ] `trinity_v1.bit` exists (~3.6 MB)
- [ ] File not corrupted (check size)
- [ ] Backup copy exists

### 2.2 Flash Command
```bash
cd /Users/playra/trinity-w1/fpga/openxc7-synth
sudo ../tools/jtag_program trinity_v1.bit
```

- [ ] Flash completed without errors
- [ ] "Done" message appeared
- [ ] LED started blinking after flash

### 2.3 Verification
- [ ] Press reset button → LED restarts pattern
- [ ] Power cycle → LED restarts pattern

**Section 2 Status**: _____ / 7 checked

---

## Section 3: UART Connection

### 3.1 Cable Setup
- [ ] FTDI USB-UART cable connected
- [ ] TX on cable → RX (H16) on FPGA
- [ ] RX on cable → TX (J16) on FPGA
- [ ] GND connected (if using separate supply)

### 3.2 Device Detection
```bash
ls /dev/tty.usb*
```

- [ ] Device appears in list (usually `/dev/tty.usbserial-FT0HQCT4`)
- [ ] Device permissions OK (no "permission denied")
- [ ] If needed: `sudo chmod 666 /dev/tty.usbserial-FT0HQCT4`

### 3.3 Host Binary
- [ ] `uart_host_v6` exists (~141 KB)
- [ ] Binary is executable (`chmod +x`)
- [ ] Architecture matches host (`file uart_host_v6`)

**Section 3 Status**: _____ / 8 checked

---

## Section 4: Command Testing

### 4.1 PING Test
```bash
./uart_host_v6 ping
```
- [ ] Returns `PONG (0xAA)`
- [ ] No timeout error
- [ ] Response time < 100ms

### 4.2 MODE Test
```bash
./uart_host_v6 mode violation
```
- [ ] Returns `OK (0x00)`
- [ ] LED changes to random flicker
- [ ] LED responds to all modes (0-3)

### 4.3 BIND Test
```bash
./uart_host_v6 bind
```
- [ ] Returns 4 bytes data
- [ ] No CRC errors
- [ ] Results reproducible

### 4.4 BUNDLE Test
```bash
./uart_host_v6 bundle
```
- [ ] Returns 4 bytes data
- [ ] No CRC errors
- [ ] Results reproducible

### 4.5 SIMILARITY Test
```bash
./uart_host_v6 similarity
```
- [ ] Returns score 0-255
- [ ] Identical vectors return 255
- [ ] Different vectors return 0-254

### 4.6 BITNET Test
```bash
./uart_host_v6 run-model 42
```
- [ ] Returns `Token: '!' (0x21)`
- [ ] LED blinks fast during inference
- [ ] Other prompt IDs work (0, 1, etc.)

**Section 4 Status**: _____ / 16 checked

---

## Section 5: Full Test Suite

### 5.1 Automated Test
```bash
./trinity_demo_test.sh
```
- [ ] All 6 tests pass
- [ ] Summary shows `6 / 6 PASSED`
- [ ] TRINITY banner appears at end

**Section 5 Status**: _____ / 3 checked

---

## Section 6: Performance

### 6.1 Latency Check
- [ ] PING response < 50ms
- [ ] BIND response < 20ms
- [ ] BITNET inference < 10ms (100 cycles @ 50MHz)

### 6.2 Benchmark
```bash
./uart_host_v6 benchmark
```
- [ ] All operations complete
- [ ] No timeouts
- [ ] Throughput > 100 ops/sec per operation

**Section 6 Status**: _____ / 5 checked

---

## Section 7: Documentation

### 7.1 Files Present
- [ ] `TRINITY_V1_README.md` exists
- [ ] `TRINITY_V1_CHECKLIST.md` exists
- [ ] `FLASH_HISTORY.md` exists
- [ ] `VIDEO_SCRIPT.md` exists

### 7.2 Flash Log
- [ ] Current flash version logged
- [ ] Date/time recorded
- [ ] Any issues noted

**Section 7 Status**: _____ / 6 checked

---

## FINAL STATUS

```
╔════════════════════════════════════════════════════════════════════════════╗
║  TRINITY V1 PRE-FLIGHT CHECKLIST                                           ║
╠════════════════════════════════════════════════════════════════════════════╣
║  Section 1 (Hardware):     ___ / 6                                           ║
║  Section 2 (Flashing):     ___ / 7                                           ║
║  Section 3 (UART):         ___ / 8                                           ║
║  Section 4 (Commands):     ___ / 16                                          ║
║  Section 5 (Full Test):    ___ / 3                                           ║
║  Section 6 (Performance):  ___ / 5                                           ║
║  Section 7 (Docs):        ___ / 6                                           ║
╠════════════════════════════════════════════════════════════════════════════╣
║  TOTAL:                   ___ / 51          100% = READY                     ║
╚════════════════════════════════════════════════════════════════════════════╝
```

### Go/No-Go Decision

- [ ] **GO**: All sections complete, proceed with full demo
- [ ] **NO-GO**: Fix issues above before cable test

### Notes
```
________________________________________________________________________________
________________________________________________________________________________
________________________________________________________________________________
```

---

**φ² + 1/φ² = 3 = TRINITY**

**Checklist completed**: _____ / _____ 2026
**Completed by**: _________________________
