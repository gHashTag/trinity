# UART Echo Test — Advanced FPGA UART Bridge Test Tool

## Overview

Trinity UART Echo Test is a comprehensive serial communication testing tool with FPGA integration support. It provides multiple testing modes for validating UART adapters, measuring performance, and testing FPGA bitstreams via ESP32 XVC Bridge.

**Version**: v3.35
**Language**: Zig 0.15+
**Dependencies**: POSIX serial port support

## Features

### Core Testing
- Multi-adapter support: FT232RL, CP210x, CH340, PL2303
- Auto-configure: Automatic termios setup via `--auto-configure` flag
- Graceful exit: SIGINT (Ctrl+C) handler for clean shutdown
- Extended baud rates: 9600 to 921600 bps

### Performance Features
- Buffered I/O: Pre-allocated buffers for reduced syscall overhead
- Batch testing: Send N packets without waiting for individual responses
- Adaptive timeout: Dynamically adjust timeout based on measured RTT
- Throughput measurement: Bytes/second calculation
- Latency tracking: Min/avg/max with histogram distribution
- Jitter measurement: RTT variance analysis

### FPGA Integration (v3.26+)
- ESP32 XVC Bridge integration
- Bitstream flashing via ESP32
- FPGA verification mode
- Configurable timeout and retry settings

### Reporting
- CSV export: Structured test results for analysis
- JSON export: Machine-readable output
- Performance reports with efficiency calculations
- Smart recommendations based on test results

## Installation

```bash
# Build from source
zig build uart-echo-test

# The binary will be at: zig-out/bin/uart-echo-test
```

## Quick Start

### Basic Echo Test
```bash
# Auto-detect serial port and run basic echo test
./uart-echo-test

# Specify device and baud rate
./uart-echo-test --device /dev/cu.usbserial-0001 --baud 115200
```

### Performance Testing
```bash
# Batch mode with throughput measurement
./uart-echo-test --throughput --batch-size 32 --json

# Adaptive timeout with jitter measurement
./uart-echo-test --adaptive-timeout --measure-jitter
```

### FPGA Testing
```bash
# Full FPGA test cycle
./uart-echo-test --fpga-mode --esp32-host esp32-xvc.local --bitstream phi_blink_top.bit

# FPGA with verification
./uart-echo-test --fpga-mode --fpga-verify --fpga-timeout 60000 --fpga-retries 5
```

## Command Line Options

### Basic Options
| Option | Description | Default |
|--------|-------------|---------|
| `--baud <rate>` | Baud rate | 115200 |
| `--delay <ms>` | Delay between tests in ms | 200 |
| `--timeout <ms>` | Read timeout in ms | 2000 |
| `--retries <n>` | Retry failed tests N times | 3 |
| `--device <path>` | Serial device (auto-detect if omitted) | auto |
| `-v, --verbose` | Enable verbose logging | false |
| `--help` | Show help message | - |

### Output Options
| Option | Description |
|--------|-------------|
| `--output <file>` | Export results to CSV file |
| `--json` | Export results to JSON format |
| `--continuous` | Run tests in continuous loop (Ctrl+C to stop) |

### Performance Options
| Option | Description | Default |
|--------|-------------|---------|
| `--throughput` | Measure and display throughput statistics | - |
| `--batch-size <n>` | Send N packets per batch | 16 |
| `--buffer-size <n>` | I/O buffer size in bytes | 4096 |
| `--adaptive-timeout` | Dynamically adjust timeout based on RTT | - |
| `--measure-jitter` | Measure RTT jitter variance | - |

### Pattern Options
| Option | Description | Default |
|--------|-------------|---------|
| `--pattern <name>` | Test pattern: default\|prbs7\|walk1\|walk0\|seq\|alt | default |
| `--pattern-length <n>` | Length of generated pattern | 256 |

### Test Modes
| Option | Description |
|--------|-------------|
| `--ping-mode` | PING (0x03) -> PONG (0x83) test mode |
| `--loopback-mode` | Local loopback test (TX->RX on adapter) |
| `--simulation` | Simulation mode (no hardware required) |
| `--dry-run` | Show what would be sent (no actual I/O) |
| `--stress-test` | High-throughput stress test mode |
| `--stress-packets <n>` | Packets per stress test | 10 |
| `--list-devices` | List all available serial devices |
| `--comprehensive` | Unified 3-phase test (Basic, Batch, Performance) |

