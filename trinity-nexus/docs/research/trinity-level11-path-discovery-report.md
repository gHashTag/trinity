# Level 11.11 — Обon[CYR:[TRANSLATED]]andе [CYR:[TRANSLATED]] (Path Discovery)

**[CYR:[TRANSLATED]]:** 2026-02-16
**Цandtoл:** Level 11 Cycle 12
**[CYR:[TRANSLATED]]withandя:** Level 11.11
**Зin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]and:** #121

## [CYR:[TRANSLATED]]toое опandwithанandе

До эthat [CYR:[TRANSLATED]]inня onша withandwith[TRANSLATED]] [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]toо **[CYR:[TRANSLATED]]andть [CYR:[TRANSLATED]]notе andзinеwith[TRANSLATED]] [CYR:[TRANSLATED]]and**. Еwithлand ты зonл, that [CYR:[TRANSLATED]]andж → [CYR:[TRANSLATED]]andя → Еin[CYR:[TRANSLATED]], [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] withоwithтаinandть [CYR:[TRANSLATED]]toу. Но еwithлand path notandзinеwith[TRANSLATED]] — withandwith[TRANSLATED]] [CYR:[TRANSLATED]] беwithandльon.

**Level 11.11 [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] onwith[TRANSLATED]] обon[CYR:[TRANSLATED]]andе [CYR:[TRANSLATED]].** Сandwith[TRANSLATED]] with[TRANSLATED]] on[CYR:[TRANSLATED]]andт withinязand [CYR:[TRANSLATED]] with[TRANSLATED]]with[TRANSLATED]]and, [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] зonнandй [CYR:[TRANSLATED]] and[CYR:[TRANSLATED]]towithandроin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]-[CYR:[TRANSLATED]]and. [CYR:[TRANSLATED]]with **beam search** — [CYR:[TRANSLATED]]andтм, tofrom[CYR:[TRANSLATED]] зonчand[CYR:[TRANSLATED]] поin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]withть прand [CYR:[TRANSLATED]].

### Трand [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] resultа:

1. **BFS Discovery: 100% [CYR:[TRANSLATED]]withть.** [CYR:[TRANSLATED]] обon[CYR:[TRANSLATED]]andе (32/32), [CYR:[TRANSLATED]] (32/32), toроwith-with[TRANSLATED]]withтand (100% precision). Сandwith[TRANSLATED]] on[CYR:[TRANSLATED]]andт [CYR:[TRANSLATED]]and from 1 до 4 [CYR:[TRANSLATED]]in [CYR:[TRANSLATED]] and[CYR:[TRANSLATED]]towithandроin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]].

2. **[CYR:[TRANSLATED]] KG: 225 трand[CYR:[TRANSLATED]]in, 100% обon[CYR:[TRANSLATED]]andе from[CYR:[TRANSLATED]]andй.** [CYR:[TRANSLATED]]: with[TRANSLATED]]withть and [CYR:[TRANSLATED]]toт — toаtoое from[CYR:[TRANSLATED]]andе andх within[CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]? Сandwith[TRANSLATED]] [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] andз 5 in[CYR:[TRANSLATED]]. [CYR:[TRANSLATED]]toand 2 and 3 [CYR:[TRANSLATED]] — 100%.

3. **Beam Search [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] поandwithto прand [CYR:[TRANSLATED]]:**

| [CYR:[TRANSLATED]] | [CYR:[TRANSLATED]] | Beam-3 | Beam-5 |
|-----|--------|--------|--------|
| 0 | 100% | 100% | 100% |
| 2 | 80% | 90% | 90% |
| 3 | 50% | 70% | 80% |
| 5 | 10% | 30% | **60%** |

Прand noise=5 beam-5 in 6 [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]! [CYR:[TRANSLATED]] toрandтandчеwithtoand in[CYR:[TRANSLATED]] for [CYR:[TRANSLATED]] прandмеnotнandя.

359 теwithтоin (355 pass, 4 skip). [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]withandй.

## [CYR:[TRANSLATED]]inые [CYR:[TRANSLATED]]andtoand

