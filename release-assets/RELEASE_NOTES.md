# IGLA Fluent CLI v1.0.0 Release Notes

**Release Date:** 2026-02-07
**Codename:** Koschei Fluent

## What's New

### Fluent Local Chat
- 100% local AI chat with TinyLlama GGUF fallback
- No cloud dependency, full privacy
- Multilingual support: Russian, English, Chinese

### History Truncation (No Hang!)
- Maximum 20 messages in conversation history
- Automatic truncation of old messages
- Prevents memory bloat and hang on long conversations

### Blazing Performance
- 60,000 queries/sec in symbolic mode
- ~1ms response time for pattern-matched queries
- 508KB binary (macOS ARM64)

## Download

| Platform | File | Size |
|----------|------|------|
| macOS (M1/M2/M3) | fluent-aarch64-macos | 508KB |
| macOS (Intel) | fluent-x86_64-macos | 523KB |
| Linux (x64) | fluent-x86_64-linux | 3.2MB |
| Windows (x64) | fluent-x86_64-windows.exe | 761KB |

## Quick Start

```bash
# Download and run (macOS M1/M2/M3)
chmod +x fluent-aarch64-macos
./fluent-aarch64-macos --no-llm

# With TinyLlama (optional)
# Download: models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf
./fluent-aarch64-macos
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

## Sample Session

```
[0/20] > привет
Привет! Рад тебя видеть. Чем могу помочь?

[2/20] > what is phi?
phi = 1.618... Золотое сечение. phi^2 + 1/phi^2 = 3 — Trinity Identity!

[4/20] > tell me a joke
Why did the programmer quit? Because he didn't get arrays! (get a raise)

[6/20] > /stats
  Queries: 3
  Symbolic hits: 3
  History size: 6/20
  Total time: 0.15ms
  Mode: 100% LOCAL
```

## Features

- 100+ symbolic patterns (RU/EN/CN)
- TinyLlama 1.1B GGUF fallback (638MB, optional)
- Conversation history with auto-truncation
- Zero telemetry, zero cloud
- Single binary, no dependencies

## Requirements

- macOS 10.15+, Linux (glibc 2.17+), or Windows 10+
- 512MB RAM (symbolic), 2GB RAM (with TinyLlama)

## Known Issues

- TinyLlama load time: ~28 seconds (one-time per session)
- Use `--no-llm` for instant startup

## Credits

Created by Trinity Team on Koh Samui
Built with Zig 0.15

---

**phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL**