### FPGA Options (v3.26+)
| Option | Description | Default |
|--------|-------------|---------|
| `--fpga-mode` | Enable FPGA XVC Bridge integration | - |
| `--esp32-host HOST` | ESP32 hostname/IP | esp32-xvc.local |
| `--esp32-port PORT` | XVC Bridge port | 2542 |
| `--bitstream PATH` | Bitstream file to flash via ESP32 | - |
| `--fpga-timeout MS` | FPGA operation timeout in ms | 30000 |
| `--fpga-retries N` | Max retries for FPGA operations | 3 |
| `--fpga-verify` | Enable FPGA verification mode | - |

### Configuration
| Option | Description |
|--------|-------------|
| `--config <file>` | Load config from TOML file |
| `--auto-configure` | Auto-configure port (termios setup) |
| `--auto-baud` | Auto-detect baud rate |
| `--rts-cts` | Enable RTS/CTS hardware flow control |

## Testing Modes

### Default Mode
Sequential echo test with byte-by-byte verification.

```bash
./uart-echo-test --device /dev/cu.usbserial-0001
```

### Batch Mode (v3.30)
Send N packets without waiting for individual responses, measure aggregated throughput.

```bash
./uart-echo-test --throughput --batch-size 32 --json
```

**Features:**
- Reduced syscall overhead via buffered I/O
- Packets/second throughput measurement
- Success rate calculation

### Adaptive Mode (v3.30)
Auto-tune timeout based on measured latency using formula: `timeout = base + (3 * std_dev)`.

```bash
./uart-echo-test --adaptive-timeout --measure-jitter
```

**Features:**
- Dynamic timeout adjustment
- RTT variance calculation
- Improved reliability with variable latency

### Performance Mode (v3.31)
Generate performance reports with efficiency calculations and recommendations.

```bash
./uart-echo-test --throughput --json --output results.csv
```

**Report includes:**
- Theoretical vs actual throughput
- Efficiency percentage
- Smart recommendations based on metrics

### Simulation Mode (v3.32)
Virtual UART testing without hardware. Ideal for development and CI/CD.

```bash
./uart-echo-test --simulation --batch-size 32 --json
```

**Features:**
- Simulated RTT (10-60ms)
- Simulated packet loss (5% fail, 2% timeout)
- Progress indicator (0-100%)

### Comprehensive Mode (v3.33)
Unified 3-phase test: Basic Echo, Batch Throughput, Performance Report.

```bash
./uart-echo-test --comprehensive --device /dev/cu.usbserial-0001
```

**Phases:**
1. **Phase 1**: Basic Echo Test — verifies serial communication
2. **Phase 2**: Batch Throughput Test — measures packets/sec throughput
3. **Phase 3**: Performance Report — calculates efficiency & recommendations

### Stress Mode (v3.24)
High-throughput continuous testing without wait periods.

```bash
./uart-echo-test --stress-test --stress-packets 1000 --throughput
```

**Features:**
- Maximum throughput testing
- Continuous packet streaming
- No inter-packet delays

### FPGA Mode (v3.26)
ESP32 XVC Bridge + FPGA + UART test cycle.

```bash
./uart-echo-test --fpga-mode --esp32-host esp32-xvc.local --bitstream phi_blink_top.bit
```

**Workflow:**
1. Connect to ESP32 XVC Bridge via TCP
2. Flash FPGA bitstream through ESP32
3. Test UART communication with FPGA
4. Verify FPGA responses (if `--fpga-verify` enabled)

## Configuration File

Supports TOML-like key=value format (one per line):

```toml
# uart-config.toml
baud=115200
timeout=2000
batch_size=32
adaptive_timeout=true
comprehensive_mode=true
auto_baud=true
rts_cts_flow=true
fpga_mode=true
esp32_host=esp32-xvc.local
fpga_timeout_ms=30000
fpga_retries=3
bitstream_path=phi_blink_top.bit
stress_test_mode=true
stress_packets=100
```

Usage:
```bash
./uart-echo-test --config uart-config.toml
```

## Test Patterns

### Available Patterns
| Pattern | Description |
|---------|-------------|
| `default` | Standard test pattern |
| `prbs7` | Pseudo-Random Binary Sequence (7-bit) |
| `walk1` | Walking 1s pattern |
| `walk0` | Walking 0s pattern |
| `seq` | Sequential increment |
| `alt` | Alternating pattern |

### Usage
```bash
./uart-echo-test --pattern prbs7 --pattern-length 512
```

## Output Formats

### Console Output
Colored ANSI output with real-time progress:

```
[+] Connected to /dev/cu.usbserial-0001 at 115200 baud
[✓] Echo test passed: 256/256 bytes matched
[i] Throughput: 12.5 KB/s
[i] Latency: avg=15.2ms min=12ms max=23ms
```

### JSON Output
Machine-readable JSON for automation:

```bash
./uart-echo-test --json
```

