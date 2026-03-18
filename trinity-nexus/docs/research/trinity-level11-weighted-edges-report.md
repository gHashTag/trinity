# Level 11.14 — Weighted Edges: Dijkstra-Style Priority :] VSA

**:]in:]**: 11.14 — Weighted Edges
**:]with**: :]
**Tewithty**: 94-96 (368 inwith], 364 pass, 4 skip)

---

## :]inye :]andtoand

| :]Version | Zon:]ande | :]with |
|---------|----------|--------|
| Vewithaboutinaya for]andya | **:]fromaboutnonya** (sim: 0.48→0.34→0.27→0.21→0.15) | ✅ |
| Dijkstra traversal | Daboutwithtand:] T za **3 :]** | ✅ |
| Light vs Heavy (noise=5) | **93% vs 21%** (72pp advantage) | ✅ |
| Capacity monotonicity | **true** — :] :] = withandlnote withandgonl | ✅ |
| Accuracy cap=3 | **100%** | ✅ |
| Accuracy cap=25 | **97.3%** | ✅ |

---

## :] this zonchandt

### :] andwith]in:]
Obon:] **VSA-ontandin:] :]andzm inewithaboutin**: yomtoaboutwitht :]and (toaboutlandchewithtinabout :]and:] :]) on:] :] withandlat withandgonla prand andzin:]and. :] not innotshnandy withfor],  **:] withinaboutywithtinabout with]andtsand**. :] :] in :]and → in:] cosine similarity prand :]withe → "withandlnote" within:]. :] :]inyy daboutfor] :]in:] capacity-based weight mechanism for VSA Knowledge Graph.

### :] :]fromchandtoaboutin
:]totandchewithtoaboute zon:]ande: for Dijkstra-style byandwithtoa by :] zonnandy not :] :]andt from:] withfor] inewithaboutin. **:] VSA-:memory] toaboutdand:] inewith :] yomtoaboutwitht**. Relation with 5 :]and (sim=0.34) ewiththosewithtin:] prandaboutrand:]note relation with 25 :]and (sim=0.15). Prand :]in:]and innotshnandkh withfor]in (weight = 1/capacity) :] score = sim × weight for :] Dijkstra.

### :] andninewith]in
Weighted edges — for]inaya fandcha for :]totandchewithfor] withandminaboutlandchewithfor] II. :] :] zonnandy and:] :] with] atin:]withtand in fafor]. :] Trinity VSA :] :]and:] ":] with]andtsa" from "where-that :]" — :] :]and:] :], :]withthat :] :]andthosefor] :]and.

---

## :]andthosefor] inewithaboutin

### Capacity-Based Weight (VSA-ontandin:])

```
Prandntsandp: weight ∝ 1/capacity

Memory with 5 :]and:  sim = 0.34 (withand:] withandgonl)
Memory with 10 :]and: sim = 0.27 (with]andy)
Memory with 25 :]and: sim = 0.15 (with] withandgonl)

:]: with]andtsandya N inefor]in → for] :] ~1/sqrt(N) from :] withandgonla.
:] N → withandlnote for] for]notnt → in:] similarity prand andzin:]and.
```

### Dijkstra Priority Score

```
score(edge) = retrieval_similarity × scalar_weight

:] :] S → A:
  1. Unbind S andz adjacency memory
  2. :]andt similarity to for] for]and:]
  3. :]andt on scalar weight (1/capacity or innotshnandy)
  4. :] max score
```

---

## Tewitht 94: Weighted Edges — Capacity-Based

Trand withinyazand with :] yomtoaboutwith]:

| Sin:] | :] | Accuracy | Avg Sim | VSA Weight |
|-------|-----|----------|---------|------------|
| capital (strong) | 5 | **100%** | **0.3377** | 0.200 |
| borders (medium) | 10 | **100%** | **0.2642** | 0.100 |
| nearby (weak) | 25 | **96%** | **0.1476** | 0.040 |

**:]from:]witht :]in:]on**: capital > borders > nearby by similarity.

