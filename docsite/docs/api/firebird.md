---
sidebar_position: 5
---

# Firebird API

LLM Inference Engine with BitNet Support.

**Module:** `src/firebird/`

## CLI Commands

### Chat Mode

```bash
./bin/firebird chat --model path/to/model.gguf
```

### Server Mode

```bash
./bin/firebird serve --port 8080 --model model.gguf
```

## HTTP API

### POST /v1/chat/completions

OpenAI-compatible chat endpoint.

```json
{
  "model": "bitnet-3b",
  "messages": [{"role": "user", "content": "Hello!"}],
  "temperature": 0.7
}
```

## Performance

| Model Size | Memory | Tokens/sec |
|------------|--------|------------|
| 1.5B | ~1GB | 15-20 |
| 3B | ~2GB | 8-12 |
| 7B | ~4GB | 4-6 |
