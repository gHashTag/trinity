# Trinity Technology Tree — Development Strategy

## DAG Structure

```
LAYER 0: FOUNDATIONS (no dependencies, parallel)
├── [F1] dev_scan.tri         ✅ SPEC DONE, GEN PASS
├── [F2] toxic_verdict.tri    ✅ WIRED INTO CLI (tri verdict → real scores + history)
└── [F3] experience_loop.tri  ✅ EXISTS (upgrade planned)

LAYER 1: DEPENDS ON FOUNDATIONS
├── [L1] dev_pick.tri         ✅ SPEC DONE, GEN PASS  (needs F1, F3)
├── [L2] spec_create_v2.tri   ✅ SPEC DONE, GEN PASS  (needs F3)
└── [L3] loop_decide_v2.tri   ✅ WIRED INTO CLI (tri loop-decide → real decisions)

LAYER 2: INTEGRATION
├── [I1] dev_loop.tri         ✅ SPEC DONE, GEN PASS  (needs F1,L1,L2,F2,L3)
└── [I2] e2e_toxic_test.tri   ✅ SPEC DONE, GEN PASS  (needs F2,F3)

LAYER 3: OPTIMIZATION
└── [O1] perf_benchmark.tri   ✅ SPEC DONE, GEN PASS  (needs I1)
```

## Critical Path

```
F1 (dev_scan) → L1 (dev_pick) → I1 (dev_loop)
F2 (toxic_verdict) → L3 (loop_decide) → I1 (dev_loop)
F3 (experience_save) → L1 (dev_pick) → I1 (dev_loop)
```

## Implementation Priority

1. F2 toxic_verdict — replaces most broken stub, unlocks quality feedback
2. F1 dev_scan — required for smart automation (73 issues + 34 dirty files)
3. F3 experience_save unification — small scope, high leverage
4. L3 loop_decide_v2 — depends only on F2
5. L1 dev_pick — depends on F1+F3, core of smart selection
6. L2 spec_create_v2 — makes spec creation write files
7. I1 dev_loop — full integration, the goal state
8. I2 e2e_toxic_test — testing infrastructure
9. O1 perf_benchmark — optimization layer

## 5 Unfair Advantages

1. **Experience != Context Window** — experience.json = infinite memory
2. **Mistakes are gold** — .trinity/mistakes/ = never repeat error twice
3. **Evolution, not memory** — ASHA+PBT evolves strategies
4. **Verifiable trace** — every step = tri issue comment = immutable GitHub record
5. **Swarm + shared experience** — 32 agents share .trinity/experience/

## Autonomous Dev Loop Architecture

```
tri dev scan          → reads issues + .trinity/experience/similar_tasks.json
tri dev pick --smart  → priority + avoids 3x failed tasks (MNL pattern)
tri issue comment N   → 🔍 [RESEARCH] Step 3/10  (immutable GitHub record)
tri spec create       → reuse closest template from experience
tri gen               → .tri → .zig + tri issue comment "⚙️ [CODEGEN]"
tri test              → IF FAIL → save to .trinity/mistakes/
tri verdict --toxic   → compare with past verdicts: "Past: 3/7. Now: 7/7"
tri experience save   → saves episode + learnings + mistakes
tri git commit        → tri issue comment "✅ [DONE]"
tri loop decide       → continue or stop
```

## Status: 2026-03-14

- 8 new specs created, all generating valid .zig
- 342 total specs (334 + 8 new)
- F2 toxic_verdict: WIRED — tri verdict computes real score 73/100, saves history
- L3 loop_decide: WIRED — tri loop-decide evaluates 9 conditions, data-driven decisions
- Next: wire F1 dev_scan and L1 dev_pick into tri CLI