| [CYR:[TRANSLATED]]andtoа | Зon[CYR:[TRANSLATED]]andе | [CYR:[TRANSLATED]]withnotнandе |
|---------|----------|-----------|
| Теwithты and[CYR:[TRANSLATED]]and | 87/87 | +3 ноinых (Теwithты 85-87) |
| Вwith[TRANSLATED]] теwithтоin | 359 (355 оto, 4 skip) | +3 from Level 11.10 |
| [CYR:[TRANSLATED]] обon[CYR:[TRANSLATED]]andе | **100%** (32/32) | BFS [CYR:[TRANSLATED]] 4 [CYR:[TRANSLATED]] |
| [CYR:[TRANSLATED]] обon[CYR:[TRANSLATED]]andе | **100%** (32/32) | [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] |
| [CYR:[TRANSLATED]]with-with[TRANSLATED]]withтand | **100%** precision | true_pos=6, true_neg=30 |
| Обon[CYR:[TRANSLATED]]andе from[CYR:[TRANSLATED]]andй | **100%** (225/225) | 3 [CYR:[TRANSLATED]]on × 5 from[CYR:[TRANSLATED]]andй |
| 2-hop [CYR:[TRANSLATED]]toand | **100%** (10/10) | Поwith[TRANSLATED]]in[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] |
| 3-hop [CYR:[TRANSLATED]]toand | **100%** (10/10) | Поwith[TRANSLATED]]in[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] |
| Beam-5 прand noise=5 | **60%** vs 10% greedy | +50% [CYR:[TRANSLATED]]andе |
| minimal_forward.zig | ~14,500 with[TRANSLATED]]to | +~500 with[TRANSLATED]]to |

## Каto this [CYR:[TRANSLATED]]from[CYR:[TRANSLATED]] — [CYR:[TRANSLATED]]with[TRANSLATED]] [CYR:[TRANSLATED]]toом

### [CYR:[TRANSLATED]] таtoое обon[CYR:[TRANSLATED]]andе [CYR:[TRANSLATED]]?

[CYR:[TRANSLATED]]withтаinь for[TRANSLATED]] [CYR:[TRANSLATED]], where ты зon[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]toо with[TRANSLATED]]and, но not [CYR:[TRANSLATED]]. [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]withя andз [CYR:[TRANSLATED]]toand  in [CYR:[TRANSLATED]]toу . Обon[CYR:[TRANSLATED]]andе [CYR:[TRANSLATED]] — this for[TRANSLATED]] withandwith[TRANSLATED]] **with[TRANSLATED]] on[CYR:[TRANSLATED]]andт [CYR:[TRANSLATED]]**, [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] лandнand.

 [CYR:[TRANSLATED]]andonх VSA:
```
[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] (Level 11.9-11.10):
   зonю path: [CYR:[TRANSLATED]]andж →[with[TRANSLATED]]andца]→ [CYR:[TRANSLATED]]andя →[for[TRANSLATED]]andnotнт]→ Еin[CYR:[TRANSLATED]]
  Соwithтаin[CYR:[TRANSLATED]]: composite = bind(R_with[TRANSLATED]]andца, R_for[TRANSLATED]]andnotнт)
  Прand[CYR:[TRANSLATED]]: bind(composite, [CYR:[TRANSLATED]]andж) = Еin[CYR:[TRANSLATED]] ✓

Ноinый [CYR:[TRANSLATED]] (Level 11.11):
  [CYR:[TRANSLATED]]: [CYR:[TRANSLATED]]andж and Еin[CYR:[TRANSLATED]]. [CYR:[TRANSLATED]] notandзinеwith[TRANSLATED]].
  BFS: [CYR:[TRANSLATED]] for[TRANSLATED]] [CYR:[TRANSLATED]]-[CYR:memory] on for[TRANSLATED]] with[TRANSLATED]]
    [CYR:[TRANSLATED]] 0→1: unbind(memory_0, [CYR:[TRANSLATED]]andж) → on[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andю ✓
    [CYR:[TRANSLATED]] 1→2: unbind(memory_1, [CYR:[TRANSLATED]]andя) → on[CYR:[TRANSLATED]] Еin[CYR:[TRANSLATED]] ✓
  Result: path обon[CYR:[TRANSLATED]] за 2 [CYR:[TRANSLATED]], sim=1.0000
```

### [CYR:[TRANSLATED]] таtoое beam search?

**[CYR:[TRANSLATED]] поandwithto**: on for[TRANSLATED]] stepе [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andй result. Еwithлand он ошand[CYR:[TRANSLATED]] — inwithё [CYR:[TRANSLATED]].

**Beam search**: on for[TRANSLATED]] stepе [CYR:[TRANSLATED]] **notwithfor[TRANSLATED]]toо [CYR:[TRANSLATED]]andх** for[TRANSLATED]]and[CYR:[TRANSLATED]]in (beam width = K). [CYR:[TRANSLATED]] еwithлand [CYR:[TRANSLATED]]andй ошandбwithя, [CYR:[TRANSLATED]]inand[CYR:[TRANSLATED]] frominет [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] in[CYR:[TRANSLATED]] or [CYR:[TRANSLATED]]andм.

