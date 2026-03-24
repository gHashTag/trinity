# No TTT Touch — Защита Священного Слоя

## Правило

**TTT (Trusted Tri Temple) — священный слой L0. Запрещено модифицировать файлы `src/temple/**` без ритуала TEMPLE_RITUAL.**

## Forbidden Zone

```
src/temple/**  —  ЗАПРЕЩЁНО для обычных агентов
```

Любые изменения в `src/temple/` требуют специального ритуала.

## Когда можно менять TTT

Только когда:
1. Установлен флаг окружения `TEMPLE_RITUAL=1`
2. Задача имеет ярлык `TEMPLE_RITUAL`
3. Изменения верифицированы: `zig build temple` → `zig build temple test`
4. Коммит содержит `#TEMPLE_RITUAL`

## Ритуал изменения TTT

```bash
# 1. Установить флаг ритуала
export TEMPLE_RITUAL=1

# 2. Внести изменения в src/temple/

# 3. Верифицировать
zig build temple
zig build temple test

# 4. Закоммитить
git add src/temple/
git commit -m "feat(temple): описание изменений #TEMPLE_RITUAL"
```

## Что делать вместо изменения TTT

Если нужно изменить sacred math или TRI-27 core:
1. Создать issue с ярлыком `TEMPLE_RITUAL`
2. Явно указать, что изменяется TTT
3. Пройти ритуал: `zig build temple` → `zig test temple` → коммит

## Enforcement

- **PreToolUse hook** блокирует запись в `src/temple/**` без `TEMPLE_RITUAL`
- Агенты видят это правило в `.claude/rules/`
- CI проверяет наличие `#TEMPLE_RITUAL` в коммитах, затрагивающих TTT

## Структура TTT

```
src/temple/
├── sacred_math.zig   # φ, Trit/Trit27, ternary logic (~250 LOC)
├── tri27_core.zig    # TRI-27 ISA, Memory, Opcodes (~200 LOC)
├── tri_lang_core.zig # Result, Patterns, Linear, Effects (~400 LOC)
├── tests.zig         # Самодостаточные unit-тесты (~500 LOC)
└── README.md         # Документация TTT
```

**Total: ~900 LOC код + ~500 LOC тестов (≤3000 LOC инвариант соблюдён ✓)**

## TTT Маркер

Каждый файл TTT начинается с:

```zig
// TTT — Trusted Tri Temple — L0 Sacred Layer
// DO NOT MODIFY without TEMPLE_RITUAL
// Re-exports from: <source files>
//
// φ² + 1/φ² = 3 | TRINITY
```

## Источник

TTT следует DRY принципу — все типы и функции re-export из существующих источников:
- `sacred_math.zig` → `src/b2t/trit.zig`, `src/ternary/logic.zig`, `src/vm/jit.zig`
- `tri27_core.zig` → `src/tri27/emu/*.zig`, `src/vm/opcodes.zig`
- `tri_lang_core.zig` → `src/tri-lang/result_type.zig`, `src/tri-lang/bit_trit_patterns.zig`, `src/tri-lang/linear_types.zig`, `src/tri-lang/effects.zig`

---

**Помни**: TTT — это ДНК Trinity. Меняй только через ритуал. 🐍⚡
