# TRI Command Reference

> Auto-generated from `src/registry/command_table.zig` by `tri docs-gen`
> **DO NOT EDIT MANUALLY** — Regenerate with: `tri docs-gen`

φ² + 1/φ² = 3 | TRINITY Unified Command Registry v10.2

---

## Summary

| Interface | Commands |
|-----------|----------|
| CLI |165 |
| MCP Tools | 23 |
| API Endpoints | 120 |

---

## AI & Chat (5)

| Command | Description | MCP | API |
|---------|-------------|-----|-----|
| `chat` (c) | Interactive chat (vision + voice + tools) | - | Y |
| `code` | Generate code with typing effect | - | Y |
| `reason` | Chain-of-thought reasoning | - | Y |
| `igla` | IGLA hybrid chat | - | - |
| `math-agent` (math_agent) | Math agent | - | - |

## Sacred Math (8)

| Command | Description | MCP | API |
|---------|-------------|-----|-----|
| `math` | Sacred mathematics dispatcher | - | Y |
| `constants` (const, c) | Display sacred constants (φ, π, e, μ, χ, σ, ε) | Y | Y |
| `phi` | Compute φⁿ (golden ratio power) | Y | Y |
| `fib` (fibonacci) | Fibonacci numbers with BigInt | Y | Y |
| `lucas` | Lucas numbers (L(2)=3=TRINITY) | Y | Y |
| `spiral` | φ-spiral coordinates | Y | Y |
| `gematria` | Gematria word value calculator | Y | Y |
| `formula` | Sacred formula evaluator | - | Y |

## Sacred Science (22)

| Command | Description | MCP | API |
|---------|-------------|-----|-----|
| `bio` (biology) | Biology v14.0 — DNA/RNA/Protein sacred analysis | Y | Y |
| `cosmos` (cosmology) | Cosmology v15.0 — Universe through φ | Y | Y |
| `neuro` (neuroscience) | Neuroscience v16.0 — Brain as sacred computer | - | Y |
| `particles` (particle, pdg) | Particle physics sacred formulas (49 constants from φ) | Y | Y |
| `sacred` | Sacred mathematics utilities | - | Y |
| `music` (audio, sound) | Sacred Music v1.0 — φ-based acoustics | - | Y |
| `frequency` (freq, note-freq) | Calculate frequency from note | - | Y |
| `scale` | Display musical scale notes and frequencies | - | - |
| `chord` | Analyze chord harmonics | - | - |
| `resonance` (res) | Calculate resonance patterns | - | - |
| `waveform` (wave, osc) | Generate waveform samples | - | - |
| `harmony` | Analyze harmonic relationship between frequencies | - | - |
| `phi-series` (phi-freq, phi-frequencies) | Show φ frequency series | - | - |
| `sacred-full-cycle` (sacred_full_cycle) | Sacred full cycle | - | - |
| `quantum` | Quantum Trinity | Y | Y |
| `release-cosmic` (release_cosmic) | Release cosmic energy | - | - |
| `omega-cmd` (omega_cmd) | Omega command | - | - |
| `all-cmd` (all_cmd) | All command | - | - |
| `holo-cmd` (holo_cmd) | Holo command | - | - |
| `release-absolute` (release_absolute) | Release absolute | - | - |
| `omega-evolve` (omega_evolve) | Omega evolve | - | - |
| `conscious` (consciousness) | Consciousness awakening simulator (IIT+GWT+OrchOR+Qutrit+ActiveInf) | Y | Y |

## Sacred Intelligence (5)

| Command | Description | MCP | API |
|---------|-------------|-----|-----|
| `intelligence` | Sacred Intelligence system | - | Y |
| `identity` | Sacred identity | Y | Y |
| `swarm` | Sacred swarm intelligence | Y | Y |
| `govern` | Sacred governance | Y | Y |
| `omega` | Omega phase | Y | Y |

## Development (20)

