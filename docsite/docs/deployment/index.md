---
sidebar_position: 1
---

# Deployment

Trinity supports multiple deployment configurations depending on your hardware, use case, and performance requirements. This section covers the primary deployment options.

## Deployment Options

### Local Development

Run Trinity on your local machine for development, testing, and small-scale inference. This requires only Zig 0.13.0 and Git. Local deployment works on macOS, Linux, and Windows, and supports both VSA operations and model inference using CPU. See [Local Deployment](/docs/deployment/local) for setup instructions.

### GPU Cloud Inference

For high-throughput BitNet inference, deploy on cloud GPU instances via providers like RunPod. This is the recommended approach for production inference workloads, benchmarking, and testing models that require GPU acceleration. Cloud GPUs provide the CUDA or AVX-512 support needed for maximum throughput with bitnet.cpp. See [RunPod GPU Deployment](/docs/deployment/runpod) for a step-by-step guide.

### Server Mode (HTTP API)

Trinity includes a built-in HTTP server for serving inference results over a REST API. This mode is suitable for integrating Trinity into larger applications or exposing model inference as a network service:

```bash
./bin/vibee serve --port 8080
```

Server mode can run on either local or cloud hardware and provides a JSON API for inference requests.

## Choosing a Deployment Strategy

| Requirement | Recommended Deployment |
|-------------|----------------------|
| Development and testing | Local |
| Interactive chat with models | Local (with GGUF model) |
| High-throughput inference (>10K tok/s) | GPU cloud (RunPod) |
| Production API serving | Server mode on GPU cloud |
| VSA operations only (no LLM) | Local (CPU is sufficient) |
| Benchmarking and evaluation | GPU cloud with H100 or A100 |

The JIT compiler for VSA operations works on all platforms (ARM64 and x86-64) and does not require a GPU. GPU acceleration is primarily beneficial for BitNet model inference where the ternary weight unpacking and matrix operations benefit from parallel hardware.
