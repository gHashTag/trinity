# BitNet Inference Tutorial

**20 минут для первого LLM inference с троичными весами**

---

## Цель этого туториала

Запустить BitNet b1.58 модель и выполнить inference.

**Что вы узнаете:**
- Как скачать BitNet модель
- Как запустить Firebird engine
- Как выполнить chat inference
- Как измерить производительность

---

## Что такое BitNet b1.58?

**BitNet b1.58** — это архитектура нейросети где веса квантованы в **троичные значения** {-1, 0, +1}.

| Преимущество | Описание |
|--------------|----------|
| **Memory** | 20x меньше чем float32 |
| **Compute** | Только сложение/вычитание |
| **Energy** | Меньше энергопотребление |

---

## Step 1: Download Model

```bash
# Create models directory
mkdir -p models

# Download BitNet b1.58-2B-4T GGUF
pip install huggingface_hub

python3 -c "
from huggingface_hub import hf_hub_download
hf_hub_download(
    'microsoft/bitnet-b1.58-2B-4T-gguf',
    'ggml-model-i2_s.gguf',
    local_dir='./models'
)
"
```

**Размер:** ~1.1 GB

---

## Step 2: Build Firebird

```bash
# Build Firebird LLM CLI
zig build firebird

# Or build TRI with Firebird included
zig build tri
```

---

## Step 3: Run Inference

### CPU Inference

```bash
# Interactive chat
./zig-out/bin/tri chat --model ./models/ggml-model-i2_s.gguf

# Single prompt
./zig-out/bin/tri chat --model ./models/ggml-model-i2_s.gguf \
  --prompt "Explain ternary computing"
```

### Server Mode

```bash
# Start HTTP server
./zig-out/bin/tri serve --model ./models/ggml-model-i2_s.gguf --port 8080

# Query via API
curl -X POST http://localhost:8080/api/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Hello Trinity"}'
```

---

## Step 4: Performance

### Ожидаемые результаты

| Hardware | Speed | Notes |
|----------|-------|-------|
| Apple M1/M2 | 5-15 tok/s | CPU only |
| x86_64 (AVX2) | 10-20 tok/s | CPU only |
| RTX 3090 (GPU) | 100K+ tok/s | via bitnet.cpp |
| H100 (GPU) | 298K tok/s | via bitnet.cpp |

### Benchmark

```bash
# Run benchmark
./zig-out/bin/tri bench --model ./models/ggml-model-i2_s.gguf
```

---

## Code Example

```zig
const std = @import("std");
const firebird = @import("firebird");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    // Load model
    var model = try firebird.Model.load(allocator, "./models/ggml-model-i2_s.gguf");
    defer model.unload();

    // Generate
    const prompt = "The golden ratio is";
    const output = try model.generate(prompt, .{
        .max_tokens = 50,
        .temperature = 0.7,
    });

    std.debug.print("{s}\n", .{output});
    // → "The golden ratio is approximately 1.618, known as phi..."
}
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Model file not found | Check path to GGUF file |
| Out of memory | Reduce context size or use smaller model |
| Slow inference | Use GPU or quantized model |

---

## What's Next?

| Tutorial | Description |
|----------|-------------|
| [VSA Operations](vsa-operations.md) | Vector operations |
| [DePIN Node](depin-node.md) | Run inference node |

---

**φ² + 1/φ² = 3 = TRINITY**
