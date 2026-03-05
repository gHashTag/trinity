---
sidebar_position: 1
sidebar_label: VSA Operations
---

# VSA Operations Cheat Sheet

**Быстрая справка по операциям Vector Symbolic Architecture**

---

## Core Operations Quick Reference

```mermaid
graph TB
    subgraph "VSA Core"
        BIND[bind<br/>a ⊗ b]
        BUNDLE[bundle<br/>a ⊕ b]
        PERM[permute<br/>rotate v,k]
        SIM[similarity<br/>cosine a,b]
    end

    BIND --> SIM
    BUNDLE --> SIM

    style BIND fill:#e1f5ff
    style BUNDLE fill:#fff9c4
    style SIM fill:#c8e6c9
```

## Operation Summary

| Operation | Symbol | Zig Function | Complexity | Use Case |
|-----------|--------|--------------|------------|----------|
| **Bind** | `⊗` | `vsa.bind(a, b)` | O(n) | Ассоциация |
| **Unbind** | `⊗⁻¹` | `vsa.unbind(bound, key)` | O(n) | Извлечение |
| **Bundle** | `⊕` | `vsa.bundle2(a, b)` | O(n) | Комбинация |
| **Permute** | `ρ` | `vsa.permute(v, k)` | O(n) | Последовательности |
| **Similarity** | `sim` | `vsa.cosineSimilarity(a, b)` | O(n) | Сравнение |

---

## Bind (Ассоциация)

**Создаёт связь между двумя векторами**

```zig
// Создать ассоциацию: cat IS-AN animal
const cat_animal = vsa.bind(&cat, &animal);

// Извлечь: что связано с cat?
const query = vsa.unbind(&cat_animal, &cat);
// query ~ animal
```

**Свойства:**
- Коммутативен: `a ⊗ b = b ⊗ a`
- Самоинверсен: `a ⊗ a = [1,1,1,...]`
- Обратим: `(a ⊗ b) ⊗ b = a`

**Использование:** Хранение пар ключ-значение, ассоциативная память

---

## Bundle (Комбинация)

**Объединяет несколько векторов**

```zig
// Объединить два вектора
const combined = vsa.bundle2(&a, &b);

// Объединить три вектора
const triple = vsa.bundle3(&a, &b, &c);
```

**Свойства:**
- Результат похож на оба входа
- `sim(bundle(a,b), a) > 0`
- `sim(bundle(a,b), b) > 0`
- Идемпотентен: `bundle(a,a) ≈ a`

**Использование:** Множества, накопление признаков

---

## Similarity (Сходство)

**Измеряет похожесть векторов**

```zig
const sim = vsa.cosineSimilarity(&a, &b);
// Результат: [-1, 1]
//   1.0  = идентичны
//   0.0  = ортогональны (не связаны)
//  -1.0  = противоположны
```

**Таблица интерпретации:**

| Similarity | Значение |
|------------|----------|
| > 0.8 | Сильное совпадение |
| 0.5 - 0.8 | Хорошее совпадение |
| 0.3 - 0.5 | Слабое совпадение |
| < 0.3 | Не связаны |

---

## Permute (Пермутация)

**Циклический сдвиг для кодирования позиции**

```zig
// Сдвиг вправо на 3 позиции
const shifted = vsa.permute(&v, 3);

// Обратный сдвиг
const restored = vsa.inversePermute(&shifted, 3);
```

**Использование:** Кодирование последовательностей, позиционная информация

---

## Common Patterns

### 1. Symbol Encoding

```zig
// Encode symbol as random vector
const symbol = vsa.HybridBigInt.random(allocator, 1000, seed);

// Encode pair: symbol1 + symbol2
const pair = vsa.bind(&symbol1, &symbol2);
```

### 2. Set Representation

```zig
// Create set from multiple elements
const set = vsa.bundle2(&elem1, &elem2);
const larger_set = vsa.bundle3(&set, &elem3, &elem4);
```

### 3. Sequence Encoding

```zig
// Encode sequence: [A, B, C]
const encoded = vsa.bundle3(
    &vsa.permute(&vecA, 0),
    &vsa.permute(&vecB, 1),
    &vsa.permute(&vecC, 2)
);
```

---

## Performance Notes

| Операция | 1000-dim | 10000-dim |
|----------|----------|------------|
| bind | ~0.1ms | ~1ms |
| bundle2 | ~0.1ms | ~1ms |
| cosineSimilarity | ~0.05ms | ~0.5ms |
| permute | ~0.05ms | ~0.5ms |

---

## CLI Commands

```bash
# Create random vector
tri vsa-random 1000

# Compute similarity
tri vsa-sim vec1 vec2

# Bind operation
tri vsa-bind a b

# Full VSA demo
tri agents-demo
```

---

## See Also

- [VSA API Reference](/api/vsa)
- [SDK API](/api/sdk)
- [VSA Operations Tutorial](/tutorials/vsa-operations)
- [HybridBigInt Storage](/api/hybrid)

---

**φ² + 1/φ² = 3 = TRINITY**