| Command | Description | MCP | API |
|---------|-------------|-----|-----|
| `fix` | Detect and fix bugs | - | Y |
| `explain` (exp) | Explain code or concept | - | Y |
| `test` | Generate tests | - | Y |
| `doc` (document) | Generate documentation | - | Y |
| `refactor` | Suggest refactoring | - | Y |
| `spec-create` (spec_create) | Create .vibee spec template (Link 6) | - | Y |
| `verify` | Run tests + benchmarks (Links 7-11) | - | Y |
| `gen` (generate) | Compile VIBEE spec to Zig/Verilog | - | Y |
| `convert` | Convert between formats | - | Y |
| `serve` (server) | Start HTTP server | - | Y |
| `analyze` | Analyze codebase structure | - | Y |
| `search` (search-cmd) | Search codebase | - | Y |
| `fmt` (format) | Format code | - | - |
| `research` (audit, analyze-code) | Research: idempotency audit, duplication check | - | - |
| `build` (build-cmd) | Build project | - | - |
| `deck` (deck-generate) | Generate flash deck | - | - |
| `needle` | Structural editor core | Y | Y |
| `needle-search` (needle_search) | Needle search | Y | Y |
| `needle-check` (needle_check) | Needle check | Y | Y |
| `test-repl` (test_repl) | Test REPL (Cycle 101) | - | - |

## Git (4)

| Command | Description | MCP | API |
|---------|-------------|-----|-----|
| `commit` | Git add -A && commit | - | Y |
| `diff` | Git diff | - | Y |
| `status` (st) | Git status --short | - | Y |
| `log` | Git log --oneline -10 | - | Y |

## System (13)

| Command | Description | MCP | API |
|---------|-------------|-----|-----|
| `tvc-stats` | Show TVC corpus statistics | - | - |
| `context-info` (context_info) | Show codebase context info | - | - |
| `doctor` | Check system health | - | Y |
| `clean` | Clean build artifacts | - | - |
| `stats` (stats-cmd) | Show code statistics | - | - |
| `dashboard` | Sacred dashboard | Y | - |
| `install` | Install dependencies | - | - |
| `deps` | Show dependencies | - | - |
| `info` | System information | - | Y |
| `version` (v, --version) | Show version | - | - |
| `docs-gen` (docs_gen, docgen) | Generate CLI reference documentation | - | - |
| `completion` | Generate shell completion scripts | - | - |
| `help` (h, ?) | Show help information | - | - |

## Demos (38)

| Command | Description | MCP | API |
|---------|-------------|-----|-----|
| `pipeline-demo` | Pipeline demo — show Golden Chain workflow | - | - |
| `tvc-demo` | Run TVC chat demo | - | - |
| `agents-demo` | Multi-Agent coordination demo | - | Y |
| `context-demo` | Long context sliding window demo | - | Y |
| `rag-demo` | Retrieval-Augmented Generation demo | - | Y |
| `voice-demo` | Voice I/O (STT+TTS) demo | - | Y |
| `sandbox-demo` | Code execution sandbox demo | - | Y |
| `stream-demo` | Streaming multi-modal pipeline demo | - | Y |
| `vision-demo` | Local vision demo | - | Y |
| `finetune-demo` | Fine-tuning engine demo | - | Y |
| `batched-demo` | Batched stealing demo | - | - |
| `priority-demo` | Priority queue demo | - | - |
| `deadline-demo` | Deadline scheduling demo | - | - |
| `multimodal-demo` | Multi-modal unified demo | - | Y |
| `tooluse-demo` | Multi-modal tool use demo | - | Y |
| `unified-demo` | Unified multi-modal agent demo | - | Y |
| `autonomous-demo` | Autonomous agent demo | - | Y |
| `orchestration-demo` | Multi-agent orchestration demo | - | Y |
| `mm-orch-demo` | MM multi-agent orchestration demo | - | Y |
| `memory-demo` | Agent memory & cross-modal learning demo | - | Y |
| `persist-demo` | Persistent memory & disk serialization demo | - | Y |
| `spawn-demo` | Dynamic agent spawning demo | - | Y |
| `cluster-demo` | Distributed multi-node agents demo | - | Y |
| `worksteal-demo` | Adaptive work-stealing scheduler demo | - | Y |
| `plugin-demo` | Plugin & extension system demo | - | Y |
| `comms-demo` | Agent communication protocol demo | - | Y |
| `observe-demo` | Observability & tracing demo | - | Y |
| `consensus-demo` | Consensus & coordination demo | - | Y |
| `specexec-demo` | Speculative execution engine demo | - | Y |
| `governor-demo` | Adaptive resource governor demo | - | Y |
| `fedlearn-demo` | Federated learning protocol demo | - | Y |
| `eventsrc-demo` | Event sourcing & CQRS engine demo | - | Y |
| `capsec-demo` | Capability-based security demo | - | Y |
| `dtxn-demo` | Distributed transaction coordinator demo | - | Y |
| `cache-demo` | Adaptive caching & memoization demo | - | Y |
| `contract-demo` | Contract-based agent negotiation demo | - | Y |
| `workflow-demo` | Temporal workflow engine demo | - | Y |
| `fpga-demo` (fpga_demo) | FPGA demo | - | - |

