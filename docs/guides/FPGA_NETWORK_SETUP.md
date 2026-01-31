# FPGA Network Agent Setup

## Provider Setup

### Requirements
- FPGA: Arty A7 / Alveo U50/U55C
- Ubuntu 20.04+
- Python 3.10+
- Xilinx Runtime

### Install

```bash
cd fpga-network
pip install -r requirements.txt
```

### Configure

```yaml
# config.yaml
provider:
  name: "my-fpga-node"
  wallet: "YOUR_SOLANA_WALLET"
  
fpga:
  type: "alveo_u55c"
  device: "/dev/xclmgmt0"
  
models:
  - name: "bitnet-3b"
    bitstream: "bitstreams/bitnet_3b.bit"
```

### Start

```bash
python -m agent.cli register --config config.yaml
python -m agent.cli start --config config.yaml
```

## Requestor Integration

### Python SDK

```python
from fpga_network import FPGANetwork

client = FPGANetwork(api_key="YOUR_KEY")
response = client.inference(
    model="bitnet-3b",
    prompt="Explain quantum computing"
)
print(response.text)
print(f"Cost: {response.cost} $FPGA")
```

### REST API

```bash
curl -X POST https://api.fpga.network/v1/inference \
  -H "Authorization: Bearer YOUR_KEY" \
  -d '{"model": "bitnet-3b", "prompt": "Hello"}'
```

## Scaling

### Multiple FPGAs

```yaml
cluster:
  nodes:
    - {fpga: "alveo_u55c", device: "/dev/xclmgmt0"}
    - {fpga: "alveo_u55c", device: "/dev/xclmgmt1"}
```

### Economics

```
Earnings = Requests * Tokens * Rate
Example: 10,000 req/day * 100 tok * 0.0001 $FPGA = 100 $FPGA/day
```

## Monitoring

```bash
python -m agent.cli status
# Status: ONLINE
# Earnings (24h): 45.2 $FPGA
# Requests: 1,247
```
