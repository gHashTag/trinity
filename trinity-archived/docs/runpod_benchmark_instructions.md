# RunPod GPU Benchmark Instructions for Trinity

## Pod Status

- **Pod ID**: `9luhnpn8r3a1i1`
- **GPU**: NVIDIA A100 80GB PCIe
- **Status**: STOPPED (to save costs)
- **SSH**: `38.140.51.195:19724` (requires SSH key from RunPod account)

## Quick Start

### 1. Resume Pod via API

```bash
curl -s "https://api.runpod.io/graphql" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"query": "mutation { podResume(input: { podId: \"9luhnpn8r3a1i1\" }) { id desiredStatus } }"}'
```

### 2. Access Pod

**Option A: RunPod Web Console**
1. Go to https://www.runpod.io/console/pods
2. Click on "trinity-bench-a100"
3. Click "Connect" -> "Web Terminal"

**Option B: SSH (if you have the private key)**
```bash
ssh root@38.140.51.195 -p 19724
```

### 3. Run Benchmark Script

Once connected to the pod, run:

```bash
# Install dependencies
apt-get update && apt-get install -y wget git

# Clone Trinity repo
cd /workspace
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Run the benchmark
python3 scripts/runpod_benchmark.py
```

## Manual Benchmark Commands

### GPU Info
```bash
nvidia-smi
nvidia-smi --query-gpu=name,memory.total,power.draw,temperature.gpu --format=csv
```

### PyTorch GPU Test
```python
import torch
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"GPU: {torch.cuda.get_device_name(0)}")
print(f"Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")

# Matrix multiplication benchmark
size = 8192
a = torch.randn(size, size, device='cuda')
b = torch.randn(size, size, device='cuda')

import time
torch.cuda.synchronize()
start = time.time()
for _ in range(100):
    c = torch.matmul(a, b)
torch.cuda.synchronize()
elapsed = time.time() - start

tflops = (2 * size**3 * 100) / elapsed / 1e12
print(f"Performance: {tflops:.1f} TFLOPS")
```

### Ternary Inference Simulation
```python
import torch
import time

device = torch.device('cuda')

# Simulate ternary weights (-1, 0, 1)
def ternary_matmul(input_tensor, weights):
    """Ternary matrix multiplication - only additions/subtractions"""
    # Decompose into positive and negative masks
    pos_mask = (weights == 1).float()
    neg_mask = (weights == -1).float()
    
    # Compute using only additions
    pos_sum = torch.matmul(input_tensor, pos_mask.T)
    neg_sum = torch.matmul(input_tensor, neg_mask.T)
    
    return pos_sum - neg_sum

# Benchmark
batch_size = 32
seq_len = 512
hidden_dim = 4096

input_data = torch.randn(batch_size, seq_len, hidden_dim, device=device)
weights = torch.randint(-1, 2, (hidden_dim, hidden_dim), device=device).float()

# Warmup
for _ in range(10):
    _ = ternary_matmul(input_data, weights)
torch.cuda.synchronize()

# Benchmark
start = time.time()
iterations = 100
for _ in range(iterations):
    output = ternary_matmul(input_data, weights)
torch.cuda.synchronize()
elapsed = time.time() - start

tokens_processed = batch_size * seq_len * iterations
tokens_per_second = tokens_processed / elapsed
print(f"Ternary inference: {tokens_per_second:.0f} tokens/s")
print(f"Latency per batch: {elapsed/iterations*1000:.2f} ms")
```

## Expected Results (A100 80GB)

Based on A100 specifications and ternary optimization:

| Metric | Expected Value | Notes |
|--------|---------------|-------|
| FP16 TFLOPS | ~312 | Peak theoretical |
| INT8 TOPS | ~624 | Peak theoretical |
| Ternary ops/s | ~1.2T | Estimated (no multiply) |
| Memory bandwidth | 2 TB/s | HBM2e |
| Power draw | 250-300W | Under load |

### Ternary Advantage

Ternary operations eliminate multiplications:
- Binary: `y = Σ(w_i * x_i)` - requires multiply-accumulate
- Ternary: `y = Σ(x_i where w=1) - Σ(x_i where w=-1)` - only add/subtract

Theoretical speedup: **3-10x** depending on memory bandwidth utilization.

## Cost Tracking

| GPU | Rate | Balance | Est. Runtime |
|-----|------|---------|--------------|
| A100 80GB | ~$1.10/hr | $7.20 | ~6.5 hours |

## Stop Pod When Done

```bash
curl -s "https://api.runpod.io/graphql" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"query": "mutation { podStop(input: { podId: \"9luhnpn8r3a1i1\" }) { id } }"}'
```

## Terminate Pod (delete completely)

```bash
curl -s "https://api.runpod.io/graphql" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"query": "mutation { podTerminate(input: { podId: \"9luhnpn8r3a1i1\" }) }"}'
```
