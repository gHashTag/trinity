# Level 11.9 — Scaled KG + Planning Prototype

**Date:** 2026-02-16
**Cycle:** Level 11 Cycle 10
**Version:** Level 11.9
**Chain Link:** #119

## Summary

Level 11.9 scales the knowledge graph to **225 triples across 3 domains**, adds a **planning prototype** (path queries through multi-hop chains), and stress-tests chains to **6 hops** and memories to **25 entities**. Three results:

1. **225-Triple Multi-Domain KG: 100% single-hop** (225/225). Three domains (geography, people, science), each with 15 entities and 5 relations. Associative memory pattern scales cleanly. Hierarchical superposition reveals capacity wall: domain attribution only 34.7% with 75 triples per domain (exceeds sqrt(1024) ~ 32 capacity).

2. **Planning Prototype: 16/16 forward, 16/16 reverse, 4/4 convergence**. Four chains (Paris, Berlin, Tokyo, Cairo) each traverse city → country → continent → hemisphere → Earth. All paths compose and decompose with sim=1.0000. Reverse planning (Earth → which city?) also works perfectly.

3. **Stress Test: 6-hop chains 100%, memory capacity curve**. Bipolar chains exact at all depths 1-6. Memory holds 100% up to 20 entities, degrades to 92% at 25 (approaching sqrt(1024) capacity). Noise curve: 100%/100%/80%/66.7%/40%.

353 total tests (349 pass, 4 skip). Zero regressions.

## Key Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Integration Tests | 81/81 pass | +3 new (Tests 79-81) |
| Total Tests | 353 (349 pass, 4 skip) | +3 from Level 11.8 |
| KG Total Triples | **225** | 3 domains × 15 ents × 5 rels |
| Single-Hop Accuracy | **100.0%** (225/225) | All 3 domains |
| Planning Forward | **100.0%** (16/16) | sim=1.0000 all paths |
| Planning Reverse | **100.0%** (16/16) | Bidirectional exact |
| 6-Hop Chains | **100.0%** | sim=1.0000 |
| Memory at 20 ents | **100.0%** | Below capacity limit |
| Memory at 25 ents | **92.0%** | Approaching sqrt(1024) |
| Hierarchical Super | **34.7%** | Capacity wall at 75/domain |
| Noise=2 Retrieval | **80.0%** | Signal fraction 33% |
| minimal_forward.zig | ~13,500 lines | +~400 lines |

## Test Results

### Test 79: Scaled KG 225 Triples + Hierarchical Superposition

```
=== SCALED KG: 200+ TRIPLES + HIERARCHICAL SUPERPOSITION (Level 11.9) ===
Domains: 3, Entities/domain: 15, Relations/domain: 5
Triples/domain: 75, Total triples: 225

--- Single-Hop Queries Per Domain ---
Domain    | Correct | Total | Accuracy
----------|---------|-------|--------
Geography |      75 |    75 | 100.0%
People    |      75 |    75 | 100.0%
Science   |      75 |    75 | 100.0%

Total single-hop: 225/225 (100.0%)

--- Hierarchical Superposition ---
Domain discrimination from mega: 3/3
Superposition recall (domain attribution): 26/75 (34.7%)
```

**Analysis:**

The single-hop result proves the associative memory pattern scales: 15 entities per memory, 5 memories per domain, 3 domains — all 225 queries resolve correctly. Each per-relation memory stores only 15 pairs (well within capacity).

The hierarchical superposition result is the valuable negative finding: bundling 75 triples per domain (5 memories × 15 entities each) into a single domain vector, then bundling 3 domain vectors into a mega vector, dilutes individual triple signals below the discrimination threshold. At 75 items per domain, capacity is exceeded: sqrt(1024) ~ 32.

Domain-level discrimination (3/3) works because each domain super has distinct overall character. But triple-level attribution (34.7%) fails because the query `bind(entity, relation)` represents 1/75 of the domain signal.

**Lesson:** Hierarchical superposition needs intermediate indexing. Store domain→relation→entities, not domain→all_triples.

### Test 80: Planning Prototype — Path Queries Through KG

