# Level 11.16 — Real Symbolic Benchmarks (bAbI/CLUTRR SOTA)

**[CYR:[TRANSLATED]]:** 2026-02-16
**[CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]:** 11.16 — Вnot[CYR:[TRANSLATED]] inалand[CYR:[TRANSLATED]]andя [CYR:[TRANSLATED]] with[TRANSLATED]] withandмin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]toand
**Теwithты:** 100-102 | **[CYR:[TRANSLATED]]with:** PASS (374 теwithтоin, 370 pass, 4 skip)

## [CYR:[TRANSLATED]]inые [CYR:[TRANSLATED]]andtoand

| [CYR:[TRANSLATED]]andtoа | Зon[CYR:[TRANSLATED]]andе | [CYR:[TRANSLATED]]with |
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

## [CYR:[TRANSLATED]] this зonчandт

### [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]
Сandмin[CYR:[TRANSLATED]] дinandжоto Trinity [CYR:[TRANSLATED]] **[CYR:[TRANSLATED]] innot[CYR:[TRANSLATED]] inалand[CYR:[TRANSLATED]]andю** on with[TRANSLATED]] [CYR:[TRANSLATED]]toах bAbI and CLUTRR. [CYR:[TRANSLATED]] озon[CYR:[TRANSLATED]], that VSA-оwithноin[CYR:[TRANSLATED]] reasoning not [CYR:[TRANSLATED]]toо [CYR:[TRANSLATED]]from[CYR:[TRANSLATED]] on in[CYR:[TRANSLATED]]andх теwith[TRANSLATED]], но and **toонfor[TRANSLATED]]withпоwith[TRANSLATED]] with not[CYR:[TRANSLATED]]withandмinолandчеwithtoandмand withandwith[TRANSLATED]]and** on [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] taskх.

### [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]fromчandtoоin
- **bAbI** (Facebook AI Research): 4 тandпа [CYR:[TRANSLATED]] — single fact, two facts, three facts, lists/sets — inwithе 100%
- **CLUTRR** (Compositional Language Understanding): kinship reasoning до 4- [CYR:[TRANSLATED]]in — 100% on inwithех [CYR:[TRANSLATED]]andonх
- **Indexed memory pattern** — for[TRANSLATED]] to inыwithоtoой accuracy: per-transition memories with [CYR:[TRANSLATED]] чandwith[TRANSLATED]] [CYR:[TRANSLATED]] (3 [CYR:[TRANSLATED]]) inмеwithто [CYR:[TRANSLATED]]withtoой [CYR:[TRANSLATED]]and

### [CYR:[TRANSLATED]] andwith[TRANSLATED]]in[CYR:[TRANSLATED]]
[CYR:[TRANSLATED]] fromfor[TRANSLATED]]andе эthat [CYR:[TRANSLATED]]inня: **indexed vs flat memory** and[CYR:[TRANSLATED]] **[CYR:[TRANSLATED]]** зon[CYR:[TRANSLATED]]andе for multi-hop reasoning:
- Indexed (per-transition, cap=3): 100% clean, 89% прand noise=5
- Flat (all-in-one, cap=12): 44% clean, 33% прand noise=5
- [CYR:[TRANSLATED]]andца: **56pp** on CLUTRR taskх

## [CYR:[TRANSLATED]]andчеwithtoandе [CYR:[TRANSLATED]]and

### Test 100: bAbI-Style QA on VSA KG
[CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя 4- [CYR:[TRANSLATED]] andз bAbI benchmark:
- **Task 1** (Single Supporting Fact): 1-hop [CYR:[TRANSLATED]]with `person → location`. [CYR:[TRANSLATED]]: 10 [CYR:[TRANSLATED]] bind(person, place), treeBundleN.
- **Task 2** (Two Supporting Facts): 2-hop `item → owner → location`. Поwith[TRANSLATED]]andе inverse owns memory, [CYR:[TRANSLATED]] chain [CYR:[TRANSLATED]] location memory.
- **Task 3** (Three Supporting Facts): 3-hop `item → owner → location → region`. Трand поwith[TRANSLATED]]in[CYR:[TRANSLATED]] unbind/match.
- **Task 8** (Lists/Sets): Multi-entity [CYR:[TRANSLATED]]with [CYR:[TRANSLATED]] 2-hop chain.

Вwithе 31 [CYR:[TRANSLATED]]with — **100% accuracy**.

### Test 101: CLUTRR Kinship Reasoning
[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]inо: 3 with[TRANSLATED]]and × 5 поfor[TRANSLATED]]andй = 15 [CYR:[TRANSLATED]].
Per-transition indexed memories: for[TRANSLATED]] [CYR:[TRANSLATED]] поfor[TRANSLATED]]andя (gen0→gen1, gen1→gen2, ...) [CYR:[TRANSLATED]]andтwithя in from[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]and with 3 [CYR:[TRANSLATED]]and.

