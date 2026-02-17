# Ralph Status Reporter

Отправка статусов Ralph в Telegram группу **TRINITY DEV** (-5160767429).

## 🚀 Быстрый старт

### Ручной запуск
```bash
bash .ralph/scripts/send_ralph_status.sh
```

### Управление cron
```bash
# Посмотреть список
openclaw cron list

# Отключить
openclaw cron update --id eeca8582-e5a0-46c2-8eda-90b231fb7671 --patch '{"enabled": false}'

# Включить
openclaw cron update --id eeca8582-e5a0-46c2-8eda-90b231fb7671 --patch '{"enabled": true}'

# Запустить сейчас
openclaw cron run --id eeca8582-e5a0-46c2-8eda-90b231fb7671
```

## 📊 Что отправляется

1. Circuit Breaker state (CLOSED/OPEN/HALF_OPEN)
2. Session info (last used, reset, calls)
3. Progress status
4. Active P1 task from fix_plan.md
5. Last 3 git commits

## 📁 Выходные файлы

- `.ralph/status_message.txt` — Telegram format
- `.ralph/status_report.json` — JSON format

## 📖 Полная документация

См. `.ralph/STATUS_INTEGRATION.md`

---

**Интервал:** 30 минут
**Job ID:** `eeca8582-e5a0-46c2-8eda-90b231fb7671`
**Создано:** 2026-02-17