```json
{
  "success": true,
  "bytes_sent": 256,
  "bytes_matched": 256,
  "throughput_bps": 12500.0,
  "latency_ms": {
    "min": 12,
    "max": 23,
    "avg": 15.2
  }
}
```

### CSV Output
Structured data for analysis:

```bash
./uart-echo-test --output results.csv --throughput
```

```csv
timestamp,device,baud,bytes_sent,bytes_received,throughput_bps,success_rate
2026-03-24T10:30:00Z,/dev/cu.usbserial-0001,115200,256,256,12500.0,100.0
```

## Supported Adapters

| Adapter | Vendor ID | Product ID | Status |
|---------|------------|-------------|--------|
| FT232RL | 0x0403 | 0x6001 | ✅ Supported |
| CP210x | 0x10C4 | Various | ✅ Supported |
| CH340 | 0x1A86 | 0x7523 | ✅ Supported |
| PL2303 | 0x067B | 0x2303 | ✅ Supported |
| Other | - | - | ⚠️ Basic support |

## FPGA Integration

### ESP32 XVC Bridge Setup

The ESP32 acts as a JTAG bridge between the host and the FPGA:
- Host → ESP32 (TCP on port 2542)
- ESP32 → FPGA (JTAG via GPIO)

### Workflow

1. **Connect** to ESP32 via TCP
2. **Flash** bitstream to FPGA through ESP32
3. **Test** UART communication with FPGA
4. **Verify** FPGA responses (optional)

### Example

```bash
# Basic FPGA test
./uart-echo-test \
  --fpga-mode \
  --esp32-host esp32-xvc.local \
  --bitstream fpga/openxc7-synth/hslm_full_top.bit

# With verification and custom timeout
./uart-echo-test \
  --fpga-mode \
  --fpga-verify \
  --fpga-timeout 60000 \
  --fpga-retries 5 \
  --esp32-host 192.168.4.1 \
  --bitstream test.bit
```

## Performance Recommendations

The tool provides smart recommendations based on test results:

- **Success rate < 95%**: Check cable/connection
- **Efficiency < 50%**: May need flow control (RTS/CTS)
- **Efficiency > 95%**: Connection optimal
- **High throughput + good efficiency**: Consider larger packets
- **Baud rate < 115200**: Higher baud rate recommended

## Troubleshooting

### Device not found
```bash
# List available devices
./uart-echo-test --list-devices
```

### Permission denied
```bash
# Add user to dialout group (Linux)
sudo usermod -a -G dialout $USER

# Use sudo (macOS - not recommended)
sudo ./uart-echo-test
```

### Auto-configure fails
```bash
# Manual configuration
stty -f /dev/cu.usbserial-* 115200 cs8 -parenb -cstopb 1 -hupcl
./uart-echo-test --device /dev/cu.usbserial-0001
```

### FPGA operations timing out
```bash
# Increase timeout and retries
./uart-echo-test --fpga-mode --fpga-timeout 60000 --fpga-retries 5
```

## Development

### Build
```bash
zig build uart-echo-test
```

### Test
```bash
# Run simulation mode (no hardware required)
./uart-echo-test --simulation

# Run full test suite
zig build test
```

### Code Structure
- `src/tools/uart_echo_test.zig` — Main implementation (2800+ LOC)
- `BufferedIO` — Buffered I/O with configurable buffers
- `BatchTestResults` — Batch test statistics
- `AdaptiveTimeout` — Dynamic timeout calculation
- `PerformanceReport` — Throughput analysis
- `LatencyHistogram` — Latency distribution
- `JitterTracker` — RTT variance measurement
- `FPGA XVC Bridge` — TCP communication with ESP32

## Version History

| Version | Date | Features |
|---------|------|----------|
| v3.35 | 2026-03-24 | RTT Histogram Integration (fully implemented) |
| v3.34 | 2026-03-24 | Full documentation update |
| v3.33 | 2026-03-24 | Unified Interface + Comprehensive Test Mode |
| v3.32 | 2026-03-24 | Simulation Batch Mode |
| v3.31 | 2026-03-24 | Performance Report + Recommendations |
| v3.30 | 2026-03-24 | Buffered I/O, Batch Testing, Adaptive Timeout |
| v3.28 | 2026-03-24 | FPGA XVC Bridge + UART integration |
| v3.26 | 2026-03-23 | ESP32 XVC Bridge integration |
| v3.24 | 2026-03-23 | Graceful exit, extended baud rates, jitter measurement |
| v3.15 | 2026-03-22 | Config file support |
| v3.14 | 2026-03-21 | Throughput measurement, batch mode |

## License

MIT License — Trinity Project

---

**φ² + 1/φ² = 3 | TRINITY**
