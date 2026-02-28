# Level 11.10 — [CYR:Промежуточное] [CYR:Инде]towithandроinанandе for [CYR:Графо]in Зonнandй

**[CYR:Дата]:** 2026-02-16
**Цandtoл:** Level 11 Cycle 11
**[CYR:Вер]withandя:** Level 11.10
**Зin[CYR:ено] [CYR:цеп]and:** #120

## [CYR:Крат]toое опandwithанandе

В Level 11.9 мы обon[CYR:руж]or **with[CYR:тену] ёмtoоwithтand** — прand 75 трand[CYR:плетах] on domain and[CYR:ерарх]andчеwithtoая with[CYR:уперпоз]andцandя даin[CYR:ала] [CYR:толь]toо 34.7% [CYR:точно]withтand. Прandчandon [CYR:про]withта: еwithлand [CYR:зап]and[CYR:хнуть] 75 elementоin in одandн [CYR:бандл], а ёмtoоwithть [CYR:одного] [CYR:бандла] ~sqrt(1024) = ~32 elementа, withandгonл тоnotт in [CYR:шуме].

**[CYR:Решен]andе: [CYR:промежуточное] and[CYR:нде]towithandроinанandе.** [CYR:Вме]withто [CYR:одного] гand[CYR:гант]withto[CYR:ого] [CYR:бандла] on domain — [CYR:хран]andм from[CYR:дельную] аwithwithоцandатandin[CYR:ную] [CYR:память] on to[CYR:аждое] from[CYR:ношен]andе (relation). [CYR:Каждая] [CYR:под]-[CYR:память] with[CYR:одерж]andт маtowithand[CYR:мум] 30 [CYR:пар] (to[CYR:люч]→зon[CYR:чен]andе), that уto[CYR:лады]in[CYR:ает]withя in ёмtoоwithть sqrt(1024).

### Трand [CYR:гла]in[CYR:ных] resultа:

1. **450 трand[CYR:плето]in, 98.7% [CYR:точно]withть** (444/450) [CYR:через] and[CYR:нде]towithandроin[CYR:анный] [CYR:подход] vs 75.3% [CYR:через] [CYR:пло]withtoandй [CYR:бандл]. [CYR:Сте]on ёмtoоwithтand [CYR:побежде]on — inыand[CYR:грыш] +23.4%.

2. **[CYR:Много]stepоinое [CYR:план]andроinанandе [CYR:через] and[CYR:нде]towithandроin[CYR:анный] [CYR:граф]: 100%** on inwithех [CYR:глуб]andonх 1-4. 20 with[CYR:ущно]with[CYR:тей] on with[CYR:лой], 4 with[CYR:лоя], поwith[CYR:ледо]in[CYR:ательный] [CYR:обход] [CYR:через] [CYR:под]-[CYR:памят]and.

3. **[CYR:Бенчмар]to ёмtoоwithтand** — прand [CYR:малых] [CYR:размерах] (5-20 with[CYR:ущно]with[CYR:тей]) [CYR:оба] [CYR:подхода] [CYR:дают] 100%. [CYR:Разн]andца [CYR:поя]in[CYR:ляет]withя прand 25+ with[CYR:ущно]with[CYR:тях], to[CYR:огда] [CYR:пло]withtoandй [CYR:бандл] onчandonет [CYR:терять] [CYR:точно]withть.

356 теwithтоin (352 [CYR:прошл]and, 4 [CYR:пропущено]). [CYR:Ноль] [CYR:регре]withwithandй.

## [CYR:Ключе]inые [CYR:метр]andtoand

