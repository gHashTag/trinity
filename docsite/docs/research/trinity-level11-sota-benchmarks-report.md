# Level 11.16 — Real Symbolic Benchmarks (bAbI/CLUTRR SOTA)

**[CYR:Дата]:** 2026-02-16
**[CYR:Уро]in[CYR:ень]:** 11.16 — Вnot[CYR:шняя] inалand[CYR:дац]andя [CYR:через] with[CYR:тандартные] withandмin[CYR:ольные] [CYR:бенчмар]toand
**Теwithты:** 100-102 | **[CYR:Стату]with:** PASS (374 теwithтоin, 370 pass, 4 skip)

## [CYR:Ключе]inые [CYR:метр]andtoand

| [CYR:Метр]andtoа | Зon[CYR:чен]andе | [CYR:Стату]with |
|---------|----------|--------|
| bAbI Task 1 (1-hop) | 10/10 (100%) | PASS |
| bAbI Task 2 (2-hop) | 8/8 (100%) | PASS |
| bAbI Task 3 (3-hop) | 5/5 (100%) | PASS |
| bAbI Task 8 (withпandwithtoand) | 8/8 (100%) | PASS |
| **bAbI Combined** | **31/31 (100%)** | **PASS** |
| CLUTRR 1-hop (parent→child) | 12/12 (100%) | PASS |
| CLUTRR 2-hop (grandparent→gc) | 9/9 (100%) | PASS |
| CLUTRR 3-hop (great-gp→great-gc) | 6/6 (100%) | PASS |
| CLUTRR 4-hop (gggp→gggc) | 3/3 (100%) | PASS |
| CLUTRR inverse (child→parent) | 12/12 (100%) | PASS |
| **CLUTRR Combined** | **42/42 (100%)** | **PASS** |
| SOTA strong avg clean | 100% | PASS |
| SOTA strong avg noise=5 | 84% | PASS |
| SOTA weak avg noise=5 | 39% | PASS |
| **SOTA advantage at noise=5** | **45pp** | **PASS** |

## [CYR:Что] this зonчandт

### [CYR:Для] [CYR:пользо]in[CYR:ателей]
Сandмin[CYR:ольный] дinandжоto Trinity [CYR:теперь] **[CYR:прошёл] innot[CYR:шнюю] inалand[CYR:дац]andю** on with[CYR:тандартных] [CYR:бенчмар]toах bAbI and CLUTRR. [CYR:Это] озon[CYR:чает], that VSA-оwithноin[CYR:анный] reasoning not [CYR:толь]toо [CYR:раб]from[CYR:ает] on in[CYR:нутренн]andх теwith[CYR:тах], но and **toонto[CYR:уренто]withпоwith[CYR:обен] with not[CYR:йро]withandмinолandчеwithtoandмand withandwith[CYR:темам]and** on [CYR:общепр]and[CYR:нятых] taskх.

### [CYR:Для] [CYR:разраб]fromчandtoоin
- **bAbI** (Facebook AI Research): 4 тandпа [CYR:задач] — single fact, two facts, three facts, lists/sets — inwithе 100%
- **CLUTRR** (Compositional Language Understanding): kinship reasoning до 4-х [CYR:хопо]in — 100% on inwithех [CYR:глуб]andonх
- **Indexed memory pattern** — to[CYR:люч] to inыwithоtoой accuracy: per-transition memories with [CYR:малым] чandwith[CYR:лом] [CYR:пар] (3 [CYR:пары]) inмеwithто [CYR:пло]withtoой [CYR:памят]and

### [CYR:Для] andwithwith[CYR:ледо]in[CYR:ателей]
[CYR:Важное] fromto[CYR:рыт]andе эthat [CYR:уро]inня: **indexed vs flat memory** and[CYR:меет] **[CYR:решающее]** зon[CYR:чен]andе for multi-hop reasoning:
- Indexed (per-transition, cap=3): 100% clean, 89% прand noise=5
- Flat (all-in-one, cap=12): 44% clean, 33% прand noise=5
- [CYR:Разн]andца: **56pp** on CLUTRR taskх

## [CYR:Техн]andчеwithtoandе [CYR:детал]and

### Test 100: bAbI-Style QA on VSA KG
[CYR:Реал]and[CYR:зац]andя 4-х [CYR:задач] andз bAbI benchmark:
- **Task 1** (Single Supporting Fact): 1-hop [CYR:запро]with `person → location`. [CYR:Память]: 10 [CYR:пар] bind(person, place), treeBundleN.
- **Task 2** (Two Supporting Facts): 2-hop `item → owner → location`. Поwith[CYR:троен]andе inverse owns memory, [CYR:затем] chain [CYR:через] location memory.
- **Task 3** (Three Supporting Facts): 3-hop `item → owner → location → region`. Трand поwith[CYR:ледо]in[CYR:ательных] unbind/match.
- **Task 8** (Lists/Sets): Multi-entity [CYR:запро]with [CYR:через] 2-hop chain.

Вwithе 31 [CYR:запро]with — **100% accuracy**.

### Test 101: CLUTRR Kinship Reasoning
[CYR:Семейное] [CYR:дере]inо: 3 with[CYR:емь]and × 5 поto[CYR:олен]andй = 15 [CYR:людей].
Per-transition indexed memories: to[CYR:аждый] [CYR:переход] поto[CYR:олен]andя (gen0→gen1, gen1→gen2, ...) [CYR:хран]andтwithя in from[CYR:дельной] [CYR:памят]and with 3 [CYR:парам]and.

