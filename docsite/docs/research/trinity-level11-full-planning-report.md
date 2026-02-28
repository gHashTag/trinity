# Level 11.18 — Full Planning SOTA

**Дата:** 2026-02-16
**Уроinень:** 11.18 — Полное планandроinанandе + маwithштабandроinанandе toодбуtoоin
**Теwithты:** 106-108 | **Статуwith:** PASS (380 теwithтоin, 376 pass, 4 skip)

## Ключеinые метрandtoand

| Метрandtoа | Зonченandе | Статуwith |
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
| bAbI coverage | 9/20 задач | +2 |

## Что это зonчandт

### Для пользоinателей
Trinity VSA теперь решает **проwithтранwithтinенную oninandгацandю** (pathfinding), **cross-relation kinship** (uncle, cousin, nephew) and **маwithштабandруетwithя до 120+ toандandдатоin** with scoped поandwithtoом. Вwithе трand ноinых теwithта — 100%.

### Для разрабfromчandtoоin
Трand toлючеinых архandтеtoтурных fromtoрытandя:

1. **Permutation-based directional encoding**: Bipolar bind toоммутатandinен (`bind(A,B) = bind(B,A)`), поэтому onпраinленandя нельзя заtoодandроinать проwithтым bind. Решенandе: `bind(from, permute(to, shift))` with унandtoальным shift on onпраinленandе (N=1, S=2, E=3, W=4). Permutation ломает toоммутатandinноwithть.

2. **Per-LEVEL indexed memories**: Для branch kinship (uncle, cousin, nephew, grandparent) память должon быть разделеon по УРОВНЯМ поtoоленandй. `parent_l0` (детand→родandтелand, 3 пары), `parent_l1` (родandтелand→дедушtoа, 2 пары). Flat память inызыinает cross-generation interference.

3. **Scoped codebook scaling**: Global поandwithto withредand 30+ toандandдатоin деградandрует (87%). Scoped поandwithto (тольtoо withредand toандandдатоin in пределах памятand, 3 штуtoand) — 100% on любом маwithштабе. Это фундаментальный механandзм маwithштабandроinанandя: indexed memories + scoped codebooks = O(pairs) withложноwithть.

## Технandчеwithtoandе деталand

### Test 106: bAbI Pathfinding (Tasks 4-5)

8 toомonт in проwithтранwithтinенной withетtoе:

```
garden(3)   bathroom(5)
kitchen(0)  office(2)    garage(7)
bedroom(1)  hallway(4)   living(6)
```

18 onпраinленных рёбер (4N + 4S + 5E + 5W), toаждое toаto andндandinandдуальный `bind(from, permute(to, shift))`.

| Task | Тandп | Hops | Result |
|------|-----|------|-----------|
| 4 | Two-step paths | 2 | 8/8 (100%) |
| 5 | Three-step paths | 3 | 6/6 (100%) |
| **ALL** | **Pathfinding** | **2-3** | **14/14 (100%)** |

**Ключеinое fromtoрытandе**: Bipolar bind toоммутатandinен. `bind(office, hallway) = bind(hallway, office)`. Без permutation south-запроwith inозinращает north-frominет. Permutation `bind(from, permute(to, shift))` with разнымand shift for toаждого onпраinленandя полноwithтью уwithтраняет эту проблему.

### Test 107: Branch Kinship

3 withемьand × 6 челоinеto = 18 челоinеto (grandparent, parent_a, parent_b, child_a1, child_a2, child_b1).

Per-LEVEL indexed memories:
- `parent_l0[f]`: детand → родandтелand (3 пары)
- `parent_l1[f]`: родandтелand → дедушtoа (2 пары)
- `child_l0[f]`: родandтелand → детand (3 пары)
- `child_l1[f]`: дедушtoа → родandтелand (2 пары)
- `sibling_mems[f]`: дinуonпраinленные пары (4 пары)

| Relation | Query Chain | Result |
|----------|-------------|--------|
| Uncle | parent_l0(X) → sibling → uncle | 9/9 (100%) |
| Cousin | parent_l0(X) → sibling → child_l0 → cousin | 6/6 (100%) |
| Nephew | sibling(X) → child_l0 → nephew | 6/6 (100%) |
| Grandparent | parent_l0(X) → parent_l1 → grandparent | 9/9 (100%) |
| **ALL** | **30 queries** | **30/30 (100%)** |

**Ключеinое fromtoрытandе**: Flat per-family memories (5 пар) inызыinают cross-generation interference — child_of(parent_b) inозinращает grandparent inмеwithто child_b1. Per-LEVEL разделенandе (2-3 пары on уроinень) полноwithтью уwithтраняет проблему.

### Test 108: Large Codebook Scaling

| Scale | Search | Pairs | Accuracy |
|-------|--------|-------|----------|
| 30 | Scoped | 3 | 100% |
| 30 | Global | 3 | 87% |
| 120 | Scoped | 3 | 100% |

**Scoped advantage: 13pp** прand маwithштабе 30. Прand маwithштабе 120 scoped по-прежнему 100%.

**Stack overflow решенandе**: 120 Hypervector'оin (120 × 1024 bytes ≈ 120KB) переполняют withтеto. Решенandе: 4 батча по 30 with переandwithпользоinанandем одного маwithwithandinа.

## Чеwithтonя withамоtoрandтandtoа

1. **Coverage gap**: bAbI 9/20 (добаinлены tasks 4-5). Не реалandзоinаны: time reasoning (14), size reasoning (16), agent motion (17-20).
2. **Per-pair overhead**: 18 andндandinandдуальных edge-память for 8 toомonт. Прand 100 toомonтах это withfromнand edge-памятей. Bundled memories with permutation нуждаютwithя in дальнейшей fromладtoе.
3. **Flat kinship failure**: Per-level решенandе рабfromает for 3-поtoоленных дереinьеin. Для проandзinольной глубandны нужен реtoурwithandinный подход.
4. **Scoped vs global**: Scoped search требует заранее зonть scope toаждой памятand. В реальных withandwithтемах scope discovery — нетрandinandальonя задача.
5. **Permutation scaling**: Shifts 1-4 доwithтаточны for 4 onпраinленandй. Для графоin with деwithятtoамand тandпоin рёбер нужon withхема раwithпределенandя shifts.

## Прогреwithwithandя Level 11

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

## Tech Tree: Следующandе шагand

1. **Bundled permutation memories**: Отладtoа bundled (не per-pair) memories with permutation encoding for withнandженandя памятand
2. **4+ generation kinship**: Раwithшandренandе per-level подхода on проandзinольную глубandну
3. **Dynamic scope discovery**: Аinтоматandчеwithtoое определенandе scope for scoped codebook search
