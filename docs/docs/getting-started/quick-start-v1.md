---
sidebar_position: 1
---

# Quick Start Guide

Get up and running with Trinity in 5 minutes. This guide covers three installation methods tailored to your needs.

## 🎯 Choose Your Installation Method

| Method | Best For | Time Required | Difficulty |
|--------|----------|---------------|------------|
| 🐳 **Docker** | Users who want quick setup | ~2 minutes | Easy |
| 🔨 **Build from Source** | Developers contributing code | ~5 minutes | Medium |
| 📦 **Binary Download** | Quick testing without build | ~1 minute | Easy |

---

## 🐳 Method 1: Docker (Recommended)

Docker is the fastest way to get started. No dependencies to install — just pull and run.

### Prerequisites

- Docker installed ([Download](https://www.docker.com/get-started))
- 4GB RAM available
- 1GB disk space

### Pull and Run

```bash
# Pull the latest Trinity image
docker pull ghcr.io/ghashtag/trinity-node:latest

# Run the container
docker run -d --name trinity-node \
  -p 8080:8080 \
  -p 9090:9090 \
  -p 9333:9333/udp \
  -p 9334:9334 \
  -v ~/.trinity:/data \
  ghcr.io/ghashtag/trinity-node:latest
```

### Verify Installation

```bash
# Check container is running
docker ps | grep trinity-node

# Health check
curl http://localhost:8080/health
# Expected output: {"status":"ok","model":"loaded"}

# View logs
docker logs -f trinity-node
```

### Docker Tips

| Command | Description |
|---------|-------------|
| `docker stop trinity-node` | Stop the container |
| `docker start trinity-node` | Restart (keeps data) |
| `docker rm trinity-node` | Remove container (data persists in `~/.trinity`) |
| `docker exec -it trinity-node /bin/sh` | Open shell inside container |

### What's Running

| Port | Service | Purpose |
|------|---------|---------|
| 8080 | HTTP API | REST endpoints for inference |
| 9090 | Metrics | Prometheus monitoring |
| 9333 | UDP | Peer discovery |
| 9334 | TCP | Job distribution |

---

## 🔨 Method 2: Build from Source

For developers who want to modify Trinity or contribute to the project.

### Prerequisites

| Requirement | Version | Install |
|-------------|---------|---------|
| **Zig** | 0.15.x | [ziglang.org/download](https://ziglang.org/download/) |
| **Git** | Any | `brew install git` (macOS) or `apt install git` (Linux) |
| **RAM** | 4GB+ | - |
| **Disk** | 1GB+ | - |

### Install Zig

#### macOS

```bash
# Option 1: Direct download (recommended)
curl -LO https://ziglang.org/download/0.15.0/zig-macos-aarch64-0.15.0.tar.xz
tar -xf zig-macos-aarch64-0.15.0.tar.xz
export PATH="$PWD/zig-macos-aarch64-0.15.0:$PATH"

# Option 2: Homebrew
brew install zig
```

#### Linux

```bash
curl -LO https://ziglang.org/download/0.15.0/zig-linux-x86_64-0.15.0.tar.xz
tar -xf zig-linux-x86_64-0.15.0.tar.xz
export PATH="$PWD/zig-linux-x86_64-0.15.0:$PATH"
```

#### Windows

1. Download from [ziglang.org/download](https://ziglang.org/download/)
2. Extract to `C:\zig`
3. Add `C:\zig` to PATH

#### Verify Installation

```bash
zig version
# Expected output: 0.15.0
```

### Clone and Build

```bash
# Clone repository
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Build all targets
zig build

# Build specific components
zig build tri        # TRI CLI (recommended)
zig build vibee      # VIBEE compiler
zig build firebird   # Firebird LLM engine
```

### Verify Installation

```bash
# Run all tests
zig build test

# Test specific module
zig test src/vsa.zig

# Check TRI CLI
./zig-out/bin/tri --help
```

---

## 📦 Method 3: Binary Download (Quick Start)

For users who want to run Trinity immediately without building.

> **Note:** Pre-built binaries are available for macOS (Intel + ARM) and Linux (x86_64).

### Download Binary

#### macOS

```bash
# Detect architecture
ARCH=$(uname -m)

# Download for your architecture
if [ "$ARCH" = "arm64" ]; then
  curl -LO https://github.com/gHashTag/trinity/releases/latest/download/tri-macos-arm64
else
  curl -LO https://github.com/gHashTag/trinity/releases/latest/download/tri-macos-x86_64
fi

# Make executable
chmod +x tri-*

# Run
./tri-macos-* --help
```

#### Linux

```bash
# Download binary
curl -LO https://github.com/gHashTag/trinity/releases/latest/download/tri-linux-x86_64

# Make executable
chmod +x tri-linux-x86_64

# Run
./tri-linux-x86_64 --help
```

#### Verify Download

```bash
# Check version
./tri-* version

# Health check
./tri-* doctor
```

---

## ✅ First Steps After Installation

### 1. Health Check

Verify your installation is working correctly:

```bash
# If using Docker
docker exec trinity-node tri doctor

# If using build from source
./zig-out/bin/tri doctor

# If using binary
./tri-* doctor
```

Expected output:
```
✓ Zig version: 0.15.0
✓ VSA module: OK
✓ VM module: OK
✓ Firebird module: OK
✓ All systems operational
```

### 2. Run Basic VSA Example

Experience the power of Vector Symbolic Architecture:

```bash
# Run memory example
zig run examples/memory.zig
```

Or using the CLI:

```bash
tri chat "Explain balanced ternary computing"
```

### 3. Explore TRI CLI Commands

TRI is the unified command-line interface for all Trinity features:

```bash
# Interactive REPL
tri

# Generate code from specification
tri gen specs/tri/example.vibee

# Chat with AI
tri chat "What is the Trinity Identity?"

# Sacred math
tri constants          # Show φ, π, e, μ, χ, σ, ε
tri phi 10             # Compute φ^10
tri fib 50             # Fibonacci with BigInt

# Code assistance
tri code fibonacci     # Generate Fibonacci code
tri explain src/vsa.zig
tri fix src/vsa.zig
tri test src/vsa.zig

# System info
tri info
tri version
```

### 4. Run Tests

Ensure everything works:

```bash
# All tests
zig build test

# VSA tests only
zig test src/vsa.zig

# VM tests only
zig test src/vm.zig

# With verbose output
zig build test --verbose
```

---

## 🧪 Test Your Installation

Run this complete test suite:

```bash
# 1. VSA Operations Test
zig test src/vsa.zig

# 2. VM Execution Test
zig test src/vm.zig

# 3. Full Test Suite
zig build test

# 4. Health Check
tri doctor

# 5. Math Verification (38 sacred math checks)
tri math-verify
```

All tests should pass with ✓ marks.

---

## 🎓 What's Next?

Congratulations! You have Trinity installed and running. Here's where to go from here:

### Learn the Basics

- 📖 **[TRI CLI Reference](/cli/)** — Complete guide to 190+ commands
- 📐 **[Concepts](/concepts/)** — Learn about balanced ternary and the Trinity Identity
- 🧮 **[Mathematical Foundations](/math-foundations/)** — Deep dive into φ² + 1/φ² = 3

### Build Something

- 🔧 **[API Reference](/api/)** — Complete API documentation for VSA, VM, Firebird
- 📝 **[VIBEE Language](/vibee/)** — Specification-driven code generation
- 💡 **[Examples](https://github.com/gHashTag/trinity/tree/main/examples)** — Sample code and demos

### Advanced Topics

- 🚀 **[Development Setup](/getting-started/development-setup)** — IDE configuration and workflow
- 🐳 **[Deployment Guide](/deployment/)** — RunPod, local, and production deployment
- 🏗️ **[Architecture](/architecture/overview)** — System design and internals
- 📊 **[Benchmarks](/benchmarks/)** — Performance metrics and comparisons

### Join the Community

- 🐛 **[Troubleshooting](/troubleshooting)** — Common issues and solutions
- 💬 **[FAQ](/faq)** — Frequently asked questions
- 🤝 **[Contributing](/contributing)** — How to contribute to Trinity

### DePIN Node Operators

- 🌐 **[DePIN Overview](/depin/)** — Run a node and earn $TRI tokens
- 💰 **[Tokenomics](/depin/tokenomics)** — Reward structure and staking tiers
- 🔗 **[API Reference](/depin/api)** — Node API documentation

---

## 🆘 Need Help?

| Issue | Solution |
|-------|----------|
| Build fails | Ensure Zig 0.15.x is installed: `zig version` |
| Docker won't start | Check Docker is running: `docker ps` |
| Tests fail | Run specific test: `zig test src/vsa.zig` |
| Can't find command | Use full path: `./zig-out/bin/tri` |
| Port already in use | Change ports: `docker run -p 8081:8080 ...` |

For more help, see the **[Troubleshooting Guide](/troubleshooting)** or open an issue on GitHub.

---

## 📊 Quick Reference

### Essential Commands

```bash
# Build
zig build              # Build all
zig build tri          # Build TRI CLI
zig build test         # Run tests

# Run
tri                    # Interactive mode
tri chat "hello"       # Chat
tri code fibonacci     # Generate code
tri doctor             # Health check

# Docker
docker pull ghcr.io/ghashtag/trinity-node:latest
docker run -d -p 8080:8080 ghcr.io/ghashtag/trinity-node:latest
docker logs -f trinity-node
```

### Directory Structure

```
trinity/
├── src/               # Core library code
│   ├── vsa.zig        # Vector Symbolic Architecture
│   ├── vm.zig         # Ternary Virtual Machine
│   └── firebird/      # LLM engine
├── examples/          # Example code
├── specs/             # VIBEE specifications
└── zig-out/           # Build output
    └── bin/
        ├── tri        # TRI CLI
        └── vibee      # VIBEE compiler
```

---

**You're ready to explore the world of ternary computing! 🎉**

For more information, visit the [full documentation](/) or check out the [research papers](/research/).
