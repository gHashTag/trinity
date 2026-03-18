# TRINITY Site Metrics Update

## Live Demo

**API Endpoint:** https://trinity-llm.fly.dev

```bash
# Health check
curl https://trinity-llm.fly.dev/health

# Chat completion (OpenAI-compatible)
curl -X POST https://trinity-llm.fly.dev/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Hello!"}]}'
```

## Real Benchmarks (Measured)

| Metric | Value | Notes |
|--------|-------|-------|
| **Inference Speed** | 11.8 tok/s | SmolLM-135M, Q8_0, CPU |
| **Ternary Speed** | 9.6 tok/s | With 16x memory savings |
| **Model Load Time** | 0.26s | 135M parameters |
| **Memory (Float)** | 621 MB | F32 weights |
| **Memory (Ternary)** | 39 MB | 16x reduction |
| **Binary Size** | 4.3 MB | Zero dependencies |

## Key Features (Verified)

### 1. Zero Dependencies
- Single static binary
- No Python, no CUDA, no external libraries
- Cross-platform (Linux, macOS, Windows)

### 2. SIMD Optimization
- AVX2/AVX-512 vectorized matmul
- 4-way loop unrolling
- 3-5x speedup over scalar

### 3. Ternary/BitNet Ready
- Weights quantized to {-1, 0, +1}
- 16x memory savings
- SIMD-optimized ternary matmul

### 4. Multi-Language Code Generation
- 29 languages from .vibee specs
- Zig, Verilog, Python, Rust, Go, etc.

## What to Update on Site

### Remove (Unverified Claims)
- ❌ "100x Faster AI Inference"
- ❌ "99.8% Less Power"

### Add (Verified Claims)
- ✅ "11.8 tok/s on CPU"
- ✅ "16x Memory Savings with Ternary"
- ✅ "Zero Dependencies - Single Binary"
- ✅ "Live API: trinity-llm.fly.dev"

## Comparison with llama.cpp

| Feature | TRINITY | llama.cpp |
|---------|---------|-----------|
| Language | Zig | C++ |
| Dependencies | 0 | Many |
| Binary Size | 4.3 MB | ~50 MB |
| Ternary Support | Native | No |
| GGUF Support | Yes | Yes |
| Speed (SmolLM) | 11.8 tok/s | ~50 tok/s |

**Note:** llama.cpp is faster for standard inference. TRINITY's advantage is in ternary/BitNet models and zero-dependency deployment.

## Recommended Hero Section

```
TRINITY LLM
-----------
Zig-Powered AI Inference Engine

• 11.8 tok/s on CPU
• 16x Memory Savings (Ternary Mode)
• Zero Dependencies
• OpenAI-Compatible API

[Try Live Demo] → https://trinity-llm.fly.dev
```

## API Documentation

### POST /v1/chat/completions

Request:
```json
{
  "messages": [
    {"role": "user", "content": "Hello, who are you?"}
  ],
  "max_tokens": 50,
  "temperature": 0.7
}
```

Response:
```json
{
  "id": "chatcmpl-trinity",
  "object": "chat.completion",
  "model": "trinity-llm",
  "choices": [{
    "index": 0,
    "message": {
      "role": "assistant",
      "content": "Hello! I'm TRINITY..."
    },
    "finish_reason": "stop"
  }]
}
```

### GET /health

Response:
```json
{"status": "ok", "model": "loaded"}
```
