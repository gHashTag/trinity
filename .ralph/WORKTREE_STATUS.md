# Ralph Worktree Status Integration

Автоматический отчёт о работе **параллельных worktrees** в Telegram группу TRINITY DEV.

---

## 🌲 Структура Worktrees

```
/Users/playra/trinity      → main repo (ralph/math-framework)
/Users/playra/trinity-w1   → ralph/nexus-src (NEXUS-011..014)
/Users/playra/trinity-w2   → ralph/nexus-specs (NEXUS-015..018)
/Users/playra/trinity-w3   → ralph/nexus-docs (docs, tech tree)
```

---

## 📊 Что отправляется каждые 10 минут

1. **Circuit Breaker** — состояние главного circuit breaker
2. **Worktree Status** — каждый worktree:
   - Ветка
   - Последний коммит
   - CB state / Loop / Calls
   - Количество изменённых файлов
3. **Orchestrator** — текущая фаза оркестрации
4. **Recent Commits** — последние 3 коммита в main

---

## 🚀 Скрипты

### Основной скрипт
```bash
.ralph/scripts/send_worktree_status.sh
```

Генерирует отчёт по всем worktrees.

### Простой статус
```bash
.ralph/scripts/send_ralph_status.sh
```

Только статус главного репозитория.

---

## ⏰ Cron Job

**Job ID:** `eeca8582-e5a0-46c2-8eda-90b231fb7671`
**Интервал:** 10 минут (600,000 ms)
**Создан:** 2026-02-17
**Обновлён:** 2026-02-18

### Управление
```bash
# Посмотреть
openclaw cron list

# Отключить
openclaw cron update --id eeca8582-e5a0-46c2-8eda-90b231fb7671 --patch '{"enabled": false}'

# Изменить интервал на 5 минут
openclaw cron update --id eeca8582-e5a0-46c2-8eda-90b231fb7671 --patch '{"schedule": {"kind": "every", "everyMs": 300000}}'

# Запустить сейчас
openclaw cron run --id eeca8582-e5a0-46c2-8eda-90b231fb7671
```

---

## 🎭 Orchestrator

Оркестратор управляет 3 worktrees параллельно:
- Проверяет статус каждые 15 минут
- Перезапускает зависшие worktrees
- Логирует в `.ralph/logs/orchestrator.log`

---

## 📝 Пример сообщения

```
🌲 Trinity Worktree Status Report

🔌 Circuit Breaker: CLOSED (Loop: 130, No-prog: 0)

📂 trinity-w1 | ralph/nexus-src
   Last: feat(nexus): NEXUS-011-014 migrate source files
   CB: CLOSED | Loop: 2 | Calls: 0
   Changes: 7 files

📂 trinity-w2 | ralph/nexus-specs
   Last: feat(nexus): NEXUS-015-018 organize specs and docs
   CB: CLOSED | Loop: 2 | Calls: 0
   Changes: 15 files

📂 trinity-w3 | ralph/nexus-docs
   Last: docs: Update tech tree DEV-002 complete
   CB: CLOSED | Loop: 2 | Calls: 0
   Changes: 8 files

📊 Summary: 3 active worktrees

🎭 Orchestrator: Phase 1 — Managing 3 worktrees

📝 Recent Commits:
• 0b3cadc docs: DEV-002 complete
• 28ac631 feat(dev): DEV-002 KG-INSIGHT
• 233159f docs: NEXUS-010 complete

---
Generated at 2026-02-18 11:16
```

---

**Создано:** 2026-02-18
**Обновлено:** 2026-02-18
**Версия:** 2.0 (worktree support)
