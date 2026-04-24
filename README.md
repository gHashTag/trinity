# trinity

[![Zig](https://img.shields.io/badge/Zig-0.15+-F7A41D?logo=zig&logoColor=white)](https://ziglang.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Golden Ratio](https://img.shields.io/badge/φ-1.618033988-gold)](https://en.wikipedia.org/wiki/Golden_ratio)
[![Ecosystem](https://img.shields.io/badge/Trinity-Main-blue)](https://github.com/gHashTag/trinity)

> **Trinity Orchestrator** — Golden Ratio mathematics meets computational physics and AI. Links all Trinity micro-repositories via `build.zig.zon`.

## 🎯 What is Trinity?

Trinity is the main orchestrator connecting a family of focused micro-repositories. Each repo has a single responsibility and can be used independently.

### Dependency Graph

\`
	t27                    ← SSOT: Ternary specs + Rust bootstrap compiler
	         ↑
	zig-golden-float      ← Numerical core: GF16, TF3, JIT, VM
	         ↑
	zig-sacred-geometry     ← Sacred geometry: φ-attention, Beal
	zig-physics             ← Quantum: QCD, gravity, dark matter, baryogenesis
	zig-hdc                 ← Hyperdimensional: VSA, Sequence HDC
	zig-knowledge-graph     ← Knowledge Graph: server + CLI
	trinity-training        ← HSLM ML: benchmarks, datasets (208MB)
	         ↑
	zig-agents              ← Agents: MCP, autonomous (~519KB)
	zig-crypto-mining       ← BTC mining + DePIN (~60KB)
	         ↑
	trinity                 ← Orchestrator (links all via build.zig.zon)
\`

## 🌌 Trinity Ecosystem

> Golden Ratio mathematics meets computational physics and AI.

| Repository | Purpose | Status |
|---|---|---|
| [trinity](https://github.com/gHashTag/trinity) | 🎯 Orchestrator, agents, API, MCP server | ✅ Here |
| [zig-golden-float](https://github.com/gHashTag/zig-golden-float) | 🔢 Numeric core: GF16, TF3, VSA, JIT | ✅ Core |
| [trinity-training](https://github.com/gHashTag/trinity-training) | 🧠 ML: HSLM, benchmarks, datasets | [![CI](https://img.shields.io/github/actions/workflow/status/gHashTag/trinity-training/ci.yml?branch=main)](https://github.com/gHashTag/trinity-training/actions) |
| [t27](https://github.com/gHashTag/t27) | 📜 Ternary SSOT + Rust bootstrap | 📜 Language |
| [vibee-lang](https://github.com/gHashTag/vibee-lang) | 🎵 VIBEE language spec (.tri/.vibee) | 📜 Language |
| [zig-hdc](https://github.com/gHashTag/zig-hdc) | 🧩 Hyperdimensional: VSA, HRR | ✅ |
| [zig-sacred-geometry](https://github.com/gHashTag/zig-sacred-geometry) | 📐 Sacred φ-geometry, Beal | ✅ |
| [zig-physics](https://github.com/gHashTag/zig-physics) | ⚛️ Quantum: QCD, gravity, dark matter | ✅ |
| [zig-knowledge-graph](https://github.com/gHashTag/zig-knowledge-graph) | 🕸️ KG server + CLI | ✅ |
| [zig-agents](https://github.com/gHashTag/zig-agents) | 🤖 Agents: MCP, autonomous | ✅ |
| [zig-crypto-mining](https://github.com/gHashTag/zig-crypto-mining) | 💰 BTC mining + DePIN | ✅ |
| [trinity-fpga](https://github.com/gHashTag/trinity-fpga) | 🔌 FPGA: Verilog synthesis | 🔄 WIP |

## 📦 Model Documentation (Consolidated)

**Complete catalog of all model-related documentation:**

**[docs/research/COMPLETE_MODEL_CATALOG.md](docs/research/COMPLETE_MODEL_CATALOG.md)**

### JEPA-T (Ternary Joint Embedding Predictive Architecture)

- Architecture: TrinityBlock, masks, EMA, MSE loss
- Training parameters and multipliers
- Experimental results (J-000, J-001)
- Research: [docs/lab/papers/2026-03-15-hslm-tjepa.md](docs/lab/papers/2026-03-15-hslm-tjepa.md)

### Neural Cellular Automata (NCA)

- Architecture: 9×9 grid, 9 states per cell
- Entropy bands: Wave 8.5 G1-G8 sweep
- Integration: Multi-objective with JEPA/NTP
- Results: [docs/experiments/FOUND_EXPERIMENTS_SUMMARY.md](docs/experiments/FOUND_EXPERIMENTS_SUMMARY.md)

### VSA (Vector Symbolic Architecture)

- Overview: Core concepts and FPGA implementation
- Operations: Quick reference for bind/unbind/bundle
- API: [docs/docs/api/vsa.md](docs/docs/api/vsa.md)
- Tutorial: [docs/docs/tutorials/vsa-operations.md](docs/docs/tutorials/vsa-operations.md)

### Ternary Models

- Guide: [docs/docs/concepts/balanced-ternary.md](docs/docs/concepts/balanced-ternary.md)
- ADR: [docs/docs/adr/002-ternary-representation.md](docs/docs/adr/002-ternary-representation.md)
- Hybrid Bipolar: [docs/docs/research/trinity-level11-hybrid-bipolar-ternary-report.md](docs/docs/research/trinity-level11-hybrid-bipolar-ternary-report.md)

### Hybrid Models

- API: [docs/docs/api/hybrid.md](docs/docs/api/hybrid.md)
- v2.0 Report: [docs/research/models/Hybrid/v2.0-report.md](docs/research/models/Hybrid/v2.0-report.md)
- v2.1 Report: [docs/research/models/Hybrid/v2.1-report.md](docs/research/models/Hybrid/v2.1-report.md)

## 📜 License

MIT © gHashTag
