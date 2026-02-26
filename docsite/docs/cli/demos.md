---
sidebar_position: 10
sidebar_label: Demos & Benchmarks
---

# Demos & Benchmarks

36 demo/benchmark pairs covering AI, agents, distributed systems, security, and more. Each feature has a `-demo` command (interactive demonstration) and a `-bench` command (performance benchmark).

## Running Demos

```bash
tri <name>-demo                         # Run interactive demo
tri <name>-bench                        # Run benchmark
```

## Pre-Cycle Demos

Early features implemented before the numbered cycle system.

| Command | Aliases | Description |
|---------|---------|-------------|
| `tri tvc-demo` | `tvc` | TVC Distributed Chat — 10,000-entry ternary vector corpus |
| `tri tvc-stats` | — | TVC corpus configuration and status |
| `tri agents-demo` | `agents` | Multi-Agent Coordination — Coordinator, Coder, Chat, Reasoner, Researcher |
| `tri agents-bench` | — | Multi-Agent System Benchmark — 10 task scenarios |
| `tri context-demo` | `context` | Long Context Engine — sliding window (20 messages) + summarization |
| `tri context-bench` | — | Long Context Benchmark — 24-turn conversation simulation |
| `tri rag-demo` | `rag` | RAG — Query → Embed → Retrieve → Augment → Generate |
| `tri rag-bench` | — | RAG Retrieval Benchmark — similarity scoring |
| `tri voice-demo` | `voice`, `mic` | Voice I/O (TTS + STT) integration |
| `tri voice-bench` | `mic-bench` | Voice I/O performance benchmark |
| `tri sandbox-demo` | `sandbox` | Code Execution Sandbox — safe execution with 5s timeout |
| `tri sandbox-bench` | — | Sandbox Benchmark — Zig, Python, JS, Shell execution |
| `tri stream-demo` | `stream`, `pipeline` | Streaming Output — token-by-token with 256-token buffer |
| `tri stream-bench` | `pipeline-bench` | Streaming Benchmark — char/token/chunk/SSE modes |
| `tri finetune-demo` | `finetune` | Fine-Tuning Engine — local model adaptation |
| `tri finetune-bench` | — | Fine-Tuning Benchmark — learning rate convergence |
| `tri batched-demo` | `batched` | Batched Work-Stealing — parallel batch scheduler |
| `tri batched-bench` | — | Batched Stealing Benchmark — throughput/latency |
| `tri priority-demo` | `priority` | Priority Queue — task scheduling |
| `tri priority-bench` | — | Priority Queue Benchmark |
| `tri deadline-demo` | `deadline` | Deadline Scheduling — SLA enforcement |
| `tri deadline-bench` | — | Deadline Scheduling Benchmark |

## Cycle 20: Vision

| Command | Aliases | Description |
|---------|---------|-------------|
| `tri vision-demo` | `vision`, `eye` | Local Vision — image → ternary embedding → scene detection → caption |
| `tri vision-bench` | `eye-bench` | Vision Benchmark — 80 COCO semantic categories |

## Cycle 26: Multi-Modal

| Command | Aliases | Description |
|---------|---------|-------------|
| `tri multimodal-demo` | `multimodal`, `mm` | Multi-Modal Unified Engine — text + vision + voice + code → VSA |
| `tri multimodal-bench` | `mm-bench` | Multi-Modal Benchmark — cross-modal fusion |

## Cycle 27: Tool Use

| Command | Aliases | Description |
|---------|---------|-------------|
| `tri tooluse-demo` | `tooluse`, `tools` | Multi-Modal Tool Use — function calling with multi-modal inputs |
| `tri tooluse-bench` | `tools-bench` | Tool Use Benchmark — invocation and result handling |

## Cycle 30-33: Unified Agents

| Command | Aliases | Cycle | Description |
|---------|---------|-------|-------------|
| `tri unified-demo` | `unified`, `agent` | 30 | Unified Multi-Modal Agent — all modalities in single agent |
| `tri unified-bench` | `agent-bench` | 30 | Unified Agent Benchmark |
| `tri autonomous-demo` | `auto`, `autonomous` | 31 | Autonomous Agent — self-directed with goal planning |
| `tri autonomous-bench` | `autonomous-bench` | 31 | Autonomous Agent Benchmark |
| `tri orchestration-demo` | `orch`, `orchestrate` | 32 | Multi-Agent Orchestration — task distribution |
| `tri orchestration-bench` | `orchestrate-bench` | 32 | Orchestration Benchmark |
| `tri mm-orch-demo` | `mmo`, `mm-orch` | 33 | MM Multi-Agent Orchestration — multi-modal coordination |
| `tri mm-orch-bench` | `mm-orch-bench` | 33 | MM Orchestration Benchmark |

