# Level 11.14 — Weighted Edges: Dijkstra-Style Priority [CYR:[TRANSLATED]] VSA

**[CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]**: 11.14 — Weighted Edges
**[CYR:[TRANSLATED]]with**: [CYR:[TRANSLATED]]
**Теwithты**: 94-96 (368 inwith[TRANSLATED]], 364 pass, 4 skip)

---

## [CYR:[TRANSLATED]]inые [CYR:[TRANSLATED]]andtoand

| [CYR:[TRANSLATED]]andtoа | Зon[CYR:[TRANSLATED]]andе | [CYR:[TRANSLATED]]with |
|---------|----------|--------|
| Веwithоinая for[TRANSLATED]]andя | **[CYR:[TRANSLATED]]fromонonя** (sim: 0.48→0.34→0.27→0.21→0.15) | ✅ |
| Dijkstra traversal | Доwithтand[CYR:[TRANSLATED]] T за **3 [CYR:[TRANSLATED]]** | ✅ |
| Light vs Heavy (noise=5) | **93% vs 21%** (72pp advantage) | ✅ |
| Capacity monotonicity | **true** — [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] = withandльnotе withandгonл | ✅ |
| Accuracy cap=3 | **100%** | ✅ |
| Accuracy cap=25 | **97.3%** | ✅ |

---

## [CYR:[TRANSLATED]] this зonчandт

### [CYR:[TRANSLATED]] andwith[TRANSLATED]]in[CYR:[TRANSLATED]]
Обon[CYR:[TRANSLATED]] **VSA-onтandin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andзм inеwithоin**: ёмtoоwithть [CYR:[TRANSLATED]]and (toолandчеwithтinо [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]) on[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] withandлу withandгonла прand andзin[CYR:[TRANSLATED]]and. [CYR:[TRANSLATED]] not innotшнandй withfor[TRANSLATED]],  **[CYR:[TRANSLATED]] withinойwithтinо with[TRANSLATED]]andцand**. [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] in [CYR:[TRANSLATED]]and → in[CYR:[TRANSLATED]] cosine similarity прand [CYR:[TRANSLATED]]withе → "withandльnotе" within[CYR:[TRANSLATED]]. [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]inый доfor[TRANSLATED]] [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] capacity-based weight mechanism for VSA Knowledge Graph.

### [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]fromчandtoоin
[CYR:[TRANSLATED]]toтandчеwithtoое зon[CYR:[TRANSLATED]]andе: for Dijkstra-style поandwithtoа по [CYR:[TRANSLATED]] зonнandй not [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andть from[CYR:[TRANSLATED]] withfor[TRANSLATED]] inеwithоin. **[CYR:[TRANSLATED]] VSA-[CYR:memory] toодand[CYR:[TRANSLATED]] inеwith [CYR:[TRANSLATED]] ёмtoоwithть**. Relation with 5 [CYR:[TRANSLATED]]and (sim=0.34) еwithтеwithтin[CYR:[TRANSLATED]] прandорand[CYR:[TRANSLATED]]notе relation with 25 [CYR:[TRANSLATED]]and (sim=0.15). Прand [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]and innotшнandх withfor[TRANSLATED]]in (weight = 1/capacity) [CYR:[TRANSLATED]] score = sim × weight for [CYR:[TRANSLATED]] Dijkstra.

### [CYR:[TRANSLATED]] andнinеwith[TRANSLATED]]in
Weighted edges — for[TRANSLATED]]inая фandча for [CYR:[TRANSLATED]]toтandчеwithfor[TRANSLATED]] withandмinолandчеwithfor[TRANSLATED]] ИИ. [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] зonнandй and[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] with[TRANSLATED]] уin[CYR:[TRANSLATED]]withтand in фаfor[TRANSLATED]]. [CYR:[TRANSLATED]] Trinity VSA [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] "[CYR:[TRANSLATED]] with[TRANSLATED]]andца" from "where-то [CYR:[TRANSLATED]]" — [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] [CYR:[TRANSLATED]], [CYR:[TRANSLATED]]withто [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andтеfor[TRANSLATED]] [CYR:[TRANSLATED]]and.

---

## [CYR:[TRANSLATED]]andтеfor[TRANSLATED]] inеwithоin

### Capacity-Based Weight (VSA-onтandin[CYR:[TRANSLATED]])

```
Прandнцandп: weight ∝ 1/capacity

Memory with 5 [CYR:[TRANSLATED]]and:  sim = 0.34 (withand[CYR:[TRANSLATED]] withandгonл)
Memory with 10 [CYR:[TRANSLATED]]and: sim = 0.27 (with[TRANSLATED]]andй)
Memory with 25 [CYR:[TRANSLATED]]and: sim = 0.15 (with[TRANSLATED]] withandгonл)

[CYR:[TRANSLATED]]: with[TRANSLATED]]andцandя N inеfor[TRANSLATED]]in → for[TRANSLATED]] [CYR:[TRANSLATED]] ~1/sqrt(N) from [CYR:[TRANSLATED]] withandгonла.
[CYR:[TRANSLATED]] N → withandльnotе for[TRANSLATED]] for[TRANSLATED]]notнт → in[CYR:[TRANSLATED]] similarity прand andзin[CYR:[TRANSLATED]]and.
```

