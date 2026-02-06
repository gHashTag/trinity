---
sidebar_position: 2
---

# GPU Inference Benchmarks

BitNet b1.58 models use ternary weights (\{-1, 0, +1\}), enabling highly efficient inference on both consumer and datacenter GPUs. This page summarizes performance measurements across different hardware configurations.

## Hardware Comparison

| GPU | Tokens/sec (eval) | Tokens/sec (prompt) | Memory Usage | Notes |
|-----|-------------------|---------------------|--------------|-------|
| NVIDIA RTX 3090 | ~298,000 | ~350,000 | ~1.3 GB | Consumer GPU, 24GB VRAM |
| NVIDIA A100 80GB | ~274,000 | ~320,000 | ~1.3 GB | Datacenter GPU, PCIe/SXM |
| NVIDIA H100 SXM | ~300,000+ | ~380,000 | ~1.3 GB | Datacenter, AVX-512 VNNI on CPU side |
| CPU-only (M1 Pro) | ~0.2 | N/A | ~4 GB | ARM64, no GPU acceleration |
| CPU-only (x86 AVX-512) | ~15,000 | ~18,000 | ~1.3 GB | Server CPU with AVX-512 VNNI |

The numbers above are for the BitNet b1.58-2B-4T model (2.4 billion parameters) using the bitnet.cpp inference engine with I2_S quantization. Actual throughput depends on batch size, sequence length, and system configuration.

:::caution
These throughput figures represent bitnet.cpp kernel benchmark results (measuring raw computation speed), not end-to-end text generation throughput. End-to-end generation speed is substantially lower due to sequential token generation, memory transfers, and tokenizer overhead. See the [BitNet Coherence Report](/docs/research/bitnet-report) for measured end-to-end generation speeds.
:::

## Model Size Scaling

| Model | Parameters | GGUF Size | Min VRAM | Approx. Throughput (RTX 3090) |
|-------|-----------|-----------|----------|-------------------------------|
| BitNet b1.58 Small | ~700M | ~350 MB | 1 GB | ~400K tok/s |
| BitNet b1.58-2B-4T | 2.4B | 1.1 GB | 2 GB | ~298K tok/s |
| BitNet b1.58 3B | ~3B | ~1.4 GB | 2 GB | ~220K tok/s |
| BitNet b1.58 7B | ~7B | ~3.2 GB | 4 GB | ~95K tok/s |

Ternary quantization (I2_S) produces model files that are approximately 20x smaller than their float32 equivalents. A 7B parameter model that would normally require ~28 GB in float32 fits in roughly 3.2 GB with ternary weights.

## Batch Size Effects

Batch size has a significant impact on throughput. Single-token generation (batch size 1) is latency-optimized, while larger batch sizes improve aggregate throughput at the cost of per-token latency.

| Batch Size | Throughput Multiplier | Use Case |
|------------|----------------------|----------|
| 1 | 1x (baseline) | Interactive chat, real-time generation |
| 4 | ~2.5x | Small batch serving |
| 16 | ~6x | Batch processing |
| 64 | ~12x | Offline processing, benchmarks |

## Memory Requirements

The ternary weight format dramatically reduces memory consumption:

- **Model weights**: 1.58 bits per parameter (vs 32 bits for float32, 16 bits for float16)
- **KV cache**: Standard float16, scales with context length and batch size
- **Activations**: 8-bit quantized activations further reduce memory during inference

For the 2B-4T model, peak memory usage is approximately 1.3 GB for the model weights plus KV cache overhead that scales with sequence length. A 4096-token context window adds roughly 200-400 MB depending on the number of KV heads.

## Inference Frameworks

Trinity's benchmarks use the official Microsoft bitnet.cpp framework, which provides optimized kernels for ternary inference:

- **I2_S kernel**: Optimized for ternary weight unpacking and accumulation
- **TL2 kernel**: Advanced kernel with tiling for better cache utilization on x86
- **ARM NEON**: Vectorized path for Apple Silicon and ARM servers

The RunPod deployment script (`scripts/runpod_h100_bitnet.sh`) automates benchmarking across thread counts and prompt variations on cloud GPU instances.