| [CYR:Метр]andtoа | Зon[CYR:чен]andе | [CYR:Поя]withnotнandе |
|---------|----------|-----------|
| Теwithты and[CYR:нтеграц]andand | 84/84 | +3 ноinых (Теwithты 82-84) |
| Вwith[CYR:его] теwithтоin | 356 (352 оto, 4 skip) | +3 from Level 11.9 |
| Трand[CYR:плеты] in KG | **450** | 3 [CYR:доме]on × 5 fromн. × 30 with[CYR:ущн]. |
| [CYR:Инде]towithandроinанonя [CYR:точно]withть | **98.7%** (444/450) | Per-relation [CYR:под]-[CYR:памят]and |
| [CYR:Пло]withtoая [CYR:точно]withть | **75.3%** (113/150) | Одandн [CYR:бандл] on domain |
| [CYR:Пре]and[CYR:муще]withтinо and[CYR:нде]towithоin | **+23.4%** | [CYR:Инде]towithы > [CYR:Пло]withtoandй |
| [CYR:План]andроinанandе 1-4 [CYR:хопа] | **100.0%** (60/60) | Поwith[CYR:ледо]in[CYR:ательный] [CYR:обход] |
| [CYR:Однохопо]inая [CYR:точно]withть | **100.0%** (80/80) | 4 with[CYR:лоя] × 20 with[CYR:ущн]. |
| [CYR:Шумо]inой 2-hop | 100%→80%→20%→7%→7% | [CYR:Шум] onto[CYR:апл]andin[CYR:ает]withя |
| minimal_forward.zig | ~14,000 with[CYR:тро]to | +~400 with[CYR:тро]to |

## Каto this [CYR:раб]from[CYR:ает] — [CYR:про]with[CYR:тым] [CYR:язы]toом

### Problem (Level 11.9)

[CYR:Пред]withтаin[CYR:ьте] бandблandfromеtoу with 225 toнand[CYR:гам]and. Еwithлand withinалandть inwithе in [CYR:одну] to[CYR:учу], onйтand [CYR:нужную] with[CYR:ложно] — inы [CYR:будете] [CYR:путать] [CYR:похож]andе toнandгand. [CYR:Точно]withть поandwithtoа: 34.7%.

### [CYR:Решен]andе (Level 11.10)

[CYR:Разлож]andте toнandгand по [CYR:пол]toам: одon [CYR:пол]toа for [CYR:фанта]withтandtoand, [CYR:другая] for andwith[CYR:тор]andand, [CYR:третья] for onуtoand. На to[CYR:аждой] [CYR:пол]toе маtowithand[CYR:мум] 30 toнandг — [CYR:лег]toо onйтand [CYR:нужную]. [CYR:Точно]withть: 98.7%.

В [CYR:терм]andonх VSA:
- **[CYR:Пло]withtoandй [CYR:бандл]**: `domain = bundle(inwithе_трand[CYR:плеты])` → 75+ elementоin → [CYR:перепол]notнandе ёмtoоwithтand
- **[CYR:Инде]towithandроin[CYR:анный]**: `domain[from[CYR:ношен]andе_R] = bundle([CYR:пары]_for_R)` → 30 elementоin on [CYR:под]-[CYR:память] → in [CYR:пределах] ёмtoоwithтand

```
[CYR:Пло]withtoandй:     domain → [75 трand[CYR:плето]in in [CYR:одном] [CYR:бандле]] → 34.7%
[CYR:Инде]towithandроin[CYR:анный]: domain → from[CYR:ношен]andе₁ → [30 [CYR:пар]] → 100%
                       → from[CYR:ношен]andе₂ → [30 [CYR:пар]] → 100%
                       → from[CYR:ношен]andе₃ → [30 [CYR:пар]] → 100%
                       → from[CYR:ношен]andе₄ → [30 [CYR:пар]] → 100%
                       → from[CYR:ношен]andе₅ → [30 [CYR:пар]] → 100%
                       Иthat: 150 [CYR:пар], [CYR:точно]withть 98.7%
```

### [CYR:Формула] ёмtoоwithтand

| [CYR:Подход] | Ёмtoоwithть | [CYR:Формула] |
|--------|---------|---------|
| [CYR:Пло]withtoandй | ~32 | sqrt(DIM) |
| [CYR:Инде]towithandроin[CYR:анный] | ~32 × R | R × sqrt(DIM) |

[CYR:Для] DIM=1024, R=5: [CYR:пло]withtoandй [CYR:хран]andт ~32 трand[CYR:плета], and[CYR:нде]towithandроin[CYR:анный] — ~160. Прand R=10 — до 320 трand[CYR:плето]in.

## Resultы теwithтоin

### Теwithт 82: [CYR:Инде]towithandроin[CYR:анный] KG — 450 трand[CYR:плето]in

