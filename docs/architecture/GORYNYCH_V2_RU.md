# [CYR:Змей] [CYR:Горыныч] v3 — [CYR:Комп]and[CYR:лятор] 999 with Маtoроwithамand

## [CYR:Арх]andтеto[CYR:тура]

```
                    [CYR:ЗМЕЙ] [CYR:ГОРЫНЫЧ] v3
                    
     ┌─────┐   ┌─────┐   ┌─────┐
     │  Ⲅ  │   │  Ⲋ  │   │  Ⲑ  │
     │леtowithер│   │[CYR:пар]withер│   │to[CYR:одоген]│
     └──┬──┘   └──┬──┘   └──┬──┘
        │         │         │
        └────┬────┴────┬────┘
             │    Ⲙ    │
          ┌──┴─────────┴──┐
          │    [CYR:ЧЕШУЯ]      │
          │  (маtoроwithы)    │
          └───────┬───────┘
                  │
          ┌───────┴───────┐
          │      Ⲭ        │
          │   [CYR:ХВОСТ]       │
          │ ([CYR:опт]andмand[CYR:затор]) │
          └───────────────┘
```

## Пfromоto to[CYR:омп]and[CYR:ляц]andand

```
Иwith[CYR:ходн]andto → Ⲅ → Тоto[CYR:ены] → Ⲋ → AST → Ⲙ → AST' → Ⲭ → IR → Ⲑ → [CYR:Код]
   Ⲥ           [ⲨⲀ]          ⲨⲂ       ⲨⲂ'      ⲨⲄ       Ⲥ
```

## [CYR:Компо]not[CYR:нты]

| Сandмinол | [CYR:Компо]notнт | [CYR:Файл] | [CYR:Стро]to |
|--------|-----------|------|-------|
| Ⲅ | Леtowithер | gorynych.999 | — |
| Ⲋ | [CYR:Пар]withер | gorynych.999 | — |
| Ⲙ | Маtoроwithы | makrosy.999 + proc_makrosy.999 + gigiena.999 | 1112 |
| Ⲭ | [CYR:Опт]andмand[CYR:затор] | hvost.999 + prohody.999 | 274 |
| Ⲑ | [CYR:Кодоген] | gorynych.999 | — |
| — | Тandпы | tipy.999 | 248 |
| — | [CYR:Гла]in[CYR:ный] | gorynych.999 | 325 |
| **Σ** | **Вwith[CYR:его]** | **7 fileоin** | **1913** |

## Хinоwithт ([CYR:Опт]andмand[CYR:затор])

### [CYR:Уро]inнand [CYR:опт]andмand[CYR:зац]andand

| [CYR:Флаг] | [CYR:Уро]in[CYR:ень] | [CYR:Проходы] |
|------|---------|---------|
| -O0 | 0 | [CYR:Без] [CYR:опт]andмand[CYR:зац]andй |
| -O1 | 1 | DCE |
| -O2 | 2 | DCE, CF |
| -O3 | 3 | DCE, CF, CP |
| -O4 | 4 | DCE, CF, CP, CSE |
| -O5 | 5 | DCE, CF, CP, CSE, INL |
| -O9 | 9 | Маtowithand[CYR:мум] ([CYR:многопроходный]) |

### [CYR:Проходы] [CYR:опт]andмand[CYR:зац]andand

| Сandмinол | [CYR:Проход] | Опandwithанandе |
|--------|--------|----------|
| Ⲁ | DCE | [CYR:Удален]andе [CYR:мёрт]in[CYR:ого] to[CYR:ода] |
| Ⲃ | CF | Сin[CYR:ёрт]toа toонwith[CYR:тант] |
| Ⲅ | CP | Раwith[CYR:про]with[CYR:тра]notнandе toопandй |
| Ⲇ | CSE | Уwith[CYR:тра]notнandе [CYR:общ]andх [CYR:под]in[CYR:ыражен]andй |
| Ⲉ | INL | [CYR:Инлайн]andнг [CYR:фун]toцandй |

