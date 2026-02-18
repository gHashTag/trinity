# FPGA.Network Agent

**Decentralized BitNet LLM Inference Network on FPGA**

## Quick Start for Providers

```bash
# 1. Installation
curl -sSL https://fpga.network/install.sh | bash

# 2. Register with network
fpga-agent register --wallet <YOUR_SOLANA_WALLET>

# 3. Start
fpga-agent start
```

## Project Structure

```
fpga-network/
├── agent/              # Provider agent
│   ├── main.py         # Entry point
│   ├── config.py       # Configuration
│   ├── fpga.py         # FPGA interface
│   ├── inference.py    # BitNet inference
│   └── network.py      # Network communication
├── server/             # Coordinating server
│   ├── api.py          # REST API
│   ├── matcher.py      # Matching requestor ↔ provider
│   └── settlement.py   # $FPGA settlements
├── client/             # SDK for requestors
│   ├── python/
│   └── javascript/
├── bitstreams/         # Pre-built bitstreams
│   └── README.md
└── scripts/            # Installation scripts
    └── install.sh
```

## Requirements

### For Providers:
- FPGA: Alveo U50/U55C/U280 or Arty A7
- OS: Ubuntu 20.04+ / Debian 11+
- RAM: 8GB+
- Vivado Runtime (for Xilinx)
- Python 3.10+
- Solana wallet with minimum 10,000 $FPGA for staking

### Supported FPGAs:

| Board | Models | Status |
|-------|--------|--------|
| Alveo U55C | BitNet 1B-13B | ✅ Full Support |
| Alveo U50 | BitNet 1B-7B | ✅ Full Support |
| Alveo U280 | BitNet 1B-30B | ✅ Full Support |
| Arty A7-35T | BitNet Demo | ⚠️ Demo Only |

## Documentation

- [Installation](docs/installation.md)
- [Configuration](docs/configuration.md)
- [API Reference](docs/api.md)
- [Troubleshooting](docs/troubleshooting.md)

## License

MIT License
