# Trinity Competitive Analysis — March 2026

## Competitor Comparison

| Name | Architecture | Memory/Learning | Multi-Agent | Spec-Driven | Pricing |
|------|-------------|----------------|-------------|-------------|---------|
| **Claude Code** | Terminal, 200K ctx, sub-agents | CLAUDE.md + MEMORY.md auto | Sub-agents (shared workspace) | No | $17-100+/mo |
| **Devin** | Cloud sandbox, autonomous | Devin Wiki (auto-index) | Single per task | No | $20/mo + $2.25/ACU |
| **Kiro** | IDE (AWS), spec-enforced | Steering files (.kiro/) | Sub-agent delegation | **Yes** | AWS pricing |
| **Cursor** | VS Code fork | Rules + Memories | Up to 8 parallel (worktrees) | No | $20-240/mo |
| **Windsurf** | IDE, SWE-1.5 model | Rules + Memories auto | Single cascade | No | $15/mo fixed |
| **Codex** | Cloud sandbox, multi-repo | Skills system | Parallel containers | No | ChatGPT Pro $20/mo |
| **Jules** | Cloud VM, GitHub-native | AGENTS.md, 1M ctx (Gemini) | Single per task | No | Google preview |
| **Augment** | IDE + terminal | Semantic codebase graph | Coordinator/Explorer/Coder | No | Enterprise |
| **Trinity** | Pure Zig, terminal, swarm | Experience episodes + mistakes | 5-role faculty board | **Yes** (.tri specs) | Self-hosted |

## SWE-bench Scores (2026)

- SWE-bench Verified: Claude Code 72.5%, Codex ~49%
- SWE-bench Pro: Codex CLI 57.0%, Augment 51.8%, Cursor 50.2%, Claude Code 49.8%
- Trinity: **No benchmark data yet** (critical gap)

## Key Research Papers (2025-2026)

| Paper | Year | Key Finding |
|-------|------|-------------|
| AgentRR (Record & Replay) | 2025 | Record traces, summarize into experiences, replay — multi-level abstraction |
| SWE-Replay | 2025 | Recycle trajectories: -17.4% cost, +3.8% performance |
| AgentCoder (3-agent) | 2025 | 91.5% vs 75.5% single-agent (GPT-4). Role separation works |
| MetaGPT | 2024-25 | Multi-role software team generates complete apps |
| PBT (DeepMind) | 2024-25 | Adapts hyperparams during training, not just at start |
| ASHA | 2024-25 | 1.5x faster than synchronous SHA, linear scaling |
| RLVR | 2025 | Unit tests as rewards replace expensive human labels |
| Pre-Act | 2025 | Multi-step planning +70% Action Recall vs ReAct |
| LocAgent | 2025 | Code graphs enable multi-hop reasoning for localization |

## Trinity's 5 Unfair Advantages — Validated

| Advantage | Status | Evidence |
|-----------|--------|----------|
| Pure Zig, zero deps | Unique | No competitor uses Zig. Eliminates dependency attack surface |
| Spec-driven (.tri) | Validated by Kiro | Kiro proves spec-first reduces errors 23-37% |
| Multi-agent swarm | Validated by AgentCoder | 91.5% vs 75.5% with role decomposition |
| Experience replay | Validated by AgentRR + SWE-Replay | -17% cost, +4% perf. No competitor implements well |
| Ternary compute (VSA) | Unvalidated | Novel but unproven for coding. BitNet supports efficiency |

## What Competitors Do BETTER (Honest)

1. **IDE integration** — Cursor/Windsurf have VS Code. Trinity: terminal only
2. **Context window** — Jules: 1M tokens. Trinity: no equivalent
3. **Production scale** — Devin: 67% PR merge rate. Trinity: zero external users
4. **Benchmark scores** — Top: 45-57% SWE-bench Pro. Trinity: zero scores
5. **Semantic indexing** — Augment: knowledge graphs. Trinity: VSA similarity only
6. **Cloud sandboxing** — Codex/Devin: automated. Trinity: manual Railway, max 10
7. **Community** — Cursor: thousands of users. Trinity: zero
8. **Cost predictability** — Windsurf: $15/mo fixed. Trinity: unpredictable
9. **Model flexibility** — Cursor: switch Claude/GPT/Gemini. Trinity: locked

## Top 3 Recommendations

1. **Experience replay system** (highest ROI) — AgentRR + SWE-Replay validate approach. Add structured trace recording, experience summarization, similarity-based retrieval at task start
2. **Real benchmark numbers** — Run on SWE-bench Lite (300 tasks). Zero data = zero credibility. Target: real number in 2 weeks
3. **VSA-based semantic indexing** — Augment proved +17 points on SWE-bench Pro. Use VSA vectors for file/function/dependency graphs. First VSA-based code index