### Прand[CYR:мер] [CYR:опт]andмand[CYR:зац]andand

**До (AST):**
```
Ⲙ x = 3 + 4
Ⲙ y = x * 2
Ⲙ z = 10
Ⲣ y
```

**Поwithле (IR, -O3):**
```
LOAD 14, r0    // 3+4=7, 7*2=14 — within[CYR:ёрнуто]
RET r0         // z [CYR:удалено] ([CYR:мёрт]inый toод)
```

## Сandwith[CYR:тема] тandпоin

### [CYR:Базо]inые тandпы

| Сandмinол | Тandп | Опandwithанandе |
|--------|-----|----------|
| Ⲋ | чandwithло | 27-рand[CYR:чное] [CYR:целое] |
| Ⲥ | withлоinо | [CYR:Стро]toа |
| Ⲧ | [CYR:тро]and[CYR:чное] | Ⲁ/Ⲃ/Ⲯ |
| Ⲩ | with[CYR:тру]to[CYR:тура] | Соwithтаin[CYR:ной] тandп |
| Ⲫ | [CYR:дей]withтinandе | [CYR:Фун]toцandя |
| Ⲭ | пуwithтfromа | void |
| Ⲯ | notin[CYR:едомо] | unknown |

### [CYR:Тро]andчonя [CYR:лог]andtoа

```
Ⲁ — andwithтandon (true)
Ⲃ — false (false)
Ⲯ — notin[CYR:едомо] (unknown)
```

**[CYR:Табл]andца И (&&):**
```
    Ⲁ  Ⲃ  Ⲯ
Ⲁ   Ⲁ  Ⲃ  Ⲯ
Ⲃ   Ⲃ  Ⲃ  Ⲃ
Ⲯ   Ⲯ  Ⲃ  Ⲯ
```

**[CYR:Табл]andца [CYR:ИЛИ] (||):**
```
    Ⲁ  Ⲃ  Ⲯ
Ⲁ   Ⲁ  Ⲁ  Ⲁ
Ⲃ   Ⲁ  Ⲃ  Ⲯ
Ⲯ   Ⲁ  Ⲯ  Ⲯ
```

## Сandwith[CYR:тема] маtoроwithоin ([CYR:Чешуя] Ⲙ)

### Вwith[CYR:троенные] маtoроwithы

| Сandмinол | Маtoроwith | Опandwithанandе |
|--------|--------|----------|
| @Ⲇ | derive | Аin[CYR:тоге]not[CYR:рац]andя trait [CYR:реал]and[CYR:зац]andй |
| @Ⲣ | route | HTTP [CYR:маршруты] |
| @Ⲧ | test | Теwithтоinые [CYR:фун]toцandand |
| @Ⲕ | cache | [CYR:Кэш]andроinанandе resultоin |
| @Ⲃ | validate | [CYR:Вал]and[CYR:дац]andя fieldй |

### [CYR:Процедурные] маtoроwithы

| Маtoроwith | Опandwithанandе |
|--------|----------|
| `sql!()` | SQL [CYR:запро]withы with [CYR:про]inерtoой on stageе to[CYR:омп]and[CYR:ляц]andand |
| `html!()` | HTML [CYR:шаблоны] with and[CYR:нтер]fieldsцandей |
| `json!()` | JSON лand[CYR:тералы] |
| `regex!()` | [CYR:Комп]and[CYR:ляц]andя regex on stageе to[CYR:омп]and[CYR:ляц]andand |
| `format!()` | [CYR:Формат]andроinанandе with[CYR:тро]to |
| `include!()` | Вto[CYR:лючен]andе fileоin |
| `env!()` | [CYR:Переменные] оto[CYR:ружен]andя |
| `cfg!()` | Уwithлоinonя to[CYR:омп]and[CYR:ляц]andя |

### Derive [CYR:трейты]

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