## Benchmarks (36)

| Command | Description | MCP | API |
|---------|-------------|-----|-----|
| `bench` (benchmark) | Run performance benchmarks | - | Y |
| `agents-bench` | Multi-Agent coordination benchmark | - | Y |
| `context-bench` | Long context benchmark | - | Y |
| `rag-bench` | RAG benchmark | - | Y |
| `voice-bench` | Voice I/O benchmark | - | Y |
| `sandbox-bench` | Sandbox benchmark | - | Y |
| `stream-bench` | Streaming benchmark | - | Y |
| `vision-bench` | Vision benchmark | - | Y |
| `finetune-bench` | Fine-tuning benchmark | - | Y |
| `batched-bench` | Batched stealing benchmark | - | - |
| `priority-bench` | Priority queue benchmark | - | - |
| `deadline-bench` | Deadline scheduling benchmark | - | - |
| `multimodal-bench` | Multi-modal unified benchmark | - | Y |
| `tooluse-bench` | Tool use benchmark | - | Y |
| `unified-bench` | Unified agent benchmark | - | Y |
| `autonomous-bench` | Autonomous agent benchmark | - | Y |
| `orchestration-bench` | Orchestration benchmark | - | Y |
| `mm-orch-bench` | MM orchestration benchmark | - | Y |
| `memory-bench` | Memory benchmark | - | Y |
| `persist-bench` | Persistent memory benchmark | - | Y |
| `spawn-bench` | Spawn benchmark | - | Y |
| `cluster-bench` | Cluster benchmark | - | Y |
| `worksteal-bench` | Work-stealing benchmark | - | Y |
| `plugin-bench` | Plugin benchmark | - | Y |
| `comms-bench` | Communication benchmark | - | Y |
| `observe-bench` | Observability benchmark | - | Y |
| `consensus-bench` | Consensus benchmark | - | Y |
| `specexec-bench` | Speculative execution benchmark | - | Y |
| `governor-bench` | Governor benchmark | - | Y |
| `fedlearn-bench` | Federated learning benchmark | - | Y |
| `eventsrc-bench` | Event sourcing benchmark | - | Y |
| `capsec-bench` | Capability security benchmark | - | Y |
| `dtxn-bench` | DTXN benchmark | - | Y |
| `cache-bench` | Caching benchmark | - | Y |
| `contract-bench` | Contract negotiation benchmark | - | Y |
| `workflow-bench` | Workflow benchmark | - | Y |

## Advanced (10)

| Command | Description | MCP | API |
|---------|-------------|-----|-----|
| `pipeline` | Execute 22-link Golden Chain v4.0 | - | Y |
| `decompose` | Break task into sub-tasks (Link 4) | - | Y |
| `plan` | Generate implementation plan (Link 5) | - | Y |
| `loop-decide` (loop_decide) | Loop decision: CONTINUE/EXIT (Link 17) | - | - |
| `verdict` | Generate toxic verdict (Link 14) | - | - |
| `evolve` | Evolve system | - | - |
| `distributed` | Distributed inference | - | Y |
| `multi-cluster` (multi_cluster) | Multi-cluster orchestration | - | Y |
| `time` | Temporal engine | - | - |
| `launch` | Launch TRINITY OS | - | - |

