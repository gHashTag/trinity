# [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] v3 — [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] 999 with Маtoроwithамand

## [CYR:[TRANSLATED]]andтеfor[TRANSLATED]]

```
                    [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] v3
                    
     ┌─────┐   ┌─────┐   ┌─────┐
     │  Ⲅ  │   │  Ⲋ  │   │  Ⲑ  │
     │леtowithер│   │[CYR:[TRANSLATED]]withер│   │for[TRANSLATED]]│
     └──┬──┘   └──┬──┘   └──┬──┘
        │         │         │
        └────┬────┴────┬────┘
             │    Ⲙ    │
          ┌──┴─────────┴──┐
          │    [CYR:[TRANSLATED]]      │
          │  (маtoроwithы)    │
          └───────┬───────┘
                  │
          ┌───────┴───────┐
          │      Ⲭ        │
          │   [CYR:[TRANSLATED]]       │
          │ ([CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]) │
          └───────────────┘
```

## Пfromоto for[TRANSLATED]]and[CYR:[TRANSLATED]]and

```
Иwith[TRANSLATED]]andto → Ⲅ → Тоfor[TRANSLATED]] → Ⲋ → AST → Ⲙ → AST' → Ⲭ → IR → Ⲑ → [CYR:[TRANSLATED]]
   Ⲥ           [ⲨⲀ]          ⲨⲂ       ⲨⲂ'      ⲨⲄ       Ⲥ
```

## [CYR:[TRANSLATED]]not[CYR:[TRANSLATED]]

| Сandмinол | [CYR:[TRANSLATED]]notнт | [CYR:[TRANSLATED]] | [CYR:[TRANSLATED]]to |
|--------|-----------|------|-------|
| Ⲅ | Леtowithер | gorynych.999 | — |
| Ⲋ | [CYR:[TRANSLATED]]withер | gorynych.999 | — |
| Ⲙ | Маtoроwithы | makrosy.999 + proc_makrosy.999 + gigiena.999 | 1112 |
| Ⲭ | [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]] | hvost.999 + prohody.999 | 274 |
| Ⲑ | [CYR:[TRANSLATED]] | gorynych.999 | — |
| — | Тandпы | tipy.999 | 248 |
| — | [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] | gorynych.999 | 325 |
| **Σ** | **Вwith[TRANSLATED]]** | **7 fileоin** | **1913** |

## Хinоwithт ([CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]])

### [CYR:[TRANSLATED]]inнand [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]and

| [CYR:[TRANSLATED]] | [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] | [CYR:[TRANSLATED]] |
|------|---------|---------|
| -O0 | 0 | [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]andй |
| -O1 | 1 | DCE |
| -O2 | 2 | DCE, CF |
| -O3 | 3 | DCE, CF, CP |
| -O4 | 4 | DCE, CF, CP, CSE |
| -O5 | 5 | DCE, CF, CP, CSE, INL |
| -O9 | 9 | Маtowithand[CYR:[TRANSLATED]] ([CYR:[TRANSLATED]]) |

### [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]and

| Сandмinол | [CYR:[TRANSLATED]] | Опandwithанandе |
|--------|--------|----------|
| Ⲁ | DCE | [CYR:[TRANSLATED]]andе [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] for[TRANSLATED]] |
| Ⲃ | CF | Сin[CYR:[TRANSLATED]]toа toонwith[TRANSLATED]] |
| Ⲅ | CP | Раwith[TRANSLATED]]with[TRANSLATED]]notнandе toопandй |
| Ⲇ | CSE | Уwith[TRANSLATED]]notнandе [CYR:[TRANSLATED]]andх [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]]andй |
| Ⲉ | INL | [CYR:[TRANSLATED]]andнг [CYR:[TRANSLATED]]toцandй |

### Прand[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]and

**До (AST):**
```
Ⲙ x = 3 + 4
Ⲙ y = x * 2
Ⲙ z = 10
Ⲣ y
```

**Поwithле (IR, -O3):**
```
LOAD 14, r0    // 3+4=7, 7*2=14 — within[CYR:[TRANSLATED]]
RET r0         // z [CYR:[TRANSLATED]] ([CYR:[TRANSLATED]]inый toод)
```

## Сandwith[TRANSLATED]] тandпоin

### [CYR:[TRANSLATED]]inые тandпы

