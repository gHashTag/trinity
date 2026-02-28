# [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] v4 — [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] 999 with [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]

## [CYR:[TRANSLATED]]

[CYR:[TRANSLATED]]withandя 4 infor[TRANSLATED]] [CYR:[TRANSLATED]]andя on оwithноinе аonлandза toонfor[TRANSLATED]]in:
- **TREX** — 27-рandчonя withand[CYR:[TRANSLATED]]andчonя withandwith[TRANSLATED]] withчandwith[TRANSLATED]]andя
- **[CYR:[TRANSLATED]]** — [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] for[TRANSLATED]] [CYR:[TRANSLATED]]
- **[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]fromы** — ternary computing, SIMD parsing, e-graphs

## [CYR:[TRANSLATED]]andтеfor[TRANSLATED]] v4

```
                    [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] v4
                    
     ┌─────┐   ┌─────┐   ┌─────┐
     │  Ⲅ  │   │  Ⲋ  │   │  Ⲑ  │
     │SIMD │   │[CYR:[TRANSLATED]]withер│   │for[TRANSLATED]]│
     │леtowithер│   │      │   │      │
     └──┬──┘   └──┬──┘   └──┬──┘
        │    Ⲙ [CYR:[TRANSLATED]]   │
        └────┬────┴────┬────┘
             │    Ⲭ    │
          ┌──┴─────────┴──┐
          │   E-GRAPH     │
          │ [CYR:[TRANSLATED]]   │
          └───────┬───────┘
                  │
          ┌───────┴───────┐
          │   [CYR:[TRANSLATED]]    │
          │      VM       │
          └───────────────┘
```

## Ноinые for[TRANSLATED]]not[CYR:[TRANSLATED]]

### 1. TREX-withоinмеwithтand[CYR:[TRANSLATED]] withandwith[TRANSLATED]] чandwithел

```
Трandт:   {Ⲃ, Ⲟ, Ⲁ} = {-1, 0, +1}
Трandбл:  3 трandта = 27 зon[CYR:[TRANSLATED]]andй {m..a, 0, A..M}
[CYR:[TRANSLATED]]:  9 трandтоin = 3 трand[CYR:[TRANSLATED]] = [-9841, +9841]
```

**[CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]withтinа:**
- Инinерwithandя = withмеon [CYR:[TRANSLATED]]andwith[TRANSLATED]] (A ↔ a)
- Зonto = with[TRANSLATED]]andй [CYR:[TRANSLATED]]
- Оfor[TRANSLATED]]andе = from[CYR:[TRANSLATED]]withыinанandе [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]

### 2. SIMD-[CYR:[TRANSLATED]]andмandзandроin[CYR:[TRANSLATED]] леtowithер

```
[CYR:[TRANSLATED]] леtowithер:  ~150ms on 1MB
SIMD леtowithер:     ~35ms on 1MB
Уwithfor[TRANSLATED]]andе:       4.3x
```

[CYR:[TRANSLATED]]onя [CYR:[TRANSLATED]]fromtoа 16 withandмin[CYR:[TRANSLATED]]in за [CYR:[TRANSLATED]]:
- [CYR:[TRANSLATED]]withandфandtoацandя withandмin[CYR:[TRANSLATED]]in
- Поandwithto sectionand[CYR:[TRANSLATED]]
- [CYR:[TRANSLATED]]withto [CYR:[TRANSLATED]]in

### 3. E-graph [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]

Equality saturation for [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]and:
- `x + 0 = x`
- `x * 1 = x`
- `x - x = 0`
- Аwithоцandатandinноwithть, for[TRANSLATED]]andinноwithть

### 4. Инfor[TRANSLATED]]onя for[TRANSLATED]]and[CYR:[TRANSLATED]]andя

