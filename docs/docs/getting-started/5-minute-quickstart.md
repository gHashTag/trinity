---
sidebar_position: 0
sidebar_label: 5-Minute Quick Start
---

# 5-Minute Quick Start

Get started with Trinity in **5 minutes**. This guide covers the fastest path to running Trinity.

## ⚡ 30-Second Install

```bash
# Clone and build (requires Zig 0.15.x)
git clone https://github.com/gHashTag/trinity.git && cd trinity && zig build tri

# Run TRI CLI
./zig-out/bin/tri --help
```

**That's it!** You now have 203 commands available.

---

## 🚀 1-Minute First Run

### Try the Interactive REPL

```bash
./zig-out/bin/tri
```

Type any message and hit Enter. Use `/quit` to exit.

### Run Your First Command

```bash
# Sacred math
./zig-out/bin/tri constants
# Output: φ, π, e, Lucas, Fibonacci arrays

./zig-out/bin/tri phi 5
# Output: φ^5 = 11.09...

# Generate code
./zig-out/bin/tri code fibonacci
# Output: Zig code for Fibonacci sequence
```

---

## 📚 Essential Commands (5 minutes)

| Category | Command | What it does |
|----------|---------|--------------|
| **Chat** | `tri chat "hello"` | Talk to AI |
| **Code** | `tri code <topic>` | Generate code |
| **Fix** | `tri fix <file>` | Auto-fix bugs |
| **Math** | `tri constants` | Show φ, π, e |
| **Help** | `tri help` | Show all commands |

---

## 🧪 Verify Installation

```bash
# Health check
./zig-out/bin/tri doctor

# Run tests
zig build test

# All tests should pass: ✓
```

---

## 🎯 Next Steps

- [Full Quick Start Guide](/getting-started/quick-start-v1) — Comprehensive guide with Docker & binary options
- [TRI CLI Reference](/cli/) — All 203 commands documented
- [API Reference](/api/) — VSA, VM, Firebird APIs
- [Examples](https://github.com/gHashTag/trinity/tree/main/examples) — Sample code

---

## 🐳 Docker Alternative (2 minutes)

```bash
docker pull ghcr.io/ghashtag/trinity:latest
docker run -it --rm ghcr.io/ghashtag/trinity:latest --help
```

---

**Need help?** See [Troubleshooting](/troubleshooting) or [FAQ](/faq)