## DePIN (4)

| Command | Description | MCP | API |
|---------|-------------|-----|-----|
| `wallet` | Wallet management — connect, balance, claim rewards | Y | Y |
| `mesh` | Global mesh management — status, topology, discovery | Y | Y |
| `reputation` (rep) | Reputation system — show node reputation, leaderboard | Y | Y |
| `hardware` | Hardware deployment — deploy, status, stop nodes | Y | Y |

---

## MCP Tools

| Tool Name | Display Name | Description |
|-----------|--------------|-------------|
| `tri_bio_dna` | DNA Analysis | Biology v14.0 — DNA/RNA/Protein sacred analysis |
| `tri_cosmos_hubble` | Hubble Tension | Cosmology v15.0 — Universe through φ |
| `tri_constants` | Sacred Constants | Display sacred constants (φ, π, e, μ, χ, σ, ε) |
| `tri_phi` | Phi Power | Compute φⁿ (golden ratio power) |
| `tri_fib` | Fibonacci | Fibonacci numbers with BigInt |
| `tri_lucas` | Lucas Numbers | Lucas numbers (L(2)=3=TRINITY) |
| `tri_spiral` | Phi Spiral | φ-spiral coordinates |
| `tri_gematria` | Gematria | Gematria word value calculator |
| `tri_particles` | Particle Physics Sacred | Particle physics sacred formulas (49 constants from φ) |
| `tri_identity` | Sacred Identity | Sacred identity |
| `tri_swarm` | Swarm Intelligence | Sacred swarm intelligence |
| `tri_govern` | Governance System | Sacred governance |
| `tri_dashboard_serve` | Dashboard Server | Sacred dashboard |
| `tri_omega_status` | Omega Status | Omega phase |
| `tri_wallet_balance` | Wallet Balance | Wallet management — connect, balance, claim rewards |
| `tri_mesh_status` | Mesh Status | Global mesh management — status, topology, discovery |
| `tri_omega_reputation` | Reputation Leaderboard | Reputation system — show node reputation, leaderboard |
| `tri_hardware_info` | Hardware Info | Hardware deployment — deploy, status, stop nodes |
| `tri_quantum_constants` | Quantum Constants | Quantum Trinity |
| `tri_consciousness` | Consciousness Simulator | Consciousness awakening simulator (IIT+GWT+OrchOR+Qutrit+ActiveInf) |
| `tri_needle` | Needle Editor | Structural editor core |
| `tri_needle_search` | Needle Search | Needle search |
| `tri_needle_check` | Needle Check | Needle check |

---

## API Endpoints

