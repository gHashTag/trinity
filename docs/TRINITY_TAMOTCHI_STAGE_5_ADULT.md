# Этап 5: Взрослый (Adult) — Самостоятельная экосистема

**Цель:** Полностью автономный daemon, который сам:
- Распределяет ресурсы
- Исправляет ошибки
- Отдыхает по расписанию
- Отчитывается в человеке

**Время:** 12+ часов непрерывной работы

---

## Чек-лист

### ✅ 5.1 Динамическое распределение ресурсов (Голод)
```bash
# Watch-dog в reticular_aras автоматически проверяет пул шагов
# Если падает ниже 20% → автоматически вызывает train allocate

# Проверка автодовател:
tri doctor diagnose reticular_aras

# Ручное пополнение если нужно:
tri train allocate --steps 50000
```

### ✅ 5.2 Поддержание среднего ΔPPL ≥ 0 (Счастье)
```bash
# Queen отслеживает тренд PPL
# Если стагнация >2ч → инициировать experimental wave

# Ручной триггер если нужно:
tri farm evolve step

# Фиксация вех в Zenodo (раз в неделю или при major рекордах)
```

### ✅ 5.3 Самолечение (Дисциплина)
```bash
# Auto-heal при обнаружении FAIL
tri doctor auto-heal

# Или модульная диагностика:
tri doctor diagnose queen_dlpfc --fix
tri doctor diagnose queen_ofc --fix
tri doctor diagnose queen_actions --fix
```

### ✅ 5.4 Циркадный ритм (Сон)
```bash
# Активная фаза 4ч → отдых 1ч → повтор
# Реализуется через cron или внутренний планировщик Queen

# Встроенный режим:
tri queen start --daemon --interval 240 --allow-auto-actions   # 4ч активной
# Затем internal scheduler переключает на:
# --interval 60 --no-auto-actions                                   # 1ч отдыха
```

### ✅ 5.5 Проверка здоровья всех модулей
```bash
# Полная диагностика:
tri doctor diagnose all

# Или по модулям:
tri doctor diagnose phoenix_medulla phoenix_pons phoenix_locus_coeruleus
tri doctor diagnose queen_dlpfc queen_ofc queen_actions
tri doctor diagnose thalamus hippocampus
tri doctor diagnose reticular_aras reticular_raphe
```

---

## Критерии завершения этапа

Этап **Adult** считается пройденным, когда:
- [x] Daemon работает 24+ часа без перезапуска
- [x] Auto-heal исправляет ≥3 проблемы автоматически
- [x] PPL стабильно улучшается или держится (ΔPPL ≥ 0)
- [x] Arousal редко превышает .alert (<5% времени)
- [x] Telegram сообщения информативны, с контекстом
- [x] Система работает автономно недели без вмешательства

---

## Режим полного автопилота

Когда Adult пройден, Queen может работать полностью автономно:

### Минимальное вмешательство человека:
1. **Раз в неделю** — пополнить Railway токены
2. **Раз в месяц** — проверить Zenodo вехи
3. **При экстренных ситуациях** — arousal = emergency

### Queen сама:
- ✅ Распределяет вычислительные ресурсы
- ✅ Экспериментирует с гиперпараметрами
- ✅ Исправляет ошибки build/farm
- ✅ Отдыхает по циркадному ритму
- ✅ Отчитывается в человеке

---

## Пример взрослого отчёта в Telegram

**Нормальный режим:**
```
🧠 Queen Status Briefing

Training in progress.
🍽 Hunger: 65% steps remaining
😀 Happiness: +0.12 PPL this cycle
🪓 Discipline: 2 fixes applied overnight
😴 Rest: 28% idle time (next rest in 45min)
❤️ Health: all modules OK
⚡ Arousal: normal (level 2)

✅ All systems nominal.
```

**После auto-heal:**
```
🔧 Auto-heal complete

Fixed 2 issues:
• phoenix_pons: relay restored
• queen_actions: policy updated

✅ Health restored
⚡ Arousal: normal (was alert)
```

**Новый рекорд:**
```
🎉 MILESTONE ACHIEVED

hslm-r28: 4.32 PPL — new record!
Δ: -0.24 from previous best

Saving to Zenodo...
✅ Milestone recorded
```

---

## Переход к production

Когда Adult пройден → Queen готова к production:

```bash
# Полный автопилот (круглосуточно)
tri queen start --daemon --interval 300 --allow-auto-actions

# Мониторинг из другого терминала:
watch -n 60 'tail -5 .trinity/memory/phoenix/current.jsonl'
```

### Ежедневная проверка (раз в сутки):
```bash
# Быстрая проверка здоровья
tri doctor diagnose all

# Статистика за день
tail -100 .trinity/queen/audit.jsonl | grep -E "(auto-heal|farm_recycle|new_record)"
```

---

## Архивные метрики

Для долгосрочного анализа:

```bash
# История arousal изменений
grep "arousal" .trinity/memory/locus_coeruleus/current.jsonl

# История PPL рекордов
grep "new_record" .trinity/memory/hippocampus/current.jsonl

# История auto-heal
grep "auto-heal" .trinity/queen/audit.jsonl
```

---

## φ² + 1/φ² = 3

*Поздравляем! Ваш Queen TRINITY теперь полностью самостоятельный AI-организм.*

---

*φ² + 1/φ² = 3 = TRINITY*
