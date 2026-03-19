---
sidebar_position: 2
---

# RunPod GPU Deployment

RunPod provides on-demand GPU instances suitable for high-throughput BitNet b1.58 inference. This guide walks through deploying Trinity on a RunPod instance for benchmarking and production inference.

## Recommended GPU Types

| GPU | VRAM | Cost Tier | Expected Throughput (2B model) | Best For |
|-----|------|-----------|-------------------------------|----------|
| NVIDIA H100 SXM | 80 GB | High | ~300K+ tok/s | Maximum performance, AVX-512 VNNI on CPU |
| NVIDIA A100 80GB | 80 GB | Medium | ~274K tok/s | Production workloads |
| NVIDIA RTX 3090 | 24 GB | Low | ~298K tok/s | Cost-effective benchmarking |
| NVIDIA RTX 4090 | 24 GB | Medium | ~310K tok/s | Consumer-grade best performance |

For the BitNet b1.58-2B-4T model (1.1 GB GGUF), even a 24 GB GPU has more than sufficient VRAM. The CPU capabilities of the host (particularly AVX-512 VNNI support) also significantly affect throughput, as bitnet.cpp uses CPU kernels for ternary weight unpacking.

## Setup Steps

### 1. Create a RunPod Instance

1. Sign up at [runpod.io](https://runpod.io)
2. Create a new GPU pod with your chosen GPU type
3. Select a PyTorch or Ubuntu template (provides CUDA and Python)
4. Ensure at least 20 GB of disk space for the model and build tools

### 2. Connect and Run the Benchmark Script

Trinity includes a pre-built benchmark script for H100 instances:

```bash
# SSH into your RunPod instance, then:
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Run the automated benchmark script
bash scripts/runpod_h100_bitnet.sh
```

The script (`scripts/runpod_h100_bitnet.sh`) automates the entire process:

- Verifies hardware (CPU features, GPU type, AVX-512 support)
- Installs dependencies (clang, cmake, Python packages)
- Clones and builds Microsoft's bitnet.cpp with optimized kernels
- Downloads the BitNet b1.58-2B-4T GGUF model from HuggingFace
- Runs thread scaling tests (1, 2, 4, 8, 16, max threads)
- Executes 12 diverse prompts with 500-token generation each
- Produces a results report and JSON metrics file

### 3. Manual Setup (Alternative)

If you prefer manual control:

```bash
# Install Zig
curl -LO https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz
tar -xf zig-linux-x86_64-0.13.0.tar.xz
export PATH="$PWD/zig-linux-x86_64-0.13.0:$PATH"

# Clone and build Trinity
git clone https://github.com/gHashTag/trinity.git
cd trinity
zig build firebird

# For bitnet.cpp inference, follow the benchmark script steps
```

### 4. Server Mode for API Access

To expose inference as an HTTP API on your RunPod instance:

```bash
./bin/vibee serve --port 8080
```

Configure the RunPod instance to expose port 8080 via the RunPod proxy URL, which provides HTTPS access to your running service.

## Cost Considerations

- RunPod charges by the hour for GPU instances. Stop your pod when not in use.
- The H100 SXM is the most expensive but provides the best throughput.
- For cost-effective testing, the RTX 3090 delivers comparable per-token throughput at a fraction of the cost.
- A single benchmark run (12 prompts, 500 tokens each) typically completes in under 5 minutes on H100 hardware.
- The benchmark script reminds you to stop the pod when finished.

## Output Files

After running the benchmark script, results are saved to:

| File | Contents |
|------|----------|
| `/root/bitnet_h100_results.txt` | Human-readable results with all prompts and outputs |
| `/root/bitnet_h100_metrics.json` | Machine-readable JSON with per-test timing and throughput |

## Troubleshooting

- **Missing AVX-512**: Some RunPod instances use older CPUs. The script detects this and falls back to a manual cmake build without TL2 optimizations.
- **Build failures**: Ensure clang and cmake are installed. The script handles this automatically.
- **Tokenizer warnings**: The GGUF model may show a "missing pre-tokenizer type" warning. The benchmark script overrides this with `--override-kv "tokenizer.ggml.pre=str:llama-bpe"`.
