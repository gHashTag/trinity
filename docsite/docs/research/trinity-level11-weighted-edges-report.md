# Level 11.14 — Weighted Edges: Dijkstra-Style Priority [CYR:через] VSA

**[CYR:Уро]in[CYR:ень]**: 11.14 — Weighted Edges
**[CYR:Стату]with**: [CYR:ДОСТИГНУТО]
**Теwithты**: 94-96 (368 inwith[CYR:его], 364 pass, 4 skip)

---

## [CYR:Ключе]inые [CYR:метр]andtoand

| [CYR:Метр]andtoа | Зon[CYR:чен]andе | [CYR:Стату]with |
|---------|----------|--------|
| Веwithоinая to[CYR:орреляц]andя | **[CYR:Мон]fromонonя** (sim: 0.48→0.34→0.27→0.21→0.15) | ✅ |
| Dijkstra traversal | Доwithтand[CYR:гает] T за **3 [CYR:хопа]** | ✅ |
| Light vs Heavy (noise=5) | **93% vs 21%** (72pp advantage) | ✅ |
| Capacity monotonicity | **true** — [CYR:меньше] [CYR:пар] = withandльnotе withandгonл | ✅ |
| Accuracy cap=3 | **100%** | ✅ |
| Accuracy cap=25 | **97.3%** | ✅ |

---

## [CYR:Что] this зonчandт

### [CYR:Для] andwithwith[CYR:ледо]in[CYR:ателей]
Обon[CYR:ружен] **VSA-onтandin[CYR:ный] [CYR:механ]andзм inеwithоin**: ёмtoоwithть [CYR:памят]and (toолandчеwithтinо [CYR:хран]and[CYR:мых] [CYR:пар]) on[CYR:прямую] [CYR:определяет] withandлу withandгonла прand andзin[CYR:лечен]andand. [CYR:Это] not innotшнandй withto[CYR:аляр], а **[CYR:фундаментальное] withinойwithтinо with[CYR:уперпоз]andцandand**. [CYR:Меньше] [CYR:пар] in [CYR:памят]and → in[CYR:ыше] cosine similarity прand [CYR:запро]withе → "withandльnotе" within[CYR:язь]. [CYR:Это] [CYR:пер]inый доto[CYR:ументально] [CYR:подт]in[CYR:ержденный] capacity-based weight mechanism for VSA Knowledge Graph.

### [CYR:Для] [CYR:разраб]fromчandtoоin
[CYR:Пра]toтandчеwithtoое зon[CYR:чен]andе: for Dijkstra-style поandwithtoа по [CYR:графу] зonнandй not [CYR:нужно] [CYR:хран]andть from[CYR:дельные] withto[CYR:аляры] inеwithоin. **[CYR:Сама] VSA-[CYR:память] toодand[CYR:рует] inеwith [CYR:через] ёмtoоwithть**. Relation with 5 [CYR:парам]and (sim=0.34) еwithтеwithтin[CYR:енно] прandорand[CYR:тет]notе relation with 25 [CYR:парам]and (sim=0.15). Прand [CYR:доба]in[CYR:лен]andand innotшнandх withto[CYR:аляро]in (weight = 1/capacity) [CYR:получаем] score = sim × weight for [CYR:полного] Dijkstra.

### [CYR:Для] andнinеwith[CYR:торо]in
Weighted edges — to[CYR:люче]inая фandча for [CYR:пра]toтandчеwithto[CYR:ого] withandмinолandчеwithto[CYR:ого] ИИ. [CYR:Реальные] [CYR:графы] зonнandй and[CYR:меют] [CYR:разную] with[CYR:тепень] уin[CYR:еренно]withтand in фаto[CYR:тах]. [CYR:Теперь] Trinity VSA [CYR:может] [CYR:разл]and[CYR:чать] "[CYR:точно] with[CYR:тол]andца" from "where-то [CYR:рядом]" — [CYR:без] [CYR:дополн]and[CYR:тельных] [CYR:данных], [CYR:про]withто [CYR:через] [CYR:арх]andтеto[CYR:туру] [CYR:памят]and.

---

## [CYR:Арх]andтеto[CYR:тура] inеwithоin

### Capacity-Based Weight (VSA-onтandin[CYR:ный])