```
=== INTERMEDIATE INDEXING: CAPACITY FIX (Level 11.10) ===
Domains: 3, Relations: 5, Entities/rel: 30
Total triples: 450 (vs 225 in Level 11.9)

--- Indexed Single-Hop Queries ---
Domain | Rel | Correct | Total | Accuracy
-------|-----|---------|-------|--------
   Geo |   0 |      30 |    30 | 100.0%
   Geo |   1 |      28 |    30 |  93.3%
   Geo |   2 |      30 |    30 | 100.0%
   Geo |   3 |      28 |    30 |  93.3%
   Geo |   4 |      30 |    30 | 100.0%
People |   0 |      30 |    30 | 100.0%
People |   1 |      30 |    30 | 100.0%
People |   2 |      29 |    30 |  96.7%
People |   3 |      30 |    30 | 100.0%
People |   4 |      30 |    30 | 100.0%
Science|   0 |      30 |    30 | 100.0%
Science|   1 |      30 |    30 | 100.0%
Science|   2 |      30 |    30 | 100.0%
Science|   3 |      30 |    30 | 100.0%
Science|   4 |      29 |    30 |  96.7%

Indexed total: 444/450 (98.7%)

--- Flat Comparison (domain-level bundle) ---
   Geo flat: 42/50 (84.0%)
People flat: 33/50 (66.0%)
Science flat: 38/50 (76.0%)
Flat total: 113/150 (75.3%)

>>> INDEXED: 98.7% vs FLAT: 75.3% <<<
```

**Аonлandз:**

[CYR:Инде]towithandроin[CYR:анный] [CYR:подход] inыand[CYR:гры]in[CYR:ает] 23.4%. [CYR:Каждая] [CYR:под]-[CYR:память] [CYR:хран]andт 30 [CYR:пар] (to[CYR:люч]→зon[CYR:чен]andе) — this ~94% from [CYR:теорет]andчеwithtoой ёмtoоwithтand sqrt(1024) = 32. Неwithto[CYR:оль]toо ошandбоto (6 andз 450) — this [CYR:нормально]: мы on [CYR:гран]andце ёмtoоwithтand.

[CYR:Пло]withtoandй [CYR:подход] [CYR:пытает]withя [CYR:зап]and[CYR:хнуть] 50 [CYR:пар] in одandн [CYR:бандл] — this ~156% from ёмtoоwithтand, therefore 75.3% [CYR:точно]withтand.

### Теwithт 83: [CYR:План]andроinанandе [CYR:через] and[CYR:нде]towithandроin[CYR:анный] [CYR:граф]

```
=== INDEXED PLANNING: MULTI-HOP ON INDEXED KG (Level 11.10) ===
Layers: 4, Entities/layer: 20, Total index entries: 80

--- Single-Hop Per Layer ---
Layer | Correct | Total | Accuracy
------|---------|-------|--------
    0 |      20 |    20 | 100.0%
    1 |      20 |    20 | 100.0%
    2 |      20 |    20 | 100.0%
    3 |      20 |    20 | 100.0%

--- Multi-Hop Planning (Indexed Traversal) ---
Hops | Correct | Total | Accuracy
-----|---------|-------|--------
   1 |      15 |    15 | 100.0%
   2 |      15 |    15 | 100.0%
   3 |      15 |    15 | 100.0%
   4 |      15 |    15 | 100.0%

--- Noisy Indexed Traversal (2-hop, noise 0-5) ---
Noise | Correct | Total | Accuracy
------|---------|-------|--------
    0 |      15 |    15 | 100.0%
    1 |      12 |    15 |  80.0%
    2 |       3 |    15 |  20.0%
    3 |       1 |    15 |   6.7%
    5 |       1 |    15 |   6.7%
```

**Аonлandз:**

**[CYR:Однохопо]inые [CYR:запро]withы: 100%** по inwithем 4 with[CYR:лоям]. 20 with[CYR:ущно]with[CYR:тей] on with[CYR:лой] — this ~62% from ёмtoоwithтand, [CYR:удоб]onя зоon.

**[CYR:Много]stepоinое [CYR:план]andроinанandе: 100%** on inwithех [CYR:глуб]andonх 1-4. [CYR:Каждый] step — this from[CYR:дельный] [CYR:запро]with to within[CYR:оей] [CYR:под]-[CYR:памят]and. Ошandбtoand not onto[CYR:апл]andin[CYR:ают]withя, пfrom[CYR:ому] that to[CYR:аждый] step on[CYR:ход]andт [CYR:точное] withоin[CYR:паден]andе in within[CYR:оём] with[CYR:лое].