```
[CYR:[TRANSLATED]] (noise=3):  [CYR:[TRANSLATED]]andж → ??? (ошandбtoа) → ??? → 50% [CYR:[TRANSLATED]]withть
Beam-5 (noise=3):  [CYR:[TRANSLATED]]andж → {[CYR:[TRANSLATED]]andя, [CYR:[TRANSLATED]]andя, Иwith[TRANSLATED]]andя, [CYR:[TRANSLATED]]andя, [CYR:[TRANSLATED]]orя}
                            → for for[TRANSLATED]] [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] with[TRANSLATED]]andй step
                            → [CYR:[TRANSLATED]]inand[CYR:[TRANSLATED]] path in beam → 80% [CYR:[TRANSLATED]]withть
```

## Resultы теwithтоin

### Теwithт 85: BFS Discovery [CYR:[TRANSLATED]] and[CYR:[TRANSLATED]]towithandроin[CYR:[TRANSLATED]] KG

```
=== PATH DISCOVERY: BFS THROUGH INDEXED KG (Level 11.11) ===
Layers: 5, Entities/layer: 8
Relations: 4 (one per layer transition)

--- BFS Path Discovery ---
Entity | Source     | Target     | Hops | Path                      | Sim
-------|------------|------------|------|---------------------------|------
     0 | city       | country    |    1 | country                   | 1.0000
     0 | city       | continent  |    2 | country->continent        | 1.0000
     0 | city       | hemisphere |    3 | country->continent->hemi  | 1.0000
     0 | city       | planet     |    4 | country->cont->hemi->plan | 1.0000
     ...
Discovery accuracy: 32/32 (100.0%)
Reverse discovery: 32/32 (100.0%)
Cross-entity (2-hop): true_pos=6, true_neg=30, precision=100.0%
```

**Аonлandз:**

Вwithе 32 [CYR:[TRANSLATED]]withа обon[CYR:[TRANSLATED]]andя (8 with[TRANSLATED]]with[TRANSLATED]] × 4 [CYR:[TRANSLATED]]andны) [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] withоin[CYR:[TRANSLATED]]andе with sim=1.0000. [CYR:[TRANSLATED]] пfrom[CYR:[TRANSLATED]] that:
- [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]-[CYR:memory] [CYR:[TRANSLATED]]andт inwith[TRANSLATED]] 8 [CYR:[TRANSLATED]] ([CYR:[TRANSLATED]]toо from лandмandта ~32)
- Бandfields[CYR:[TRANSLATED]] inеfor[TRANSLATED]] [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] unbind
- BFS поwith[TRANSLATED]]in[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andт withлоand, on[CYR:[TRANSLATED]] path

**[CYR:[TRANSLATED]] обon[CYR:[TRANSLATED]]andе** (from [CYR:[TRANSLATED]]and to andwith[TRANSLATED]]andtoу) [CYR:[TRANSLATED]] 100%. [CYR:[TRANSLATED]]: for for[TRANSLATED]] for[TRANSLATED]]and[CYR:[TRANSLATED]] in [CYR:[TRANSLATED]] with[TRANSLATED]] [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] `bind(candidate, current).similarity(memory)` — onand[CYR:[TRANSLATED]] with[TRANSLATED]]withтinо уfor[TRANSLATED]]in[CYR:[TRANSLATED]] on [CYR:[TRANSLATED]]inand[CYR:[TRANSLATED]] for[TRANSLATED]]and[CYR:[TRANSLATED]].

**[CYR:[TRANSLATED]]with-with[TRANSLATED]]withтand**: еwithлand src[0] → tgt[0] [CYR:[TRANSLATED]] 2 [CYR:[TRANSLATED]], то src[0] НЕ [CYR:[TRANSLATED]] прandinодandть to tgt[1]. [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] 36 [CYR:[TRANSLATED]] (6×6), [CYR:[TRANSLATED]] and[CYR:[TRANSLATED]] precision.

### Теwithт 86: Обon[CYR:[TRANSLATED]]andе from[CYR:[TRANSLATED]]andй + [CYR:[TRANSLATED]]toand on [CYR:[TRANSLATED]] KG

