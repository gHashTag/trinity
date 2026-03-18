# Firebird API Reference

> LLM Inference Engine with BitNet Support

**Module:** `src/firebird/`

---

## Overview

Firebird is Trinity's LLM inference engine optimized for ternary weight models (BitNet b1.58). It provides:
- Efficient model loading (GGUF format)
- BitNet-to-Ternary conversion
- WASM extension support
- DePIN integration

---

## CLI Commands

### Chat Mode

```bash
./bin/firebird chat --model path/to/model.gguf
```

Options:
| Flag | Description |
|------|-------------|
| `--model` | Path to GGUF model file |
| `--context` | Context size (default: 2048) |
| `--temp` | Temperature (default: 0.7) |

### Server Mode

```bash
./bin/firebird serve --port 8080 --model path/to/model.gguf
```

Options:
| Flag | Description |
|------|-------------|
| `--port` | HTTP port (default: 8080) |
| `--model` | Model path |
| `--max-batch` | Max batch size |

---

## Core Modules

### b2t_integration.zig

BitNet-to-Ternary conversion.

```zig
const b2t = @import("firebird/b2t_integration.zig");

// Convert binary weights to ternary
const ternary_weights = b2t.convertWeights(binary_weights);
```

### wasm_parser.zig

WASM module loading for extensions.

```zig
const wasm = @import("firebird/wasm_parser.zig");

var module = try wasm.WASMParser.parse(allocator, wasm_bytes);
defer module.deinit();
```

### extension_wasm.zig

Extension system for plugins.

```zig
const ext = @import("firebird/extension_wasm.zig");

var extension = try ext.loadExtension("plugin.wasm");
const result = try extension.invoke("process", input);
```

### depin.zig

Decentralized Physical Infrastructure Network.

```zig
const depin = @import("firebird/depin.zig");

// Register as compute node
var node = try depin.Node.init(config);
try node.start();
```

---

## HTTP API

### POST /v1/chat/completions

OpenAI-compatible chat endpoint.

**Request:**
```json
{
  "model": "bitnet-3b",
  "messages": [
    {"role": "user", "content": "Hello!"}
  ],
  "temperature": 0.7,
  "max_tokens": 100
}
```

**Response:**
```json
{
  "choices": [{
    "message": {
      "role": "assistant",
      "content": "Hello! How can I help you?"
    }
  }]
}
```

### POST /v1/embeddings

Generate embeddings.

**Request:**
```json
{
  "model": "bitnet-3b",
  "input": "Text to embed"
}
```

### GET /health

Health check endpoint.

---

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `FIREBIRD_MODEL` | Default model path | - |
| `FIREBIRD_PORT` | Server port | 8080 |
| `FIREBIRD_CONTEXT` | Context size | 2048 |
| `FIREBIRD_THREADS` | CPU threads | auto |

---

## Performance

| Model Size | Memory | Tokens/sec |
|------------|--------|------------|
| 1.5B | ~1GB | 15-20 |
| 3B | ~2GB | 8-12 |
| 7B | ~4GB | 4-6 |

*BitNet models use 20x less memory than float32 equivalents.*

---

## See Also

- [VIBEE_API.md](VIBEE_API.md) — Model specification compiler
- [PLUGIN_API.md](PLUGIN_API.md) — Extension system
- [../fpga/FPGA_QUICKSTART.md](../fpga/FPGA_QUICKSTART.md) — Hardware acceleration