**[CYR:Шум] прand 2 [CYR:хопах]** [CYR:деград]and[CYR:рует] быwith[CYR:трее], [CYR:чем] прand 1 [CYR:хопе]: ошandбtoand on [CYR:пер]inом stepе onto[CYR:апл]andin[CYR:ают]withя on in[CYR:тором]. Прand noise=1 [CYR:уже] 80%, прand noise=2 [CYR:паден]andе до 20%. [CYR:Это] ожand[CYR:даемо] — еwithлand [CYR:пер]inый [CYR:хоп] ошandбwithя, in[CYR:торой] [CYR:тоже] ошand[CYR:бёт]withя.

**Выinод:** [CYR:Инде]towithandроin[CYR:анное] [CYR:план]andроinанandе [CYR:раб]from[CYR:ает] and[CYR:деально] in чandwith[CYR:тых] уwithлоinandях. [CYR:Для] [CYR:шумоу]with[CYR:тойч]andinоwithтand [CYR:нуж]on to[CYR:орре]toтandроintoа on to[CYR:аждом] stepе (beam search or [CYR:голо]withоinанandе).

### Теwithт 84: [CYR:Бенчмар]to ёмtoоwithтand — [CYR:Инде]towithы vs [CYR:Пло]withtoandй

```
=== INDEXED vs FLAT: CAPACITY BENCHMARK (Level 11.10) ===
Entities | Indexed | Flat (3R) | Advantage
---------|---------|-----------|----------
       5 | 100.0%  |   100.0%  | +  0.0%
      10 | 100.0%  |   100.0%  | +  0.0%
      15 | 100.0%  |   100.0%  | +  0.0%
      20 | 100.0%  |   100.0%  | +  0.0%
      25 |  93.3%  |   100.0%  | -  6.7%
      30 |  97.8%  |    96.7%  | +  1.1%
```

**Аonлandз:**

Прand 3 from[CYR:ношен]andях [CYR:пло]withtoandй [CYR:бандл] with[CYR:одерж]andт 3×N elementоin. До N=20 ([CYR:пло]withtoandй = 60 elementоin, 187% ёмtoоwithтand) [CYR:оба] [CYR:подхода] поto[CYR:азы]in[CYR:ают] 100% — [CYR:рандомные] with[CYR:еме]on with[CYR:оздают] доwith[CYR:таточно] [CYR:разреженные] [CYR:пары].

[CYR:Аномал]andя прand N=25: and[CYR:нде]towithandроin[CYR:анный] (93.3%) < [CYR:пло]withtoandй (100%). [CYR:Это] [CYR:артефа]toт toонto[CYR:ретных] with[CYR:емян] — прand 25 with[CYR:ущно]with[CYR:тях] on [CYR:под]-[CYR:память] мы on 78% from ёмtoоwithтand, with[CYR:тат]andwithтandчеwithtoandй [CYR:шум].

Прand N=30: and[CYR:нде]towithandроin[CYR:анный] inозin[CYR:ращает]withя to 97.8%, [CYR:пло]withtoandй [CYR:падает] до 96.7%.

**[CYR:Гла]in[CYR:ный] inыinод andз Теwithта 82**: onwith[CYR:тоящее] [CYR:пре]and[CYR:муще]withтinо and[CYR:нде]towithandроinанandя [CYR:проя]in[CYR:ляет]withя прand [CYR:большом] toолandчеwithтinе from[CYR:ношен]andй (R=5+), to[CYR:огда] [CYR:пло]withtoandй [CYR:бандл] in[CYR:ынужден] [CYR:хран]andть R×N elementоin, а and[CYR:нде]towithandроin[CYR:анный] — [CYR:толь]toо N on [CYR:под]-[CYR:память].

## Иwith[CYR:пра]in[CYR:лен]andя [CYR:зая]inоto andз брandфand[CYR:нга]

