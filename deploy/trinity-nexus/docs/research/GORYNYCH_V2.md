# Zmey Gorynych v3 — Compiler 999 with Macros

## Architecture

```
                    ZMEY GORYNYCH v3
                    
     ┌─────┐   ┌─────┐   ┌─────┐
     │  Ⲅ  │   │  Ⲋ  │   │  Ⲑ  │
     │lexer│   │parser│   │codegen│
     └──┬──┘   └──┬──┘   └──┬──┘
        │         │         │
        └────┬────┴────┬────┘
             │    Ⲙ    │
          ┌──┴─────────┴──┐
          │    CHESHUYA      │
          │  (macros)    │
          └───────┬───────┘
                  │
          ┌───────┴───────┐
          │      Ⲭ        │
          │   HVOST       │
          │ (optimizer) │
          └───────────────┘
```

## Compilation flow

```
Source → Ⲅ → Tokens → Ⲋ → AST → Ⲙ → AST' → Ⲭ → IR → Ⲑ → Code
   Ⲥ           [ⲨⲀ]          ⲨⲂ       ⲨⲂ'      ⲨⲄ       Ⲥ
```

## Components

| Symbol | Component | File | Lines |
|--------|-----------|------|-------|
| Ⲅ | Lexer | gorynych.999 | — |
| Ⲋ | Parser | gorynych.999 | — |
| Ⲙ | Macros | makrosy.999 + proc_makrosy.999 + gigiena.999 | 1112 |
| Ⲭ | Optimizer | hvost.999 + prohody.999 | 274 |
| Ⲑ | Codegen | gorynych.999 | — |
| — | Types | tipy.999 | 248 |
| — | Main | gorynych.999 | 325 |
| **Σ** | **Total** | **7 files** | **1913** |

## Khvost (Optimizer)

### Optimization levels

| Flag | Level | Passes |
|------|-------|---------|
| -O0 | 0 | No optimizations |
| -O1 | 1 | DCE |
| -O2 | 2 | DCE, CF |
| -O3 | 3 | DCE, CF, CP |
| -O4 | 4 | DCE, CF, CP, CSE |
| -O5 | 5 | DCE, CF, CP, CSE, INL |
| -O9 | 9 | Maximum (multi-pass) |

### Optimization passes

| Symbol | Pass | Description |
|--------|------|-------------|
| Ⲁ | DCE | Dead code elimination |
| Ⲃ | CF | Constant folding |
| Ⲅ | CP | Copy propagation |
| Ⲇ | CSE | Common subexpression elimination |
| Ⲉ | INL | Function inlining |

### Optimization example

**Before (AST):**
```
Ⲙ x = 3 + 4
Ⲙ y = x * 2
Ⲙ z = 10
Ⲣ y
```

**After (IR, -O3):**
```
LOAD 14, r0    // 3+4=7, 7*2=14 — folded
RET r0         // z deleted (dead code)
```

## Type system

### Base types

| Symbol | Type | Description |
|--------|------|-------------|
| Ⲋ | number | 27-nary integer |
| Ⲥ | word | String |
| Ⲧ | ternary | Ⲁ/Ⲃ/Ⲯ |
| Ⲩ | structure | Composite type |
| Ⲫ | action | Function |
| Ⲭ | void | void |
| Ⲯ | unknown | unknown |

### Ternary logic

```
Ⲁ — true
Ⲃ — false
Ⲯ — unknown
```

**AND table (&&):**
```
    Ⲁ  Ⲃ  Ⲯ
Ⲁ   Ⲁ  Ⲃ  Ⲯ
Ⲃ   Ⲃ  Ⲃ  Ⲃ
Ⲯ   Ⲯ  Ⲃ  Ⲯ
```

**OR table (||):**
```
    Ⲁ  Ⲃ  Ⲯ
Ⲁ   Ⲁ  Ⲁ  Ⲁ
Ⲃ   Ⲁ  Ⲃ  Ⲯ
Ⲯ   Ⲁ  Ⲯ  Ⲯ
```

## Macro system (Cheshuya Ⲙ)

### Built-in macros

| Symbol | Macro | Description |
|--------|-------|-------------|
| @Ⲇ | derive | Auto-generate trait implementations |
| @Ⲣ | route | HTTP routes |
| @Ⲧ | test | Test functions |
| @Ⲕ | cache | Cache results |
| @Ⲃ | validate | Field validation |

### Procedural macros

| Macro | Description |
|--------|-------------|
| `sql!()` | SQL queries with compile-time verification |
| `html!()` | HTML templates with interpolation |
| `json!()` | JSON literals |
| `regex!()` | Compile-time regex compilation |
| `format!()` | String formatting |
| `include!()` | File inclusion |
| `env!()` | Environment variables |
| `cfg!()` | Conditional compilation |

### Derive traits

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

### Usage example

```
// Without macros: ~50 lines of boilerplate
// With macros: 5 lines

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

## Version comparison

| Version | Language | Lines | Components | Optimization | Macros |
|---------|----------|-------|------------|---------------|---------|
| v0 | Zig | ~2630 | 3 heads | No | No |
| v1 | .vibee | ~1054 | 3 heads | No | No |
| v2 | .999 | 790 | 3 heads + tail | 5 passes | No |
| v3 | .999 | 1913 | 3 heads + scales + tail | 5 passes | 15+ macros |

### Code compression

```
v0 (Zig)   ████████████████████████████ 2630 lines
v1 (vibee) ██████████ 1054 lines (-60%)
v2 (999)   ███████ 790 lines (-70%)
v3 (999)   ███████████████ 1913 lines (with macros)
```

### Boilerplate reduction

```
Without macros: ~100 lines per entity + routes
With macros:     ~10 lines
Reduction:       10x
```

## Usage

```bash
# Compile with default optimization (-O3)
./gorynych program.999

# No optimization
./gorynych -O0 program.999

# Maximum optimization
./gorynych -O9 program.999

# Generate to different targets
./gorynych --zig program.999
./gorynych --wasm program.999
./gorynych --python program.999
```

## Files

```
src/999/
├── gorynych.999      # Main compiler (325 lines)
├── makrosy.999       # Declarative macros (423 lines)
├── proc_makrosy.999  # Procedural macros (364 lines)
├── gigiena.999       # Hygienic macros (279 lines)
├── hvost.999         # Khvost — IR (92 lines)
├── prohody.999       # Optimization passes (182 lines)
└── tipy.999          # Type system (248 lines)
```

## Creation Pattern

```
Source → Transformer → Result

Ⲥ → Ⲅ → [ⲨⲀ]     # Lexer
[ⲨⲀ] → Ⲋ → ⲨⲂ    # Parser
ⲨⲂ → Ⲭ → ⲨⲄ      # Optimizer (NEW!)
ⲨⲄ → Ⲑ → Ⲥ       # Codegen
```
