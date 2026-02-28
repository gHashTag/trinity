# TRI CLI Commands Reference (v8.27 - STRICT MODE)

**TRI** is the Unified Trinity Command Line Interface — the primary orchestrator for all development workflows.

```bash
# Build and run
zig build tri                    # Build TRI binary
./zig-out/bin/tri                # Interactive REPL mode
./zig-out/bin/tri <command>      # Run specific command
./zig-out/bin/tri help           # Show all commands
```

---

## Core Commands (Link 1-6)

| Command | Aliases | Description | Link |
|---------|---------|-------------|------|
| `tri chat [--stream] <msg>` | - | Interactive chat (vision + voice + tools) | - |
| `tri code [--stream] <prompt>` | - | Generate code with typing effect | - |
| `tri gen <spec.vibee>` | - | Compile VIBEE spec to Zig/Verilog | - |
| `tri pipeline run <task>` | `chain` | Execute 17-link Golden Chain (incl TVC) | 0-17 |
| `tri decompose <task>` | - | Break task into sub-tasks (Link 4) | 4 |
| `tri plan <task>` | - | Generate implementation plan (Link 5) | 5 |
| `tri spec_create <name>` | `spec-create` | Create .vibee spec template (Link 6) | 6 |
| `tri loop-decide [mode]` | `loop_decide` | Loop decision: CONTINUE/EXIT (Link 17) | 17 |

---

## Verification Commands (Link 7-13)

| Command | Description |
|---------|-------------|
| `tri verify` | Run tests + benchmarks (Links 7-11) |
| `tri bench` | Run performance benchmarks |
| `tri verdict` | Generate toxic verdict (Link 14) |

---

## SWE Agent Commands

| Command | Description |
|---------|-------------|
| `tri fix <file>` | Detect and fix bugs |
| `tri explain <file\|prompt>` | Explain code or concept |
| `tri test <file>` | Generate tests |
| `tri doc <file>` | Generate documentation |
| `tri refactor <file>` | Suggest refactoring |
| `tri reason <prompt>` | Chain-of-thought reasoning |

---

## Git Commands

| Command | Description |
|---------|-------------|
| `tri status` | Git status --short |
| `tri diff` | Git diff |
| `tri log` | Git log --oneline -10 |
| `tri commit <message>` | Git add -A && commit |

---

## Tools

| Command | Description |
|---------|-------------|
| `tri convert <file>` | Convert WASM/Binary → Ternary |
| `tri serve --model <path>` | Start HTTP API server |
| `tri bench` | Run performance benchmarks |
| `tri evolve [--dim N]` | Evolve fingerprint (Firebird) |

---

## TVC (Distributed Learning)

| Command | Aliases | Description |
|---------|---------|-------------|
| `tri tvc-demo` | `tvc` | Run TVC chat demo (distributed learning) |
| `tri tvc-stats` | - | Show TVC corpus statistics |

---

## Demo & Benchmark Commands

Each cycle has `-demo` and `-bench` variants for running demonstrations and performance benchmarks.