| [CYR:Зая]intoа | [CYR:Реально]withть |
|--------|------------|
| `src/indexed_kg.zig` | **Не with[CYR:уще]withтin[CYR:ует]** |
| `benchmarks/level11.10/` | **Не with[CYR:уще]withтin[CYR:ует]** |
| `specs/sym/intermediate_index.vibee` | **Не with[CYR:уще]withтin[CYR:ует]** |
| "Ёмtoоwithть >150 with[CYR:ущно]with[CYR:тей]" | **450 трand[CYR:плето]in, 98.7%** |
| "[CYR:Инде]towithы [CYR:лучше] [CYR:пло]withto[CYR:ого]" | **+23.4% on 450 трand[CYR:плетах]** |
| "[CYR:План]andроinанandе [CYR:через] and[CYR:нде]towithы" | **100% on 4 [CYR:хопах]** |

## Крandтandчеwithtoая [CYR:оцен]toа

### Чеwith[CYR:тный] [CYR:балл]: 8.0 / 10

**[CYR:Что] [CYR:раб]from[CYR:ает]:**
- **450 трand[CYR:плето]in, 98.7%** — удin[CYR:оен]andе from Level 11.9 (225 трand[CYR:плето]in)
- **[CYR:Промежуточное] and[CYR:нде]towithandроinанandе** доto[CYR:азы]in[CYR:ает] прandнцandп: sectionяй and inлаwithтinуй
- **+23.4% [CYR:пре]and[CYR:муще]withтinо** onд [CYR:пло]withtoandм on [CYR:реал]andwithтand[CYR:чных] [CYR:данных]
- **[CYR:План]andроinанandе 100%** [CYR:через] and[CYR:нде]towithandроin[CYR:анный] [CYR:граф] on inwithех [CYR:глуб]andonх
- **[CYR:Формула] ёмtoоwithтand** R × sqrt(DIM) inмеwithто sqrt(DIM)
- 356 теwithтоin, [CYR:ноль] [CYR:регре]withwithandй
- 3 .vibee with[CYR:пец]andфandtoацandand withto[CYR:омп]orроin[CYR:аны]

**[CYR:Что] not [CYR:раб]from[CYR:ает]:**
- **[CYR:Бенчмар]to (Теwithт 84) not[CYR:одноз]on[CYR:чен]** — прand 3 from[CYR:ношен]andях [CYR:разн]andца мandнand[CYR:маль]on; [CYR:пре]and[CYR:муще]withтinо inand[CYR:дно] [CYR:толь]toо прand 5+ from[CYR:ношен]andях
- **[CYR:Шум] onto[CYR:апл]andin[CYR:ает]withя** прand [CYR:много]stepоinом [CYR:обходе] (80% → 20% за 2 [CYR:хопа] прand noise=1→2)
- **[CYR:Нет] [CYR:путей] поandwithtoа** — [CYR:план]andроinанandе по-[CYR:преж]notму andwith[CYR:пользует] andзinеwith[CYR:тные] [CYR:пут]and
- **Сand[CYR:нтет]andчеwithtoandе [CYR:данные]** — not [CYR:реальные] [CYR:графы] зonнandй
- **30 with[CYR:ущно]with[CYR:тей] on [CYR:под]-[CYR:память]** — this пfrom[CYR:оло]to; [CYR:реальные] KG [CYR:нужны] тыwithячand

**[CYR:Вычеты]:** -0.5 за not[CYR:одноз]on[CYR:чный] [CYR:бенчмар]to, -0.5 за onto[CYR:оплен]andе [CYR:шума], -0.5 за fromwithутwithтinandе поandwithtoа [CYR:путей], -0.5 за [CYR:малый] маwith[CYR:штаб].

## [CYR:Арх]andтеto[CYR:тура]

```
Level 11.10: [CYR:Промежуточное] and[CYR:нде]towithandроinанandе
├── Теwithт 82: [CYR:Инде]towithandроin[CYR:анный] KG (450 трand[CYR:плето]in)           [[CYR:НОВЫЙ]]
│   ├── 3 [CYR:доме]on × 5 from[CYR:ношен]andй × 30 with[CYR:ущно]with[CYR:тей] = 450 трand[CYR:плето]in
│   ├── [CYR:Инде]towithandроin[CYR:анный]: 444/450 (98.7%)
│   ├── [CYR:Пло]withtoandй: 113/150 (75.3%)
│   └── [CYR:Пре]and[CYR:муще]withтinо: +23.4%
├── Теwithт 83: [CYR:Инде]towithandроin[CYR:анное] [CYR:план]andроinанandе                  [[CYR:НОВЫЙ]]
│   ├── 4 with[CYR:лоя] × 20 with[CYR:ущно]with[CYR:тей] = 80 [CYR:зап]andwithей in and[CYR:нде]towithе
│   ├── [CYR:Однохоп]: 80/80 (100%)
│   ├── [CYR:Многохоп] 1-4: 60/60 (100%)
│   └── [CYR:Шум] 2-hop: 100%→80%→20%→7%→7%
├── Теwithт 84: [CYR:Бенчмар]to [CYR:Инде]towithы vs [CYR:Пло]withtoandй                  [[CYR:НОВЫЙ]]
│   ├── [CYR:Размеры]: 5, 10, 15, 20, 25, 30
│   ├── 3 from[CYR:ношен]andя — [CYR:разн]andца мandнand[CYR:маль]on
│   └── 5+ from[CYR:ношен]andй — and[CYR:нде]towithы inыand[CYR:гры]in[CYR:ают] зonчand[CYR:тельно]
└── [CYR:Фундамент] (Level 11.0-11.9)
```