| Endpoint | Description | Protocols |
|----------|-------------|-----------|
| `/api/bio` | Biology v14.0 — DNA/RNA/Protein sacred analysis | REST, GRAPHQL |
| `/api/cosmos` | Cosmology v15.0 — Universe through φ | REST, GRAPHQL |
| `/api/neuro` | Neuroscience v16.0 — Brain as sacred computer | REST, GRAPHQL |
| `/api/math` | Sacred mathematics dispatcher | REST, GRAPHQL |
| `/api/constants` | Display sacred constants (φ, π, e, μ, χ, σ, ε) | REST, GRAPHQL, GRPC, WEBSOCKET |
| `/api/phi` | Compute φⁿ (golden ratio power) | REST, GRAPHQL, GRPC, WEBSOCKET |
| `/api/fib` | Fibonacci numbers with BigInt | REST, GRAPHQL, GRPC, WEBSOCKET |
| `/api/lucas` | Lucas numbers (L(2)=3=TRINITY) | REST, GRAPHQL, GRPC, WEBSOCKET |
| `/api/spiral` | φ-spiral coordinates | REST, GRAPHQL |
| `/api/gematria` | Gematria word value calculator | REST, GRAPHQL |
| `/api/formula` | Sacred formula evaluator | REST, GRAPHQL |
| `/api/particles` | Particle physics sacred formulas (49 constants from φ) | REST, GRAPHQL |
| `/api/sacred` | Sacred mathematics utilities | REST, GRAPHQL |
| `/api/music` | Sacred Music v1.0 — φ-based acoustics | REST, GRAPHQL |
| `/api/frequency` | Calculate frequency from note | REST, GRAPHQL |
| `/api/chat` | Interactive chat (vision + voice + tools) | REST, GRAPHQL, GRPC, WEBSOCKET |
| `/api/code` | Generate code with typing effect | REST, GRAPHQL |
| `/api/fix` | Detect and fix bugs | REST, GRAPHQL |
| `/api/explain` | Explain code or concept | REST, GRAPHQL |
| `/api/test` | Generate tests | REST, GRAPHQL |
| `/api/doc` | Generate documentation | REST, GRAPHQL |
| `/api/refactor` | Suggest refactoring | REST, GRAPHQL |
| `/api/reason` | Chain-of-thought reasoning | REST, GRAPHQL |
| `/api/commit` | Git add -A && commit | REST |
| `/api/diff` | Git diff | REST |
| `/api/status` | Git status --short | REST |
| `/api/log` | Git log --oneline -10 | REST |
| `/api/pipeline` | Execute 22-link Golden Chain v4.0 | REST, GRAPHQL |
| `/api/decompose` | Break task into sub-tasks (Link 4) | REST, GRAPHQL |
| `/api/plan` | Generate implementation plan (Link 5) | REST, GRAPHQL |
| `/api/spec-create` | Create .vibee spec template (Link 6) | REST, GRAPHQL |
| `/api/verify` | Run tests + benchmarks (Links 7-11) | REST |
| `/api/gen` | Compile VIBEE spec to Zig/Verilog | REST, GRAPHQL |
| `/api/convert` | Convert between formats | REST |
| `/api/serve` | Start HTTP server | REST |
| `/api/bench` | Run performance benchmarks | REST, GRAPHQL |
| `/api/agents-demo` | Multi-Agent coordination demo | REST |
| `/api/agents-bench` | Multi-Agent coordination benchmark | REST |
| `/api/context-demo` | Long context sliding window demo | REST |
| `/api/context-bench` | Long context benchmark | REST |
| `/api/rag-demo` | Retrieval-Augmented Generation demo | REST |
| `/api/rag-bench` | RAG benchmark | REST |
| `/api/voice-demo` | Voice I/O (STT+TTS) demo | REST |
| `/api/voice-bench` | Voice I/O benchmark | REST |
| `/api/sandbox-demo` | Code execution sandbox demo | REST |
| `/api/sandbox-bench` | Sandbox benchmark | REST |
| `/api/stream-demo` | Streaming multi-modal pipeline demo | REST |
| `/api/stream-bench` | Streaming benchmark | REST |
| `/api/vision-demo` | Local vision demo | REST |
| `/api/vision-bench` | Vision benchmark | REST |
| `/api/finetune-demo` | Fine-tuning engine demo | REST |
| `/api/finetune-bench` | Fine-tuning benchmark | REST |
| `/api/multimodal-demo` | Multi-modal unified demo | REST |
| `/api/multimodal-bench` | Multi-modal unified benchmark | REST |
| `/api/tooluse-demo` | Multi-modal tool use demo | REST |
| `/api/tooluse-bench` | Tool use benchmark | REST |
| `/api/unified-demo` | Unified multi-modal agent demo | REST |
| `/api/unified-bench` | Unified agent benchmark | REST |
| `/api/autonomous-demo` | Autonomous agent demo | REST |
| `/api/autonomous-bench` | Autonomous agent benchmark | REST |
| `/api/orchestration-demo` | Multi-agent orchestration demo | REST |
| `/api/orchestration-bench` | Orchestration benchmark | REST |
| `/api/mm-orch-demo` | MM multi-agent orchestration demo | REST |
| `/api/mm-orch-bench` | MM orchestration benchmark | REST |
| `/api/memory-demo` | Agent memory & cross-modal learning demo | REST |
| `/api/memory-bench` | Memory benchmark | REST |
| `/api/persist-demo` | Persistent memory & disk serialization demo | REST |
| `/api/persist-bench` | Persistent memory benchmark | REST |
| `/api/spawn-demo` | Dynamic agent spawning demo | REST |
| `/api/spawn-bench` | Spawn benchmark | REST |
| `/api/cluster-demo` | Distributed multi-node agents demo | REST |
| `/api/cluster-bench` | Cluster benchmark | REST |
| `/api/worksteal-demo` | Adaptive work-stealing scheduler demo | REST |
| `/api/worksteal-bench` | Work-stealing benchmark | REST |
| `/api/plugin-demo` | Plugin & extension system demo | REST |
| `/api/plugin-bench` | Plugin benchmark | REST |
| `/api/comms-demo` | Agent communication protocol demo | REST |
| `/api/comms-bench` | Communication benchmark | REST |
| `/api/observe-demo` | Observability & tracing demo | REST |
| `/api/observe-bench` | Observability benchmark | REST |
| `/api/consensus-demo` | Consensus & coordination demo | REST |
| `/api/consensus-bench` | Consensus benchmark | REST |
| `/api/specexec-demo` | Speculative execution engine demo | REST |
| `/api/specexec-bench` | Speculative execution benchmark | REST |
| `/api/governor-demo` | Adaptive resource governor demo | REST |
| `/api/governor-bench` | Governor benchmark | REST |
| `/api/fedlearn-demo` | Federated learning protocol demo | REST |
| `/api/fedlearn-bench` | Federated learning benchmark | REST |
| `/api/eventsrc-demo` | Event sourcing & CQRS engine demo | REST |
| `/api/eventsrc-bench` | Event sourcing benchmark | REST |
| `/api/capsec-demo` | Capability-based security demo | REST |
| `/api/capsec-bench` | Capability security benchmark | REST |
| `/api/dtxn-demo` | Distributed transaction coordinator demo | REST |
| `/api/dtxn-bench` | DTXN benchmark | REST |
| `/api/cache-demo` | Adaptive caching & memoization demo | REST |
| `/api/cache-bench` | Caching benchmark | REST |
| `/api/contract-demo` | Contract-based agent negotiation demo | REST |
| `/api/contract-bench` | Contract negotiation benchmark | REST |
| `/api/workflow-demo` | Temporal workflow engine demo | REST |
| `/api/workflow-bench` | Workflow benchmark | REST |
| `/api/distributed` | Distributed inference | REST, GRAPHQL |
| `/api/multi-cluster` | Multi-cluster orchestration | REST, GRAPHQL |
| `/api/analyze` | Analyze codebase structure | REST, GRAPHQL |
| `/api/search` | Search codebase | REST, GRAPHQL |
| `/api/intelligence` | Sacred Intelligence system | REST, GRAPHQL |
| `/api/doctor` | Check system health | REST |
| `/api/identity` | Sacred identity | REST, GRAPHQL |
| `/api/swarm` | Sacred swarm intelligence | REST, GRAPHQL |
| `/api/govern` | Sacred governance | REST, GRAPHQL |
| `/api/omega` | Omega phase | REST, GRAPHQL |
| `/api/wallet` | Wallet management — connect, balance, claim rewards | REST, GRAPHQL |
| `/api/mesh` | Global mesh management — status, topology, discovery | REST, GRAPHQL |
| `/api/reputation` | Reputation system — show node reputation, leaderboard | REST, GRAPHQL |
| `/api/hardware` | Hardware deployment — deploy, status, stop nodes | REST, GRAPHQL |
| `/api/quantum` | Quantum Trinity | REST, GRAPHQL |
| `/api/conscious` | Consciousness awakening simulator (IIT+GWT+OrchOR+Qutrit+ActiveInf) | REST, GRAPHQL |
| `/api/needle` | Structural editor core | REST, GRAPHQL |
| `/api/needle-search` | Needle search | REST, GRAPHQL |
| `/api/needle-check` | Needle check | REST, GRAPHQL |
| `/api/info` | System information | REST |
