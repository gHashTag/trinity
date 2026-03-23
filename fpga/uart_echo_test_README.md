# UART Echo Test README

## Overview

Simple Zig tool for testing UART echo on FT232RL to FPGA bridge.

## Prerequisites

- Zig 0.15+
- FT232RL USB-serial cable connected to FPGA
- FPGA programmed with `uart_bridge_fixed.bit`
- Serial port configured (via stty or auto-configured by tool)

## Building

```bash
zig build src/tools/uart_echo_test.zig
```

Binary location: `./zig-out/bin/uart-echo-test`

## Usage

```bash
# Basic usage
./zig-out/bin/uart-echo-test

# With parameters
./zig-out/bin/uart-echo-test --baud 115200 --delay 100 --timeout 3000 -v
```

### Options

| Option | Description | Default |
|---------|-------------|----------|
| `--baud <rate>` | UART baud rate | 115200 |
| `--delay <ms>` | Delay between tests | 200 |
| `--timeout <ms>` | Read timeout | 2000 |
| `-v` / `--verbose` | Verbose logging | false |
| `--help` | Show help message | |

### Example

```bash
# Test with default settings
./zig-out/bin/uart-echo-test

# Test with custom settings and verbose output
./zig-out/bin/uart-echo-test --baud 115200 --delay 100 --timeout 3000 -v
```

## How It Works

1. **Scanning**: Searches `/dev/cu.usbserial-*` for FT232RL device
2. **Configuration**: Sets up serial port with specified baud rate
3. **Testing**: Runs 6 predefined test patterns:
   - Single byte `'A'` (0x41)
   - Alternating `0x55` and `0xAA`
   - String `"Hello"`
   - Zero byte `0x00`
   - All ones `0xFF`
4. **Verification**: Expects exact echo of sent data
5. **Results**: Shows pass/fail summary

## Test Patterns

| Name | Data | Description |
|------|-------|-------------|
| 'A' | 0x41 | Single uppercase letter |
| 0x55 | 0x55 | Alternating bits |
| 0xAA | 0xAA | Alternating bits |
| "Hello" | 0x48... | ASCII string |
| 0x00 | 0x00 | Zero byte |
| 0xFF | 0xFF | All ones |

## Expected Behavior

- **Echo test**: Each byte sent should be received identically
- **Timing**: Each test waits for echo (timeout configurable)
- **LED**: FPGA LED should blink during UART activity
- **Error handling**: Shows detailed mismatch information

## Troubleshooting

### Device Not Found

If FT232RL not found, the tool will list available serial ports:

```bash
[!] FT232RL not found!

Available serial ports:
  /dev/cu.usbserial-0001
  /dev/cu.usbserial-0002
```

### Configuration Required

Before running, configure the serial port:

```bash
stty -f /dev/cu.usbserial-* 115200 cs8 -parenb -cstopb 1 -hupcl
```

**Note**: The tool may also work without pre-configuration on some systems.

### Timeout Issues

- If using custom delays, increase `--timeout` accordingly
- Default 2000ms is sufficient for 115200 baud + typical response time

### Verbose Mode

Add `-v` flag for detailed operation logging:

```
[*] Config:
    baud: 115200
    delay: 100ms
    timeout: 3000ms
    verbose: true

[+] Opened: /dev/cu.usbserial-0001
[+] Configured: 115200 baud
[->] Test 1/6 Sending data: 4848656C (5 bytes)
[->] Sent (5 bytes)
[*] Waiting for echo (timeout: 3000ms)...
[<-] Received 4848656C (5 bytes)
[*] Read 5 bytes
[✓] ECHO SUCCESS!
```

## FPGA Programming

1. Connect FT232RL JTAG cable to FPGA
2. Program with:
   ```bash
   sudo ./tools/jtag_program uart_bridge_fixed.bit
   ```
3. Wait for LED to blink on power-up

## Related Files

- `src/tools/uart_echo_test.zig` — Test tool source
- `fpga/openxc7-synth/uart_bridge_fixed.v` — Verilog UART bridge
- `fpga/openxc7-synth/uart_bridge_fixed.bit` — Compiled bitstream
- `fpga/openxc7-synth/uart_bridge_fixed.xdc` — Pin constraints

## License

MIT

## Version History

- v2.0 — Initial PING/PONG protocol
- v2.1 — Added parameters, verbose logging, improved error handling
