# RunPod Direct Workflow Report - RTX 4090

**Date:** February 4, 2026
**GPU:** NVIDIA RTX 4090 (24GB VRAM)
**Cost:** $0.59/hr
**Duration:** ~15 minutes
**Total Cost:** ~$0.15

---

## Executive Summary

Successfully ran all benchmarks on RunPod RTX 4090 using the new "All Tests on RunPod Only" workflow. No local downloads, no OOM issues. GPU benchmarks excellent, BitNet model inference produces incoherent output (known issue).

---

## Benchmark Results

### GPU Performance

| Metric | RTX 4090 | Notes |
|--------|----------|-------|
| **Matrix Mult** | 50.78 TFLOPS | FP32 4096x4096 |
| **Ternary Tokens** | 603,847 /s | 2x RTX 3090 |
| **Mining Hash** | 92.74 MH/s | TriHash simulation |
| **Latency** | 27.13 ms | Per batch (32x512) |
| **Memory Used** | 0.77 GB | During benchmark |
| **Memory Total** | 25.4 GB | Available |
| **Power Draw** | 181 W | Under load |
| **Temperature** | 30°C | Peak |

### Noise Robustness Test

| Noise Level | Accuracy Retention |
|-------------|-------------------|
| 0% | 100.0% |
| 5% | 95.0% |
| 10% | 90.0% |
| 15% | 84.9% |
| 20% | 79.8% |
| 25% | 75.0% |
| 30% | 69.9% |

### Comparison vs Previous

| GPU | Tokens/s | TFLOPS | Cost/hr |
|-----|----------|--------|---------|
| CPU baseline | ~1K | N/A | $0 |
| RTX 3090 | 298K | ~35 | ~$0.30 |
| **RTX 4090** | **604K** | **51** | **$0.59** |
| A100 80GB | TBD | ~80 | $1.19 |

---

## BitNet Model Inference

### Model Details
- **Model:** 1bitLLM/bitnet_b1_58-large
- **Parameters:** 728,707,584
- **Format:** HuggingFace transformers (FP16)

### Inference Speed
- **Generation:** 43-64 tokens/s
- **Latency:** ~0.78s per 50 tokens

### Output Quality: INCOHERENT

Example outputs:
```
Prompt: "Write a Python function to calculate fibonacci:"
Output: "Write a Python function to calculate fibonacci: O super, c fatal fan, brut fem p..."

Prompt: "What is the capital of France?"
Output: "What is the capital of France? ch z As s brut. R institution. commit v super brut..."

Prompt: "1 + 1 ="
Output: "1 + 1 = brut. brut. brut. brut. brut"
```

### Analysis

This confirms the issue documented in `docs/bitnet_full_e2e_report.md`:
- Model loads successfully
- Inference runs without errors
- **Output is garbage** (not coherent text)

**Root Cause:** Likely forward pass bug in the model implementation or weight loading.

---

## Workflow Validation

### What Worked
1. **Pod launch via API** - Fast (~20s)
2. **SSH access** - Works after adding key to RunPod settings
3. **Model download inside pod** - Fast (1.2GB in ~3s)
4. **Zig build** - Compiles successfully
5. **PyTorch CUDA** - Works on RTX 4090
6. **Benchmarks** - All metrics collected

### Issues Encountered
1. **Image not found** - `runpod/pytorch:2.1.0-py3.10-cuda12.1.0-devel-ubuntu22.04` doesn't exist
   - Fix: Use `runpod/base:0.6.2-cuda12.2.0`
2. **CUDA toolkit missing** - Can't build llama.cpp with CUDA
   - Workaround: Used transformers instead
3. **GPU availability** - 4090 hosts sometimes full
   - Fallback: A100 or L40S

---

## Pod Details

```
Pod ID: z8ksxw50wedbfl
Name: trinity-4090-v2
GPU: NVIDIA GeForce RTX 4090
Memory: 24564 MiB
vCPUs: 16
RAM: ~125 GB
Image: runpod/base:0.6.2-cuda12.2.0
SSH: root@103.196.86.109 -p 15532
```

---

## Cost Analysis

| Item | Time | Cost |
|------|------|------|
| Pod startup | ~20s | $0.00 |
| Model download | ~3s | $0.01 |
| Benchmarks | ~5 min | $0.05 |
| Inference tests | ~10 min | $0.10 |
| **Total** | ~15 min | **~$0.15** |

---

## Recommendations

### For Future Tests
1. Use `runpod/base:0.6.2-cuda12.2.0` image
2. Add SSH key to RunPod account settings first
3. Stop pod immediately after tests

### For BitNet Coherence
1. Debug forward pass in transformer implementation
2. Compare intermediate values with reference
3. Try llama.cpp with pre-built CUDA binaries
4. Consider using Microsoft's official BitNet.cpp

---

## JSON Results

```json
{
  "matmul_tflops": 50.78,
  "ternary_tokens_per_sec": 603847,
  "latency_ms": 27.13,
  "hashrate_mh_s": 92.74,
  "memory_used_gb": 0.77,
  "memory_total_gb": 25.4,
  "noise_robustness": [
    [0.0, 100.0],
    [5.0, 95.0],
    [10.0, 90.0],
    [15.0, 84.9],
    [20.0, 79.8],
    [25.0, 75.0],
    [30.0, 69.9]
  ]
}
```

---

## Success Criteria

- [x] No local model downloads (all on pod)
- [x] Pod launched and connected
- [x] BitNet model loaded
- [ ] Coherent text generated (FAILED - known issue)
- [x] Benchmarks completed (tokens/s, hashrate, power)
- [x] Report saved with real logs
- [ ] Pod stopped (pending)
- [ ] Changes pushed to main (pending)

---

**KOSCHEI IS IMMORTAL | BENCHMARKS COMPLETE | COHERENCE DEBUGGING NEEDED | φ² + 1/φ² = 3**
