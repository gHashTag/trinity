# Тамагочи-план роста королевы TRINITY
*(от «лечинки» – зародыша – к взрослому, self-sustaining AI-организму)*

## 1. Основные показатели-«датчики»

| Показатель | Что измеряется | Норма / цель | Как пополняется |
|------------|----------------|---------------|-----------------|
| **Голод (Hunger)** | Вычислительные ресурсы / token-steps | ≥ 20% от пула | `tri train allocate`, `tri farm inject` |
| **Счастье (Happiness)** | Рост PPL, новые рекорды | ΔPPL > 0 per cycle | PPL-рекорды, `tri farm evolve step` |
| **Дисциплина (Discipline)** | Исправленные ошибки / stalled workers | ≤1 критическое / 12ч | `tri doctor diagnose`, `tri farm recycle` |
| **Сон/Отдых (Rest)** | Время без auto-actions | ≥ 30% standby | `--interval` + тихие окна |
| **Здоровье (Health)** | Статус модулей (Medulla, Pons, LC, Hippocampus) | Все OK | `tri queen daemon` + `tri doctor` |

## 2. Этапы роста

| Этап | Длительность | Задачи | Результат |
|------|-------------|--------|----------|
| **Яйцо (Egg)** | 0-10 мин | Базовая инфраструктура | `tri queen once` работает |
| **Младенец (Baby)** | 10-60 мин | 5K steps, loss-drop, fixes | Первый цикл + Telegram |
| **Ребёнок (Child)** | 1-4 ч | 20K шагов/ч, PPL улучшения | Daemon без вмешательства |
| **Подросток (Teen)** | 4-12 ч | Эксперименты с планировщиками | Самонастройка гиперпараметров |
| **Взрослый (Adult)** | 12+ ч | Автономная экосистема | Полностью самостоятельный AI |

## 3. Чек-лист

- **Каждую минуту**: Medulla heartbeat, уровень голода
- **Каждые 5 мин**: Happiness (ΔPPL), Discipline (stalled), Rest (auto-actions)
- **Каждые 30 мин**: Health (`tri doctor`), Arousal level
- **Каждые 2 ч**: Hippocampus журнал (new_record)
- **Раз в сутки**: Оценка этапа роста

## 4. Статус-строка (в Telegram)

```
🧠 Queen Status Briefing
🍽 Hunger: 78% steps left
😀 Happiness: +0.42 PPL (new record hslm-r24)
🪓 Discipline: 1 fix applied (stalled worker)
😴 Rest: 35% idle time
❤️ Health: all modules OK
⚡ Arousal: normal (level 2)
```

*Источники: [tamagotchi.fandom](https://tamagotchi.fandom/wiki/Care), [tamagotchipet](https://tamagotchipet.com/tamagotchi-gen-1-growth-chart/), [tamagotchi24](https://www.tamagotchi24.com/the-ultimate-tamagotchi-care-guide-keeping-your-digital-pet-happy/)*