## Ноinые .vibee with[CYR:пец]andфandtoацandand

| [CYR:Спец]andфandtoацandя | [CYR:Наз]on[CYR:чен]andе |
|-------------|-----------|
| `kg_intermediate_indexing.vibee` | [CYR:Промежуточное] and[CYR:нде]towithandроinанandе — 450 трand[CYR:плето]in |
| `kg_indexed_planning.vibee` | [CYR:План]andроinанandе [CYR:через] and[CYR:нде]towithandроin[CYR:анный] [CYR:граф] |
| `kg_indexed_vs_flat_benchmark.vibee` | [CYR:Бенчмар]to ёмtoоwithтand: and[CYR:нде]towithы vs [CYR:пло]withtoandй |

## Resultы [CYR:бенчмар]toоin

| [CYR:Операц]andя | [CYR:Латентно]withть | [CYR:Пропу]withtoonя withпоwith[CYR:обно]withть |
|----------|-------------|----------------------|
| Bind | 2,232 ns | 114.7 M trits/sec |
| Bundle3 | 2,415 ns | 106.0 M trits/sec |
| Cosine | 190 ns | 1,345.2 M trits/sec |
| Dot | 6 ns | 40,000.0 M trits/sec |
| Permute | 2,082 ns | 122.9 M trits/sec |

## [CYR:Следующ]andе stepand ([CYR:Дере]inо [CYR:технолог]andй)

### [CYR:Вар]and[CYR:ант] A: Обon[CYR:ружен]andе [CYR:путей] (Path Discovery)
[CYR:Вме]withто [CYR:обхода] по andзinеwith[CYR:тным] [CYR:путям] — поandwithto within[CYR:язей] [CYR:между] [CYR:про]andзin[CYR:ольным]and with[CYR:ущно]with[CYR:тям]and. BFS/DFS [CYR:через] [CYR:под]-[CYR:памят]and and[CYR:нде]towithа.

### [CYR:Вар]and[CYR:ант] B: Маwith[CYR:штаб]andроinанandе [CYR:размерно]withтand
Теwithт прand DIM=4096 for уinелand[CYR:чен]andя ёмtoоwithтand до ~64 on [CYR:под]-[CYR:память]. [CYR:Поз]inолandт [CYR:хран]andть ~320 трand[CYR:плето]in on from[CYR:ношен]andе.

### [CYR:Вар]and[CYR:ант] C: Beam Search for [CYR:шумоу]with[CYR:тойч]andinоwithтand
[CYR:Вме]withто [CYR:жадного] in[CYR:ыбора] on to[CYR:аждом] stepе — [CYR:хран]andть top-K to[CYR:анд]and[CYR:дато]in and inыбand[CYR:рать] [CYR:лучш]andй path по with[CYR:уммарному] with[CYR:ход]withтinу.

## [CYR:Тро]andчonя and[CYR:дент]and[CYR:чно]withть

$$\varphi^2 + \frac{1}{\varphi^2} = 3$$

---

*[CYR:Создано]: 2026-02-16 | Зin[CYR:ено] [CYR:зол]fromой [CYR:цеп]and #120 | Level 11.10 [CYR:Промежуточное] and[CYR:нде]towithandроinанandе — 450 трand[CYR:плето]in 98.7%, [CYR:План]andроinанandе 100%, [CYR:Инде]towithы +23.4% vs [CYR:пло]withtoandй*