### Dijkstra Priority Score

```
score(edge) = retrieval_similarity × scalar_weight

[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] S → A:
  1. Unbind S andз adjacency memory
  2. [CYR:[TRANSLATED]]andть similarity to for[TRANSLATED]] for[TRANSLATED]]and[CYR:[TRANSLATED]]
  3. [CYR:[TRANSLATED]]andть on scalar weight (1/capacity or innotшнandй)
  4. [CYR:[TRANSLATED]] max score
```

---

## Теwithт 94: Weighted Edges — Capacity-Based

Трand withinязand with [CYR:[TRANSLATED]] ёмtoоwith[TRANSLATED]]:

| Сin[CYR:[TRANSLATED]] | [CYR:[TRANSLATED]] | Accuracy | Avg Sim | VSA Weight |
|-------|-----|----------|---------|------------|
| capital (strong) | 5 | **100%** | **0.3377** | 0.200 |
| borders (medium) | 10 | **100%** | **0.2642** | 0.100 |
| nearby (weak) | 25 | **96%** | **0.1476** | 0.040 |

**[CYR:[TRANSLATED]]from[CYR:[TRANSLATED]]withть [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]on**: capital > borders > nearby по similarity.

[CYR:[TRANSLATED]]inое fromfor[TRANSLATED]]andе: [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] яin[CYR:[TRANSLATED]] inеwithоin, VSA аin[CYR:[TRANSLATED]]andчеwithtoand прandорandтandзand[CYR:[TRANSLATED]] withinязand with [CYR:[TRANSLATED]] toонfor[TRANSLATED]]andей in [CYR:[TRANSLATED]]and.

---

## Теwithт 95: Dijkstra Priority Traversal

[CYR:[TRANSLATED]] with 6 [CYR:[TRANSLATED]]and (S, A, B, C, D, T) and 7 [CYR:[TRANSLATED]]and:

```
S → A (weight=0.9)    A → T (weight=0.9)
S → B (weight=0.3)    B → T (weight=0.3)
S → C (weight=0.6)    C → D (weight=0.6)    D → T (weight=0.6)
```

**Result**: [CYR:[TRANSLATED]] methodа (weighted and unweighted) доwithтand[CYR:[TRANSLATED]] T за 3 [CYR:[TRANSLATED]].

| [CYR:[TRANSLATED]] | [CYR:[TRANSLATED]] | [CYR:[TRANSLATED]] | Score |
|-------|------|------|-------|
| Weighted (sim×weight) | S→C→D→T | 3 | 1.7169 |
| Unweighted (sim only) | S→C→D→T | 3 | 2.8615 |

[CYR:[TRANSLATED]] in[CYR:[TRANSLATED]]and S→C→D→T пfrom[CYR:[TRANSLATED]] that S and[CYR:[TRANSLATED]] 3 andwith[TRANSLATED]]andх [CYR:[TRANSLATED]] in [CYR:[TRANSLATED]] adjacency memory (toонfor[TRANSLATED]]andя),  C and D and[CYR:[TRANSLATED]] по [CYR:[TRANSLATED]] (чandwith[TRANSLATED]] withandгonл sim=1.0). [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] capacity-based weight: одand[CYR:[TRANSLATED]] bindings [CYR:[TRANSLATED]] and[CYR:[TRANSLATED]] inоwith[TRANSLATED]]in[CYR:[TRANSLATED]]andе.

---

## Теwithт 96: Weight vs Noise Benchmark

### Capacity → Similarity ([CYR:[TRANSLATED]] [CYR:[TRANSLATED]])

| Capacity | Accuracy | Avg Sim | VSA Weight |
|----------|----------|---------|------------|
| 3 | 100% | 0.4786 | 0.333 |
| 5 | 100% | 0.3411 | 0.200 |
| 10 | 100% | 0.2700 | 0.100 |
| 15 | 100% | 0.2106 | 0.067 |
| 25 | 97.3% | 0.1491 | 0.040 |

### Noise Resilience

| Capacity \ Noise | 0 | 1 | 2 | 3 | 5 |
|-------------------|-----|-----|-----|-----|-----|
| 5 (light/strong) | 100% | 100% | 100% | 80% | **93%** |
| 10 (medium) | 100% | 100% | 83% | 77% | 87% |
| 25 (heavy/weak) | 95% | 72% | 24% | 24% | **21%** |

**Light advantage at noise=5: 72 [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]toта** (93% vs 21%).