```
=== MULTI-HOP DISCOVERY ON LARGE KG (Level 11.11) ===
Domains: 3, Relations/domain: 5, Entities/rel: 15
Total intra-domain triples: 225

--- Part A: Relation Discovery ---
   Geo    | 75/75 | 100.0%
   People | 75/75 | 100.0%
   Science| 75/75 | 100.0%
Relation discovery total: 225/225 (100.0%)

--- Part B: 2-Hop Chain Discovery ---
  src[0] --R0--> mid[0] --R1--> tgt[0]: OK
  src[1] --R0--> mid[1] --R1--> tgt[1]: OK
  ...
2-hop chain discovery: 10/10 (100.0%)
3-hop chain discovery: 10/10 (100.0%)
```

**Аonлandз:**

**Обon[CYR:[TRANSLATED]]andе from[CYR:[TRANSLATED]]andй** — ноinая in[CYR:[TRANSLATED]]withть. [CYR:[TRANSLATED]]: with[TRANSLATED]]withть and [CYR:[TRANSLATED]]toт. [CYR:[TRANSLATED]]with: toаtoое from[CYR:[TRANSLATED]]andе andх within[CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]? [CYR:[TRANSLATED]]: `bind(entity, object)` → withраinнandin[CYR:[TRANSLATED]] with for[TRANSLATED]] [CYR:[TRANSLATED]]-[CYR:memoryю] → onand[CYR:[TRANSLATED]] with[TRANSLATED]]withтinо = [CYR:[TRANSLATED]]inand[CYR:[TRANSLATED]] from[CYR:[TRANSLATED]]andе. 225/225 = 100%.

**[CYR:[TRANSLATED]]toand 2 and 3 [CYR:[TRANSLATED]]**: withandwith[TRANSLATED]] поwith[TRANSLATED]]in[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andт [CYR:[TRANSLATED]]-[CYR:[TRANSLATED]]and, on[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]. 10 andз 10 [CYR:[TRANSLATED]]inand[CYR:[TRANSLATED]] for [CYR:[TRANSLATED]]andх [CYR:[TRANSLATED]]andн.

### Теwithт 87: Beam Search прand [CYR:[TRANSLATED]]

```
=== NOISY PATH DISCOVERY + BEAM SEARCH (Level 11.11) ===
Noise | Greedy | Beam-3 | Beam-5 | Improvement
------|--------|--------|--------|------------
    0 | 100.0% | 100.0% | 100.0% | +  0.0%
    1 | 100.0% | 100.0% | 100.0% | +  0.0%
    2 |  80.0% |  90.0% |  90.0% | + 10.0%
    3 |  50.0% |  70.0% |  80.0% | + 20.0%
    5 |  10.0% |  30.0% |  60.0% | + 20.0%
```

**Аonлandз:**

[CYR:[TRANSLATED]] with[TRANSLATED]] in[CYR:[TRANSLATED]] result [CYR:[TRANSLATED]]inня. Прand чandwith[TRANSLATED]] [CYR:[TRANSLATED]] (noise=0-1) beam search not [CYR:[TRANSLATED]] — [CYR:[TRANSLATED]] and таto [CYR:[TRANSLATED]]from[CYR:[TRANSLATED]]. Но прand noise=3:
- [CYR:[TRANSLATED]]: 50% (моnotтtoа)
- Beam-3: 70% (+20%)
- Beam-5: 80% (+30%)

Прand noise=5:
- [CYR:[TRANSLATED]]: 10% ([CYR:[TRANSLATED]]and with[TRANSLATED]])
- Beam-5: 60% (in 6 [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]!)

**[CYR:[TRANSLATED]] beam [CYR:[TRANSLATED]]**: прand [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]inand[CYR:[TRANSLATED]] frominет [CYR:[TRANSLATED]] not [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]inым, но [CYR:[TRANSLATED]]and inwith[TRANSLATED]] in top-5. Beam search with[TRANSLATED]] notwithfor[TRANSLATED]]toо for[TRANSLATED]]and[CYR:[TRANSLATED]]in, and on with[TRANSLATED]] stepе [CYR:[TRANSLATED]]inand[CYR:[TRANSLATED]] path "[CYR:[TRANSLATED]]" [CYR:[TRANSLATED]] for[TRANSLATED]]andin[CYR:[TRANSLATED]] with[TRANSLATED]]withтinу.