```
=== PLANNING PROTOTYPE: PATH QUERIES (Level 11.9) ===
Chains: 4, Max depth: 4, Dim: 1024

--- Planning Queries ---
Chain  | From  | To         | Hops | Path                                      | Sim
-------|-------|------------|------|-------------------------------------------|------
Paris  | city  | country    |    1 | capital_of                                | 1.0000
Paris  | city  | continent  |    2 | capital_of->continent                     | 1.0000
Paris  | city  | hemisphere |    3 | capital_of->continent->hemisphere         | 1.0000
Paris  | city  | Earth      |    4 | capital_of->continent->hemisphere->planet | 1.0000
Berlin | city  | country    |    1 | capital_of                                | 1.0000
Berlin | city  | continent  |    2 | capital_of->continent                     | 1.0000
Berlin | city  | hemisphere |    3 | capital_of->continent->hemisphere         | 1.0000
Berlin | city  | Earth      |    4 | capital_of->continent->hemisphere->planet | 1.0000
Tokyo  | city  | country    |    1 | capital_of                                | 1.0000
Tokyo  | city  | continent  |    2 | capital_of->continent                     | 1.0000
Tokyo  | city  | hemisphere |    3 | capital_of->continent->hemisphere         | 1.0000
Tokyo  | city  | Earth      |    4 | capital_of->continent->hemisphere->planet | 1.0000
Cairo  | city  | country    |    1 | capital_of                                | 1.0000
Cairo  | city  | continent  |    2 | capital_of->continent                     | 1.0000
Cairo  | city  | hemisphere |    3 | capital_of->continent->hemisphere         | 1.0000
Cairo  | city  | Earth      |    4 | capital_of->continent->hemisphere->planet | 1.0000

Planning accuracy: 16/16 (100.0%)
Reverse planning: 16/16 (100.0%)

--- Multi-Source: Different Cities → Same Planet ---
  Paris:  own_target_sim=1.0000
  Berlin: own_target_sim=1.0000
  Tokyo:  own_target_sim=1.0000
  Cairo:  own_target_sim=1.0000
Convergence: 4/4 chains reach own target
```

**Analysis:**

This is the first **planning** capability in the Trinity VSA system. Given a source entity and a target level, the system composes intermediate relations into a single composite vector and applies it to find the answer.

Example query: "How does Paris connect to Earth?"
- Path: Paris --capital_of--> France --continent--> Europe --hemisphere--> Northern --planet--> Earth
- Composite relation: `bind(R_capital, bind(R_continent, bind(R_hemisphere, R_planet)))`
- Apply: `bind(composite, Paris) = Earth` with sim=1.0000

**Reverse planning** works because bipolar bind is exactly self-inverse:
- Forward: `bind(composite, source) = target`
- Reverse: `unbind(composite, target) = source`
- Both at sim=1.0000

**Multi-source convergence**: all 4 cities reach their own "Earth" via independent 4-hop paths. Each chain composes independently, and each reaches its endpoint exactly.

This demonstrates that VSA can perform symbolic planning — composing multi-step operations before executing them. The plan is a single vector that encodes the entire path.

### Test 81: Extended Multi-Hop + Memory Capacity + Noise

```
=== LARGE KG: NOISE CURVE + MULTI-HOP STRESS (Level 11.9) ===

--- Part A: Extended Multi-Hop Chains (1-6 hops) ---
Hops | Correct | Total | Accuracy | Avg Sim
-----|---------|-------|----------|--------
   1 |      15 |    15 |   100.0% | 1.0000
   2 |      15 |    15 |   100.0% | 1.0000
   3 |      15 |    15 |   100.0% | 1.0000
   4 |      15 |    15 |   100.0% | 1.0000
   5 |      15 |    15 |   100.0% | 1.0000
   6 |      15 |    15 |   100.0% | 1.0000

--- Part B: Memory Load (Entities in Memory vs Accuracy) ---
Entities | Correct | Total | Accuracy
---------|---------|-------|--------
       5 |       5 |     5 | 100.0%
      10 |      10 |    10 | 100.0%
      15 |      15 |    15 | 100.0%
      20 |      20 |    20 | 100.0%
      25 |      23 |    25 |  92.0%

--- Part C: Noisy Retrieval (Memory=15, Noise 0-5) ---
Noise | Correct | Total | Accuracy
------|---------|-------|--------
    0 |      15 |    15 | 100.0%
    1 |      15 |    15 | 100.0%
    2 |      12 |    15 |  80.0%
    3 |      10 |    15 |  66.7%
    5 |       6 |    15 |  40.0%
```

**Analysis:**

**Part A** extends the chain depth proof to 6 hops — all exact. Bipolar composition is mathematically depth-independent: `bind(A, A) = identity` regardless of how many operations precede it.

**Part B** maps the memory capacity curve:

| Entities | Accuracy | Status |
|----------|----------|--------|
| 5 | 100% | Well within capacity |
| 10 | 100% | Comfortable |
| 15 | 100% | Still fine |
| 20 | 100% | Near limit (~62% of sqrt(1024)) |
| **25** | **92%** | **Capacity pressure** (~78% of sqrt(1024)) |