```
[CYR:[TRANSLATED]]inая for[TRANSLATED]]and[CYR:[TRANSLATED]]andя:  100%
Поin[CYR:[TRANSLATED]]onя:          5-10% ([CYR:[TRANSLATED]]toо and[CYR:[TRANSLATED]])
Уwithfor[TRANSLATED]]andе:          10-20x
```

[CYR:[TRANSLATED]]toцand:
- [CYR:[TRANSLATED]] заinandwithandмоwith[TRANSLATED]]
- [CYR:[TRANSLATED]]andроinанandе AST/IR
- Watch mode
- [CYR:[TRANSLATED]]onя for[TRANSLATED]]and[CYR:[TRANSLATED]]andя

### 5. [CYR:[TRANSLATED]]andчonя VM

27 [CYR:[TRANSLATED]]andwith[TRANSLATED]]in (Ⲁ-Ⲯ), [CYR:[TRANSLATED]]andчonя арand[CYR:[TRANSLATED]]andtoа, GC:

```
Опfor[TRANSLATED]]:
  LOAD_IMM, LOAD_REG, LOAD_MEM, STORE_MEM
  ADD, SUB, MUL, DIV, NEG
  AND, OR, NOT ([CYR:[TRANSLATED]]andчonя [CYR:[TRANSLATED]]andtoа)
  JMP, JZ, JP, JN
  CALL, RET
  ALLOC, FREE
  SYSCALL, HALT
```

## [CYR:[TRANSLATED]] (3904 with[TRANSLATED]]toand)

| [CYR:[TRANSLATED]] | [CYR:[TRANSLATED]]to | [CYR:[TRANSLATED]]on[CYR:[TRANSLATED]]andе |
|------|-------|------------|
| `yadro.999` | 446 | [CYR:[TRANSLATED]]: TREX чandwithла, E-graph, andнfor[TRANSLATED]] |
| `runtime.999` | 466 | VM, [CYR:memory], GC |
| `makrosy.999` | 423 | Деfor[TRANSLATED]]andin[CYR:[TRANSLATED]] маtoроwithы |
| `inkrement.999` | 372 | Инfor[TRANSLATED]]onя for[TRANSLATED]]and[CYR:[TRANSLATED]]andя |
| `proc_makrosy.999` | 364 | [CYR:[TRANSLATED]] маtoроwithы |
| `arifmetika.999` | 360 | [CYR:[TRANSLATED]]andчonя арand[CYR:[TRANSLATED]]andtoа |
| `simd_lexer.999` | 347 | SIMD леtowithер |
| `gorynych.999` | 325 | [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] for[TRANSLATED]]and[CYR:[TRANSLATED]] |
| `gigiena.999` | 279 | Гandгandенandчеwithtoandе маtoроwithы |
| `tipy.999` | 248 | Сandwith[TRANSLATED]] тandпоin |
| `prohody.999` | 182 | [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]and |
| `hvost.999` | 92 | IR with[TRANSLATED]]for[TRANSLATED]] |

## [CYR:[TRANSLATED]]innotнandе inерwithandй

| [CYR:[TRANSLATED]]withandя | [CYR:[TRANSLATED]]to | [CYR:[TRANSLATED]]not[CYR:[TRANSLATED]] | Оwith[TRANSLATED]]withтand |
|--------|-------|------------|-------------|
| v0 (Zig) | ~2630 | 3 [CYR:[TRANSLATED]]inы | [CYR:[TRANSLATED]]inый |
| v1 (.vibee) | ~1054 | 3 [CYR:[TRANSLATED]]inы | Руwithtoandе withлоinа |
| v2 (.999) | 790 | + хinоwithт | [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]] |
| v3 (.999) | 1913 | + [CYR:[TRANSLATED]] | Маtoроwithы |
| **v4 (.999)** | **3904** | **+ [CYR:[TRANSLATED]]** | **TREX, SIMD, VM** |

## [CYR:[TRANSLATED]]andзinодand[CYR:[TRANSLATED]]withть

