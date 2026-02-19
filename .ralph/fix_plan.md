# CODEGEN-001: VIBEE Real Codegen (заглушки → рабочий код)

**Приоритет:** ВЫСОКИЙ
**Ветка:** `vibee-real-codegen-v1`
**Статус:** IN_PROGRESS
**Дата:** 2026-02-19

## Acceptance Criteria

- [ ] `implementation:` field из .vibee вставляется как полная функция (с сигнатурой)
- [ ] Тестовая спека `test_implementation.vibee` с реальным кодом компилируется
- [ ] 31 заглушка в patterns/*.zig заменена реальным кодом (19% → 46%)
- [ ] tests_gen.zig генерирует assertions из test_cases, не `@TypeOf`
- [ ] Fallback `"implemented"` заменён на `@compileError`
- [ ] 3 спеки аудита + 1 новая: `zig build vibee -- gen ... && zig test generated/...`
- [ ] CLAUDE.md и TECH_TREE обновлены

## Задачи

### Phase B: implementation field (emitter.zig)
- [ ] B.1: Изменить `generateBehaviorImplementation()` — поддержка полных функций
  - Файл: `trinity-nexus/lang/src/codegen/emitter.zig:1399-1455`
  - Если `implementation` содержит `pub fn` → вставить как есть
  - Если body only → обернуть в сгенерированную сигнатуру
- [ ] B.2: Создать `specs/tri/test_implementation.vibee` с vec3_add, vec3_dot
- [ ] B.3: Верификация: gen → test → pass

### Phase C: Реальные паттерны (patterns/*.zig)
- [ ] C.1: vsa.zig — 6 заглушек: random, ones, zeros, distance, analogy, vector
- [ ] C.2: ml.zig — 5 ключевых: softmax, layer_norm, embed, loss, attention
- [ ] C.3: data.zig — 4 ключевых: quantize, normalize, encode, decode
- [ ] C.4: io.zig — 2 ключевых: read, write (через std.fs)
- [ ] C.5: lifecycle.zig — 3 ключевых: start, stop, shutdown
- [ ] После каждого: `cd trinity-nexus/lang && zig build test`

### Phase D: Реальные тесты (tests_gen.zig)
- [ ] D.1: Генерация из test_cases → реальные assertions
- [ ] D.2: Fallback: вызов функции вместо `@TypeOf`
  - Файл: `trinity-nexus/lang/src/codegen/tests_gen.zig:3325-3336`

### Phase E: generateRealBody + docs
- [ ] E.1: Заменить `"implemented"` на `@compileError("not implemented")`
  - Файл: `trinity-nexus/lang/src/codegen/emitter.zig:1769`
- [ ] E.2: CLAUDE.md — обновить статус VIBEE codegen
- [ ] E.3: TECH_TREE.md — добавить узел CODEGEN-001

## Метрики

| Метрика | До | Цель |
|---------|:--:|:----:|
| Реальных паттернов | 21/112 (19%) | 52/112 (46%) |
| Тесты с assertions | 0% | 100% (где есть test_cases) |
| Заглушек "implemented" | 91 | 0 |
| E2E passing | 3 (fake) | 4 (real) |

## Критические файлы

| Файл | Строки | Действие |
|------|--------|----------|
| `trinity-nexus/lang/src/codegen/emitter.zig` | 1399-1455, 1769 | implementation + fallback |
| `trinity-nexus/lang/src/codegen/patterns/ml.zig` | 20-302 | 5 реализаций |
| `trinity-nexus/lang/src/codegen/patterns/vsa.zig` | 140-219 | 6 реализаций |
| `trinity-nexus/lang/src/codegen/patterns/data.zig` | 20-300 | 4 реализации |
| `trinity-nexus/lang/src/codegen/patterns/io.zig` | 20-257 | 2 реализации |
| `trinity-nexus/lang/src/codegen/patterns/lifecycle.zig` | 46-215 | 3 реализации |
| `trinity-nexus/lang/src/codegen/tests_gen.zig` | 3325-3336 | assertions |
