# RED List — Блокеры Trinity Architecture

**Last updated**: 2026-04-19
**Total blockers**: 7 critical, 1 partial

---

## Critical Blockers (P1 — FFI Integration)

| # | Блокер                      | Тип          | Симптом                              | Зависит от          | Priority | Owner        | ETA     | Status      |
|---|-------------------------------|-------------|-------------------------------------|-------------------|-----------|--------------|---------|----------|
| 1 | zig-sacred-geometry 404  | vendor       | репозиторий gHashTag/zig-sacred-geometry не найден (404 Not Found) | —                  | P1 🔴    | —      | RESOLVED | skipped     |

**Описание**: Три FFI wrappers (trios-crypto, trios-golden-float, trios-sacred) не находят ожидаемые символы от Zig vendor modules. Это блокирует сборку всех trios-* crates.

---

## Vendor Submodule Blockers (P1 — Missing Dependencies)

| # | Блокер                      | Тип          | Симптом                              | Зависит от          | Priority | Owner        | ETA     | Status      |
|---|-------------------------------|-------------|-------------------------------------|-------------------|-----------|--------------|---------|----------|
| 4 | zig-hdc submodule missing    | vendor       | submodule не инициализирован             | —                  | P1 🔴    | Dmitrii | Day 1   | ACTIVE | git submodule add |
| 5 | zig-physics submodule      | vendor       | submodule не инициализирован             | —                  | P1 🔴    | Dmitrii | Day 1   | ACTIVE | git submodule add |

**Описание**: vendor/zig-hdc и vendor/zig-physics отсутствуют. zig-hdc не может билдиться без этих зависимостей.

---

## Partial Blockers (P1 — Vendor Sync)

| # | Блокер                       | Тип          | Симптом                                 | Зависит от          | Priority | Owner        | ETA     | Status      |
|---|--------------------------------|-------------|-----------------------------------------|-------------------|-----------|--------------|---------|----------|
| 6 | zig-golden-float build     | vendor       | symbols mismatch с rust export            | —                  | P1 FFI debt | —       | ACTIVE | investigation |
| 7 | zig-sacred-geometry 404     | vendor       | репо недоступен/удален (404 Not Found) | —                  | P1 🔴    | —       | ACTIVE | —            |

**Описание**: zig-sacred-geometry репо возвращал 404, нужно либо восстановить из backup либо пересоздать sacred geometry модуль.

---

## Spec Completion Blockers (P1 — Documentation)

| # | Блокер                      | Тип          | Симптом                              | Зависит от          | Priority | Owner        | ETA     | Status      |
|---|-------------------------------|-------------|-------------------------------------|-------------------|-----------|--------------|---------|----------|
| 8 | T27 specs incomplete          | spec         | gold/hdc/phys/sacred/*.t27 = partial     | —                  | P1        | —       | ACTIVE | Day 2-3  |

**Описание**: Spec files для golden-float, hdc, physics и sacred geometry modules не полностью готовы — часть операций отсутствует или не документирована.

---

## Summary

### By Priority

| Priority | Count | Blocked items |
|----------|-------|---------------|
| P1 🔴    | 7      | 3 FFI symbols + 2 vendor submodules + 1 sync + 1 spec |
| P2        | 0      | — |
| P3        | 0      | — |

### By Type

| Тип       | Count | Items |
|-----------|-------|-------|
| FFI       | 3      | crypto, golden-float, sacred symbols |
| vendor    | 3      | hdc submodule, physics submodule, sacred 404, golden sync |
| spec      | 1      | T27 specs partial |

### Dependency Chain

```
┌─────────────────────────────────────────────────────────────┐
│                                                   │
│  zig-crypto-mining ─┐                            │
│                     │                            │
│              trios-crypto ─┤                            │
│                     │        Missing sha256    │
│                     ▼                           │
│            ┌──────────────────────┐           │
│            │  zig-golden-float  │           │
│            │        Missing symbols │           │
│            └────┬─────────────────┘           │
│                 │                              │
│          trios-golden-float ─┤                  │
│                 │  Missing _gf16_*          │
│                 ▼                              │
│  zig-sacred-geometry ─┐                         │
│                     │  404 Not Found            │
│                     ▼                          │
│           trios-sacred ─┤                        │
│                     │  Missing _sacred_*          │
│                     ▼                          │
│            ┌──────────────────────┐          │
│            │   zig-hdc missing    │          │
│            │   zig-physics missing │          │
│            └───────────────────────┘          │
│                     ▼                              │
│              trios-hdc (can't build)             │
│              trios-physics (no bindings)            │
└─────────────────────────────────────────────────────┘
```

---

## Actions to Clear

### Immediate (Day 1)
- [ ] `git submodule add https://github.com/gHashTag/zig-hdc.git vendor/zig-hdc`
- [ ] `git submodule add https://github.com/gHashTag/zig-physics.git vendor/zig-physics`
- [ ] `git submodule update --init --recursive`
- [ ] Investigate zig-sacred-geometry 404 (restore or recreate)

### Short-term (Day 2-3)
- [ ] Complete specs/golden-float/*.t27
- [ ] Complete specs/hdc/*.t27
- [ ] Complete specs/physics/*.t27
- [ ] Fix zig-golden-float symbols mismatch
- [ ] Add sha256 to zig-crypto-mining exports
- [ ] Add _gf16_compress_weights* to zig-golden-float exports
- [ ] Add _sacred_golden_sequence* to zig-sacred-geometry exports

---

## Related Issues

- GitHub issue: TBD (needs creation)
- Related: TECH_DEBT.md
