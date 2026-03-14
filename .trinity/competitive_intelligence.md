# Trinity Competitive Intelligence — 2026-03-14

## Competitor Weaknesses to Exploit

| Competitor | Critical Weakness | Trinity Advantage |
|-----------|-------------------|-------------------|
| Devin | No cross-session memory, $500/mo, "last 30% problem" | experience.json = infinite memory, free |
| Kiro | Multi-agent experimental, setup overhead | Cloud dev pipeline already working |
| Claude Code | Memory unreliable, 5h window, no parallel codegen | ExpeL + shared experience across agents |
| Cursor | Memory-execution DISCONNECTED (critical bug) | Memory feeds directly into pick algorithm |
| Windsurf | Single-agent only, no coordination | 32-agent swarm with shared experience |
| SWE-agent | 12.5% pass rate, no memory/learning | Full experience + mistake tracking |
| OpenHands | Condensation opaque, 18-20% on live benchmarks | Verifiable GitHub trace |
| Aider | No specs, no multi-agent | .tri spec pipeline |
| Augment Intent | Most advanced (Coord-Spec-Verifier) but unproven | Similar architecture, pure Zig |

## Key Papers to Implement

### 1. ExpeL Insight Voting (AAAI 2024)
- Paper: arxiv.org/abs/2308.10144
- Add UPVOTE/DOWNVOTE/EDIT ops to experience insights
- Trinity already has ExpeL-style episodes; add voting

### 2. ASHA for Training Farm (MLSys 2020)
- Paper: arxiv.org/abs/1810.05934
- Auto-promote best LR/schedule combos across Railway services
- Directly applicable to 15-service HSLM farm

### 3. Recovery-Bench (Letta 2025)
- Full failure history can HURT (agents fixate on failed approaches)
- Trinity should use SELECTIVE failure context, not full traces
- MNL pattern already handles this partially

### 4. BitNet b1.58 Validates Ternary (2025)
- Paper: arxiv.org/html/2504.12285v1
- Native {-1,0,+1} at 2B scale, parity with full precision
- Validates Trinity's ternary VSA approach

### 5. PBT for Agent Evolution (DeepMind)
- Paper: deepmind.google/blog/population-based-training
- Formalize evolution_state.json into proper PBT loop
- PB2 variant works with just 4 agents

### 6. Multi-Agent Patterns
- MapCoder (ACL 2024): 4 agents, 93.9% HumanEval
- AgentCoder: 96.3% pass@1, 56.9K tokens (2.4x efficient)
- Key: stable individual identities + explicit perspective-taking

## Technology Tree Priorities (Research-Informed)

1. ExpeL insight voting → tri experience vote
2. ASHA for farm → tri farm evolve --asha
3. Selective failure context → tri dev pick --smart (already MNL)
4. Living spec coordination → tri dev loop (I1 spec)
5. PBT agent evolution → tri dev evolve (exists, enhance)
