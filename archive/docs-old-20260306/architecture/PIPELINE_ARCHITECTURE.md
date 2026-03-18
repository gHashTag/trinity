# VIBEE Pipeline Architecture

## Why are we doing this?

### Traditional approach problem

```
Traditional approach:
Programmer → writes code → tests → bugs → fixes → repeat

Problems:
1. Code is written without formal specification
2. Tests are written after code (or not written at all)
3. No single source of truth
4. Difficult to generate code for different languages
5. No scientific basis for improvements
```

### Solution: Specification-First Development

```
VIBEE approach:
Specification → Compiler → Code + Tests (automatically)

Advantages:
1. Specification = single source of truth
2. Tests are generated from behaviors
3. Code is generated for any language
4. PAS DAEMONS predict improvements
5. Scientific basis (12 papers, 150K citations)
```

---

## Current Pipeline (v35)

### Problem: Manual code in zig_output

```yaml
# specs/tri/example.vibee

name: example
types:
  - name: User
    fields:
      - name: id
        type: Int

# PROBLEM: Code is written manually!
zig_output: """
pub const User = struct {
    id: i64,  // ← This is handwritten
};
"""
```

### Why this is bad:

1. **Duplication** - types described twice (in spec and in code)
2. **Desynchronization** - spec and code can diverge
3. **Manual work** - violates the idea of autogeneration
4. **Errors** - human can make mistakes in code

---

## Target Pipeline (v36+)

### Solution: Automatic generation

```yaml
# specs/tri/example.vibee

name: example
version: "1.0.0"
language: zig

types:
  - name: User
    fields:
      - name: id
        type: Int
      - name: name
        type: String
      - name: email
        type: String

behaviors:
  - name: create_user
    given: "Valid user data"
    when: "create_user is called"
    then: "Return new User"
    test_cases:
      - name: test_create_valid
        input: '{"id": 1, "name": "John"}'
        expected: '{"id": 1}'

# NO zig_output - code is generated automatically!
```

### Compiler generates:

```zig
// AUTOMATICALLY GENERATED from example.vibee

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;

// From types:
pub const User = struct {
    id: i64,
    name: []const u8,
    email: []const u8,
};

// From behaviors:
pub fn create_user(id: i64, name: []const u8, email: []const u8) User {
    return User{
        .id = id,
        .name = name,
        .email = email,
    };
}

// From test_cases:
test "test_create_valid" {
    const user = create_user(1, "John", "john@example.com");
    try std.testing.expectEqual(@as(i64, 1), user.id);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), phi_sq + 1.0/phi_sq, 0.0001);
}
```

---

## Compiler architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    VIBEEC COMPILER                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   PARSER    │ →  │  ANALYZER   │ →  │  CODEGEN    │     │
│  │             │    │             │    │             │     │
│  │ YAML → AST  │    │ Type Check  │    │ AST → Code  │     │
│  │             │    │ Validate    │    │             │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│         ↓                  ↓                  ↓             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    CODE TEMPLATES                    │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │  Zig    │ Python │  Go   │ Rust  │  TS   │ Gleam   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Compilation stages:

1. **Parser** - reads .vibee, builds AST
2. **Analyzer** - type checks, validates
3. **CodeGen** - generates code for target language

---

## Type Mapping

| VIBEE Type | Zig | Python | Go | Rust | TypeScript |
|------------|-----|--------|-----|------|------------|
| String | `[]const u8` | `str` | `string` | `String` | `string` |
| Int | `i64` | `int` | `int64` | `i64` | `number` |
| Float | `f64` | `float` | `float64` | `f64` | `number` |
| Bool | `bool` | `bool` | `bool` | `bool` | `boolean` |
| List<T> | `[]T` | `list[T]` | `[]T` | `Vec<T>` | `T[]` |
| Option<T> | `?T` | `Optional[T]` | `*T` | `Option<T>` | `T \| null` |

---

## Behavior → Function Mapping

```yaml
# Specification
behaviors:
  - name: calculate_total
    given: "List of prices"
    when: "calculate_total is called"
    then: "Return sum of prices"
    params:
      - name: prices
        type: List<Float>
    returns: Float
```

### Generated:

**Zig:**
```zig
pub fn calculate_total(prices: []const f64) f64 {
    var total: f64 = 0;
    for (prices) |price| {
        total += price;
    }
    return total;
}
```

**Python:**
```python
def calculate_total(prices: list[float]) -> float:
    return sum(prices)
```

**Go:**
```go
func CalculateTotal(prices []float64) float64 {
    var total float64
    for _, price := range prices {
        total += price
    }
    return total
}
```

---

## Test Generation

```yaml
# Specification
test_cases:
  - name: test_empty_list
    input: '{"prices": []}'
    expected: '0.0'
  
  - name: test_single_item
    input: '{"prices": [10.0]}'
    expected: '10.0'
  
  - name: test_multiple_items
    input: '{"prices": [10.0, 20.0, 30.0]}'
    expected: '60.0'
```

### Generated:

```zig
test "test_empty_list" {
    const result = calculate_total(&[_]f64{});
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), result, 0.0001);
}

test "test_single_item" {
    const result = calculate_total(&[_]f64{10.0});
    try std.testing.expectApproxEqAbs(@as(f64, 10.0), result, 0.0001);
}

test "test_multiple_items" {
    const result = calculate_total(&[_]f64{10.0, 20.0, 30.0});
    try std.testing.expectApproxEqAbs(@as(f64, 60.0), result, 0.0001);
}
```

---

## PAS DAEMONS Integration

### Automatic algorithm analysis:

```yaml
behaviors:
  - name: search_item
    given: "Sorted list and target"
    when: "search_item is called"
    then: "Return index or -1"
    
    # PAS automatically determines:
    pas_analysis:
      current_complexity: O(n)      # Linear search
      optimal_complexity: O(log n)  # Binary search
      applicable_patterns:
        - D&C: 0.85  # Divide-and-Conquer fits
        - PRE: 0.20  # Precomputation less applicable
      recommendation: "Use binary search (D&C pattern)"
```

---

## Roadmap

### v36: Basic Auto-Generation
- [ ] Generate structs from types
- [ ] Generate functions from behaviors
- [ ] Generate tests from test_cases

### v37: Multi-Language
- [ ] Python codegen
- [ ] Go codegen
- [ ] Rust codegen

### v38: PAS Integration
- [ ] Automatic complexity analysis
- [ ] Optimization recommendations
- [ ] Pattern application

### v39: Full Pipeline
- [ ] IDE integration
- [ ] Hot reload
- [ ] Incremental compilation

---

## Commands

```bash
# Current (manual)
./bin/tri-extract specs/tri/example.vibee

# Target (automatic)
vibeec compile specs/tri/example.vibee --target zig
vibeec compile specs/tri/example.vibee --target python
vibeec compile specs/tri/example.vibee --target go
```

---

## Conclusion

**Why this is important:**

1. **Single source of truth** - specification determines everything
2. **Automation** - code is generated, not written
3. **Multilingual** - one spec → many languages
4. **Testability** - tests from specification
5. **Scientific basis** - PAS predicts improvements

```
φ² + 1/φ² = 3

Specification → Compiler → Code
Known → PAS → Predicted
```
