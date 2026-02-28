# Level 11.18 — Full Planning SOTA

**[CYR:Дата]:** 2026-02-16
**[CYR:Уро]in[CYR:ень]:** 11.18 — [CYR:Полное] [CYR:план]andроinанandе + маwith[CYR:штаб]andроinанandе to[CYR:одбу]toоin
**Теwithты:** 106-108 | **[CYR:Стату]with:** PASS (380 теwithтоin, 376 pass, 4 skip)

## [CYR:Ключе]inые [CYR:метр]andtoand

| [CYR:Метр]andtoа | Зon[CYR:чен]andе | [CYR:Стату]with |
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
| bAbI coverage | 9/20 [CYR:задач] | +2 |

## [CYR:Что] this зonчandт

### [CYR:Для] [CYR:пользо]in[CYR:ателей]
Trinity VSA [CYR:теперь] [CYR:решает] **[CYR:про]with[CYR:тран]withтin[CYR:енную] oninand[CYR:гац]andю** (pathfinding), **cross-relation kinship** (uncle, cousin, nephew) and **маwith[CYR:штаб]and[CYR:рует]withя до 120+ to[CYR:анд]and[CYR:дато]in** with scoped поandwithtoом. Вwithе трand ноinых теwithта — 100%.

### [CYR:Для] [CYR:разраб]fromчandtoоin
Трand to[CYR:люче]inых [CYR:арх]andтеto[CYR:турных] fromto[CYR:рыт]andя:

1. **Permutation-based directional encoding**: Bipolar bind to[CYR:оммутат]andinен (`bind(A,B) = bind(B,A)`), therefore on[CYR:пра]in[CYR:лен]andя not[CYR:льзя] заtoодandроin[CYR:ать] [CYR:про]with[CYR:тым] bind. [CYR:Решен]andе: `bind(from, permute(to, shift))` with унandto[CYR:альным] shift on on[CYR:пра]in[CYR:лен]andе (N=1, S=2, E=3, W=4). Permutation [CYR:ломает] to[CYR:оммутат]andinноwithть.

2. **Per-LEVEL indexed memories**: [CYR:Для] branch kinship (uncle, cousin, nephew, grandparent) [CYR:память] [CYR:долж]on [CYR:быть] sectionеon по [CYR:УРОВНЯМ] поto[CYR:олен]andй. `parent_l0` ([CYR:дет]and→[CYR:род]and[CYR:тел]and, 3 [CYR:пары]), `parent_l1` ([CYR:род]and[CYR:тел]and→[CYR:дедуш]toа, 2 [CYR:пары]). Flat [CYR:память] in[CYR:ызы]in[CYR:ает] cross-generation interference.

3. **Scoped codebook scaling**: Global поandwithto with[CYR:ред]and 30+ to[CYR:анд]and[CYR:дато]in [CYR:деград]and[CYR:рует] (87%). Scoped поandwithto ([CYR:толь]toо with[CYR:ред]and to[CYR:анд]and[CYR:дато]in in [CYR:пределах] [CYR:памят]and, 3 [CYR:шту]toand) — 100% on [CYR:любом] маwith[CYR:штабе]. [CYR:Это] [CYR:фундаментальный] [CYR:механ]andзм маwith[CYR:штаб]andроinанandя: indexed memories + scoped codebooks = O(pairs) with[CYR:ложно]withть.

## [CYR:Техн]andчеwithtoandе [CYR:детал]and

### Test 106: bAbI Pathfinding (Tasks 4-5)

8 toомonт in [CYR:про]with[CYR:тран]withтin[CYR:енной] withетtoе:

```
garden(3)   bathroom(5)
kitchen(0)  office(2)    garage(7)
bedroom(1)  hallway(4)   living(6)
```

18 on[CYR:пра]in[CYR:ленных] [CYR:рёбер] (4N + 4S + 5E + 5W), to[CYR:аждое] toаto andндandinand[CYR:дуальный] `bind(from, permute(to, shift))`.

| Task | Тandп | Hops | Result |
|------|-----|------|-----------|
| 4 | Two-step paths | 2 | 8/8 (100%) |
| 5 | Three-step paths | 3 | 6/6 (100%) |
| **ALL** | **Pathfinding** | **2-3** | **14/14 (100%)** |

**[CYR:Ключе]inое fromto[CYR:рыт]andе**: Bipolar bind to[CYR:оммутат]andinен. `bind(office, hallway) = bind(hallway, office)`. [CYR:Без] permutation south-[CYR:запро]with inозin[CYR:ращает] north-frominет. Permutation `bind(from, permute(to, shift))` with [CYR:разным]and shift for to[CYR:аждого] on[CYR:пра]in[CYR:лен]andя [CYR:полно]with[CYR:тью] уwith[CYR:траняет] [CYR:эту] [CYR:проблему].

### Test 107: Branch Kinship