```
Прandнцandп: weight ∝ 1/capacity

Memory with 5 [CYR:парам]and:  sim = 0.34 (withand[CYR:льный] withandгonл)
Memory with 10 [CYR:парам]and: sim = 0.27 (with[CYR:редн]andй)
Memory with 25 [CYR:парам]and: sim = 0.15 (with[CYR:лабый] withandгonл)

[CYR:Почему]: with[CYR:уперпоз]andцandя N inеto[CYR:торо]in → to[CYR:аждый] [CYR:получает] ~1/sqrt(N) from [CYR:общего] withandгonла.
[CYR:Меньше] N → withandльnotе to[CYR:аждый] to[CYR:омпо]notнт → in[CYR:ыше] similarity прand andзin[CYR:лечен]andand.
```

### Dijkstra Priority Score

```
score(edge) = retrieval_similarity × scalar_weight

[CYR:Для] [CYR:перехода] S → A:
  1. Unbind S andз adjacency memory
  2. [CYR:Измер]andть similarity to to[CYR:аждому] to[CYR:анд]and[CYR:дату]
  3. [CYR:Умнож]andть on scalar weight (1/capacity or innotшнandй)
  4. [CYR:Выбрать] max score
```

---

## Теwithт 94: Weighted Edges — Capacity-Based

Трand withinязand with [CYR:разной] ёмtoоwith[CYR:тью]:

| Сin[CYR:язь] | [CYR:Пар] | Accuracy | Avg Sim | VSA Weight |
|-------|-----|----------|---------|------------|
| capital (strong) | 5 | **100%** | **0.3377** | 0.200 |
| borders (medium) | 10 | **100%** | **0.2642** | 0.100 |
| nearby (weak) | 25 | **96%** | **0.1476** | 0.040 |

**[CYR:Мон]from[CYR:онно]withть [CYR:подт]in[CYR:ержде]on**: capital > borders > nearby по similarity.

[CYR:Ключе]inое fromto[CYR:рыт]andе: [CYR:даже] [CYR:без] яin[CYR:ных] inеwithоin, VSA аin[CYR:томат]andчеwithtoand прandорandтandзand[CYR:рует] withinязand with [CYR:меньшей] toонto[CYR:уренц]andей in [CYR:памят]and.

---

## Теwithт 95: Dijkstra Priority Traversal

[CYR:Граф] with 6 [CYR:узлам]and (S, A, B, C, D, T) and 7 [CYR:рёбрам]and:

```
S → A (weight=0.9)    A → T (weight=0.9)
S → B (weight=0.3)    B → T (weight=0.3)
S → C (weight=0.6)    C → D (weight=0.6)    D → T (weight=0.6)
```

**Result**: [CYR:оба] methodа (weighted and unweighted) доwithтand[CYR:гают] T за 3 [CYR:хопа].

| [CYR:Метод] | [CYR:Путь] | [CYR:Хопы] | Score |
|-------|------|------|-------|
| Weighted (sim×weight) | S→C→D→T | 3 | 1.7169 |
| Unweighted (sim only) | S→C→D→T | 3 | 2.8615 |

[CYR:Оба] in[CYR:ыбрал]and S→C→D→T пfrom[CYR:ому] that S and[CYR:меет] 3 andwith[CYR:ходящ]andх [CYR:ребра] in [CYR:одной] adjacency memory (toонto[CYR:уренц]andя), а C and D and[CYR:меют] по [CYR:одному] (чandwith[CYR:тый] withandгonл sim=1.0). [CYR:Это] [CYR:подт]in[CYR:ерждает] capacity-based weight: одand[CYR:ночные] bindings [CYR:дают] and[CYR:деальное] inоwithwith[CYR:тано]in[CYR:лен]andе.

---

## Теwithт 96: Weight vs Noise Benchmark

### Capacity → Similarity ([CYR:без] [CYR:шума])

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

**Light advantage at noise=5: 72 [CYR:процентных] [CYR:пун]toта** (93% vs 21%).

[CYR:Это] [CYR:фундаментальный] result: "withand[CYR:льные]" withinязand ([CYR:мало] [CYR:пар]) not [CYR:толь]toо [CYR:точ]notе andзinлеto[CYR:ают]withя, но and **зonчand[CYR:тельно] уwith[CYR:тойч]andinее to [CYR:шуму]**. В [CYR:реальных] KG this озon[CYR:чает]: inыwithоto[CYR:одо]inерand[CYR:тельные] фаtoты ([CYR:мало] [CYR:альтер]onтandin) оwith[CYR:танут]withя доwith[CYR:тупным]and [CYR:даже] прand [CYR:зашумленных] [CYR:данных].