| [CYR:[TRANSLATED]]andon | [CYR:[TRANSLATED]]andе | Result |
|---------|-----------|-----------|
| 1 hop | parent→child | 12/12 (100%) |
| 2 hop | grandparent→grandchild | 9/9 (100%) |
| 3 hop | great-grandparent→great-grandchild | 6/6 (100%) |
| 4 hop | great-great-gp→great-great-gc | 3/3 (100%) |
| 1 hop | child→parent (inverse) | 12/12 (100%) |
| **ALL** | **CLUTRR Combined** | **42/42 (100%)** |

### Test 102: SOTA Comparison Benchmark
[CYR:[TRANSLATED]]innotнandе strong vs weak weight classes on [CYR:[TRANSLATED]]andх [CYR:[TRANSLATED]]toах with [CYR:[TRANSLATED]]:

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

| [CYR:[TRANSLATED]]to | Веwith | Clean | Noise=5 | Advantage |
|----------|-----|-------|---------|-----------|
| bAbI T1 | strong | 100% | 80% | |
| bAbI T1 | weak | 100% | 45% | 35pp |
| CLUTRR 2h | strong | 100% | 89% | |
| CLUTRR 2h | weak | 44% | 33% | 56pp |
| **Average** | **strong** | **100%** | **84%** | |
| **Average** | **weak** | **72%** | **39%** | **45pp** |

## [CYR:[TRANSLATED]]inое fromfor[TRANSLATED]]andе: Indexed vs Flat Memory

На CLUTRR taskх flat memory (12 [CYR:[TRANSLATED]] in [CYR:[TRANSLATED]] bundle) [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] до 44% [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]. Indexed memory (3 [CYR:[TRANSLATED]] on transition) with[TRANSLATED]] 100%. Прandчandon: прand flat bundling 12 [CYR:[TRANSLATED]], signal-to-noise ratio [CYR:[TRANSLATED]] нandже [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andчandмоwithтand for for[TRANSLATED]]inой toнandгand andз 15 [CYR:[TRANSLATED]]. Indexed approach section[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]with[TRANSLATED]]withтinо on [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]and.

[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] andз Level 11.10+: **indexed memories — this [CYR:[TRANSLATED]] маwith[TRANSLATED]]andроinанandя VSA reasoning**.

## [CYR:[TRANSLATED]]withandя Level 11

| Level | Feature | Result |
|-------|---------|-----------|
| 11.10 | Intermediate indexing | 225/225 100% |
| 11.11 | Path discovery + beam | BFS 100%, beam 60% |
| 11.12 | Arbitrary graph | Cycles 3/3, neighbors 12/12 |
| 11.13 | Massive KG 1000 | 989/1000 (98.9%) |
| 11.14 | Weighted edges | 72pp advantage |
| 11.15 | Massive weighted | 625/625, 42pp |
| **11.16** | **bAbI+CLUTRR SOTA** | **100% both, 45pp advantage** |

## Чеwithтonя with[TRANSLATED]]toрandтandtoа

1. **bAbI — [CYR:[TRANSLATED]]toо 4 andз 20 [CYR:[TRANSLATED]]**: [CYR:[TRANSLATED]]andзоin[CYR:[TRANSLATED]] Tasks 1, 2, 3, 8. Не [CYR:[TRANSLATED]]andзоin[CYR:[TRANSLATED]] counting (Task 7), yes/no (Task 6), indefinite knowledge (Task 10) and [CYR:[TRANSLATED]]andе. [CYR:[TRANSLATED]] bAbI coverage — [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]fromа.
2. **CLUTRR — лandnot[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]toand**: Теwithтand[CYR:[TRANSLATED]]withя [CYR:[TRANSLATED]]toо [CYR:[TRANSLATED]] лandнandя parent→child. [CYR:[TRANSLATED]] CLUTRR infor[TRANSLATED]] branch queries (uncle, cousin), tofrom[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] cross-relation composition.
3. **Noise model [CYR:[TRANSLATED]]**: Ternary random noise injection — not то же with[TRANSLATED]], that adversarial perturbation or missing data. [CYR:[TRANSLATED]] noise patterns with[TRANSLATED]]notе.
4. **Codebook size**: CLUTRR and[CYR:[TRANSLATED]] with[TRANSLATED]]and 3 for[TRANSLATED]]and[CYR:[TRANSLATED]]in on generation. [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]and and[CYR:[TRANSLATED]] withfromнand for[TRANSLATED]]and[CYR:[TRANSLATED]]in.

## Tech Tree: [CYR:[TRANSLATED]]andе stepand

1. **[CYR:[TRANSLATED]] bAbI-20**: Вwithе 20 [CYR:[TRANSLATED]] benchmark — counting, pathfinding, deduction, induction
2. **Branch kinship**: uncle, cousin, nephew — cross-relation multi-hop
3. **Large-scale CLUTRR**: Сfromнand with[TRANSLATED]], деwithятtoand поfor[TRANSLATED]]andй, [CYR:[TRANSLATED]]andwithтand[CYR:[TRANSLATED]] for[TRANSLATED]]inые toнandгand