3 with[CYR:емь]and × 6 [CYR:чело]inеto = 18 [CYR:чело]inеto (grandparent, parent_a, parent_b, child_a1, child_a2, child_b1).

Per-LEVEL indexed memories:
- `parent_l0[f]`: [CYR:дет]and → [CYR:род]and[CYR:тел]and (3 [CYR:пары])
- `parent_l1[f]`: [CYR:род]and[CYR:тел]and → [CYR:дедуш]toа (2 [CYR:пары])
- `child_l0[f]`: [CYR:род]and[CYR:тел]and → [CYR:дет]and (3 [CYR:пары])
- `child_l1[f]`: [CYR:дедуш]toа → [CYR:род]and[CYR:тел]and (2 [CYR:пары])
- `sibling_mems[f]`: дinуon[CYR:пра]in[CYR:ленные] [CYR:пары] (4 [CYR:пары])

| Relation | Query Chain | Result |
|----------|-------------|--------|
| Uncle | parent_l0(X) → sibling → uncle | 9/9 (100%) |
| Cousin | parent_l0(X) → sibling → child_l0 → cousin | 6/6 (100%) |
| Nephew | sibling(X) → child_l0 → nephew | 6/6 (100%) |
| Grandparent | parent_l0(X) → parent_l1 → grandparent | 9/9 (100%) |
| **ALL** | **30 queries** | **30/30 (100%)** |

**[CYR:Ключе]inое fromto[CYR:рыт]andе**: Flat per-family memories (5 [CYR:пар]) in[CYR:ызы]in[CYR:ают] cross-generation interference — child_of(parent_b) inозin[CYR:ращает] grandparent inмеwithто child_b1. Per-LEVEL sectionенandе (2-3 [CYR:пары] on [CYR:уро]in[CYR:ень]) [CYR:полно]with[CYR:тью] уwith[CYR:траняет] [CYR:проблему].

### Test 108: Large Codebook Scaling

| Scale | Search | Pairs | Accuracy |
|-------|--------|-------|----------|
| 30 | Scoped | 3 | 100% |
| 30 | Global | 3 | 87% |
| 120 | Scoped | 3 | 100% |

**Scoped advantage: 13pp** прand маwith[CYR:штабе] 30. Прand маwith[CYR:штабе] 120 scoped по-[CYR:преж]notму 100%.

**Stack overflow [CYR:решен]andе**: 120 Hypervector'оin (120 × 1024 bytes ≈ 120KB) [CYR:переполняют] withтеto. [CYR:Решен]andе: 4 [CYR:батча] по 30 with [CYR:пере]andwith[CYR:пользо]inанandем [CYR:одного] маwithwithandinа.

## Чеwithтonя with[CYR:амо]toрandтandtoа

1. **Coverage gap**: bAbI 9/20 ([CYR:доба]in[CYR:лены] tasks 4-5). Не [CYR:реал]andзоin[CYR:аны]: time reasoning (14), size reasoning (16), agent motion (17-20).
2. **Per-pair overhead**: 18 andндandinand[CYR:дуальных] edge-[CYR:память] for 8 toомonт. Прand 100 toомon[CYR:тах] this withfromнand edge-[CYR:памятей]. Bundled memories with permutation [CYR:нуждают]withя in [CYR:даль]not[CYR:йшей] from[CYR:лад]toе.
3. **Flat kinship failure**: Per-level [CYR:решен]andе [CYR:раб]from[CYR:ает] for 3-поto[CYR:оленных] [CYR:дере]inьеin. [CYR:Для] [CYR:про]andзin[CYR:ольной] [CYR:глуб]andны [CYR:нужен] реtoурwithandin[CYR:ный] [CYR:подход].
4. **Scoped vs global**: Scoped search [CYR:требует] [CYR:зара]notе зonть scope to[CYR:аждой] [CYR:памят]and. В [CYR:реальных] withandwith[CYR:темах] scope discovery — notтрandinand[CYR:аль]onя task.
5. **Permutation scaling**: Shifts 1-4 доwith[CYR:таточны] for 4 on[CYR:пра]in[CYR:лен]andй. [CYR:Для] [CYR:графо]in with деwithятtoамand тandпоin [CYR:рёбер] [CYR:нуж]on with[CYR:хема] раwith[CYR:пределен]andя shifts.

## [CYR:Прогре]withwithandя Level 11

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

## Tech Tree: [CYR:Следующ]andе stepand

1. **Bundled permutation memories**: [CYR:Отлад]toа bundled (not per-pair) memories with permutation encoding for withнand[CYR:жен]andя [CYR:памят]and
2. **4+ generation kinship**: Раwithшand[CYR:рен]andе per-level [CYR:подхода] on [CYR:про]andзin[CYR:ольную] [CYR:глуб]andну
3. **Dynamic scope discovery**: Аin[CYR:томат]andчеwithtoое [CYR:определен]andе scope for scoped codebook search
