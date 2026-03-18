# Trinity Models Directory

All model files consolidated here. **Single source of truth for weights.**

## Directory Structure

```
models/
├── bitnet/          # Microsoft BitNet b1.58 (ternary native)
│   ├── bitnet-2b-fixed.gguf      # 2B params, GGUF format (2.8GB)
│   ├── bitnet-2b.bin              # 2B params, raw binary (2.9GB)
│   ├── microsoft-bitnet-2b/       # Original safetensors
│   └── microsoft-bitnet-2b-bf16/  # BF16 embeddings
├── qwen/            # Qwen 2.5 Instruct (coder model candidate)
│   └── qwen2.5-7b-instruct-q4_k_m.gguf  # 7B params, Q4_K_M (4.4GB)
├── tinyllama/       # TinyLlama (fast testing)
│   └── tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf  # 1.1B params (637MB)
├── mistral/         # Mistral 7B
│   └── mistral-7b/
├── embeddings/      # Embedding models
├── test/            # Test fixtures (small .tri files)
│   ├── mistral-7b-layer1.tri
│   ├── test_minimal.tri
│   ├── test_model.tri
│   ├── trinity_god_weights.tri
│   └── trinity_god_weights_v2.tri
└── vocab/           # Vocabulary files
```

## Ternary Conversion

Convert any GGUF model to Trinity's native TRI format:
```bash
zig build vibee -- gen specs/tri/gguf_to_tri.vibee
./zig-out/bin/gguf_to_tri models/qwen/qwen2.5-7b-instruct-q4_k_m.gguf models/qwen/qwen2.5-7b.tri
```

## Compression Ratios (Ternary)

| Model | Float16 | Ternary | Ratio |
|-------|---------|---------|-------|
| BitNet 2B | 4GB | 0.5GB | 8x |
| Qwen 7B | 14GB | 1.65GB | 8.5x |
| TinyLlama 1.1B | 2.2GB | 0.26GB | 8.5x |
