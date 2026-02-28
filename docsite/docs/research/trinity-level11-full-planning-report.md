# Level 11.18 — Full Planning SOTA

**[CYR:[TRANSLATED]]:** 2026-02-16
**[CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]:** 11.18 — [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andроinанandе + маwith[TRANSLATED]]andроinанandе for[TRANSLATED]]toоin
**Теwithты:** 106-108 | **[CYR:[TRANSLATED]]with:** PASS (380 теwithтоin, 376 pass, 4 skip)

## [CYR:[TRANSLATED]]inые [CYR:[TRANSLATED]]andtoand

| [CYR:[TRANSLATED]]andtoа | Зon[CYR:[TRANSLATED]]andе | [CYR:[TRANSLATED]]with |
|---------|----------|--------|
| bAbI Task 4 (2-step pathfinding) | 8/8 (100%) | PASS |
| bAbI Task 5 (3-step pathfinding) | 6/6 (100%) | PASS |
| Pathfinding combined | 14/14 (100%) | PASS |
| Branch kinship (uncle) | 9/9 (100%) | PASS |
| Branch kinship (cousin) | 6/6 (100%) | PASS |
| Branch kinship (nephew) | 6/6 (100%) | PASS |
| Branch kinship (grandparent) | 9/9 (100%) | PASS |
| Branch kinship combined | 30/30 (100%) | PASS |
| Large codebook scoped (30) | 30/30 (100%) | PASS |
| Large codebook global (30) | 26/30 (87%) | PASS |
| Large codebook scoped (120) | 120/120 (100%) | PASS |
| Scoped vs global advantage | **13pp** | PASS |
| bAbI coverage | 9/20 [CYR:[TRANSLATED]] | +2 |

## [CYR:[TRANSLATED]] this зonчandт

### [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]
Trinity VSA [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] **[CYR:[TRANSLATED]]with[TRANSLATED]]withтin[CYR:[TRANSLATED]] oninand[CYR:[TRANSLATED]]andю** (pathfinding), **cross-relation kinship** (uncle, cousin, nephew) and **маwith[TRANSLATED]]and[CYR:[TRANSLATED]]withя до 120+ for[TRANSLATED]]and[CYR:[TRANSLATED]]in** with scoped поandwithtoом. Вwithе трand ноinых теwithта — 100%.

### [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]fromчandtoоin
Трand for[TRANSLATED]]inых [CYR:[TRANSLATED]]andтеfor[TRANSLATED]] fromfor[TRANSLATED]]andя:

1. **Permutation-based directional encoding**: Bipolar bind for[TRANSLATED]]andinен (`bind(A,B) = bind(B,A)`), therefore on[CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]andя not[CYR:[TRANSLATED]] заtoодandроin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]with[TRANSLATED]] bind. [CYR:[TRANSLATED]]andе: `bind(from, permute(to, shift))` with унandfor[TRANSLATED]] shift on on[CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]andе (N=1, S=2, E=3, W=4). Permutation [CYR:[TRANSLATED]] for[TRANSLATED]]andinноwithть.

2. **Per-LEVEL indexed memories**: [CYR:[TRANSLATED]] branch kinship (uncle, cousin, nephew, grandparent) [CYR:memory] [CYR:[TRANSLATED]]on [CYR:[TRANSLATED]] sectionеon по [CYR:[TRANSLATED]] поfor[TRANSLATED]]andй. `parent_l0` ([CYR:[TRANSLATED]]and→[CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]and, 3 [CYR:[TRANSLATED]]), `parent_l1` ([CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]and→[CYR:[TRANSLATED]]toа, 2 [CYR:[TRANSLATED]]). Flat [CYR:memory] in[CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] cross-generation interference.

