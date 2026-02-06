---
sidebar_position: 3
---

# Local Deployment

Run Trinity on your local machine for development, testing, and inference with ternary models. This guide covers building from source, running inference, and using the CLI tools.

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Zig | 0.13.0 | Exact version required |
| Git | Any recent | For cloning the repository |
| RAM | 4 GB minimum | 8 GB+ recommended for model inference |
| Disk | 1 GB minimum | Plus model file size |

## Build from Source

### macOS

```bash
# Install Zig (Apple Silicon)
curl -LO https://ziglang.org/download/0.13.0/zig-macos-aarch64-0.13.0.tar.xz
tar -xf zig-macos-aarch64-0.13.0.tar.xz
export PATH="$PWD/zig-macos-aarch64-0.13.0:$PATH"

# Alternatively, use Homebrew
brew install zig@0.13

# Clone and build
git clone https://github.com/gHashTag/trinity.git
cd trinity
zig build
```

### Linux

```bash
# Install Zig
curl -LO https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz
tar -xf zig-linux-x86_64-0.13.0.tar.xz
export PATH="$PWD/zig-linux-x86_64-0.13.0:$PATH"

# Clone and build
git clone https://github.com/gHashTag/trinity.git
cd trinity
zig build
```

### Windows

1. Download Zig 0.13.0 from [ziglang.org/download](https://ziglang.org/download/)
2. Extract to `C:\zig` and add to your PATH
3. Clone and build:

```powershell
git clone https://github.com/gHashTag/trinity.git
cd trinity
zig build
```

### Verify the Build

```bash
zig build test
```

All tests should pass. You can also run specific module tests:

```bash
zig test src/vsa.zig     # VSA operations
zig test src/vm.zig      # Virtual machine
```

## Running Inference with Local Models

### Obtaining GGUF Models

BitNet b1.58 models in GGUF format are available from HuggingFace:

- **microsoft/bitnet-b1.58-2B-4T-gguf** -- 2.4B parameter model, ~1.1 GB
- Other ternary models can be converted to GGUF using the tools provided with bitnet.cpp

Download using the HuggingFace CLI or directly:

```bash
pip install huggingface_hub
python -c "
from huggingface_hub import hf_hub_download
hf_hub_download('microsoft/bitnet-b1.58-2B-4T-gguf', 'ggml-model-i2_s.gguf', local_dir='./models')
"
```

### Chat Mode

Start an interactive chat session with a local model:

```bash
./bin/vibee chat --model ./models/ggml-model-i2_s.gguf
```

### Server Mode

Run Trinity as an HTTP server for API-based inference:

```bash
./bin/vibee serve --port 8080
```

This starts a local HTTP server that accepts inference requests via JSON API.

## Memory Requirements by Model Size

| Model | Parameters | GGUF File Size | Min RAM (inference) | Recommended RAM |
|-------|-----------|----------------|---------------------|-----------------|
| BitNet Small | ~700M | ~350 MB | 2 GB | 4 GB |
| BitNet 2B-4T | 2.4B | 1.1 GB | 4 GB | 8 GB |
| BitNet 3B | ~3B | ~1.4 GB | 4 GB | 8 GB |
| BitNet 7B | ~7B | ~3.2 GB | 8 GB | 16 GB |

These numbers reflect the ternary-packed model weights. During inference, additional memory is required for the KV cache (which scales with context length) and activation buffers.

## CPU Performance Expectations

Local CPU inference is significantly slower than GPU inference. On an Apple M1 Pro or comparable x86 CPU, expect:

- **Without optimized kernels**: 0.1-0.5 tokens/second (very slow)
- **With AVX-512 VNNI (x86)**: Up to ~15,000 tokens/second
- **ARM NEON (Apple Silicon)**: Performance depends on kernel availability

For production-grade throughput, see the [RunPod GPU Deployment](/docs/deployment/runpod) guide.

## Other CLI Commands

```bash
# Generate code from a .vibee specification
./bin/vibee gen specs/tri/module.vibee

# Run a program via the bytecode VM
./bin/vibee run program.999

# Build the Firebird LLM CLI in release mode
zig build firebird

# Cross-platform release builds
zig build release
```