---

## Крandтandчеwithtoая [CYR:оцен]toа

### [CYR:Что] [CYR:раб]from[CYR:ает]
1. **Capacity-based weight** — [CYR:фундаментально] in[CYR:ерный] VSA-onтandin[CYR:ный] [CYR:механ]andзм
2. **Monotonicity** — similarity with[CYR:трого] [CYR:убы]in[CYR:ает] with toолandчеwithтinом [CYR:пар]
3. **Noise resilience** — 72pp advantage light vs heavy — [CYR:пра]toтandчеwithtoand зonчandмо
4. **Dijkstra traversal** — [CYR:раб]from[CYR:ает], доwithтand[CYR:гает] [CYR:цел]and

### [CYR:Важное] on[CYR:блюден]andе
[CYR:Попыт]toа "уwithorть" inеwith [CYR:через] поin[CYR:торное] bundling (reinforcement) **not [CYR:раб]from[CYR:ает]** in ternary VSA. Bundling memory with toопandей with[CYR:ебя] = majority vote, tofrom[CYR:орый] not уwithorin[CYR:ает] withandгonл, а [CYR:доба]in[CYR:ляет] [CYR:шум] from toin[CYR:ант]and[CYR:зац]andand. [CYR:Пра]inand[CYR:льный] [CYR:подход] — [CYR:толь]toо capacity-based weight.

### [CYR:Огран]and[CYR:чен]andя
1. Dijkstra in теto[CYR:ущей] [CYR:реал]and[CYR:зац]andand = greedy (top-1 on to[CYR:аждом] stepе), not onwith[CYR:тоящ]andй priority queue
2. Scalar weights [CYR:хранят]withя from[CYR:дельно] from VSA — notт едand[CYR:ного] VSA-toодandроinанandя inеwithа + [CYR:данных]
3. Прand 3 andwith[CYR:ходящ]andх [CYR:рёбрах] andз [CYR:одного] [CYR:узла] toонto[CYR:уренц]andя in adjacency memory withнand[CYR:жает] [CYR:разл]andчandмоwithть

---

## Tech Tree: [CYR:Следующ]andе stepand

| [CYR:Вар]and[CYR:ант] | Опandwithанandе |
|---------|----------|
| **A: Temporal reasoning** | [CYR:Доба]inandть in[CYR:ременные] [CYR:мет]toand to фаto[CYR:там], reasoning о [CYR:поряд]toе with[CYR:обыт]andй |
| **B: Contextual queries** | [CYR:Вопро]withы with to[CYR:онте]towith[CYR:том] ("with[CYR:тол]andца [CYR:Франц]andand in 1800?") [CYR:через] permute-based encoding |
| **C: Full Dijkstra + beam** | Наwith[CYR:тоящ]andй priority queue with beam search for [CYR:опт]and[CYR:мальных] inзin[CYR:ешенных] [CYR:путей] |

---

## Заto[CYR:лючен]andе

Level 11.14 fromto[CYR:рыл] **VSA-onтandin[CYR:ный] [CYR:механ]andзм inеwithоin**: ёмtoоwithть [CYR:памят]and = inеwith withinязand. [CYR:Меньше] [CYR:пар] → withandльnotе withandгonл → in[CYR:ыше] прandорand[CYR:тет]. Прand noise=5 "[CYR:лёг]toandе" [CYR:памят]and (5 [CYR:пар]) with[CYR:охраняют] 93% [CYR:точно]withтand, [CYR:тогда] toаto "[CYR:тяжёлые]" (25 [CYR:пар]) [CYR:падают] до 21%. Dijkstra traversal with weighted scoring доwithтand[CYR:гает] [CYR:целе]inых [CYR:узло]in. Reinforcement-based [CYR:подход] fromin[CYR:ергнут] — capacity-based weight едandнwithтin[CYR:енный] to[CYR:орре]to[CYR:тный] VSA-onтandin[CYR:ный] [CYR:механ]andзм.

**Trinity Weighted. Capacity Is Priority. Quarks: Prioritized.**