3. **Scoped codebook scaling**: Global поandwithto with[TRANSLATED]]and 30+ for[TRANSLATED]]and[CYR:[TRANSLATED]]in [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] (87%). Scoped поandwithto ([CYR:[TRANSLATED]]toо with[TRANSLATED]]and for[TRANSLATED]]and[CYR:[TRANSLATED]]in in [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]and, 3 [CYR:[TRANSLATED]]toand) — 100% on [CYR:[TRANSLATED]] маwith[TRANSLATED]]. [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andзм маwith[TRANSLATED]]andроinанandя: indexed memories + scoped codebooks = O(pairs) with[TRANSLATED]]withть.

## [CYR:[TRANSLATED]]andчеwithtoandе [CYR:[TRANSLATED]]and

### Test 106: bAbI Pathfinding (Tasks 4-5)

8 toомonт in [CYR:[TRANSLATED]]with[TRANSLATED]]withтin[CYR:[TRANSLATED]] withетtoе:

```
garden(3)   bathroom(5)
kitchen(0)  office(2)    garage(7)
bedroom(1)  hallway(4)   living(6)
```

18 on[CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] (4N + 4S + 5E + 5W), for[TRANSLATED]] toаto andндandinand[CYR:[TRANSLATED]] `bind(from, permute(to, shift))`.

| Task | Тandп | Hops | Result |
|------|-----|------|-----------|
| 4 | Two-step paths | 2 | 8/8 (100%) |
| 5 | Three-step paths | 3 | 6/6 (100%) |
| **ALL** | **Pathfinding** | **2-3** | **14/14 (100%)** |

**[CYR:[TRANSLATED]]inое fromfor[TRANSLATED]]andе**: Bipolar bind for[TRANSLATED]]andinен. `bind(office, hallway) = bind(hallway, office)`. [CYR:[TRANSLATED]] permutation south-[CYR:[TRANSLATED]]with inозin[CYR:[TRANSLATED]] north-frominет. Permutation `bind(from, permute(to, shift))` with [CYR:[TRANSLATED]]and shift for for[TRANSLATED]] on[CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]andя [CYR:[TRANSLATED]]with[TRANSLATED]] уwith[TRANSLATED]] [CYR:[TRANSLATED]] [CYR:[TRANSLATED]].

### Test 107: Branch Kinship

3 with[TRANSLATED]]and × 6 [CYR:[TRANSLATED]]inеto = 18 [CYR:[TRANSLATED]]inеto (grandparent, parent_a, parent_b, child_a1, child_a2, child_b1).

Per-LEVEL indexed memories:
- `parent_l0[f]`: [CYR:[TRANSLATED]]and → [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]and (3 [CYR:[TRANSLATED]])
- `parent_l1[f]`: [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]and → [CYR:[TRANSLATED]]toа (2 [CYR:[TRANSLATED]])
- `child_l0[f]`: [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]and → [CYR:[TRANSLATED]]and (3 [CYR:[TRANSLATED]])
- `child_l1[f]`: [CYR:[TRANSLATED]]toа → [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]and (2 [CYR:[TRANSLATED]])
- `sibling_mems[f]`: дinуon[CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] (4 [CYR:[TRANSLATED]])

| Relation | Query Chain | Result |
|----------|-------------|--------|
| Uncle | parent_l0(X) → sibling → uncle | 9/9 (100%) |
| Cousin | parent_l0(X) → sibling → child_l0 → cousin | 6/6 (100%) |
| Nephew | sibling(X) → child_l0 → nephew | 6/6 (100%) |
| Grandparent | parent_l0(X) → parent_l1 → grandparent | 9/9 (100%) |
| **ALL** | **30 queries** | **30/30 (100%)** |

**[CYR:[TRANSLATED]]inое fromfor[TRANSLATED]]andе**: Flat per-family memories (5 [CYR:[TRANSLATED]]) in[CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] cross-generation interference — child_of(parent_b) inозin[CYR:[TRANSLATED]] grandparent inмеwithто child_b1. Per-LEVEL sectionенandе (2-3 [CYR:[TRANSLATED]] on [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]) [CYR:[TRANSLATED]]with[TRANSLATED]] уwith[TRANSLATED]] [CYR:[TRANSLATED]].

### Test 108: Large Codebook Scaling

