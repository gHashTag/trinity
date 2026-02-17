# Ralph Status Integration — Trinity Dev Telegram

Автоматическая отправка статусов из `.ralph/` в Telegram группу **TRINITY DEV** (-5160767429).

---

## 📊 Что отправляется

1. **Circuit Breaker State**
   - Состояние: CLOSED / HALF_OPEN / OPEN
   - Текущий loop
   - Кол-во циклов без прогресса
   - Причина открытия (если OPEN)

2. **Session Info**
   - Последняя активность
   - Последний сброс
   - Причина сброса
   - Общее количество вызовов

3. **Progress**
   - Статус прогресса
   - Время последнего обновления

4. **Active P1 Task**
   - Текущая приоритетная задача из `fix_plan.md`

5. **Recent Commits**
   - Последние 3 коммита из git

---

## 🚀 Как работает

### 1. Статус-репортер
```bash
/Users/playra/trinity/.ralph/scripts/send_ralph_status.sh
```

Генерирует два файла:
- `status_message.txt` — форматированное сообщение для Telegram
- `status_report.json` — JSON для программного доступа

Запуск вручную:
```bash
bash /Users/playra/trinity/.ralph/scripts/send_ralph_status.sh
```

### 2. Cron Job
Автоматический запуск каждые **30 минут** через OpenClaw cron.

**Job ID:** `eeca8582-e5a0-46c2-8eda-90b231fb7671`
**Название:** Ralph Status to Trinity Dev
**Интервал:** 30 минут (1,800,000 ms)

Репортер читает:
- `.ralph/internal/.circuit_breaker_state`
- `.ralph/internal/.ralph_session`
- `.ralph/internal/.call_count`
- `.ralph/internal/progress.json`
- `.ralph/internal/fix_plan.md`
- Git log последних 3 коммитов

---

## 🛠 Управление

### Посмотреть список cron jobs
```bash
openclaw cron list
```

### Отключить статус-репортер
```bash
openclaw cron update --id eeca8582-e5a0-46c2-8eda-90b231fb7671 --patch '{"enabled": false}'
```

### Включить статус-репортер
```bash
openclaw cron update --id eeca8582-e5a0-46c2-8eda-90b231fb7671 --patch '{"enabled": true}'
```

### Удалить статус-репортер
```bash
openclaw cron remove --id eeca8582-e5a0-46c2-8eda-90b231fb7671
```

### Запустить немедленно
```bash
openclaw cron run --id eeca8582-e5a0-46c2-8eda-90b231fb7671
```

---

## 📁 Файлы

| Путь | Описание |
|------|----------|
| `.ralph/scripts/send_ralph_status.sh` | Скрипт генерации статуса |
| `.ralph/status_message.txt` | Форматированное сообщение (Telegram) |
| `.ralph/status_report.json` | JSON статуса (для программного доступа) |
| `.ralph/internal/.circuit_breaker_state` | Состояние circuit breaker |
| `.ralph/internal/.ralph_session` | Информация о сессии |
| `.ralph/internal/.call_count` | Счётчик вызовов |
| `.ralph/internal/progress.json` | Статус прогресса |
| `.ralph/internal/fix_plan.md` | План работ (откуда берётся P1 задача) |

---

## 🔧 Требования

- `jq` — для парсинга JSON
- `git` — для чтения коммитов
- OpenClaw cron — для автоматических запусков

Установка jq:
```bash
brew install jq
```

---

## 📊 Пример сообщения

```
🤖 **Ralph Status Report**

🟢 **Circuit Breaker:** CLOSED (Normal)
   Loop: `8` | No progress: `0`

📊 **Session**
   Last: `2026-02-17T14:22:14+00:00`
   Reset: `2026-02-17T12:24:48+00:00` (manual_circuit_reset)
   Calls: `2`

📈 **Progress:** `completed`
   Last update: `2026-02-17 17:02:44`

🎯 **Current P1 Task:**
   NEXUS-001: Create Trinity Nexus repository structure

📝 **Recent Commits:**
   • ee71b2815 docs: Update tech tree SYM-003 complete
   • e66d86166 feat(symbolic): SYM-003 Decentralized KG Sync
   • afc3ba7b8 fix(symbolic): SYM-004 cleanup

---
*Generated at 2026-02-17 21:23:45*
```

---

## 🔄 Изменение интервала

Чтобы изменить интервал (например, на 15 минут):

```bash
openclaw cron update \
  --id eeca8582-e5a0-46c2-8eda-90b231fb7671 \
  --patch '{"schedule": {"kind": "every", "everyMs": 900000}}'
```

Интервалы:
- 5 минут = 300,000 ms
- 15 минут = 900,000 ms
- 30 минут = 1,800,000 ms (текущий)
- 1 час = 3,600,000 ms
- 2 часа = 7,200,000 ms

---

## 📝 Создано

- **Дата:** 2026-02-17
- **Автор:** VIBEE (clawd)
- **Цель:** Мониторинг статуса Ralph автономной разработки в Telegram группе

---

φ² + 1/φ² = 3 | TRINITY
