# TDGS-1: Tri Dev Guarded Stack — Full Stack Guarded Editing

## Sacred Formula
V = n × 3^k × π^m × φ^p × e^q
φ² + 1/φ² = 3

---

## Цель

Все критичные слои Trinity/Tri (от Zig-ядра до Tri-кода и .t27) изменяются **только через `tri dev`**, а не руками в редакторе. Это уменьшает число ошибок, обеспечивает единый pipeline проверок и готовит почву для автогенерации/само-хостинга.

---

## TDGS-1: Core Development Law (Расширенный)

> **Любые изменения файлов из списка «Guarded scope» должны выполняться ИСКЛЮЧИТЕЛЬНО через команды `tri dev`.**
>
> **Прямое редактирование этих файлов руками считается нарушением** и блокируется pre-commit/CI.

---

## 1. Область действия

### 1.1. Trusted Tri Core (TTC, Zig)

| File | LOC | Purpose |
|------|-----|---------|
| `src/tri-lang/lexer.zig` | 310 | Tokenization |
| `src/tri-lang/parser.zig` | 300 | Parse AST |
| `src/tri-lang/ast.zig` | 370 | AST definitions |
| `src/tri-lang/typecheck_core.zig` | ~150 | Type checking |
| `src/tri-lang/emit_t27.zig` | ~200 | .t27 generation |
| `src/tri-lang/emit_zig.zig` | ~200 | Zig emission |
| `src/tri/cell.zig` | 150 | NA-R11 signature |
| `src/tri/t27_cli.zig` | 50 | CLI for verify/diff |
| `src/tri27/coptic.zig` | 170 | Coptic alphabet |

**Total TTC: ≤ 3000 LOC Zig**

### 1.2. Tri-язык (основные модули)

- Все файлы `src/tri-lang/*.tri` (язык/stdlib/комбинаторы)
- Все Tri-модули, помеченные как **core/canon** в `canon_map.json`

### 1.3. TRI-27 артефакты и спецификации

- Все `.t27` в `src/tri27/`
- Все исследовательские спецификации в `docs/research/*.md` и `docs/tri27/*.md`, помеченные как **normative**

### 1.4. Neuro/HSLM/Queen матрёшка (если помечена как core)

- Модули `src/tri/queen/*.tri`, `src/hslm/*.tri`, указанные в `trinity_s3ai_overview.md` как части 8-уровневого стека

---

## 2. Команды tri dev

### 2.1. tri dev core

| Command | Purpose |
|---------|---------|
| `tri dev core audit` | Проверить TTC здоровье (LOC, сигнатуры) |
| `tri dev core sign` | Обновить core подписи |
| `tri dev core edit-ast` | Редактировать AST через декларативную спецификацию |
| `tri dev core edit-parser` | Добавить правило парсера из grammar |
| `tri dev core edit-emit` | Обновить emit_t27/emit_zig |

### 2.2. tri dev tri (язык и stdlib)

| Command | Purpose |
|---------|---------|
| `tri dev tri new-module <name>` | Создать новый .tri модуль |
| `tri dev tri refactor <op>` | Безопасный рефакторинг (rename, extract, move) |
| `tri dev tri canonize <module>` | Пометить модуль как canon |

### 2.3. tri dev t27 (низкий уровень)

| Command | Purpose |
|---------|---------|
| `tri dev t27 create <region>` | Генерация .t27 из спецификации |
| `tri dev t27 regen` | Перегенерировать все .t27 из исходников |

### 2.4. tri dev docs

| Command | Purpose |
|---------|---------|
| `tri dev docs norm <doc>` | Пометить документ как нормативный |
| `tri dev docs sync` | Проверить соответствие кода документации |

---

## 3. Enforcement (pre-commit/CI)

### 3.1. Pre-commit hook

```bash
# .git/hooks/pre-commit
for f in $(git diff --cached --name-only | grep -E 'src/tri-lang/|src/tri/cell.zig|src/tri27/coptic.zig|\.t27$|docs/research/.*\.md'); do
    tri dev verify-guarded "$f" || {
        echo "ERROR: $f modified without tri dev"
        echo "Use 'tri dev ...' to change Guarded files"
        exit 1
    }
done
```

### 3.2. CI (build.zig + отдельный шаг)

- `tri dev audit`:
  - Проверяет TTC ≤ 3000 LOC
  - Проверяет подписи TTC-файлов
  - Проверяет .t27 подписи (NA-R11)
  - Проверяет canon=true модули

---

## 4. Формат core-signature

```zig
// TRI_CORE_SIGNATURE: tri-dev:1711900800:sha256:deadbeef...
// TRI_CORE_SCOPE: TTC
// DO NOT EDIT MANUALLY — USE `tri dev core ...`
```

---

## 5. Конфигурация

Файл `.trinity/ttc.toml`:

```toml
[ttc]
name = "Trusted Tri Core"
version = "1.0.0"

[files]
lexer = "src/tri-lang/lexer.zig"
parser = "src/tri-lang/parser.zig"
# ... (все 9 файлов)

[enforcement]
max_loc = 3000
signature_required = true
```

---

## 6. Требования к реализации

### 6.1. Базовый tri dev core audit

- [x] Считать список Guarded-файлов из `.trinity/ttc.toml`
- [x] Посчитать LOC по каждому файлу
- [x] Проверить лимит TTC ≤ 3000 LOC
- [x] Проверить наличие TRI_CORE_SIGNATURE

### 6.2. tri dev tri new-module

- [ ] Создавать `.tri` с шаблоном `@spec/@example`
- [ ] Добавлять тест-каркас

### 6.3. Pre-commit hook

- [ ] `tri dev init` устанавливает `.git/hooks/pre-commit`
- [ ] Хук запрещает прямые изменения Guarded-файлов

### 6.4. Документация TDGS-1

- [x] `docs/research/CORE_DEVELOPMENT_LAW.md`
- [x] `docs/research/TDGS_1_GUARDED_STACK.md`

---

## 7. Related Issues

- #411: Linear Types + Ownership Modes (выполнено)
- #421: tri dev core audit implementation (следующая)
- #422: Tri self-hosting phase 1
- #423: Tri self-hosting phase 2

---

## 8. Аналоги в других системах

| System | Approach |
|--------|----------|
| **seL4** | Formal verification, tiny kernel |
| **CompCert** | Coq-spec → C code |
| **Lean 4** | Trusted kernel + tactics |
| **JetBrains MPS** | Projectional editing |
| **Intentional Programming** | Domain code → generator |

---

φ² + 1/φ² = 3 | TRINITY
