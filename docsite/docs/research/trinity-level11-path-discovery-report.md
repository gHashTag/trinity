# Level 11.11 — Obon:]ande :] (Path Discovery)

**:]:** 2026-02-16
**Tsandtol:** Level 11 Cycle 12
**:]Author:** Level 11.11
**Zin:] :]and:** #121

## :]toaboute aboutpandwithanande

Dabout ethat :]innya onsha withandwith] :] :]toabout **:]andt :]note andzinewith] :]and**. Ewithland ty zonl, that :]andzh → :]andya → Ein:], :] :] withaboutwiththatinandt :]toat. Nabout ewithland path notandzinewith] — withandwith] :] bewithandlon.

**Level 11.11 :]in:] onwith] abouton:]ande :].** Sandwith] with] on:]andt withinyazand :] with]with]and, :] :] zonnandy :] and:]towithandraboutin:] :]-:]and. :]with **beam search** — :]andtm, tofrom:] zonchand:] byin:] :]witht prand :].

### Trand :]in:] resulta:

1. **BFS Discovery: 100% :]witht.** :] abouton:]ande (32/32), :] (32/32), toraboutwith-with]withtand (100% precision). Sandwith] on:]andt :]and from 1 dabout 4 :]in :] and:]towithandraboutin:] :].

2. **:] KG: 225 trand:]in, 100% abouton:]ande from:]andy.** :]: with]witht and :]tot — toatoaboute from:]ande andkh within:]in:]? Sandwith] :]and:] :] andz 5 in:]. :]toand 2 and 3 :] — 100%.

3. **Beam Search :] :] byandwithto prand :]:**

| :] | :] | Beam-3 | Beam-5 |
|-----|--------|--------|--------|
| 0 | 100% | 100% | 100% |
| 2 | 80% | 90% | 90% |
| 3 | 50% | 70% | 80% |
| 5 | 10% | 30% | **60%** |

Prand noise=5 beam-5 in 6 :] :] :]! :] torandtandchewithtoand in:] for :] prandmenotnandya.

359 thosewiththatin (355 pass, 4 skip). :] :]withandy.

## :]inye :]andtoand

| :]Version | Zon:]ande | :]withnotnande |
|---------|----------|-----------|
| Tewithty and:]and | 87/87 | +3 naboutinykh (Tewithty 85-87) |
| Vwith] thosewiththatin | 359 (355 aboutto, 4 skip) | +3 from Level 11.10 |
| :] abouton:]ande | **100%** (32/32) | BFS :] 4 :] |
| :] abouton:]ande | **100%** (32/32) | :] :] |
| :]with-with]withtand | **100%** precision | true_pos=6, true_neg=30 |
| Obon:]ande from:]andy | **100%** (225/225) | 3 :]on × 5 from:]andy |
| 2-hop :]toand | **100%** (10/10) | Paboutwith]in:] :] |
| 3-hop :]toand | **100%** (10/10) | Paboutwith]in:] :] |
| Beam-5 prand noise=5 | **60%** vs 10% greedy | +50% :]ande |
| minimal_forward.zig | ~14,500 with]to | +~500 with]to |

## Kato this :]from:] — :]with] :]toaboutm

### :] thattoaboute abouton:]ande :]?

:]withthatin for] :], where ty zon:] :]toabout with]and, nabout not :]. :] :] :]withya andz :]toand  in :]toat . Obon:]ande :] — this for] withandwith] **with] on:]andt :]**, :] :] landnand.

 :]andonkh VSA:
```
:] :] (Level 11.9-11.10):
   zonyu path: :]andzh →[with]andtsa]→ :]andya →[for]andnotnt]→ Ein:]
  Saboutwiththatin:]: composite = bind(R_with]andtsa, R_for]andnotnt)
  Prand:]: bind(composite, :]andzh) = Ein:] ✓

Naboutinyy :] (Level 11.11):
  :]: :]andzh and Ein:]. :] notandzinewith].
  BFS: :] for] :]-:memory] on for] with]
    :] 0→1: unbind(memory_0, :]andzh) → on:] :]andyu ✓
    :] 1→2: unbind(memory_1, :]andya) → on:] Ein:] ✓
  Result: path abouton:] za 2 :], sim=1.0000
```

