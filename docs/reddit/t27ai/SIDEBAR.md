# r/t27ai — Sidebar Content

## Description

**r/t27ai** — Trinity project community

Trinity — Pure Zig autonomous AI agent swarm.
0 TypeScript, 0 Python, 0 bash dependencies.

---

## Key Features

### Ternary Computing
- **{-1, 0, +1} instead of float32** — 20x memory savings
- Ternary logic: 1.58 bits/trit vs 8 bits/byte
- Natural FPGA implementation

### VSA (Vector Symbolic Architecture)
- `bind(a, b)` — associate vectors
- `unbind(bound, key)` — retrieve from binding
- `bundle2(a, b)`, `bundle3(a, b, c)` — majority voting
- Cognitive computing with hypervectors

### BitNet LLM
- CPU inference without GPU
- 63 tok/s @ 1W on FPGA
- Quantized weights: {-1, 0, +1}

### TRI-27
- Ternary core with 27 registers
- 3 banks × 9 registers (Coptic alphabet)
- 36 opcodes: MOV, JGT, JLT, JUMP, PHI, CALL, RET...

### FPGA
- QMTech XC7A100T ($30)
- 0% DSP, 19.6% LUT, 1.2W
- Fully open-source toolchain

---

## Trinity Identity

```
φ² + 1/φ² = 3
where φ = (1 + √5) / 2
```

The connection between ternary systems and the golden ratio.

---

## Useful Links

| Resource | Link |
|----------|------|
| 🌐 Website | https://t27.ai/ |
| 📖 Documentation | https://t27.ai/docs/ |
| 📱 Reddit | https://www.reddit.com/r/t27ai/ |
| ✈️ Telegram | https://t.me/t27_lang |
| 𝕏 X (Twitter) | https://x.com/t27_lang |
| 💻 GitHub | https://github.com/gHashTag/trinity |
| 📜 Zenodo | https://zenodo.org/communities/trinity |
| 📦 Releases | https://github.com/gHashTag/trinity/releases |

---

## Installation

```bash
# Via npm
npm install -g @playra/tri

# Via Homebrew
brew install trinity

# From source
git clone https://github.com/gHashTag/trinity
cd trinity
zig build
zig build tri
./zig-out/bin/tri --help
```

---

## Quick Start

```bash
# Show status
tri status

# Run tests
tri test

# List issues
tri issue list

# Create new agent
tri agent spawn
```

---

## Project Stats

- **50+ binaries** from one build.zig
- **3000+ tests** passing
- **SIMD 17x+** speedup
- **JIT 22x+** speedup
- **8 Zenodo bundles** with scientific publications

---

## Contributing

1. ⭐ Star on GitHub
2. 🔀 Fork and PR
3. 📝 Create issues for bugs/features
4. 💬 Join discussions

---

## License

MIT License — use freely in your projects!