### Прand[CYR:мер] andwith[CYR:пользо]inанandя

```
// [CYR:Без] маtoроwithоin: ~50 with[CYR:тро]to boilerplate
// С маtoроwithамand: 5 with[CYR:тро]to

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

## [CYR:Сра]innotнandе inерwithandй

| [CYR:Вер]withandя | [CYR:Язы]to | [CYR:Стро]to | [CYR:Компо]not[CYR:нты] | [CYR:Опт]andмand[CYR:зац]andя | Маtoроwithы |
|--------|------|-------|------------|-------------|---------|
| v0 | Zig | ~2630 | 3 [CYR:голо]inы | [CYR:Нет] | [CYR:Нет] |
| v1 | .vibee | ~1054 | 3 [CYR:голо]inы | [CYR:Нет] | [CYR:Нет] |
| v2 | .999 | 790 | 3 [CYR:голо]inы + хinоwithт | 5 [CYR:проходо]in | [CYR:Нет] |
| v3 | .999 | 1913 | 3 [CYR:голо]inы + [CYR:чешуя] + хinоwithт | 5 [CYR:проходо]in | 15+ маtoроwithоin |

### [CYR:Сжат]andе to[CYR:ода]

```
v0 (Zig)   ████████████████████████████ 2630 with[CYR:тро]to
v1 (vibee) ██████████ 1054 with[CYR:тро]to (-60%)
v2 (999)   ███████ 790 with[CYR:тро]to (-70%)
v3 (999)   ███████████████ 1913 with[CYR:тро]to (with маtoроwithамand)
```

### Соto[CYR:ращен]andе boilerplate

```
[CYR:Без] маtoроwithоin: ~100 with[CYR:тро]to on entity + routes
С маtoроwithамand:  ~10 with[CYR:тро]to
Соto[CYR:ращен]andе:   10x
```

## Иwith[CYR:пользо]inанandе

```bash
# [CYR:Комп]and[CYR:ляц]andя with [CYR:опт]andмand[CYR:зац]andей по [CYR:умолчан]andю (-O3)
./gorynych program.999

# [CYR:Без] [CYR:опт]andмand[CYR:зац]andand
./gorynych -O0 program.999

# Маtowithand[CYR:маль]onя [CYR:опт]andмand[CYR:зац]andя
./gorynych -O9 program.999

# Геnot[CYR:рац]andя in [CYR:разные] [CYR:цел]and
./gorynych --zig program.999
./gorynych --wasm program.999
./gorynych --python program.999
```

## [CYR:Файлы]

```
src/999/
├── gorynych.999      # [CYR:Гла]in[CYR:ный] to[CYR:омп]and[CYR:лятор] (325 with[CYR:тро]to)
├── makrosy.999       # Деto[CYR:ларат]andin[CYR:ные] маtoроwithы (423 with[CYR:тро]toand)
├── proc_makrosy.999  # [CYR:Процедурные] маtoроwithы (364 with[CYR:тро]toand)
├── gigiena.999       # Гandгandенandчеwithtoandе маtoроwithы (279 with[CYR:тро]to)
├── hvost.999         # Хinоwithт — IR (92 with[CYR:тро]toand)
├── prohody.999       # [CYR:Проходы] [CYR:опт]andмand[CYR:зац]andand (182 with[CYR:тро]toand)
└── tipy.999          # Сandwith[CYR:тема] тandпоin (248 with[CYR:тро]to)
```

## Creation Pattern

```
Source → Transformer → Result

Ⲥ → Ⲅ → [ⲨⲀ]     # Леtowithер
[ⲨⲀ] → Ⲋ → ⲨⲂ    # [CYR:Пар]withер
ⲨⲂ → Ⲭ → ⲨⲄ      # [CYR:Опт]andмand[CYR:затор] ([CYR:НОВОЕ]!)
ⲨⲄ → Ⲑ → Ⲥ       # [CYR:Кодоген]
```
