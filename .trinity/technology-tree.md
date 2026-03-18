# Trinity Technology Tree

## Layer 0 — Core Mathematics

**Status: COMPLETE**

| Component | Files | Tests | Status |
|-----------|-------|-------|--------|
| VSA (Vector Symbolic Architecture) | `src/vsa.zig` | 1,017 across codebase | COMPLETE |
| Ternary VM (stack bytecode) | `src/vm.zig` | inline tests | COMPLETE |
| VIBEE Specs | `specs/**/*.tri` (442 specs) | ast-check pass | COMPLETE |
| Phi Identity (phi^2 + 1/phi^2 = 3) | `src/vsa.zig` | math proof | COMPLETE |
| SDK | `src/sdk.zig` | inline tests | COMPLETE |
| Hybrid Engine | `src/hybrid.zig` | inline tests | COMPLETE |

Key: Ternary {-1, 0, +1} = 1.58 bits/trit, 20x memory savings vs float32.

## Layer 1 — HSLM Model

**Status: COMPLETE**

| Component | Detail | Status |
|-----------|--------|--------|
| Architecture | 23 modules, 1.95M ternary params | COMPLETE |
| Training | Best: v4R, PPL=125, Loss=4.83 | COMPLETE |
| Config | Vocab=729, Embed=243, Hidden=729, Blocks=3, Heads=3, Ctx=81 | COMPLETE |
| Checkpoints | Binary format with step/loss headers | COMPLETE |
| CLI | `src/hslm/cli.zig` + `src/hslm/model.zig` | COMPLETE |

## Layer 2 — Infrastructure

**Status: COMPLETE**

| Component | Detail | Status |
|-----------|--------|--------|
| MCP Server | `trinity-mcp`, 47+ tools | COMPLETE |
| tri CLI | Single entry point, all commands | COMPLETE |
| Telegram Bot | `tri-bot`, SSE streaming, ReplyKeyboardMarkup only | COMPLETE |
| Ralph Agent | Sleep-wake daemon, GitHub issue picker | COMPLETE |
| Ralph Hook | Event → Telegram notifications | COMPLETE |
| Oracle Watchdog | Health monitoring, circuit breakers | COMPLETE |
| tri-api | Claude Code replacement, 2,555 LOC, 11 files | COMPLETE |
| Railway SSH | Bridge entrypoint, cloud deploy | COMPLETE |

## Layer 3 — FPGA

**Status: 90%**

| Component | Detail | Status |
|-----------|--------|--------|
| Bitstream | `hslm_full_top.bit`, XC7A100T | COMPLETE |
| Resources | 4,267 LUT (6.7%), 135 BRAM36-eq (100%), 0 DSP48 — Yosys 0.63 verified | COMPLETE |
| Open Toolchain | openXC7 + nextpnr-xilinx + prjxray | COMPLETE |
| JTAG Programmer | Auto-flash pipeline | PLANNED |
| Runtime Inference | On-chip HSLM forward pass | PLANNED |

## Layer 4 — Cloud Dev (Agent Swarm)

**Status: COMPLETE**

| Component | Detail | Status |
|-----------|--------|--------|
| Cloud Orchestrator | `src/tri/cloud_orchestrator.zig` | COMPLETE |
| SOUL.md | Agent mission template, injected into containers | COMPLETE |
| Dockerfile.agent | Multi-stage, prebuild cached | COMPLETE |
| agent-entrypoint.sh | Auth → clone → solve → self-review → PR | COMPLETE |
| GitHub Actions | `agent-spawn.yml` + `agent-cleanup.yml` | COMPLETE |
| Cloud Monitor | HTTP + JSONL persistence | COMPLETE |
| Feedback Loop | Issue comments, Telegram alerts, dashboard | COMPLETE |
| Self-Review | Build check, format, diff size, generated files | COMPLETE |
| Agent Roles | ralph (code), scholar (research), mu (memory) | COMPLETE |
| Safety | Max 10 containers, 1h timeout, bearer auth | COMPLETE |

## Layer 5 — Research

**Status: IN PROGRESS**

| Component | Detail | Status |
|-----------|--------|--------|
| LR Sweep | v1→v5R, cosine/flat, 1e-4→1e-3 | COMPLETE |
| Zenodo | DOI 10.5281/zenodo.18950696, v2.0.3 | COMPLETE |
| HSLM Paper | `papers/hslm/draft.md` | IN PROGRESS |
| FPGA Paper | `papers/trinity-fpga/draft.md` | IN PROGRESS |
| arXiv Submission | Not yet submitted | PLANNED |
| Scaling Experiments | Beyond 1.95M params | PLANNED |

## Layer 6 — Production

**Status: PLANNED**

| Component | Detail | Status |
|-----------|--------|--------|
| Docker GHCR | Container registry for agent images | PLANNED |
| Live Spawn | First real issue → container → PR | PLANNED |
| Dashboard UI | Web-based agent monitoring | PLANNED |
| Multi-Repo | Agent swarm across repositories | PLANNED |
| Budget Guard | Railway cost limits | PLANNED |
| Agent Memory | Cross-session learning persistence | PLANNED |

## Stats Summary

| Metric | Value |
|--------|-------|
| Tests | 1,017 |
| Specs (.tri) | 442 |
| MCP Tools | 47+ |
| Skills | 15 |
| Binaries | 5 (from single build.zig) |
| GitHub Workflows | 18 |
| Zig Modules | 100+ |
| External Dependencies | 0 |
| Languages | Zig only (+ Verilog for FPGA) |

## Dependency Graph

```
Layer 6: Production
  └── Layer 5: Research
       └── Layer 4: Cloud Dev
            ├── Layer 3: FPGA
            │    └── Layer 1: HSLM
            │         └── Layer 0: Core (VSA, VM, Specs)
            └── Layer 2: Infrastructure
                 └── Layer 0: Core (VSA, VM, Specs)
```

Each layer builds on the ones below. Layer 0 is the foundation — everything depends on VSA math and ternary VM.
