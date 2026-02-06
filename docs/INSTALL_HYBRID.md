# Trinity Hybrid Local Coder — Install Guide

**Version:** 1.0.2  
**Date:** 2026-02-07

---

## Quick Start

```bash
# 1. Install Ollama
brew install ollama          # macOS
# or: curl -fsSL https://ollama.com/install.sh | sh  # Linux

# 2. Start Ollama
ollama serve &

# 3. Pull the model (4.7GB, one-time)
ollama pull qwen2.5-coder:7b

# 4. Run Trinity Hybrid
./trinity-hybrid              # Interactive mode
./trinity-hybrid "hello"      # One-shot (instant)
./trinity-hybrid "write fibonacci in zig"  # LLM (fluent code)
```

---

## Requirements

| Component | Version | Size |
|-----------|---------|------|
| Zig | 0.15.x | — |
| Ollama | 0.1.x+ | — |
| qwen2.5-coder:7b | latest | 4.7GB |
| trinity-hybrid | 1.0.2 | **388KB** |

---

## Build from Source

```bash
git clone https://github.com/gHashTag/trinity.git
cd trinity
zig build

# Binary at: zig-out/bin/trinity-hybrid
./zig-out/bin/trinity-hybrid --help
```

---

## Usage

### Interactive Mode

```bash
$ ./trinity-hybrid

╔═══════════════════════════════════════════════════════════════════╗
║     TRINITY HYBRID LOCAL CODER v1.0.2                             ║
║     IGLA Symbolic (instant) + Ollama LLM (fluent)                ║
║     100% Local | No Cloud | M1 Pro Optimized                     ║
╚═══════════════════════════════════════════════════════════════════╝

[You] > hello
[Trinity] (Symbolic, 40%, 34μs)
Hello! Great to see you. How can I help?

[You] > write factorial in zig
[Trinity] Calling Ollama...
[Trinity] (LLM, 4673ms)
fn factorial(n: u64) u64 {
    if (n == 0 or n == 1) return 1;
    return n * factorial(n - 1);
}

[You] > /quit
```

### One-Shot Mode

```bash
# Symbolic (instant, 2-45μs)
./trinity-hybrid "привет"
./trinity-hybrid "tell me a joke"
./trinity-hybrid "who are you?"

# LLM (fluent, 4-30s)
./trinity-hybrid "write quicksort in zig"
./trinity-hybrid "explain recursion"
./trinity-hybrid "what is golden ratio"
```

### Commands

| Command | Description |
|---------|-------------|
| `/help` | Show commands |
| `/quit` | Exit |
| `/stats` | Show statistics |

---

## Architecture

```
Query → IGLA Symbolic (100+ patterns, 2-45μs)
          │
          ├─ Match found → Instant response
          │
          └─ No match → Ollama qwen2.5-coder (4-30s, fluent)
```

---

## Troubleshooting

### "Error: CurlFailed"

```bash
# Check Ollama is running
curl http://localhost:11434/api/version

# Start Ollama
ollama serve &
```

### "Model not found"

```bash
ollama pull qwen2.5-coder:7b
```

---

## Metrics

| Mode | Latency | Quality |
|------|---------|---------|
| Symbolic | 2-45μs | Deterministic, no hallucination |
| LLM | 4-30s | Fluent code, natural language |

---

**φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL**
