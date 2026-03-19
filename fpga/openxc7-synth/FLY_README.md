# Fly.io FPGA Synthesis — Cloud Pipeline

FPGA synthesis in the cloud without loading local machine.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│  Local Mac     │────▶│  fly.io (cloud)│────▶│   FPGA      │
│                 │◀────│                  │     │  (JTAG)     │
│  - JTAG only    │     │  - Yosys         │     │             │
│  - UART client  │     │  - nextpnr       │     │             │
│  - Lightweight  │     │  - fasm2frames   │     │             │
└─────────────────┘     └──────────────────┘     └─────────────┘
```

## Quick Start

### 1. Deploy to fly.io (one time)

```bash
cd fpga/openxc7-synth
fly launch --no-deploy
fly deploy
```

### 2. Synthesis in the Cloud

```bash
# Simple way
fpga/tools/cloud-synth.sh uart_top.v uart_top

# You get uart_top.bit ready for flashing
```

### 3. Flash FPGA

```bash
# First firmware for JTAG (if needed)
sudo fpga/tools/fxload -v -t fx2 -d 03fd:0013 -i fpga/tools/xusb_xp2.hex
# Reconnect cable

# Flash
sudo fpga/tools/jtag_program uart_top.bit
```

## Files

| File | Description |
|------|-------------|
| `fly.toml` | fly.io configuration (4 CPU, 8GB RAM) |
| `Dockerfile.fly` | Docker image with Python API |
| `synth_cloud.py` | HTTP API for synthesis |
| `../tools/cloud-synth.sh` | Client for local machine |
| `../tools/uart-bitstream.py` | UART delivery (optional) |

## API

### POST /synthesize

```json
{
    "verilog": "module top...",
    "top": "uart_top",
    "xdc": "set_property..." // optional
}
```

Response:
```json
{
    "bitstream": "<base64>",
    "status": "success",
    "size_bytes": 3774864
}
```

### GET /

Health check — returns service status.

## Cost

- **CPU**: 4 vCPU
- **RAM**: 8 GB
- **Disk**: 40 GB
- **Setup**: auto_stop_machines = true (don't pay when not using)

Estimated price: ~$0.50/hour of active usage.

## Troubleshooting

### "Cannot get app URL"
```bash
fly status -a trinity-fpga-synth
```

### "Synthesis timeout"
Increase timeout in `synth_cloud.py` (default: 300 sec)

### "chipdb not found"
Copy `chipdb/xc7a100tfgg676.bin` to directory before deploy.
