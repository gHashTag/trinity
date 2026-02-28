# Ralph Status Reporter

[CYR:Отпра]intoа with[CYR:тату]withоin Ralph in Telegram [CYR:группу] **TRINITY DEV** (-5160767429).

## 🚀 Быwith[CYR:трый] with[CYR:тарт]

### [CYR:Ручной] [CYR:запу]withto
```bash
bash .ralph/scripts/send_ralph_status.sh
```

### [CYR:Упра]in[CYR:лен]andе cron
```bash
# Поwithмfrom[CYR:реть] withпandwithоto
openclaw cron list

# Отto[CYR:люч]andть
openclaw cron update --id eeca8582-e5a0-46c2-8eda-90b231fb7671 --patch '{"enabled": false}'

# Вto[CYR:люч]andть
openclaw cron update --id eeca8582-e5a0-46c2-8eda-90b231fb7671 --patch '{"enabled": true}'

# [CYR:Запу]withтandть with[CYR:ейча]with
openclaw cron run --id eeca8582-e5a0-46c2-8eda-90b231fb7671
```

## 📊 [CYR:Что] from[CYR:пра]in[CYR:ляет]withя

1. Circuit Breaker state (CLOSED/OPEN/HALF_OPEN)
2. Session info (last used, reset, calls)
3. Progress status
4. Active P1 task from fix_plan.md
5. Last 3 git commits

## 📁 [CYR:Выходные] fileы

- `.ralph/status_message.txt` — Telegram format
- `.ralph/status_report.json` — JSON format

## 📖 [CYR:Пол]onя доto[CYR:ументац]andя

См. `.ralph/STATUS_INTEGRATION.md`

---

**[CYR:Интер]inал:** 30 мand[CYR:нут]
**Job ID:** `eeca8582-e5a0-46c2-8eda-90b231fb7671`
**[CYR:Создано]:** 2026-02-17
