<p align="center">
  <img src="https://img.shields.io/badge/Trinity-Network-6366F1?style=for-the-badge" alt="Trinity Network">
</p>

<h1 align="center">Trinity Network</h1>

<p align="center">
  <strong>Decentralized AI Inference</strong><br>
  Run LLMs on your CPU. Earn $TRI tokens. No GPU required.
</p>

<p align="center">
  <a href="#-why-trinity">Why Trinity</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-libraries">Libraries</a> •
  <a href="#-tokenomics">Tokenomics</a> •
  <a href="#-roadmap">Roadmap</a> •
  <a href="docs/business/BUSINESS_MODEL.md">Business Model</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Languages-29-blue" alt="29 Languages">
  <img src="https://img.shields.io/badge/Token-$TRI-green" alt="$TRI Token">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="MIT License">
  <img src="https://img.shields.io/badge/CPU-Inference-orange" alt="CPU Inference">
</p>

---

## 🚀 Why Trinity?

**The Problem:** AI inference requires expensive GPUs. NVIDIA controls 90%+ of the market. Cloud GPU costs $2-4/hour.

**Our Solution:** Ternary weights {-1, 0, +1} eliminate multiplications, enabling **CPU-only inference**.

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRINITY ADVANTAGE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Traditional LLM          Trinity Network                      │
│   ───────────────          ───────────────                      │
│   32 bits/weight    →      1.58 bits/weight                     │
│   70B = 280 GB RAM  →      70B = 14 GB RAM                      │
│   Requires GPU      →      ANY CPU works                        │
│   Float multiply    →      Just add/subtract                    │
│                                                                 │
│   Weights W ∈ {-1, 0, +1}:                                      │
│   • Multiply by -1 → negate (free)                              │
│   • Multiply by  0 → skip (free)                                │
│   • Multiply by +1 → nothing (free)                             │
│                                                                 │
│   Result: 20x memory savings, 10x faster on CPU                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⚡ Quick Start

### For Node Operators (Earn $TRI)

```bash
# Coming soon: Trinity Node desktop app
# 1. Download Trinity Node
# 2. Run on your PC/Mac/Linux
# 3. Earn $TRI for compute contribution
```

### For Developers (Use API)

```bash
# OpenAI-compatible API
curl https://api.trinity.network/v1/chat/completions \
  -H "Authorization: Bearer $TRI_API_KEY" \
  -d '{"model": "bitnet-70b", "messages": [{"role": "user", "content": "Hello"}]}'
```

### For Library Users

```bash
# Python
pip install trinity-vsa

# Rust
cargo add trinity-vsa

# npm
npm install trinity-vsa
```

---

## 📦 Libraries

**29 programming languages** with unified API:

| Category | Languages |
|----------|-----------|
| **Systems** | C, Rust, Zig, Nim, D, Ada, Fortran |
| **JVM** | Java, Kotlin, Scala, Clojure |
| **Functional** | Haskell, OCaml, F#, Elixir, Erlang |
| **Scientific** | Python, Julia, R, MATLAB, Mathematica |
| **Web/Mobile** | TypeScript, Go, Swift, Dart, PHP, Ruby |
| **Scripting** | Lua, Perl |

### Core API

```python
from trinity_vsa import TritVector, bind, similarity

# Create concept vectors
apple = TritVector.random(10000)
red = TritVector.random(10000)

# Bind: create association
red_apple = bind(apple, red)

# Query: measure similarity
print(similarity(red_apple, apple))  # ~0.0 (orthogonal after bind)
```

[📚 Full Library Documentation →](libs/README.md)

---

## 💰 Tokenomics

### $TRI Token

| Metric | Value |
|--------|-------|
| **Total Supply** | 1,000,000,000 |
| **Token** | $TRI |
| **Network** | Ethereum + Trinity L2 |

### Distribution

```
Node Rewards     ████████████████████  40%
Team & Advisors  ████████              20%
Treasury (DAO)   ██████                15%
Public Sale      ██████                15%
Ecosystem        ████                  10%
```

### Utility

- 💳 **Pay** for inference API calls
- 💰 **Earn** for compute contribution
- 🗳️ **Vote** on governance proposals
- 📈 **Stake** for priority access

[📄 Full Tokenomics →](docs/business/TOKENOMICS.md)

---

## 🗺️ Roadmap

```
Q1 2025  ✅ Trinity VSA libraries (29 languages)
         ✅ C library with AVX2 SIMD
         □  Trinity Node alpha

Q2 2025  □  $TRI token launch
         □  Mainnet beta
         □  BitNet 7B model

Q3 2025  □  BitNet 70B model
         □  Mobile apps
         □  10,000 nodes

Q4 2025  □  DAO governance
         □  Enterprise partnerships
         □  100,000 nodes
```

---

## 📁 Project Structure

```
trinity/
├── libs/           # 29-language VSA libraries
├── src/            # Core source code
│   ├── vibeec/     # VIBEE compiler
│   └── phi-engine/ # Quantum-inspired engine
├── specs/          # .vibee specifications
├── docs/           # Documentation
│   └── business/   # Business model, tokenomics
├── fpga-network/   # FPGA acceleration
└── examples/       # Usage examples
```

---

## 🔗 Links

| Resource | Link |
|----------|------|
| **GitHub** | [github.com/gHashTag/trinity](https://github.com/gHashTag/trinity) |
| **Documentation** | [docs/](docs/) |
| **Business Model** | [docs/business/BUSINESS_MODEL.md](docs/business/BUSINESS_MODEL.md) |
| **Tokenomics** | [docs/business/TOKENOMICS.md](docs/business/TOKENOMICS.md) |
| **Brand Guidelines** | [docs/business/BRANDING.md](docs/business/BRANDING.md) |

---

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

```bash
# Clone
git clone https://github.com/gHashTag/trinity.git

# Build
cd trinity && zig build

# Test
zig test src/vsa.zig
```

---

## 📜 License

MIT License - see [LICENSE](LICENSE)

---

<p align="center">
  <strong>Trinity Network</strong><br>
  <em>Decentralized AI Inference</em><br><br>
  <code>Trinity = 3 = Ternary = {-1, 0, +1}</code><br>
  <code>φ² + 1/φ² = 3</code>
</p>
