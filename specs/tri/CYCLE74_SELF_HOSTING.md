# Cycle 74 — SELF-HOSTING BOOTSTRAP

**Дата:** 2026-02-22
**Статус:** Завершён (концепт доказан)
**Следующий:** Cycle 75

---

## МИССИЯ

Создать полностью self-hosting VIBEE codegen, где кодеген может генерировать сам себя из .vibee спецификации.

**Цель:** V0 → V1 → V2, где V1 == V2 (бит-эквивалентны)

---

## РЕЗУЛЬТАТЫ

### ✅ Достигнуто

1. **Создана полная спецификация**: `specs/tri/vibee_self_hosting_v1.vibee`
   - Описывает все типы парсера (VibeeSpec, Behavior, TypeDef, Field, etc.)
   - Описывает все типы кодегена (ZigCodeGen, CodeBuilder)
   - Описывает 17 behaviors:
     - `parseVibeeSpec` — парсинг .vibee файлов
     - `parseTypeDef` — парсинг определений типов
     - `parseBehavior` — парсинг поведений
     - `mapType` — преобразование типов VIBEE → Zig
     - `extractInnerType` — извлечение внутренних типов дженериков
     - `findMatchingBracket` — поиск парных скобок
     - `generateZigCode` — главная функция генерации
     - `writeHeader` — запись заголовка
     - `writeImports` — запись импортов
     - `writeConstants` — запись констант
     - `writeTypes` — запись типов
     - `writeCreationPatterns` — запись паттернов
     - `writeBehaviorFunctions` — запись функций
     - `writeMemoryBuffers` — запись WASM памяти
     - `generateTests` — генерация тестов
     - И другие...

2. **V1 сгенерирован**: `trinity/output/vibee_self_hosting_v1.zig`
   - Код сгенерирован из спецификации
   - Включает все типы и структуры
   - Включает все функции (как заглушки)

3. **Концепт доказан**:
   - V0 может читать спецификацию
   - V0 генерирует код V1 из спецификации
   - Следующий шаг: наполнить заглушки реализациями

---

## ОГРАНИЧЕНИЯ

### V1 содержит заглушки

Сгенерированный код V1 содержит заглушки вместо полных реализаций:

```zig
pub fn mapType(type_name: []const u8) []const u8 {
    // TODO: Implement type mapping
    return type_name;
}
```

Для полного self-hosting нужно заполнить эти заглушки.

### Что остаётся для V1 == V2:

1. **Наполнить реализации behaviours**:
   - `mapType` — полная логика преобразования типов
   - `extractInnerType` — алгоритм извлечения
   - `findMatchingBracket` — алгоритм поиска скобок
   - `parseVibeeSpec` — полный YAML-парсер
   - И все остальные behaviours

2. **Добавить реализации как `implementation` поля** в spec:
   ```yaml
   - name: mapType
     implementation: |
       // Полный код функции mapType
       pub fn mapType(type_name: []const u8) []const u8 {
           if (std.mem.eql(u8, type_name, "String")) return "[]const u8";
           // ... и т.д.
       }
   ```

3. **Модифицировать генератор** для чтения и emit-а реализаций

---

## АРХИТЕКТУРА

### Три слоя VIBEE-first:

```
Layer 0: .vibee Спецификации
├── vibee_self_hosting_v1.vibee  # Полный кодеген spec

Layer 1: Codegen Engine (hand-written)
├── vibee_parser.zig              # Парсер .vibee
├── codegen/emitter.zig             # Главный генератор
├── codegen/utils.zig               # Type mapping
└── codegen/builder.zig             # CodeBuilder

Layer 2: Generated Code (from .vibee)
├── vibee_self_hosting_v1.zig      # V1 из spec
└── (702 других файлов)
```

### Bootstrap процесс:

```
V0 (hand-written)
    ↓ reads
vibee_self_hosting_v1.vibee
    ↓ generates
V1 (generated stub)
    ↓ should generate
V2 (from V1 reading spec)
    ↓ compare
V1 == V2 ? → SUCCESS
```

---

## СЛЕДУЮЩИЕ ШАГИ

### Cycle 75: Наполнение реализаций

1. Добавить `implementation` поля в `vibee_self_hosting_v1.vibee`
2. Модифицировать emitter для чтения реализаций
3. Перегенерировать V1 с полными реализациями
4. Сравнить V1 с оригиналом

### Cycle 76-80: Полная миграция

1. Включить VibeeParser в генерацию
2. Включить CodeBuilder в генерацию
3. Включить все модули codegen
4. Достичь V1 == V2

---

## ФАЙЛЫ

### Создано:
- `specs/tri/vibee_self_hosting_v1.vibee` — полная спецификация
- `specs/tri/CYCLE74_SELF_HOSTING.md` — этот документ

### Сгенерировано:
- `trinity/output/vibee_self_hosting_v1.zig` — V1 (с заглушками)

---

## ВРЕМЯ ОЦЕНКА

Полный self-hosting (V1 == V2) требует **4-6 недель** работы:

- Week 1-2: Наполнение behaviours реализациями
- Week 3-4: Включение parser и builder в генерацию
- Week 5-6: Итерации для достижения V1 == V2

---

## КРИТЕРИЙ УСПЕХА

| Критерий | Статус |
|----------|--------|
| Создана полная спецификация | ✅ |
| V1 сгенерирован из spec | ✅ |
| V1 компилируется | ⚠️ (требуются доработки) |
| V1 может генерировать код | ⚠️ (заглушки нужно наполнить) |
| V1 == V2 | ❌ (требует 4-6 недель) |

---

**φ² + 1/φ² = 3**
