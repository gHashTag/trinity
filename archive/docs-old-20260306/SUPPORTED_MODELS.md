# TRINITY Supported Models

## Quick Start

```bash
# General chat (fast, small)
./bin/vibee chat --model models/smollm-135m-instruct-q8_0.gguf --prompt "Hello"

# Coding (requires more RAM)
./bin/vibee chat --model models/qwen2.5-coder-0.5b-instruct-q8_0.gguf --prompt "Write fibonacci in Python"
```

## Supported Models

### General Chat

| Model | Size | RAM | Speed | Quality |
|-------|------|-----|-------|---------|
| SmolLM-135M-Instruct | 139 MB | 1 GB | 12 tok/s | ★★☆☆☆ |
| TinyLlama-1.1B | 1.1 GB | 4 GB | 4 tok/s | ★★★☆☆ |

### Coding

| Model | Size | RAM | Speed | Quality |
|-------|------|-----|-------|---------|
| Qwen2.5-Coder-0.5B | 600 MB | 2 GB | 6 tok/s | ★★★☆☆ |
| Qwen2.5-Coder-1.5B | 1.8 GB | 6 GB | 3 tok/s | ★★★★☆ |

## Download Models

```bash
cd models/

# SmolLM-135M (recommended for demos)
curl -L -o smollm-135m-instruct-q8_0.gguf \
  "https://huggingface.co/HuggingFaceTB/smollm-135M-instruct-v0.2-Q8_0-GGUF/resolve/main/smollm-135m-instruct-add-basics-q8_0.gguf"

# Qwen2.5-Coder-0.5B (coding, small)
curl -L -o qwen2.5-coder-0.5b-instruct-q8_0.gguf \
  "https://huggingface.co/Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-0.5b-instruct-q8_0.gguf"

# Qwen2.5-Coder-1.5B (coding, better quality)
curl -L -o qwen2.5-coder-1.5b-instruct-q8_0.gguf \
  "https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q8_0.gguf"
```

## Quantization Support

| Format | Supported | Notes |
|--------|-----------|-------|
| Q8_0 | ✅ Yes | Best quality, larger size |
| Q4_0 | ✅ Yes | Good balance |
| Q4_K_M | ⚠️ Partial | K-quants, experimental |
| F32 | ✅ Yes | Full precision |
| F16 | ✅ Yes | Half precision |

## Chat Templates

TRINITY auto-detects the model and uses appropriate chat template:

| Model | Template |
|-------|----------|
| Qwen* | ChatML (`<\|im_start\|>`) |
| SmolLM* | ChatML |
| TinyLlama* | TinyLlama format |
| Llama-2* | Llama2 format |

## Fly.io Deployment

Current deployment uses SmolLM-135M (fits in 2GB RAM):

```bash
# API endpoint
curl https://trinity-llm.fly.dev/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello"}]}'
```

For coding models, deploy with more RAM:

```toml
# fly.toml
[[vm]]
  size = "shared-cpu-4x"
  memory = "4gb"
```

## Ternary Mode

Enable 16x memory savings (experimental):

```bash
./bin/vibee chat --model models/smollm-135m-instruct-q8_0.gguf --ternary
```

Note: Quality may degrade for non-BitNet models.
