# Anti-Idle Rules — Autonomous Cycle Guardrails

## ⛔ Filesystem Safety

- **ЗАПРЕЩЕНО** делать `rm -rf .zig-cache/o` или частичное удаление кэша
- Если нужно очистить кэш: **ТОЛЬКО** `rm -rf .zig-cache && rm -rf zig-out` (полностью)
- После очистки кэша: сначала `zig build l0`, потом `zig build l1`, потом остальное
- **ЗАПРЕЩЕНО** запускать `zig build` больше 2 раз подряд на одну и ту же ошибку
- Если билд падает 2 раза с одной ошибкой → запиши в HIVELOG и **СТОП**

## 🔄 No-Spin Rule

- **ЗАПРЕЩЕНО** бесконечно повторять одни и те же проверки без прогресса
- Если 3 цикла подряд нет новых коммитов → **СТОП** и сообщить статус
- Если все задачи выполнены → сообщить "ALL TASKS COMPLETE" и ждать новых инструкций

## 📋 Task Progress Rule

- Каждая задача должна иметь конкретный чекбокс: `[ ]`
- После выполнения `[ ]` → `[x]` → коммит
- Не переходить к следующей задаче пока текущая не закоммичена
- Если задача блокирована → записать в HIVELOG и ждать

## 🚨 Error Logging

При любой ошибке:
1. Записать в HIVELOG.md: `[ERROR] timestamp: описание`
2. Полный stderr в `.autonomous/errors/<timestamp>.log`
3. Не повторять ошибочное действие больше 2 раз

## ✅ Success Pattern

```
[ ] Task name
    ├─ zig build → PASS/FAIL
    ├─ zig test → PASS/FAIL
    ├─ zig fmt → DONE
    ├─ git commit → DONE
    └─ [x] COMPLETE
```

φ² + 1/φ² = 3 | TRINITY