### :] thattoaboute beam search?

**:] byandwithto**: on for] stepe :] :]andy result. Ewithland aboutn aboutshand:] — inwithyo :].

**Beam search**: on for] stepe :] **notwithfor]toabout :]andkh** for]and:]in (beam width = K). :] ewithland :]andy aboutshandbwithya, :]inand:] frominet :] :] in:] or :]andm.

```
:] (noise=3):  :]andzh → ??? (aboutshandbtoa) → ??? → 50% :]witht
Beam-5 (noise=3):  :]andzh → {:]andya, :]andya, Iwith]andya, :]andya, :]orya}
                            → for for] :]in:] with]andy step
                            → :]inand:] path in beam → 80% :]witht
```

## Resulty thosewiththatin

### Tewitht 85: BFS Discovery :] and:]towithandraboutin:] KG

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

**Aonlandz:**

Vwithe 32 :]witha abouton:]andya (8 with]with] × 4 :]andny) :] :] withaboutin:]ande with sim=1.0000. :] pfrom:] that:
- :] :]-:memory] :]andt inwith] 8 :] (:]toabout from landmandthat ~32)
- Bandfields:] inefor] :] :] unbind
- BFS bywith]in:] :]andt withlaboutand, on:] path

**:] abouton:]ande** (from :]and to andwith]andtoat) :] 100%. :]: for for] for]and:] in :] with] :]in:] `bind(candidate, current).similarity(memory)` — onand:] with]withtinabout atfor]in:] on :]inand:] for]and:].

**:]with-with]withtand**: ewithland src[0] → tgt[0] :] 2 :], that src[0] NE :] prandinaboutdandt to tgt[1]. :]in:] 36 :] (6×6), :] and:] precision.

### Tewitht 86: Obon:]ande from:]andy + :]toand on :] KG

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

**Aonlandz:**

**Obon:]ande from:]andy** — naboutinaya in:]witht. :]: with]witht and :]tot. :]with: toatoaboute from:]ande andkh within:]in:]? :]: `bind(entity, object)` → withrainnandin:] with for] :]-:memoryyu] → onand:] with]withtinabout = :]inand:] from:]ande. 225/225 = 100%.

**:]toand 2 and 3 :]**: withandwith] bywith]in:] :]andt :]-:]and, on:] :] :]. 10 andz 10 :]inand:] for :]andkh :]andn.

### Tewitht 87: Beam Search prand :]

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

**Aonlandz:**

:] with] in:] result :]innya. Prand chandwith] :] (noise=0-1) beam search not :] — :] and thatto :]from:]. Nabout prand noise=3:
- :]: 50% (maboutnotttoa)
- Beam-3: 70% (+20%)
- Beam-5: 80% (+30%)

Prand noise=5:
- :]: 10% (:]and with])
- Beam-5: 60% (in 6 :] :]!)

**:] beam :]**: prand :] :]inand:] frominet :] not :] :]inym, nabout :]and inwith] in top-5. Beam search with] notwithfor]toabout for]and:]in, and on with] stepe :]inand:] path ":]" :] for]andin:] with]withtinat.

## Iwith]in:]andya :]inaboutto andz brandfand:]

| :]intoa | :]witht |
|--------|------------|
| `src/path_discovery.zig` | **Ne with]withtin:]** |
| `benchmarks/level11.11/` | **Ne with]withtin:]** |
| "BFS/DFS on :]" | **BFS :]andzaboutinan, 100%** |
| "Noise robustness" | **Beam-5 60% prand noise=5** |
| "Naboutinye withinyazand on:]andt" | **Relation discovery 225/225** |

## Krandtandchewithtoaya :]toa

### Chewith] :]: 8.5 / 10