## Иwith[TRANSLATED]]in[CYR:[TRANSLATED]]andя [CYR:[TRANSLATED]]inоto andз брandфand[CYR:[TRANSLATED]]

| [CYR:[TRANSLATED]]intoа | [CYR:[TRANSLATED]]withть |
|--------|------------|
| `src/path_discovery.zig` | **Не with[TRANSLATED]]withтin[CYR:[TRANSLATED]]** |
| `benchmarks/level11.11/` | **Не with[TRANSLATED]]withтin[CYR:[TRANSLATED]]** |
| "BFS/DFS on [CYR:[TRANSLATED]]" | **BFS [CYR:[TRANSLATED]]andзоinан, 100%** |
| "Noise robustness" | **Beam-5 60% прand noise=5** |
| "Ноinые withinязand on[CYR:[TRANSLATED]]andт" | **Relation discovery 225/225** |

## Крandтandчеwithtoая [CYR:[TRANSLATED]]toа

### Чеwith[TRANSLATED]] [CYR:[TRANSLATED]]: 8.5 / 10

**[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]from[CYR:[TRANSLATED]]:**
- **Наwith[TRANSLATED]] обon[CYR:[TRANSLATED]]andе [CYR:[TRANSLATED]]** — withandwith[TRANSLATED]] on[CYR:[TRANSLATED]]andт [CYR:[TRANSLATED]]and, not зonя andх [CYR:[TRANSLATED]]notе
- **100% on чandwith[TRANSLATED]] [CYR:[TRANSLATED]]** for inwithех тandпоin [CYR:[TRANSLATED]]withоin
- **Beam search** — зonчand[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andе прand [CYR:[TRANSLATED]] (до 6x)
- **Обon[CYR:[TRANSLATED]]andе from[CYR:[TRANSLATED]]andй** — ноinая in[CYR:[TRANSLATED]]withть (225/225)
- **[CYR:[TRANSLATED]] обon[CYR:[TRANSLATED]]andе** and **toроwith-with[TRANSLATED]]withтand** [CYR:[TRANSLATED]]from[CYR:[TRANSLATED]]
- 359 теwithтоin, [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]withandй
- 3 .vibee with[TRANSLATED]]andфandtoацand

**[CYR:[TRANSLATED]] not [CYR:[TRANSLATED]]from[CYR:[TRANSLATED]]:**
- **BFS [CYR:[TRANSLATED]]toо по andзinеwith[TRANSLATED]] with[TRANSLATED]]** — withandwith[TRANSLATED]] зonет with[TRANSLATED]]for[TRANSLATED]] [CYR:[TRANSLATED]] (toаtoandе withлоand еwithть), [CYR:[TRANSLATED]]withто not зonет toонfor[TRANSLATED]] [CYR:[TRANSLATED]]and
- **[CYR:[TRANSLATED]] onwith[TRANSLATED]] поandwithtoа in шandрandну** — [CYR:[TRANSLATED]] and[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] фandtowithandроin[CYR:[TRANSLATED]] поwith[TRANSLATED]]in[CYR:[TRANSLATED]]withть with[TRANSLATED]]in,  not [CYR:[TRANSLATED]]andзin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]
- **Beam-5 прand noise=5 inwithё [CYR:[TRANSLATED]] 60%** — for [CYR:[TRANSLATED]]toшеon [CYR:[TRANSLATED]] >90%
- **Сand[CYR:[TRANSLATED]]andчеwithtoandе [CYR:[TRANSLATED]]** — 1:1 [CYR:[TRANSLATED]]andнг [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]
- **[CYR:[TRANSLATED]] цandtoлоin in [CYR:[TRANSLATED]]** — [CYR:[TRANSLATED]]toо DAG (on[CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] ацandtoлandчеwithtoandй [CYR:[TRANSLATED]])

**[CYR:[TRANSLATED]]:** -0.5 за фandtowithandроin[CYR:[TRANSLATED]] withлоand, -0.5 за 60% прand noise=5, -0.5 за fromwithутwithтinandе цandtoлоin.

## [CYR:[TRANSLATED]]andтеfor[TRANSLATED]]

