# Level 11.18 — Full Planning SOTA

**:]:** 2026-02-16
**:]in:]:** 11.18 — :] :]andraboutinanande + mawith]andraboutinanande for]toaboutin
**Tewithty:** 106-108 | **:]with:** PASS (380 thosewiththatin, 376 pass, 4 skip)

## :]inye :]andtoand

| :]Version | Zon:]ande | :]with |
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
| bAbI coverage | 9/20 :] | +2 |

## :] this zonchandt

### :] :]in:]
Trinity VSA :] :] **:]with]withtin:] oninand:]andyu** (pathfinding), **cross-relation kinship** (uncle, cousin, nephew) and **mawith]and:]withya dabout 120+ for]and:]in** with scoped byandwithtoaboutm. Vwithe trand naboutinykh thosewiththat — 100%.

### :] :]fromchandtoaboutin
Trand for]inykh :]andthosefor] fromfor]andya:

1. **Permutation-based directional encoding**: Bipolar bind for]andinen (`bind(A,B) = bind(B,A)`), therefore on:]in:]andya not:] zatoaboutdandraboutin:] :]with] bind. :]ande: `bind(from, permute(to, shift))` with atnandfor] shift on on:]in:]ande (N=1, S=2, E=3, W=4). Permutation :] for]andinnaboutwitht.

2. **Per-LEVEL indexed memories**: :] branch kinship (uncle, cousin, nephew, grandparent) :memory] :]on :] sectioneon by :] byfor]andy. `parent_l0` (:]and→:]and:]and, 3 :]), `parent_l1` (:]and:]and→:]toa, 2 :]). Flat :memory] in:]in:] cross-generation interference.

3. **Scoped codebook scaling**: Global byandwithto with]and 30+ for]and:]in :]and:] (87%). Scoped byandwithto (:]toabout with]and for]and:]in in :] :]and, 3 :]toand) — 100% on :] mawith]. :] :] :]andzm mawith]andraboutinanandya: indexed memories + scoped codebooks = O(pairs) with]witht.

## :]andchewithtoande :]and

### Test 106: bAbI Pathfinding (Tasks 4-5)

8 toaboutmont in :]with]withtin:] withettoe:

```
garden(3)   bathroom(5)
kitchen(0)  office(2)    garage(7)
bedroom(1)  hallway(4)   living(6)
```

18 on:]in:] :] (4N + 4S + 5E + 5W), for] toato andndandinand:] `bind(from, permute(to, shift))`.

| Task | Tandp | Hops | Result |
|------|-----|------|-----------|
| 4 | Two-step paths | 2 | 8/8 (100%) |
| 5 | Three-step paths | 3 | 6/6 (100%) |
| **ALL** | **Pathfinding** | **2-3** | **14/14 (100%)** |

**:]inaboute fromfor]ande**: Bipolar bind for]andinen. `bind(office, hallway) = bind(hallway, office)`. :] permutation south-:]with inaboutzin:] north-frominet. Permutation `bind(from, permute(to, shift))` with :]and shift for for] on:]in:]andya :]with] atwith] :] :].

### Test 107: Branch Kinship

3 with]and × 6 :]ineto = 18 :]ineto (grandparent, parent_a, parent_b, child_a1, child_a2, child_b1).

Per-LEVEL indexed memories:
- `parent_l0[f]`: :]and → :]and:]and (3 :])
- `parent_l1[f]`: :]and:]and → :]toa (2 :])
- `child_l0[f]`: :]and:]and → :]and (3 :])
- `child_l1[f]`: :]toa → :]and:]and (2 :])
- `sibling_mems[f]`: dinaton:]in:] :] (4 :])

| Relation | Query Chain | Result |
|----------|-------------|--------|
| Uncle | parent_l0(X) → sibling → uncle | 9/9 (100%) |
| Cousin | parent_l0(X) → sibling → child_l0 → cousin | 6/6 (100%) |
| Nephew | sibling(X) → child_l0 → nephew | 6/6 (100%) |
| Grandparent | parent_l0(X) → parent_l1 → grandparent | 9/9 (100%) |
| **ALL** | **30 queries** | **30/30 (100%)** |

**:]inaboute fromfor]ande**: Flat per-family memories (5 :]) in:]in:] cross-generation interference — child_of(parent_b) inaboutzin:] grandparent inmewiththat child_b1. Per-LEVEL sectionenande (2-3 :] on :]in:]) :]with] atwith] :].

### Test 108: Large Codebook Scaling

| Scale | Search | Pairs | Accuracy |
|-------|--------|-------|----------|
| 30 | Scoped | 3 | 100% |
| 30 | Global | 3 | 87% |
| 120 | Scoped | 3 | 100% |

**Scoped advantage: 13pp** prand mawith] 30. Prand mawith] 120 scoped by-:]notmat 100%.

**Stack overflow :]ande**: 120 Hypervector'aboutin (120 × 1024 bytes ≈ 120KB) :] withthoseto. :]ande: 4 :] by 30 with :]andwith]inanandem :] mawithandina.

## Chewithtonya with]torandtVersion

1. **Coverage gap**: bAbI 9/20 (:]in:] tasks 4-5). Ne :]andzaboutin:]: time reasoning (14), size reasoning (16), agent motion (17-20).
2. **Per-pair overhead**: 18 andndandinand:] edge-:memory] for 8 toaboutmont. Prand 100 toaboutmon:] this withfromnand edge-:]. Bundled memories with permutation :]withya in :]not:] from:]toe.
3. **Flat kinship failure**: Per-level :]ande :]from:] for 3-byfor] :]inein. :] :]andzin:] :]andny :] retoatrwithandin:] :].
4. **Scoped vs global**: Scoped search :] :]note zont scope for] :]and.  :] withandwith] scope discovery — nottrandinand:]onya task.
5. **Permutation scaling**: Shifts 1-4 daboutwith] for 4 on:]in:]andy. :] :]in with dewithyattoamand tandbyin :] :]on with] rawith]andya shifts.

## :]Author Level 11

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

## Tech Tree: :]ande stepand

1. **Bundled permutation memories**: :]toa bundled (not per-pair) memories with permutation encoding for withnand:]andya :]and
2. **4+ generation kinship**: Rawithshand:]ande per-level :] on :]andzin:] :]andnat
3. **Dynamic scope discovery**: Author:]andchewithtoaboute :]ande scope for scoped codebook search
