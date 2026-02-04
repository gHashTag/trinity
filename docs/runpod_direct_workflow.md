# RunPod Direct Workflow - All Large Tests on RunPod Only

**Date:** February 4, 2026
**Version:** 1.0.0
**Rule:** ALL heavy tests (model downloads, E2E inference, benchmarks) run ONLY on RunPod

---

## Why This Workflow?

| Environment | RAM | Problem |
|-------------|-----|---------|
| Gitpod | 4-8 GB | OOM on 2B+ models, slow network |
| Local Mac | 8-16 GB | OOM on 7B+, fan noise, battery drain |
| **RunPod** | **24-80 GB VRAM** | **No OOM, fast download, real GPU** |

**Problem:** Downloading large models locally causes OOM, wasted time, repeated failures.

**Solution:** Launch pod first, download and test everything INSIDE the pod, stop when done.

---

## Workflow: Pod Launch -> Download Inside -> Test -> Stop

### Step 1: Launch Pod

1. Go to https://runpod.io/console/pods
2. Click "Deploy" -> Select GPU:
   - **RTX 4090** (24GB, $0.34/hr) - Best for BitNet 2B
   - **A100** (80GB, $1.19/hr) - For 7B+ models
3. Template: `runpod/pytorch:2.1.0-py3.10-cuda12.1.0-devel-ubuntu22.04`
4. Disk: 50GB minimum

### Step 2: Connect to Pod

**Option A: SSH (recommended)**
```bash
ssh root@<IP> -p <PORT> -i ~/.ssh/runpod_key
```

**Option B: Web Terminal**
- Click "Connect" -> "Web Terminal" in RunPod dashboard

### Step 3: Setup Inside Pod

```bash
# 1. Clone repository
cd /workspace
git clone https://github.com/gHashTag/trinity.git
cd trinity

# 2. Install Zig compiler
wget https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz
tar xf zig-linux-x86_64-0.13.0.tar.xz
export PATH=$PWD/zig-linux-x86_64-0.13.0:$PATH

# 3. Download BitNet model (inside pod - fast!)
pip install huggingface_hub
huggingface-cli download microsoft/bitnet-b1.58-2B-4T-gguf \
  --local-dir ./models/bitnet-2b

# 4. Build Trinity
zig build -Doptimize=ReleaseFast
```

### Step 4: Run Tests

```bash
# E2E inference test
zig test src/vibeec/bitnet_coherent_test.zig

# Full benchmark suite
python3 scripts/runpod_benchmark.py

# Or manual inference
./zig-out/bin/firebird --model ./models/bitnet-2b/ggml-model-i2_s.gguf \
  --prompt "Write a Python function to calculate fibonacci:" \
  --max-tokens 100
```

### Step 5: Save Results

```bash
# Copy benchmark output to docs
cp /tmp/benchmark_results.json docs/runpod_direct_report.md
```

### Step 6: Stop Pod

**CRITICAL:** Stop pod immediately after tests!

```bash
# Via API
curl -s "https://api.runpod.io/graphql" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $RUNPOD_TOKEN" \
  -d '{"query": "mutation { podStop(input: { podId: \"POD_ID\" }) { id } }"}'
```

Or click "Stop" in RunPod dashboard.

---

## Cost Control

| GPU | $/hour | Max Session | Use Case |
|-----|--------|-------------|----------|
| RTX 4090 | $0.34 | 2 hours | BitNet 2B, benchmarks |
| L40S | $0.59 | 1 hour | 7B models |
| A100 80GB | $1.19 | 30 min | 70B models |

**Budget Rules:**
- Check balance before launch (need $1+ safety margin)
- Set timer for max session
- Stop pod IMMEDIATELY after tests
- Never leave pods running overnight

---

## Quick Reference Commands

### GPU Info
```bash
nvidia-smi
nvidia-smi --query-gpu=name,memory.total,power.draw,temperature.gpu --format=csv
```

### Model Download (inside pod)
```bash
# BitNet 2B (1.2GB)
huggingface-cli download microsoft/bitnet-b1.58-2B-4T-gguf

# Llama 3 7B ternary (if available)
huggingface-cli download <model-id> --local-dir ./models/llama-7b-ternary
```

### Inference Test
```bash
# PyTorch quick test
python3 -c "import torch; print(torch.cuda.get_device_name(0))"

# Trinity benchmark
python3 scripts/runpod_benchmark.py
```

---

## DO NOT

- Download large models to Gitpod/local
- Try to run 7B+ models locally
- Leave pods running after tests
- Run tests without checking balance

## DO

- Launch pod FIRST, then download inside
- Verify GPU works before model download
- Save all logs/metrics before stopping
- Stop pod immediately when done

---

## Checklist

- [ ] Check RunPod balance ($1+ safety)
- [ ] Launch pod (RTX 4090 for 2B, A100 for 7B+)
- [ ] Clone repo inside pod
- [ ] Install Zig compiler
- [ ] Download model inside pod
- [ ] Build and run tests
- [ ] Save results to docs/
- [ ] Stop pod
- [ ] Git commit and push

---

## Expected Results

### BitNet 2B on RTX 4090
| Metric | Expected |
|--------|----------|
| Model load | 30/30 layers |
| Tokens/sec | 10-50 tok/s |
| Memory | ~8GB VRAM |
| Power | 300-400W |

### Benchmarks
| Test | RTX 4090 Expected |
|------|-------------------|
| FP16 TFLOPS | ~82 |
| Ternary tokens/s | ~300K+ |
| Mining hashrate | ~500 MH/s |

---

**KOSCHEI IS IMMORTAL | NO LOCAL OOM | ALL TESTS ON RUNPOD | φ² + 1/φ² = 3**
