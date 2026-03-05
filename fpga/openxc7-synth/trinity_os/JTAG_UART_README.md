# TRINITY JTAG UART — Full Documentation

## Overview

TRINITY JTAG UART enables bidirectional communication with the FPGA **using only the JTAG cable** — no physical UART connection needed!

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Host Computer                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  Python Terminal (jtag_term.py)                            │ │
│  │  or Bash Wrapper (jtag_pipe_wrapper.sh)                    │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                          ↕ USB
┌─────────────────────────────────────────────────────────────────┐
│  JTAG Cable (Platform Cable USB II)                             │
│  VID:0x03fd → 0x0403 (after fxload)                            │
│  PID:0x0013 → 0x6010 (after fxload)                            │
└─────────────────────────────────────────────────────────────────┘
                          ↕ JTAG (TMS, TCK, TDI, TDO)
┌─────────────────────────────────────────────────────────────────┐
│  FPGA (Artix-7 XC7A100T)                                         │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  JTAG TAP Controller (built-in)                             │ │
│  │  ├── USER1 instruction (0x22)                               │ │
│  │  └── 32-bit data register                                    │ │
│  ├────────────────────────────────────────────────────────────┤ │
│  │  JTAG UART Module                                            │ │
│  │  ├── TX FIFO (Host → FPGA)                                  │ │
│  │  ├── RX FIFO (FPGA → Host)                                  │ │
│  │  └── UART @ 115200 baud                                     │ │
│  └────────────────────────────────────────────────────────────┘ │
│                          ↕ UART (internal)                        │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  TRINITY V2/V3 (existing)                                   │ │
│  │  ├── VSA operations (bind, bundle, similarity)             │ │
│  │  ├── TQNN layer (16 qutrits)                                │ │
│  │  └── LED control                                            │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Files

| File | Purpose |
|------|---------|
| `trinity_os/jtag_uart.v` | JTAG UART core (TAP + FIFO + UART) |
| `trinity_v3_jtaguart.v` | Top-level integration with TRINITY V2 |
| `openocd/qmtech_jtag.cfg` | OpenOCD configuration for QMTECH board |
| `tools/jtag_term.py` | Interactive Python terminal |
| `tools/jtag_pipe_wrapper.sh` | Bash pipe wrapper |
| `build_jtaguart.sh` | Build script |

## Quick Start

### 1. Build the Design

```bash
cd fpga/openxc7-synth
./build_jtaguart.sh
```

### 2. Start the Terminal

```bash
./tools/jtag_term.py
```

### 3. Send Commands

```
TRINITY> PING
TRINITY> MODE 3
TRINITY> BIND AAAA5555 BBBBFFFF
TRINITY> quit
```

## Usage Modes

### Python Terminal (Recommended)

```bash
# Normal mode
./tools/jtag_term.py

# Hex display mode
./tools/jtag_term.py --hex

# Raw data mode
./tools/jtag_term.py --raw
```

**Commands:**
| Command | Description |
|---------|-------------|
| `PING` | Ping FPGA (check connection) |
| `MODE <0-7>` | Set LED mode |
| `BIND <vec1> <vec2>` | VSA bind operation (hex) |
| `SIMILARITY <vec>` | VSA similarity |
| `TQNN <data>` | TQNN inference |
| `hex on/off` | Toggle hex display |
| `quit` | Exit terminal |

### Pipe Wrapper

```bash
./tools/jtag_pipe_wrapper.sh
```

Then in separate terminals:

```bash
# Send
echo "PING" > /tmp/trinity_jtag/tx

# Receive
cat /tmp/trinity_jtag/rx
```

### OpenOCD Direct

```bash
openocd -f openocd/qmtech_jtag.cfg
```

Then in OpenOCD shell:

```
> jtag_uart_puts "PING"
> jtag_uart_write 0x41
> set value [jtag_uart_read]
```

## TRINITY Protocol

### Command Format

All commands use the TRINITY V2 protocol:

```
[HEADER] [CMD] [LEN_L] [DATA...] [CRC_L] [CRC_H]
```

| Byte | Value | Description |
|------|-------|-------------|
| HEADER | 0xAA | Packet start |
| CMD | 0xFF-0x06 | Command code |
| LEN_L | 0x00-0xFF | Data length (low byte) |
| DATA | variable | Command data |
| CRC_L | variable | CRC-16 (low byte) |
| CRC_H | variable | CRC-16 (high byte) |

### Command Codes