## Cycle 34-37: Memory & Distribution

| Command | Aliases | Cycle | Description |
|---------|---------|-------|-------------|
| `tri memory-demo` | `memory`, `mem` | 34 | Agent Memory & Cross-Modal Learning |
| `tri memory-bench` | `mem-bench` | 34 | Memory Benchmark |
| `tri persist-demo` | `persist`, `save` | 35 | Persistent Memory & Disk Serialization |
| `tri persist-bench` | `save-bench` | 35 | Persistence Benchmark — I/O performance |
| `tri spawn-demo` | `spawn`, `pool` | 36 | Dynamic Agent Spawning & Load Balancing |
| `tri spawn-bench` | `pool-bench` | 36 | Spawn Benchmark — spawn latency |
| `tri cluster-demo` | `cluster`, `nodes` | 37 | Distributed Multi-Node Agents |
| `tri cluster-bench` | `nodes-bench` | 37 | Cluster Benchmark — network latency/throughput |

## Cycle 39-45: Scheduling & Plugins

| Command | Aliases | Cycle | Description |
|---------|---------|-------|-------------|
| `tri worksteal-demo` | `worksteal`, `steal` | 39 | Adaptive Work-Stealing Scheduler |
| `tri worksteal-bench` | `steal-bench` | 39 | Work-Stealing Benchmark |
| `tri plugin-demo` | `plugin`, `ext` | 40 | Plugin & Extension System |
| `tri plugin-bench` | `ext-bench` | 40 | Plugin Benchmark |
| `tri comms-demo` | `comms`, `msg` | 41 | Agent Communication Protocol |
| `tri comms-bench` | `msg-bench` | 41 | Communication Benchmark — message throughput |
| `tri observe-demo` | `observe`, `otel` | 42 | Observability & Tracing System |
| `tri observe-bench` | `otel-bench` | 42 | Observability Benchmark — tracing overhead |
| `tri consensus-demo` | `consensus`, `raft` | 43 | Consensus & Coordination Protocol (Byzantine-tolerant) |
| `tri consensus-bench` | `raft-bench` | 43 | Consensus Benchmark |
| `tri specexec-demo` | `specexec`, `spec` | 44 | Speculative Execution Engine |
| `tri specexec-bench` | `spec-bench` | 44 | Speculative Execution Benchmark |
| `tri governor-demo` | `governor`, `gov` | 45 | Adaptive Resource Governor |
| `tri governor-bench` | `gov-bench` | 45 | Resource Governor Benchmark |

## Cycle 46-52: Advanced Systems

| Command | Aliases | Cycle | Description |
|---------|---------|-------|-------------|
| `tri fedlearn-demo` | `fedlearn`, `fl` | 46 | Federated Learning Protocol |
| `tri fedlearn-bench` | `fl-bench` | 46 | Federated Learning Benchmark — convergence |
| `tri eventsrc-demo` | `eventsrc`, `es` | 47 | Event Sourcing & CQRS Engine |
| `tri eventsrc-bench` | `es-bench` | 47 | Event Sourcing Benchmark — event throughput |
| `tri capsec-demo` | `capsec`, `sec` | 48 | Capability-Based Security Model |
| `tri capsec-bench` | `sec-bench` | 48 | Security Benchmark — authorization overhead |
| `tri dtxn-demo` | `dtxn`, `txn` | 49 | Distributed Transaction Coordinator (ACID) |
| `tri dtxn-bench` | `txn-bench` | 49 | Transaction Benchmark — throughput |
| `tri cache-demo` | `cache`, `memo` | 50 | Adaptive Caching & Memoization |
| `tri cache-bench` | `memo-bench` | 50 | Cache Benchmark — hit rates |
| `tri contract-demo` | `contract`, `sla` | 51 | Contract-Based Agent Negotiation |
| `tri contract-bench` | `sla-bench` | 51 | Contract Benchmark — negotiation speed |
| `tri workflow-demo` | `workflow`, `wf` | 52 | Temporal Workflow Engine |
| `tri workflow-bench` | `wf-bench` | 52 | Workflow Benchmark — latency |

## Summary

| Category | Pairs | Cycles |
|----------|-------|--------|
| Pre-cycle (AI, scheduling) | 11 | — |
| Vision | 1 | 20 |
| Multi-Modal | 1 | 26 |
| Tool Use | 1 | 27 |
| Unified Agents | 4 | 30-33 |
| Memory & Distribution | 4 | 34-37 |
| Scheduling & Plugins | 7 | 39-45 |
| Advanced Systems | 7 | 46-52 |
| **Total** | **36 pairs** | **72 commands** |