[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] result: "withand[CYR:[TRANSLATED]]" withinязand ([CYR:[TRANSLATED]] [CYR:[TRANSLATED]]) not [CYR:[TRANSLATED]]toо [CYR:[TRANSLATED]]notе andзinлеfor[TRANSLATED]]withя, но and **зonчand[CYR:[TRANSLATED]] уwith[TRANSLATED]]andinее to [CYR:[TRANSLATED]]**.  [CYR:[TRANSLATED]] KG this озon[CYR:[TRANSLATED]]: inыwithоfor[TRANSLATED]]inерand[CYR:[TRANSLATED]] фаtoты ([CYR:[TRANSLATED]] [CYR:[TRANSLATED]]onтandin) оwith[TRANSLATED]]withя доwith[TRANSLATED]]and [CYR:[TRANSLATED]] прand [CYR:[TRANSLATED]] [CYR:[TRANSLATED]].

---

## Крandтandчеwithtoая [CYR:[TRANSLATED]]toа

### [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]from[CYR:[TRANSLATED]]
1. **Capacity-based weight** — [CYR:[TRANSLATED]] in[CYR:[TRANSLATED]] VSA-onтandin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andзм
2. **Monotonicity** — similarity with[TRANSLATED]] [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] with toолandчеwithтinом [CYR:[TRANSLATED]]
3. **Noise resilience** — 72pp advantage light vs heavy — [CYR:[TRANSLATED]]toтandчеwithtoand зonчandмо
4. **Dijkstra traversal** — [CYR:[TRANSLATED]]from[CYR:[TRANSLATED]], доwithтand[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]and

### [CYR:[TRANSLATED]] on[CYR:[TRANSLATED]]andе
[CYR:[TRANSLATED]]toа "уwithorть" inеwith [CYR:[TRANSLATED]] поin[CYR:[TRANSLATED]] bundling (reinforcement) **not [CYR:[TRANSLATED]]from[CYR:[TRANSLATED]]** in ternary VSA. Bundling memory with toопandей with[TRANSLATED]] = majority vote, tofrom[CYR:[TRANSLATED]] not уwithorin[CYR:[TRANSLATED]] withandгonл,  [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] from toin[CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]and. [CYR:[TRANSLATED]]inand[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] — [CYR:[TRANSLATED]]toо capacity-based weight.

### [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя
1. Dijkstra in теfor[TRANSLATED]] [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]and = greedy (top-1 on for[TRANSLATED]] stepе), not onwith[TRANSLATED]]andй priority queue
2. Scalar weights [CYR:[TRANSLATED]]withя from[CYR:[TRANSLATED]] from VSA — notт едand[CYR:[TRANSLATED]] VSA-toодandроinанandя inеwithа + [CYR:[TRANSLATED]]
3. Прand 3 andwith[TRANSLATED]]andх [CYR:[TRANSLATED]] andз [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] toонfor[TRANSLATED]]andя in adjacency memory withнand[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andчandмоwithть

---

## Tech Tree: [CYR:[TRANSLATED]]andе stepand

| [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] | Опandwithанandе |
|---------|----------|
| **A: Temporal reasoning** | [CYR:[TRANSLATED]]inandть in[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]toand to фаfor[TRANSLATED]], reasoning  [CYR:[TRANSLATED]]toе with[TRANSLATED]]andй |
| **B: Contextual queries** | [CYR:[TRANSLATED]]withы with for[TRANSLATED]]towith[TRANSLATED]] ("with[TRANSLATED]]andца [CYR:[TRANSLATED]]and in 1800?") [CYR:[TRANSLATED]] permute-based encoding |
| **C: Full Dijkstra + beam** | Наwith[TRANSLATED]]andй priority queue with beam search for [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] inзin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] |

---

## Заfor[TRANSLATED]]andе

Level 11.14 fromfor[TRANSLATED]] **VSA-onтandin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andзм inеwithоin**: ёмtoоwithть [CYR:[TRANSLATED]]and = inеwith withinязand. [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] → withandльnotе withandгonл → in[CYR:[TRANSLATED]] прandорand[CYR:[TRANSLATED]]. Прand noise=5 "[CYR:[TRANSLATED]]toandе" [CYR:[TRANSLATED]]and (5 [CYR:[TRANSLATED]]) with[TRANSLATED]] 93% [CYR:[TRANSLATED]]withтand, [CYR:[TRANSLATED]] toаto "[CYR:[TRANSLATED]]" (25 [CYR:[TRANSLATED]]) [CYR:[TRANSLATED]] до 21%. Dijkstra traversal with weighted scoring доwithтand[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]inых [CYR:[TRANSLATED]]in. Reinforcement-based [CYR:[TRANSLATED]] fromin[CYR:[TRANSLATED]] — capacity-based weight едandнwithтin[CYR:[TRANSLATED]] for[TRANSLATED]]for[TRANSLATED]] VSA-onтandin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andзм.

**Trinity Weighted. Capacity Is Priority. Quarks: Prioritized.**