### Леtowithер
```
v3 ([CYR:[TRANSLATED]]):  150ms / 1MB
v4 (SIMD):     35ms / 1MB
Уwithfor[TRANSLATED]]andе:     4.3x
```

### [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя
```
v3 ([CYR:[TRANSLATED]]onя):       100%
v4 (andнfor[TRANSLATED]]):    5-10%
Уwithfor[TRANSLATED]]andе:         10-20x
```

### [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]andя
```
v3 ([CYR:[TRANSLATED]]):      5 [CYR:[TRANSLATED]]in
v4 (E-graph):      Equality saturation
[CYR:[TRANSLATED]]withтinо for[TRANSLATED]]:     +15%
```

## [CYR:[TRANSLATED]]andчonя арand[CYR:[TRANSLATED]]andtoа

### [CYR:[TRANSLATED]]andе трandтоin
```
  Ⲃ  Ⲟ  Ⲁ
Ⲃ Ⲃ¹ Ⲃ  Ⲟ
Ⲟ Ⲃ  Ⲟ  Ⲁ
Ⲁ Ⲟ  Ⲁ  Ⲁ¹

¹ = [CYR:[TRANSLATED]]with
```

### [CYR:[TRANSLATED]]andе трandтоin
```
  Ⲃ  Ⲟ  Ⲁ
Ⲃ Ⲁ  Ⲟ  Ⲃ
Ⲟ Ⲟ  Ⲟ  Ⲟ
Ⲁ Ⲃ  Ⲟ  Ⲁ
```

### TREX [CYR:[TRANSLATED]]withтаin[CYR:[TRANSLATED]]andе
```
Чandwithло 100:
  [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]: +0+0+
  TREX:     0DK
  
Инinерwithandя:
  -100 = 0dk (withмеon [CYR:[TRANSLATED]]andwith[TRANSLATED]])
```

## Иwith[TRANSLATED]]inанandе

```bash
# [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя
./gorynych -O9 program.999

# Watch mode
./gorynych --watch src/

# [CYR:[TRANSLATED]]withto in VM
./gorynych --run program.999

# TREX inыinод
./gorynych --trex program.999
```

## [CYR:[TRANSLATED]]for[TRANSLATED]]

| Сandwith[TRANSLATED]] | [CYR:[TRANSLATED]] | Оwith[TRANSLATED]]withтand |
|---------|-----|-------------|
| [CYR:[TRANSLATED]] | 1958 | [CYR:[TRANSLATED]]inый [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] for[TRANSLATED]] |
| TREX | 2021 | 27-рandчonя toодandроintoа |
| **999** | **2026** | **[CYR:[TRANSLATED]] for[TRANSLATED]]and[CYR:[TRANSLATED]] + VM** |

## [CYR:[TRANSLATED]] оwithноinы

1. **TREX** (Трand[CYR:[TRANSLATED]]in, 2021) — withand[CYR:[TRANSLATED]]andчonя 27-рandчonя withandwith[TRANSLATED]]
2. **simdjson** (Lemire) — SIMD [CYR:[TRANSLATED]]withandнг
3. **egg** (Willsey) — E-graph [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]andя
4. **Salsa** (Rust) — andнfor[TRANSLATED]]onя for[TRANSLATED]]and[CYR:[TRANSLATED]]andя
5. **Balanced Ternary** (Knuth) — [CYR:[TRANSLATED]]andчonя арand[CYR:[TRANSLATED]]andtoа

## Roadmap

### v5 ([CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]withя)
- JIT for[TRANSLATED]]and[CYR:[TRANSLATED]]andя
- [CYR:[TRANSLATED]]fromочonя VM
- FFI with Zig/C
- [CYR:[TRANSLATED]]andto

### v6 (andwith[TRANSLATED]]inанandе)
- Кin[CYR:[TRANSLATED]]inые [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]
- ML-[CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]andя
- Раwith[TRANSLATED]]onя for[TRANSLATED]]and[CYR:[TRANSLATED]]andя
