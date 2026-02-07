# IGLA Fluent CLI v1.0 - Install Guide

**Version:** 1.0.0
**Date:** 2026-02-07

## Quick Start

### Download Binary

| Platform | Binary | Size |
|----------|--------|------|
| macOS (M1/M2/M3) | `fluent-aarch64-macos` | 508KB |
| macOS (Intel) | `fluent-x86_64-macos` | 523KB |
| Linux (x64) | `fluent-x86_64-linux` | 3.2MB |
| Windows (x64) | `fluent-x86_64-windows.exe` | 761KB |

### Install

**macOS/Linux:**
```bash
# Download (replace URL with actual release)
curl -L -o fluent https://github.com/gHashTag/trinity/releases/download/v1.0.0/fluent-aarch64-macos

# Make executable
chmod +x fluent

# Move to PATH (optional)
sudo mv fluent /usr/local/bin/

# Run
fluent
```

**Windows:**
```powershell
# Download fluent.exe from releases
# Run directly
.\fluent.exe
```

## Usage Modes

### Symbolic-Only Mode (Fastest)
```bash
# 60,000 queries/sec, no LLM loading
fluent --no-llm
# or
fluent -s
```

### Full Mode (with TinyLlama fallback)
```bash
# Requires TinyLlama GGUF model
fluent
```

## TinyLlama Setup (Optional)

For fluent fallback on unknown patterns:

### Option 1: Manual Download
```bash
# Create models directory
mkdir -p models

# Download TinyLlama GGUF (638MB)
curl -L -o models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf \
  https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf
```

### Option 2: Using Ollama
```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull TinyLlama
ollama pull tinyllama

# Export to GGUF (use llama.cpp or similar)
```

## Commands

```
/stats    - Show conversation statistics
/clear    - Clear conversation history
/verbose  - Toggle verbose mode
/history  - Show conversation history
/help     - Show available commands
/quit     - Exit CLI
```

## Demo

```bash
$ fluent --no-llm

╔══════════════════════════════════════════════════════════════╗
║     IGLA FLUENT CLI v1.0 - Local Chat                        ║
║     100% Local | History Truncation | No Hang                ║
║     φ² + 1/φ² = 3 = TRINITY                                   ║
╚══════════════════════════════════════════════════════════════╝

[0/20] > привет
Привет! Рад тебя видеть. Чем могу помочь?

[2/20] > hello
Hello! Great to see you. How can I help?

[4/20] > what is phi?
phi = 1.618... Золотое сечение. phi^2 + 1/phi^2 = 3 — Trinity Identity!

[6/20] > /stats
═══ Conversation Statistics ═══
  Queries: 3
  Symbolic hits: 3
  History size: 6/20
  Total time: 0.15ms
  Mode: 100% LOCAL
```

## Features

- **History Truncation:** Max 20 messages (prevents hang)
- **Symbolic Patterns:** 100+ multilingual (RU/EN/CN)
- **TinyLlama Fallback:** Fluent responses for unknown queries
- **Zero Cloud:** 100% local, full privacy
- **Blazing Fast:** 60,000 queries/sec (symbolic mode)

## Troubleshooting

### "TinyLlama not found"
```bash
# Run in symbolic-only mode
fluent --no-llm

# Or download model to ./models/ directory
```

### Permission denied (macOS)
```bash
# Allow execution
chmod +x fluent
xattr -d com.apple.quarantine fluent
```

### Slow startup (with LLM)
```
LLM load time: ~28 seconds (one-time per session)
Use --no-llm for instant startup
```

## Build from Source

```bash
# Clone
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Build (requires Zig 0.15+)
zig build fluent

# Run
./zig-out/bin/fluent

# Build release binaries
zig build release-fluent
ls zig-out/release-fluent/
```

## System Requirements

| Platform | Requirement |
|----------|-------------|
| macOS | 10.15+ (Catalina or later) |
| Linux | glibc 2.17+ (Ubuntu 18.04+) |
| Windows | Windows 10+ |
| RAM | 512MB (symbolic), 2GB (with TinyLlama) |
| Disk | 1MB (binary) + 638MB (TinyLlama optional) |

## Support

- GitHub Issues: https://github.com/gHashTag/trinity/issues
- Documentation: https://gHashTag.github.io/trinity/

---

**φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL | 100% LOCAL**