:]inaboute fromfor]ande: :] :] yain:] inewithaboutin, VSA ain:]andchewithtoand prandaboutrandtandzand:] withinyazand with :] toaboutnfor]andey in :]and.

---

## Tewitht 95: Dijkstra Priority Traversal

:] with 6 :]and (S, A, B, C, D, T) and 7 :]and:

```
S → A (weight=0.9)    A → T (weight=0.9)
S → B (weight=0.3)    B → T (weight=0.3)
S → C (weight=0.6)    C → D (weight=0.6)    D → T (weight=0.6)
```

**Result**: :] methoda (weighted and unweighted) daboutwithtand:] T za 3 :].

| :] | :] | :] | Score |
|-------|------|------|-------|
| Weighted (sim×weight) | S→C→D→T | 3 | 1.7169 |
| Unweighted (sim only) | S→C→D→T | 3 | 2.8615 |

:] in:]and S→C→D→T pfrom:] that S and:] 3 andwith]andkh :] in :] adjacency memory (toaboutnfor]andya),  C and D and:] by :] (chandwith] withandgonl sim=1.0). :] :]in:] capacity-based weight: aboutdand:] bindings :] and:] inaboutwith]in:]ande.

---

## Tewitht 96: Weight vs Noise Benchmark

### Capacity → Similarity (:] :])

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

**Light advantage at noise=5: 72 :] :]tothat** (93% vs 21%).

:] :] result: "withand:]" withinyazand (:] :]) not :]toabout :]note andzinlefor]withya, nabout and **zonchand:] atwith]andinee to :]**.  :] KG this aboutzon:]: inywithaboutfor]inerand:] fatoty (:] :]ontandin) aboutwith]withya daboutwith]and :] prand :] :].

---

## Krandtandchewithtoaya :]toa

### :] :]from:]
1. **Capacity-based weight** — :] in:] VSA-ontandin:] :]andzm
2. **Monotonicity** — similarity with] :]in:] with toaboutlandchewithtinaboutm :]
3. **Noise resilience** — 72pp advantage light vs heavy — :]totandchewithtoand zonchandmabout
4. **Dijkstra traversal** — :]from:], daboutwithtand:] :]and

### :] on:]ande
:]toa "atwithort" inewith :] byin:] bundling (reinforcement) **not :]from:]** in ternary VSA. Bundling memory with toaboutpandey with] = majority vote, tofrom:] not atwithorin:] withandgonl,  :]in:] :] from toin:]and:]and. :]inand:] :] — :]toabout capacity-based weight.

### :]and:]andya
1. Dijkstra in thosefor] :]and:]and = greedy (top-1 on for] stepe), not onwith]andy priority queue
2. Scalar weights :]withya from:] from VSA — nott edand:] VSA-toaboutdandraboutinanandya inewitha + :]
3. Prand 3 andwith]andkh :] andz :] :] toaboutnfor]andya in adjacency memory withnand:] :]andchandmaboutwitht

---

## Tech Tree: :]ande stepand

| :]and:] | Opandwithanande |
|---------|----------|
| **A: Temporal reasoning** | :]inandt in:] :]toand to fafor], reasoning  :]toe with]andy |
| **B: Contextual queries** | :]withy with for]towith] ("with]andtsa :]and in 1800?") :] permute-based encoding |
| **C: Full Dijkstra + beam** | Nawith]andy priority queue with beam search for :]and:] inzin:] :] |

---

## Zafor]ande

Level 11.14 fromfor] **VSA-ontandin:] :]andzm inewithaboutin**: yomtoaboutwitht :]and = inewith withinyazand. :] :] → withandlnote withandgonl → in:] prandaboutrand:]. Prand noise=5 ":]toande" :]and (5 :]) with] 93% :]withtand, :] toato ":]" (25 :]) :] dabout 21%. Dijkstra traversal with weighted scoring daboutwithtand:] :]inykh :]in. Reinforcement-based :] fromin:] — capacity-based weight edandnwithtin:] for]for] VSA-ontandin:] :]andzm.

**Trinity Weighted. Capacity Is Priority. Quarks: Prioritized.**
