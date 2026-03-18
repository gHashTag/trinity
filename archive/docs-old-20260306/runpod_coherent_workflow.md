# RunPod BitNet Coherent Generation Workflow

**Date:** February 5, 2026
**Purpose:** Run BitNet b1.58-2B-4T coherent text generation on x86_64 (RunPod)
**Why:** ARM NEON kernel bug (upstream #198) prevents coherent output on Apple M1 Pro

---

## Prerequisites

- RunPod account with ~$2 balance (RTX 4090 at $0.34/hr, ~1hr needed)
- SSH key configured in RunPod settings

## Step 1: Launch Pod

1. Go to https://runpod.io/console/pods
2. Click **Deploy** → Select **RTX 4090** (24GB VRAM, $0.34/hr)
3. Template: `runpod/pytorch:2.1.0-py3.10-cuda12.1.0-devel-ubuntu22.04`
4. Disk: 50GB (model is 1.1GB + build artifacts)
5. Launch and wait for "Running" status

## Step 2: Connect via SSH

```bash
ssh root@<IP> -p <PORT> -i ~/.ssh/runpod_key
```

## Step 3: Run the Test Script

**Option A: Automated (recommended)**
```bash
cd /workspace
git clone https://github.com/gHashTag/trinity.git
cd trinity
bash scripts/runpod_bitnet_coherent.sh
```

**Option B: Manual**
```bash
# Clone BitNet
cd /workspace
git clone --recursive https://github.com/microsoft/BitNet.git
cd BitNet
pip install -r requirements.txt

# Build with official pipeline (handles x86_64 AVX2 kernels)
python setup_env.py -hr microsoft/BitNet-b1.58-2B-4T -q i2_s

# Find model
MODEL=$(find models -name "*.gguf" | head -1)

# Generate (10 prompts, 500 tokens each)
build/bin/llama-cli -m "$MODEL" \
    -p "The capital of France is" \
    -n 500 -b 1 -t 4 --temp 0.0 \
    --override-kv "tokenizer.ggml.pre=str:llama-bpe"
```

## Step 4: Copy Results

```bash
# From local machine
scp -P <PORT> root@<IP>:/workspace/bitnet_coherent_results.txt docs/
scp -P <PORT> root@<IP>:/workspace/bitnet_coherent_metrics.json docs/
```

## Step 5: Stop Pod

**Immediately after copying results** — stop the pod to save costs.

## Cost Estimate

| GPU | $/hr | Est. Time | Total |
|-----|------|-----------|-------|
| RTX 4090 | $0.34 | ~1hr | ~$0.34 |
| A100 80GB | $1.19 | ~1hr | ~$1.19 |

## What to Expect

On x86_64 with AVX2, BitNet b1.58-2B-4T should produce:
- Coherent English text (not word salad)
- ~2-10 tokens/sec on CPU, faster with GPU offloading
- Proper token boundaries (with tokenizer fix applied)

If output is still garbage on x86_64, the issue is in the model weights or forward pass, not just the ARM kernel.

---

**KOSCHEI IS IMMORTAL | x86_64 FOR COHERENT | φ² + 1/φ² = 3**
