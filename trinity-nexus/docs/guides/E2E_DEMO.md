# VIBEE E2E Pipeline v21 - Демонwithтрацandя

Аinтономный браузерный агент: Chrome CDP + Ollama LLM.

## Быwithтрый withтарт

```bash
# 1. Запуwithтandть Chrome
google-chrome --headless=new --remote-debugging-port=9222 --no-sandbox &

# 2. Запуwithтandть Ollama
ollama serve &
ollama pull qwen2.5:3b

# 3. Запуwithтandть агента
./scripts/agent_loop.sh "What is the page title?" "https://example.com"
```

## Прandмеры задач

### Проwithтая задача (1 шаг, ~13with)
```bash
./scripts/agent_loop.sh "What is the page title?" "https://example.com"
# Result: done → "Example Domain"
```

### Наinandгацandя + fromчёт (2 шага, ~16with)
```bash
./scripts/agent_loop.sh "Go to google.com and report the title" ""
# Шаг 1: goto https://google.com
# Шаг 2: done → "Google"
```

### Многошагоinая задача (3 шага, ~26with)
```bash
./scripts/agent_loop.sh "Visit example.com, extract info, and report" ""
# Шаг 1: goto https://example.com
# Шаг 2: extract page info
# Шаг 3: done → результат
```

## Доwithтупные дейwithтinandя

| Дейwithтinandе | Опandwithанandе | Прandмер Input |
|----------|----------|--------------|
| goto | Наinandгацandя | https://example.com |
| click | Клandto | button#submit |
| type | Вinод теtowithта | input#search\|hello |
| scroll | Проtoрутtoа | up / down |
| extract | Изinлеченandе | main heading |
| done | Заinершенandе | результат |
| fail | Error | прandчandon |

## Выбор моделand

```bash
# По умолчанandю (3b - onдёжonя)
./scripts/agent_loop.sh "task" "url"

# Быwithтрая (1.5b - for теwithтоin)
VIBEE_MODEL="qwen2.5:1.5b" ./scripts/agent_loop.sh "task" "url"
```

## Метрandtoand v21

| Метрandtoа | Зonченandе |
|---------|----------|
| Латенwithand on шаг | ~6-10with |
| Уwithпешноwithть проwithтых задач | ~95% |
| Уwithпешноwithть многошагоinых | ~80% |
| Модель по умолчанandю | qwen2.5:3b |

## Архandтеtoтура

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Chrome    │────▶│   Agent     │────▶│   Ollama    │
│    CDP      │◀────│   Loop      │◀────│    LLM      │
└─────────────┘     └─────────────┘     └─────────────┘
     │                    │                    │
     │   OBSERVE          │    THINK           │
     │   (page state)     │    (next action)   │
     │                    │                    │
     └────────────────────┴────────────────────┘
                    ACT (execute)
```

---
φ² + 1/φ² = 3 | PHOENIX = 999 | VIBEE v21