| Cycle | Demo Commands | Bench Commands | Description |
|-------|---------------|----------------|-------------|
| **Multi-Agent** | `agents-demo`, `agents` | `agents-bench` | Coordination |
| **Long Context** | `context-demo`, `context` | `context-bench` | Sliding window |
| **RAG** | `rag-demo`, `rag` | `rag-bench` | Retrieval |
| **Voice I/O** | `voice-demo`, `voice`, `mic` | `voice-bench`, `mic-bench` | STT+TTS |
| **Code Sandbox** | `sandbox-demo`, `sandbox` | `sandbox-bench` | Safe execution |
| **Streaming** (Cycle 38) | `stream-demo`, `stream`, `pipeline` | `stream-bench` | Multi-modal pipeline |
| **Vision** (Cycle 28) | `vision-demo`, `vision`, `eye` | `vision-bench`, `eye-bench` | Image analysis |
| **Fine-tuning** | `finetune-demo`, `finetune` | `finetune-bench` | Model adaptation |
| **Multi-Modal** (Cycle 26) | `multimodal-demo`, `multimodal`, `mm` | `multimodal-bench`, `mm-bench` | Unified |
| **Tool Use** (Cycle 27) | `tooluse-demo`, `tooluse`, `tools` | `tooluse-bench`, `tools-bench` | Tools from any modality |
| **Unified Agent** (Cycle 30) | `unified-demo`, `unified`, `agent` | `unified-bench`, `agent-bench` | All capabilities |
| **Autonomous** (Cycle 31) | `auto-demo`, `auto`, `autonomous` | `auto-bench`, `autonomous-bench` | Self-directed |
| **Orchestration** (Cycle 32) | `orch-demo`, `orch`, `orchestrate` | `orch-bench`, `orchestrate-bench` | Coordinator+specialists |
| **MM Orchestration** (Cycle 33) | `mmo-demo`, `mmo`, `mm-orch` | `mmo-bench`, `mm-orch-bench` | Multi-modal agents |
| **Memory** (Cycle 34) | `memory-demo`, `memory`, `mem` | `memory-bench`, `mem-bench` | Cross-modal learning |
| **Persistent** (Cycle 35) | `persist-demo`, `persist`, `save` | `persist-bench`, `save-bench` | Disk serialization |
| **Spawn** (Cycle 36) | `spawn-demo`, `spawn`, `pool` | `spawn-bench`, `pool-bench` | Dynamic agents |
| **Cluster** (Cycle 37) | `cluster-demo`, `cluster`, `nodes` | `cluster-bench`, `nodes-bench` | Multi-node |
| **Work-Stealing** (Cycle 39) | `worksteal-demo`, `worksteal`, `steal` | `worksteal-bench`, `steal-bench` | Adaptive scheduler |
| **Plugin** (Cycle 40) | `plugin-demo`, `plugin`, `ext` | `plugin-bench`, `ext-bench` | Extension system |
| **Comms** (Cycle 41) | `comms-demo`, `comms`, `msg` | `comms-bench`, `msg-bench` | Communication protocol |
| **Observe** (Cycle 42) | `observe-demo`, `observe`, `otel` | `observe-bench`, `otel-bench` | Observability |
| **Consensus** (Cycle 43) | `consensus-demo`, `consensus`, `raft` | `consensus-bench`, `raft-bench` | Coordination |
| **Spec Exec** (Cycle 44) | `specexec-demo`, `specexec`, `spec` | `specexec-bench`, `spec-bench` | Speculative execution |
| **Governor** (Cycle 45) | `governor-demo`, `governor`, `gov` | `governor-bench`, `gov-bench` | Resource governor |
| **Fed Learn** (Cycle 46) | `fedlearn-demo`, `fedlearn`, `fl` | `fedlearn-bench`, `fl-bench` | Federated learning |
| **Event Src** (Cycle 47) | `eventsrc-demo`, `eventsrc`, `es` | `eventsrc-bench`, `es-bench` | Event sourcing |
| **Cap Sec** (Cycle 48) | `capsec-demo`, `capsec`, `sec` | `capsec-bench`, `sec-bench` | Capability security |
| **DTXN** (Cycle 49) | `dtxn-demo`, `dtxn`, `txn` | `dtxn-bench`, `txn-bench` | Distributed transactions |
| **Cache** (Cycle 50) | `cache-demo`, `cache`, `memo` | `cache-bench`, `memo-bench` | Adaptive caching |
| **Contract** (Cycle 51) | `contract-demo`, `contract`, `sla` | `contract-bench`, `sla-bench` | Agent negotiation |
| **Workflow** (Cycle 52) | `workflow-demo`, `workflow`, `wf` | `workflow-bench`, `wf-bench` | Temporal workflows |

---

## Sacred Mathematics (v2.0)

| Command | Description |
|---------|-------------|
| `tri math` | Sacred math dispatcher |
| `tri constants` | Show φ, π, e, μ, χ, σ, ε... |
| `tri phi <n>` | Compute φⁿ |
| `tri fib <n>` | Fibonacci with BigInt |
| `tri lucas <n>` | Lucas L(n) — L(2)=3=TRINITY |
| `tri spiral <n>` | φ-spiral coordinates |

---

## Info Commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `tri info` | - | System information |
| `tri version` | `--version`, `-v` | Show version |
| `tri help` | `--help`, `-h` | This help message |

---

## REPL Commands (Interactive Mode)

When running `tri` without arguments, you enter interactive REPL mode:

| Command | Description |
|---------|-------------|
| `/chat` | Switch to Chat mode |
| `/code` | Switch to Code Generation mode |
| `/fix` | Switch to Bug Fix mode |
| `/explain` | Switch to Explain mode |
| `/test` | Switch to Test Generation mode |
| `/doc` | Switch to Documentation mode |
| `/reason` | Switch to Chain-of-Thought mode |
| `/zig` | Set language to Zig |
| `/python` | Set language to Python |
| `/rust` | Set language to Rust |
| `/js` | Set language to JavaScript |
| `/stats` | Show session statistics |
| `/verbose` | Toggle verbose output |
| `/help` | Show REPL help |
| `/quit` | Exit REPL |

---

## Sacred Logging

All TRI CLI calls are logged to `trinity-nexus/.ralph/sacred_tool_calls.log`:

```
[φ] 1 | tri spec-create test_module
[φ] 2 | tri loop-decide auto
```

---

## Multilingual Support

TRI CLI auto-detects and responds in multiple languages:

```bash
tri code "onпandшand фунtoцandю фandбоonччand"    # Russian
tri code "写一个斐波那契函数"           # Chinese
tri code "write fibonacci function"   # English
```

---

**φ² + 1/φ² = 3 = TRINITY**