| Сandмinол | Тandп | Опandwithанandе |
|--------|-----|----------|
| Ⲋ | чandwithло | 27-рand[CYR:[TRANSLATED]] [CYR:[TRANSLATED]] |
| Ⲥ | withлоinо | [CYR:[TRANSLATED]]toа |
| Ⲧ | [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]] | Ⲁ/Ⲃ/Ⲯ |
| Ⲩ | with[TRANSLATED]]for[TRANSLATED]] | Соwithтаin[CYR:[TRANSLATED]] тandп |
| Ⲫ | [CYR:[TRANSLATED]]withтinandе | [CYR:[TRANSLATED]]toцandя |
| Ⲭ | пуwithтfromа | void |
| Ⲯ | notin[CYR:[TRANSLATED]] | unknown |

### [CYR:[TRANSLATED]]andчonя [CYR:[TRANSLATED]]andtoа

```
Ⲁ — andwithтandon (true)
Ⲃ — false (false)
Ⲯ — notin[CYR:[TRANSLATED]] (unknown)
```

**[CYR:[TRANSLATED]]andца  (&&):**
```
    Ⲁ  Ⲃ  Ⲯ
Ⲁ   Ⲁ  Ⲃ  Ⲯ
Ⲃ   Ⲃ  Ⲃ  Ⲃ
Ⲯ   Ⲯ  Ⲃ  Ⲯ
```

**[CYR:[TRANSLATED]]andца [CYR:[TRANSLATED]] (||):**
```
    Ⲁ  Ⲃ  Ⲯ
Ⲁ   Ⲁ  Ⲁ  Ⲁ
Ⲃ   Ⲁ  Ⲃ  Ⲯ
Ⲯ   Ⲁ  Ⲯ  Ⲯ
```

## Сandwith[TRANSLATED]] маtoроwithоin ([CYR:[TRANSLATED]] Ⲙ)

### Вwith[TRANSLATED]] маtoроwithы

| Сandмinол | Маtoроwith | Опandwithанandе |
|--------|--------|----------|
| @Ⲇ | derive | Аin[CYR:[TRANSLATED]]not[CYR:[TRANSLATED]]andя trait [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andй |
| @Ⲣ | route | HTTP [CYR:[TRANSLATED]] |
| @Ⲧ | test | Теwithтоinые [CYR:[TRANSLATED]]toцand |
| @Ⲕ | cache | [CYR:[TRANSLATED]]andроinанandе resultоin |
| @Ⲃ | validate | [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя fieldй |

### [CYR:[TRANSLATED]] маtoроwithы

| Маtoроwith | Опandwithанandе |
|--------|----------|
| `sql!()` | SQL [CYR:[TRANSLATED]]withы with [CYR:[TRANSLATED]]inерtoой on stageе for[TRANSLATED]]and[CYR:[TRANSLATED]]and |
| `html!()` | HTML [CYR:[TRANSLATED]] with and[CYR:[TRANSLATED]]fieldsцandей |
| `json!()` | JSON лand[CYR:[TRANSLATED]] |
| `regex!()` | [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя regex on stageе for[TRANSLATED]]and[CYR:[TRANSLATED]]and |
| `format!()` | [CYR:[TRANSLATED]]andроinанandе with[TRANSLATED]]to |
| `include!()` | Вfor[TRANSLATED]]andе fileоin |
| `env!()` | [CYR:[TRANSLATED]] оfor[TRANSLATED]]andя |
| `cfg!()` | Уwithлоinonя for[TRANSLATED]]and[CYR:[TRANSLATED]]andя |

### Derive [CYR:[TRANSLATED]]

```
@Ⲇ(Entity)       — table_name, columns, from_row, to_row, id
@Ⲇ(Serialize)    — to_json, to_yaml, to_msgpack
@Ⲇ(Deserialize)  — from_json, from_yaml
@Ⲇ(Clone)        — clone
@Ⲇ(Debug)        — debug
@Ⲇ(Eq)           — eq, ne
@Ⲇ(Hash)         — hash
@Ⲇ(Default)      — default
@Ⲇ(Builder)      — with_*, build
```

### Прand[CYR:[TRANSLATED]] andwith[TRANSLATED]]inанandя