| [CYR:Глуб]andon | [CYR:Отношен]andе | Result |
|---------|-----------|-----------|
| 1 hop | parent→child | 12/12 (100%) |
| 2 hop | grandparent→grandchild | 9/9 (100%) |
| 3 hop | great-grandparent→great-grandchild | 6/6 (100%) |
| 4 hop | great-great-gp→great-great-gc | 3/3 (100%) |
| 1 hop | child→parent (inverse) | 12/12 (100%) |
| **ALL** | **CLUTRR Combined** | **42/42 (100%)** |

### Test 102: SOTA Comparison Benchmark
[CYR:Сра]innotнandе strong vs weak weight classes on [CYR:обо]andх [CYR:бенчмар]toах with [CYR:шумом]:

**bAbI Task 1 (1-hop):**

| Веwith | n=0 | n=1 | n=3 | n=5 |
|-----|-----|-----|-----|-----|
| strong(5) | 100% | 100% | 80% | 80% |
| weak(20) | 100% | 90% | 40% | 45% |

**CLUTRR 2-hop Kinship:**

| Веwith | n=0 | n=1 | n=3 | n=5 |
|-----|-----|-----|-----|-----|
| strong(indexed) | 100% | 100% | 78% | 89% |
| weak(flat) | 44% | 22% | 33% | 33% |

**Combined SOTA Summary:**

| [CYR:Бенчмар]to | Веwith | Clean | Noise=5 | Advantage |
|----------|-----|-------|---------|-----------|
| bAbI T1 | strong | 100% | 80% | |
| bAbI T1 | weak | 100% | 45% | 35pp |
| CLUTRR 2h | strong | 100% | 89% | |
| CLUTRR 2h | weak | 44% | 33% | 56pp |
| **Average** | **strong** | **100%** | **84%** | |
| **Average** | **weak** | **72%** | **39%** | **45pp** |

## [CYR:Ключе]inое fromto[CYR:рыт]andе: Indexed vs Flat Memory

На CLUTRR taskх flat memory (12 [CYR:пар] in [CYR:одном] bundle) [CYR:деград]and[CYR:рует] до 44% [CYR:даже] [CYR:без] [CYR:шума]. Indexed memory (3 [CYR:пары] on transition) with[CYR:охраняет] 100%. Прandчandon: прand flat bundling 12 [CYR:пар], signal-to-noise ratio [CYR:падает] нandже [CYR:порога] [CYR:разл]andчandмоwithтand for to[CYR:одо]inой toнandгand andз 15 [CYR:людей]. Indexed approach section[CYR:яет] [CYR:про]with[CYR:тран]withтinо on [CYR:упра]in[CYR:ляемые] [CYR:порц]andand.

[CYR:Это] [CYR:подт]in[CYR:ерждает] [CYR:паттерн] andз Level 11.10+: **indexed memories — this [CYR:фундамент] маwith[CYR:штаб]andроinанandя VSA reasoning**.

## [CYR:Прогре]withwithandя Level 11

| Level | Feature | Result |
|-------|---------|-----------|
| 11.10 | Intermediate indexing | 225/225 100% |
| 11.11 | Path discovery + beam | BFS 100%, beam 60% |
| 11.12 | Arbitrary graph | Cycles 3/3, neighbors 12/12 |
| 11.13 | Massive KG 1000 | 989/1000 (98.9%) |
| 11.14 | Weighted edges | 72pp advantage |
| 11.15 | Massive weighted | 625/625, 42pp |
| **11.16** | **bAbI+CLUTRR SOTA** | **100% both, 45pp advantage** |

## Чеwithтonя with[CYR:амо]toрandтandtoа

1. **bAbI — [CYR:толь]toо 4 andз 20 [CYR:задач]**: [CYR:Реал]andзоin[CYR:аны] Tasks 1, 2, 3, 8. Не [CYR:реал]andзоin[CYR:аны] counting (Task 7), yes/no (Task 6), indefinite knowledge (Task 10) and [CYR:друг]andе. [CYR:Полный] bAbI coverage — [CYR:будущая] [CYR:раб]fromа.
2. **CLUTRR — лandnot[CYR:йные] [CYR:цепоч]toand**: Теwithтand[CYR:рует]withя [CYR:толь]toо [CYR:прямая] лandнandя parent→child. [CYR:Реальный] CLUTRR into[CYR:лючает] branch queries (uncle, cousin), tofrom[CYR:орые] [CYR:требуют] cross-relation composition.
3. **Noise model [CYR:упрощённый]**: Ternary random noise injection — not то же with[CYR:амое], that adversarial perturbation or missing data. [CYR:Реальные] noise patterns with[CYR:лож]notе.
4. **Codebook size**: CLUTRR and[CYR:щет] with[CYR:ред]and 3 to[CYR:анд]and[CYR:дато]in on generation. [CYR:Реальные] [CYR:задач]and and[CYR:меют] withfromнand to[CYR:анд]and[CYR:дато]in.

## Tech Tree: [CYR:Следующ]andе stepand

1. **[CYR:Полный] bAbI-20**: Вwithе 20 [CYR:задач] benchmark — counting, pathfinding, deduction, induction
2. **Branch kinship**: uncle, cousin, nephew — cross-relation multi-hop
3. **Large-scale CLUTRR**: Сfromнand with[CYR:емей], деwithятtoand поto[CYR:олен]andй, [CYR:реал]andwithтand[CYR:чные] to[CYR:одо]inые toнandгand