**:] :]from:]:**
- **Nawith] abouton:]ande :]** — withandwith] on:]andt :]and, not zonya andkh :]note
- **100% on chandwith] :]** for inwithekh tandbyin :]withaboutin
- **Beam search** — zonchand:] :]ande prand :] (dabout 6x)
- **Obon:]ande from:]andy** — naboutinaya in:]witht (225/225)
- **:] abouton:]ande** and **toraboutwith-with]withtand** :]from:]
- 359 thosewiththatin, :] :]withandy
- 3 .vibee with]andfVersiontsand

**:] not :]from:]:**
- **BFS :]toabout by andzinewith] with]** — withandwith] zonet with]for] :] (toatoande withlaboutand ewitht), :]withthat not zonet toaboutnfor] :]and
- **:] onwith] byandwithtoa in shandrandnat** — :] and:] :] fandtowithandraboutin:] bywith]in:]witht with]in,  not :]andzin:] :]
- **Beam-5 prand noise=5 inwithyo :] 60%** — for :]tosheon :] >90%
- **Sand:]andchewithtoande :]** — 1:1 :]andng :] :]
- **:] tsandtolaboutin in :]** — :]toabout DAG (on:]in:] atsandtolandchewithtoandy :])

**:]:** -0.5 za fandtowithandraboutin:] withlaboutand, -0.5 za 60% prand noise=5, -0.5 za fromwithattwithtinande tsandtolaboutin.

## :]andthosefor]

```
Level 11.11: Obon:]ande :] (Path Discovery)
├── Tewitht 85: BFS Discovery                              [:]]
│   ├── 5 with]in × 8 with]with] = 40 :]andwithey
│   ├── :]: 32/32 (100%)
│   ├── :]: 32/32 (100%)
│   └── :]with-with]withtand: 100% precision
├── Tewitht 86: :] KG Discovery                       [:]]
│   ├── 225 trand:]in, 3 :]on
│   ├── Obon:]ande from:]andy: 225/225 (100%)
│   ├── 2-hop :]toand: 10/10 (100%)
│   └── 3-hop :]toand: 10/10 (100%)
├── Tewitht 87: Beam Search prand :]                        [:]]
│   ├── Greedy vs Beam-3 vs Beam-5
│   ├── Noise=0: inwithe 100%
│   ├── Noise=3: 50% → 70% → 80%
│   └── Noise=5: 10% → 30% → 60%
└── :] (Level 11.0-11.10)
```

## Naboutinye .vibee with]andfVersiontsand

| :]andfVersiontsandya | :]on:]ande |
|-------------|-----------|
| `kg_path_discovery.vibee` | BFS abouton:]ande :] |
| `kg_multihop_discovery.vibee` | Obon:]ande from:]andy + :]toand |
| `kg_beam_search.vibee` | Beam search prand :] |

## Resulty :]toaboutin

| :]andya | :]witht | :]withtoonya withbywith]witht |
|----------|-------------|----------------------|
| Bind | 2,023 ns | 126.5 M trits/sec |
| Bundle3 | 2,370 ns | 108.0 M trits/sec |
| Cosine | 201 ns | 1,273.6 M trits/sec |
| Dot | 6 ns | 40,000.0 M trits/sec |
| Permute | 2,175 ns | 117.7 M trits/sec |

## :]ande stepand (:]inabout :]andy)

### :]and:] A: :]andzin:] :] (not DAG)
:]inandt tsandtoly, :]withtin:] :]and :] with]with]and. BFS with fromwith]andem bywith] :]in. :]onya with]for] KG.

### :]and:] B: Dimension Scaling (DIM=4096)
Uinelandchandt :]witht for byin:]andya yomtoaboutwithtand and :]with]andinaboutwithtand. Beam-5 prand noise=5 :] :] >90%.

### :]and:] C: :]ande inewithaboutin (Weight Learning)
:]withthat fandtowithandraboutin:] beam scores — :]andt inewitha for :] tandbyin from:]andy. :]andin:] :]andraboutinanande.

## :]andchonya and:]and:]witht

$$\varphi^2 + \frac{1}{\varphi^2} = 3$$

---

*:]: 2026-02-16 | Zin:] :]fromabouty :]and #121 | Level 11.11 Path Discovery — BFS 100%, Relation Discovery 225/225, Beam-5 60% prand noise=5*