```
// [CYR:[TRANSLATED]] маtoроwithоin: ~50 with[TRANSLATED]]to boilerplate
//  маtoроwithамand: 5 with[TRANSLATED]]to

@Ⲇ(Entity, Serialize, Clone, Debug)
Ⲏ User:
  id: Ⲋ
  name: Ⲥ
  email: Ⲥ

@Ⲣ(GET, "/users/:id")
@Ⲕ(ttl: 60)
Ⲫ get_user(req: Request) -> Response:
  Ⲙ user = sql!("SELECT * FROM users WHERE id = ?", req.params["id"])
  Ⲣ Response.json(user)
```

## [CYR:[TRANSLATED]]innotнandе inерwithandй

| [CYR:[TRANSLATED]]withandя | [CYR:[TRANSLATED]]to | [CYR:[TRANSLATED]]to | [CYR:[TRANSLATED]]not[CYR:[TRANSLATED]] | [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]andя | Маtoроwithы |
|--------|------|-------|------------|-------------|---------|
| v0 | Zig | ~2630 | 3 [CYR:[TRANSLATED]]inы | [CYR:[TRANSLATED]] | [CYR:[TRANSLATED]] |
| v1 | .vibee | ~1054 | 3 [CYR:[TRANSLATED]]inы | [CYR:[TRANSLATED]] | [CYR:[TRANSLATED]] |
| v2 | .999 | 790 | 3 [CYR:[TRANSLATED]]inы + хinоwithт | 5 [CYR:[TRANSLATED]]in | [CYR:[TRANSLATED]] |
| v3 | .999 | 1913 | 3 [CYR:[TRANSLATED]]inы + [CYR:[TRANSLATED]] + хinоwithт | 5 [CYR:[TRANSLATED]]in | 15+ маtoроwithоin |

### [CYR:[TRANSLATED]]andе for[TRANSLATED]]

```
v0 (Zig)   ████████████████████████████ 2630 with[TRANSLATED]]to
v1 (vibee) ██████████ 1054 with[TRANSLATED]]to (-60%)
v2 (999)   ███████ 790 with[TRANSLATED]]to (-70%)
v3 (999)   ███████████████ 1913 with[TRANSLATED]]to (with маtoроwithамand)
```

### Соfor[TRANSLATED]]andе boilerplate

```
[CYR:[TRANSLATED]] маtoроwithоin: ~100 with[TRANSLATED]]to on entity + routes
 маtoроwithамand:  ~10 with[TRANSLATED]]to
Соfor[TRANSLATED]]andе:   10x
```

## Иwith[TRANSLATED]]inанandе

```bash
# [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя with [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]andей по [CYR:[TRANSLATED]]andю (-O3)
./gorynych program.999

# [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]and
./gorynych -O0 program.999

# Маtowithand[CYR:[TRANSLATED]]onя [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]andя
./gorynych -O9 program.999

# Геnot[CYR:[TRANSLATED]]andя in [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]and
./gorynych --zig program.999
./gorynych --wasm program.999
./gorynych --python program.999
```

## [CYR:[TRANSLATED]]

```
src/999/
├── gorynych.999      # [CYR:[TRANSLATED]]in[CYR:[TRANSLATED]] for[TRANSLATED]]and[CYR:[TRANSLATED]] (325 with[TRANSLATED]]to)
├── makrosy.999       # Деfor[TRANSLATED]]andin[CYR:[TRANSLATED]] маtoроwithы (423 with[TRANSLATED]]toand)
├── proc_makrosy.999  # [CYR:[TRANSLATED]] маtoроwithы (364 with[TRANSLATED]]toand)
├── gigiena.999       # Гandгandенandчеwithtoandе маtoроwithы (279 with[TRANSLATED]]to)
├── hvost.999         # Хinоwithт — IR (92 with[TRANSLATED]]toand)
├── prohody.999       # [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]]and (182 with[TRANSLATED]]toand)
└── tipy.999          # Сandwith[TRANSLATED]] тandпоin (248 with[TRANSLATED]]to)
```

## Creation Pattern

```
Source → Transformer → Result

Ⲥ → Ⲅ → [ⲨⲀ]     # Леtowithер
[ⲨⲀ] → Ⲋ → ⲨⲂ    # [CYR:[TRANSLATED]]withер
ⲨⲂ → Ⲭ → ⲨⲄ      # [CYR:[TRANSLATED]]andмand[CYR:[TRANSLATED]] ([CYR:[TRANSLATED]]!)
ⲨⲄ → Ⲑ → Ⲥ       # [CYR:[TRANSLATED]]
```