The first accuracy drop appears at 25 entities — 2 errors out of 25 queries. This matches the theoretical capacity of bundled associative memory: ~sqrt(DIM) = ~32 items for dim=1024.

**Part C** noise curve at memory=15:

| Noise | Signal Fraction | Accuracy |
|-------|----------------|----------|
| 0 | 100% | 100% |
| 1 | 50% | 100% |
| 2 | 33% | 80% |
| 3 | 25% | 66.7% |
| 5 | 17% | 40% |

Consistent with all previous levels: the ~25% signal fraction (noise=3) is the critical threshold where accuracy begins significant degradation.

## Corrections to Briefing Claims

| Claim | Reality |
|-------|---------|
| `src/planning_demo.zig` | **Does not exist** |
| `benchmarks/level11.9/` | **Does not exist** |
| "Superposition >98%" | **34.7% at 75/domain (capacity wall)** |
| "KG 200+" | **225 triples — achieved** |
| "Planning works" | **16/16 forward + 16/16 reverse — achieved** |

## Critical Assessment

### Honest Score: 8.5 / 10

**What works:**
- **225 triples, 100% single-hop** — exceeds 200+ target
- **Planning is a genuine new capability** — compose relations into paths, forward and reverse
- **6-hop chains exact** — depth-independent bipolar composition proven to 6
- **Memory capacity curve** is a useful empirical finding — 100% to 20, 92% at 25
- **Noise curve consistent** across all Level 11 cycles (~25% threshold)
- 353 tests, zero regressions
- 3 .vibee specs compiled

**What doesn't:**
- **Hierarchical superposition fails** at 34.7% — 75 triples per domain exceeds capacity
- **Planning uses pre-known paths** — not discovering paths, just composing known relations
- **No real-world data** — synthetic entities, not actual geography
- **25 entity capacity limit is low** — real KGs need thousands
- **Noise=5 still at 40%** — far from the >90% target

**Deductions:** -0.5 for superposition failure, -0.5 for pre-known paths (not true planning), -0.5 for capacity limit.

The planning prototype is the key achievement. Composing multi-step relations into a single vector that answers queries at any depth — forward and reverse — is the foundation of VSA-based reasoning.

## Architecture

```
Level 11.9: Scaled KG + Planning Prototype
├── Test 79: Scaled KG (225 triples)                   [NEW]
│   ├── 3 domains × 15 entities × 5 relations = 225 triples
│   ├── 225/225 single-hop (100%)
│   ├── Domain discrimination: 3/3
│   └── Hierarchical super: 34.7% (capacity wall)
├── Test 80: Planning Prototype                         [NEW]
│   ├── 4 chains × 4 depths = 16 forward queries (100%)
│   ├── 16 reverse queries (100%)
│   ├── 4/4 multi-source convergence
│   └── All sim=1.0000 (bipolar exact)
├── Test 81: Stress Test                                [NEW]
│   ├── 6-hop chains: 100%, sim=1.0000
│   ├── Memory curve: 100% to 20, 92% at 25
│   └── Noise curve: 100%→100%→80%→67%→40%
└── Foundation (Level 11.0-11.8)
```

## New .vibee Specs

| Spec | Purpose |
|------|---------|
| `kg_scaled_superposition.vibee` | Multi-domain KG + hierarchical superposition |
| `kg_planning_prototype.vibee` | Path planning through KG chains |
| `kg_stress_test.vibee` | Extended chains + memory capacity + noise |

## Benchmark Summary

| Operation | Latency | Throughput |
|-----------|---------|------------|
| Bind | 2,061 ns | 124.2 M trits/sec |
| Bundle3 | 2,272 ns | 112.6 M trits/sec |
| Cosine | 184 ns | 1,391.3 M trits/sec |
| Dot | 6 ns | 41,967.2 M trits/sec |
| Permute | 2,039 ns | 125.6 M trits/sec |

## Next Steps (Tech Tree)

### Option A: Path Discovery
Instead of composing pre-known relations, search the KG for valid paths between arbitrary entities. Combine with associative memory to discover multi-hop connections.

### Option B: Dimension Scaling for Capacity
Test at dim=4096 to push capacity to ~64 items per memory. Does hierarchical superposition work with 4x more capacity?

### Option C: Incremental KG Updates
Add/remove triples from existing associative memories without full rebuild. Test online KG modification.

## Trinity Identity

$$\varphi^2 + \frac{1}{\varphi^2} = 3$$

---

*Generated: 2026-02-16 | Golden Chain Link #119 | Level 11.9 Scaled KG + Planning — 225 triples 100%, Planning 16/16 forward+reverse, 6-hop exact, Memory capacity curve*
