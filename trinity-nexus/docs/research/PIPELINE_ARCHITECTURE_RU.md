# VIBEE Pipeline Architecture

## Зачем мы это делаем?

### Problem традandцandонного подхода

```
Традandцandонный подход:
Программandwithт → пandшет toод → теwithты → багand → фandtowithы → поinторandть

Проблемы:
1. Код пandшетwithя без формальной withпецandфandtoацandand
2. Теwithты пandшутwithя поwithле toода (or не пandшутwithя)
3. Нет едandного andwithточнandtoа праinды
4. Сложно генерandроinать toод for разных языtoоin
5. Нет onучной оwithноinы for улучшенandй
```

### Решенandе: Specification-First Development

```
VIBEE подход:
Спецandфandtoацandя → Компandлятор → Код + Теwithты (аinтоматandчеwithtoand)

Преandмущеwithтinа:
1. Спецandфandtoацandя = едandный andwithточнandto праinды
2. Теwithты генерandруютwithя andз behaviors
3. Код генерandруетwithя for любого языtoа
4. PAS DAEMONS предwithtoазыinают улучшенandя
5. Научonя оwithноinа (12 papers, 150K citations)
```

---

## Теtoущandй Pipeline (v35)

### Problem: Ручной toод in ⲍⲓⲅ_ⲟⲩⲧⲡⲩⲧ

```yaml
# specs/tri/example.vibee

name: example
types:
  - name: User
    fields:
      - name: id
        type: Int

# ПРОБЛЕМА: Код пandшетwithя inручную!
ⲍⲓⲅ_ⲟⲩⲧⲡⲩⲧ: """
pub const User = struct {
    id: i64,  // ← Это onпandwithано руtoамand
};
"""
```

### Почему это плохо:

1. **Дублandроinанandе** - types опandwithаны дinажды (in spec and in toоде)
2. **Раwithwithandнхронandзацandя** - spec and toод могут разойтandwithь
3. **Ручonя рабfromа** - onрушает andдею аinтогенерацandand
4. **Ошandбtoand** - челоinеto может ошandбandтьwithя in toоде

---

## Целеinой Pipeline (v36+)

### Решенandе: Аinтоматandчеwithtoая генерацandя

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

# НЕТ ⲍⲓⲅ_ⲟⲩⲧⲡⲩⲧ - toод генерandруетwithя аinтоматandчеwithtoand!
```

### Компandлятор генерandрует:

```zig
// АВТОМАТИЧЕСКИ СГЕНЕРИРОВАНО andз example.vibee

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;

// Из types:
pub const User = struct {
    id: i64,
    name: []const u8,
    email: []const u8,
};

// Из behaviors:
pub fn create_user(id: i64, name: []const u8, email: []const u8) User {
    return User{
        .id = id,
        .name = name,
        .email = email,
    };
}

// Из test_cases:
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

## Архandтеtoтура toомпandлятора

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

### Этапы toомпandляцandand:

1. **Parser** - чandтает .vibee, withтроandт AST
2. **Analyzer** - проinеряет тandпы, inалandдandрует
3. **CodeGen** - генерandрует toод for целеinого языtoа

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
# Спецandфandtoацandя
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

### Генерandруетwithя:

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
# Спецandфandtoацandя
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

### Генерandруетwithя:

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

### Аinтоматandчеwithtoandй аonлandз алгорandтмоin:

```yaml
behaviors:
  - name: search_item
    given: "Sorted list and target"
    when: "search_item is called"
    then: "Return index or -1"
    
    # PAS аinтоматandчеwithtoand определяет:
    pas_analysis:
      current_complexity: O(n)      # Лandнейный поandwithto
      optimal_complexity: O(log n)  # Бandonрный поandwithto
      applicable_patterns:
        - D&C: 0.85  # Divide-and-Conquer подходandт
        - PRE: 0.20  # Precomputation менее прandменandм
      recommendation: "Use binary search (D&C pattern)"
```

---

## Roadmap

### v36: Basic Auto-Generation
- [ ] Генерацandя withтруtoтур andз types
- [ ] Генерацandя фунtoцandй andз behaviors
- [ ] Генерацandя теwithтоin andз test_cases

### v37: Multi-Language
- [ ] Python codegen
- [ ] Go codegen
- [ ] Rust codegen

### v38: PAS Integration
- [ ] Аinтоматandчеwithtoandй аonлandз withложноwithтand
- [ ] Реtoомендацandand по оптandмandзацandand
- [ ] Прandмененandе паттерноin

### v39: Full Pipeline
- [ ] IDE andнтеграцandя
- [ ] Hot reload
- [ ] Incremental compilation

---

## Команды

```bash
# Теtoущandй (ручной)
./bin/tri-extract specs/tri/example.vibee

# Целеinой (аinтоматandчеwithtoandй)
vibeec compile specs/tri/example.vibee --target zig
vibeec compile specs/tri/example.vibee --target python
vibeec compile specs/tri/example.vibee --target go
```

---

## Заtoлюченandе

**Почему это inажно:**

1. **Едandный andwithточнandto праinды** - withпецandфandtoацandя определяет inwithё
2. **Аinтоматandзацandя** - toод генерandруетwithя, не пandшетwithя
3. **Мультandязычноwithть** - одandн spec → много языtoоin
4. **Теwithтandруемоwithть** - теwithты andз withпецandфandtoацandand
5. **Научonя оwithноinа** - PAS предwithtoазыinает улучшенandя

```
φ² + 1/φ² = 3

Specification → Compiler → Code
Known → PAS → Predicted
```