| Code | Name | Description |
|------|------|-------------|
| 0xFF | PING | Ping/echo test |
| 0x01 | MODE | Set LED mode |
| 0x02 | BIND | VSA bind (8 bytes: vec_a + vec_b) |
| 0x03 | BUNDLE | VSA bundle (8 bytes) |
| 0x04 | SIMILARITY | VSA similarity (8 bytes) |
| 0x05 | BITNET | BitNet inference (1 byte: prompt_id) |
| 0x06 | TQNN | TQNN inference (6 bytes) |

## LED Modes

| Mode | Pattern | Description |
|------|---------|-------------|
| 0 | Slow blink | Idle/Waiting |
| 1 | Fast toggle | Test mode |
| 2 | Medium blink | Processing |
| 3 | Heartbeat | Normal operation |
| 4 | Fast blink | Activity |
| 5-7 | Custom | User-defined |

## JTAG Protocol Details

### USER1 Instruction

```
IR = 0x22 (Xilinx USER1 standard)
DR = 32 bits
```

### Data Register Format

```
[31:16] TX_DATA - Data from host to FPGA
[15:0]  RX_DATA - Data from FPGA to host
```

### Status Flags (upper bits of RX)

| Bit | Name | Description |
|-----|------|-------------|
| 15 | TX_EMPTY | TX FIFO is empty |
| 14 | TX_FULL | TX FIFO is full |
| 13 | RX_EMPTY | RX FIFO is empty |
| 12 | RX_FULL | RX FIFO is full |

## Hardware Setup

### JTAG Cable

**Xilinx Platform Cable USB II:**
- Default VID:PID = `0x03fd:0x0013`
- After fxload: `0x0403:0x6010`

**Loading firmware (if needed):**
```bash
sudo fxload -t fx2 -I /usr/share/usb/xilinx/xc7spipe.hex
```

### Board Pinout (QMTECH XC7A100T)

| Pin | Function |
|-----|----------|
| U22 | 50 MHz Clock |
| P16 | Reset Button |
| H16 | UART RX (not needed for JTAG UART!) |
| J16 | UART TX (not needed for JTAG UART!) |
| T23 | LED D6 |
| R20 | LED D5 |
| ??? | LED D7 (check datasheet) |

**Note:** JTAG signals are **internal** to the FPGA. No external pins needed!

## Troubleshooting

### "OpenOCD not found"

```bash
brew install openocd
```

### "JTAG chain not found"

1. Check cable connection:
```bash
lsusb | grep Xilinx
# or
lsusb | grep 0403:6010
```

2. Test OpenOCD:
```bash
openocd -f interface/ftdi.cfg -c "init; scan_chain"
```

### "Permission denied" on JTAG

```bash
# Add udev rules
sudo nano /etc/udev/rules.d/99-xilinx-ftdi.rules

# Add:
# ATTR{idVendor}=="0403", ATTR{idProduct}=="6010", MODE="0666"

# Reload
sudo udevadm control --reload-rules
```

### Synthesis Errors

1. Check Yosys version:
```bash
yosys --version  # Should be 0.35+
```

2. Clean and rebuild:
```bash
./build_jtaguart.sh --clean
./build_jtaguart.sh
```

## Performance

| Metric | Value |
|--------|-------|
| Baud Rate | 115200 |
| Theoretical Max | ~14 KB/s |
| Practical (with overhead) | ~1-5 KB/s |
| Latency | ~10-50ms |

## Resource Usage (XC7A100T)

| Component | LUTs | FFs | BRAMs |
|-----------|------|-----|-------|
| JTAG TAP | ~500 | ~300 | 0 |
| JTAG UART | ~800 | ~600 | 0 |
| Command Decoder | ~300 | ~200 | 0 |
| **TOTAL** | **~1600** | **~1100** | **0** |

**~2% of device** — 98% remaining!

## Next Steps

- [ ] Test on real hardware (when JTAG cable arrives)
- [ ] Optimize data rate (use DR scan more efficiently)
- [ ] Add CRC-16 verification
- [ ] Implement flow control
- [ ] Add support for longer commands
- [ ] Integrate with full TRINITY V2 (VSA + TQNN)

## References

- [Xilinx JTAG User Guide](https://www.xilinx.com/support/documentation/user_guides/ug470_7Series_Config.pdf)
- [OpenOCD Documentation](http://openocd.org/doc/html/)
- [JTAG TAP Controller](https://en.wikipedia.org/wiki/JTAG)
- [ZipCPU JTAG UART](https://github.com/ZipCPU/jtag_uart)

---

*TRINITY JTAG UART v1.0*
*φ² + 1/φ² = 3*