| Scale | Search | Pairs | Accuracy |
|-------|--------|-------|----------|
| 30 | Scoped | 3 | 100% |
| 30 | Global | 3 | 87% |
| 120 | Scoped | 3 | 100% |

**Scoped advantage: 13pp** прand маwith[TRANSLATED]] 30. Прand маwith[TRANSLATED]] 120 scoped по-[CYR:[TRANSLATED]]notму 100%.

**Stack overflow [CYR:[TRANSLATED]]andе**: 120 Hypervector'оin (120 × 1024 bytes ≈ 120KB) [CYR:[TRANSLATED]] withтеto. [CYR:[TRANSLATED]]andе: 4 [CYR:[TRANSLATED]] по 30 with [CYR:[TRANSLATED]]andwith[TRANSLATED]]inанandем [CYR:[TRANSLATED]] маwithandinа.

## Чеwithтonя with[TRANSLATED]]toрandтandtoа

1. **Coverage gap**: bAbI 9/20 ([CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] tasks 4-5). Не [CYR:[TRANSLATED]]andзоin[CYR:[TRANSLATED]]: time reasoning (14), size reasoning (16), agent motion (17-20).
2. **Per-pair overhead**: 18 andндandinand[CYR:[TRANSLATED]] edge-[CYR:memory] for 8 toомonт. Прand 100 toомon[CYR:[TRANSLATED]] this withfromнand edge-[CYR:[TRANSLATED]]. Bundled memories with permutation [CYR:[TRANSLATED]]withя in [CYR:[TRANSLATED]]not[CYR:[TRANSLATED]] from[CYR:[TRANSLATED]]toе.
3. **Flat kinship failure**: Per-level [CYR:[TRANSLATED]]andе [CYR:[TRANSLATED]]from[CYR:[TRANSLATED]] for 3-поfor[TRANSLATED]] [CYR:[TRANSLATED]]inьеin. [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andзin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andны [CYR:[TRANSLATED]] реtoурwithandin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]].
4. **Scoped vs global**: Scoped search [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]notе зonть scope for[TRANSLATED]] [CYR:[TRANSLATED]]and.  [CYR:[TRANSLATED]] withandwith[TRANSLATED]] scope discovery — notтрandinand[CYR:[TRANSLATED]]onя task.
5. **Permutation scaling**: Shifts 1-4 доwith[TRANSLATED]] for 4 on[CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]andй. [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]in with деwithятtoамand тandпоin [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]on with[TRANSLATED]] раwith[TRANSLATED]]andя shifts.

## [CYR:[TRANSLATED]]withandя Level 11

| Level | Feature | Result |
|-------|---------|---------  |
| 11.10 | Intermediate indexing | 225/225 100% |
| 11.11 | Path discovery + beam | BFS 100%, beam 60% |
| 11.12 | Arbitrary graph | Cycles 3/3 |
| 11.13 | Massive KG 1000 | 989/1000 (98.9%) |
| 11.14 | Weighted edges | 72pp advantage |
| 11.15 | Massive weighted | 625/625, 42pp |
| 11.16 | bAbI+CLUTRR SOTA | 100% both, 45pp |
| 11.17 | Neuro-symbolic bench | 100% + 78pp indexed |
| **11.18** | **Full planning SOTA** | **pathfind 14/14 + kinship 30/30 + codebook 120/120** |

## Tech Tree: [CYR:[TRANSLATED]]andе stepand

1. **Bundled permutation memories**: [CYR:[TRANSLATED]]toа bundled (not per-pair) memories with permutation encoding for withнand[CYR:[TRANSLATED]]andя [CYR:[TRANSLATED]]and
2. **4+ generation kinship**: Раwithшand[CYR:[TRANSLATED]]andе per-level [CYR:[TRANSLATED]] on [CYR:[TRANSLATED]]andзin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andну
3. **Dynamic scope discovery**: Аin[CYR:[TRANSLATED]]andчеwithtoое [CYR:[TRANSLATED]]andе scope for scoped codebook search