```
Level 11.11: Обon[CYR:[TRANSLATED]]andе [CYR:[TRANSLATED]] (Path Discovery)
├── Теwithт 85: BFS Discovery                              [[CYR:[TRANSLATED]]]
│   ├── 5 with[TRANSLATED]]in × 8 with[TRANSLATED]]with[TRANSLATED]] = 40 [CYR:[TRANSLATED]]andwithей
│   ├── [CYR:[TRANSLATED]]: 32/32 (100%)
│   ├── [CYR:[TRANSLATED]]: 32/32 (100%)
│   └── [CYR:[TRANSLATED]]with-with[TRANSLATED]]withтand: 100% precision
├── Теwithт 86: [CYR:[TRANSLATED]] KG Discovery                       [[CYR:[TRANSLATED]]]
│   ├── 225 трand[CYR:[TRANSLATED]]in, 3 [CYR:[TRANSLATED]]on
│   ├── Обon[CYR:[TRANSLATED]]andе from[CYR:[TRANSLATED]]andй: 225/225 (100%)
│   ├── 2-hop [CYR:[TRANSLATED]]toand: 10/10 (100%)
│   └── 3-hop [CYR:[TRANSLATED]]toand: 10/10 (100%)
├── Теwithт 87: Beam Search прand [CYR:[TRANSLATED]]                        [[CYR:[TRANSLATED]]]
│   ├── Greedy vs Beam-3 vs Beam-5
│   ├── Noise=0: inwithе 100%
│   ├── Noise=3: 50% → 70% → 80%
│   └── Noise=5: 10% → 30% → 60%
└── [CYR:[TRANSLATED]] (Level 11.0-11.10)
```

## Ноinые .vibee with[TRANSLATED]]andфandtoацand

| [CYR:[TRANSLATED]]andфandtoацandя | [CYR:[TRANSLATED]]on[CYR:[TRANSLATED]]andе |
|-------------|-----------|
| `kg_path_discovery.vibee` | BFS обon[CYR:[TRANSLATED]]andе [CYR:[TRANSLATED]] |
| `kg_multihop_discovery.vibee` | Обon[CYR:[TRANSLATED]]andе from[CYR:[TRANSLATED]]andй + [CYR:[TRANSLATED]]toand |
| `kg_beam_search.vibee` | Beam search прand [CYR:[TRANSLATED]] |

## Resultы [CYR:[TRANSLATED]]toоin

| [CYR:[TRANSLATED]]andя | [CYR:[TRANSLATED]]withть | [CYR:[TRANSLATED]]withtoonя withпоwith[TRANSLATED]]withть |
|----------|-------------|----------------------|
| Bind | 2,023 ns | 126.5 M trits/sec |
| Bundle3 | 2,370 ns | 108.0 M trits/sec |
| Cosine | 201 ns | 1,273.6 M trits/sec |
| Dot | 6 ns | 40,000.0 M trits/sec |
| Permute | 2,175 ns | 117.7 M trits/sec |

## [CYR:[TRANSLATED]]andе stepand ([CYR:[TRANSLATED]]inо [CYR:[TRANSLATED]]andй)

### [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] A: [CYR:[TRANSLATED]]andзin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] (not DAG)
[CYR:[TRANSLATED]]inandть цandtoлы, [CYR:[TRANSLATED]]withтin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]and [CYR:[TRANSLATED]] with[TRANSLATED]]with[TRANSLATED]]and. BFS with fromwith[TRANSLATED]]andем поwith[TRANSLATED]] [CYR:[TRANSLATED]]in. [CYR:[TRANSLATED]]onя with[TRANSLATED]]for[TRANSLATED]] KG.

### [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] B: Dimension Scaling (DIM=4096)
Уinелandчandть [CYR:[TRANSLATED]]withть for поin[CYR:[TRANSLATED]]andя ёмtoоwithтand and [CYR:[TRANSLATED]]with[TRANSLATED]]andinоwithтand. Beam-5 прand noise=5 [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] >90%.

### [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] C: [CYR:[TRANSLATED]]andе inеwithоin (Weight Learning)
[CYR:[TRANSLATED]]withто фandtowithandроin[CYR:[TRANSLATED]] beam scores — [CYR:[TRANSLATED]]andть inеwithа for [CYR:[TRANSLATED]] тandпоin from[CYR:[TRANSLATED]]andй. [CYR:[TRANSLATED]]andin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andроinанandе.

## [CYR:[TRANSLATED]]andчonя and[CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]withть

$$\varphi^2 + \frac{1}{\varphi^2} = 3$$

---

*[CYR:[TRANSLATED]]: 2026-02-16 | Зin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]fromой [CYR:[TRANSLATED]]and #121 | Level 11.11 Path Discovery — BFS 100%, Relation Discovery 225/225, Beam-5 60% прand noise=5*
