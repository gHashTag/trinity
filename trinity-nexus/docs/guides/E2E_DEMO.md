# VIBEE E2E Pipeline v21 - [CYR:Демон]with[CYR:трац]andя

Аin[CYR:тономный] browser[CYR:ный] [CYR:агент]: Chrome CDP + Ollama LLM.

## Быwith[CYR:трый] with[CYR:тарт]

```bash
# 1. [CYR:Запу]withтandть Chrome
google-chrome --headless=new --remote-debugging-port=9222 --no-sandbox &

# 2. [CYR:Запу]withтandть Ollama
ollama serve &
ollama pull qwen2.5:3b

# 3. [CYR:Запу]withтandть [CYR:агента]
./scripts/agent_loop.sh "What is the page title?" "https://example.com"
```

## Прand[CYR:меры] [CYR:задач]

### [CYR:Про]with[CYR:тая] task (1 step, ~13with)
```bash
./scripts/agent_loop.sh "What is the page title?" "https://example.com"
# Result: done → "Example Domain"
```

### Наinand[CYR:гац]andя + from[CYR:чёт] (2 stepа, ~16with)
```bash
./scripts/agent_loop.sh "Go to google.com and report the title" ""
# [CYR:Шаг] 1: goto https://google.com
# [CYR:Шаг] 2: done → "Google"
```

### [CYR:Много]stepоinая task (3 stepа, ~26with)
```bash
./scripts/agent_loop.sh "Visit example.com, extract info, and report" ""
# [CYR:Шаг] 1: goto https://example.com
# [CYR:Шаг] 2: extract page info
# [CYR:Шаг] 3: done → result
```

## Доwith[CYR:тупные] [CYR:дей]withтinandя

| [CYR:Дей]withтinandе | Опandwithанandе | Прand[CYR:мер] Input |
|----------|----------|--------------|
| goto | Наinand[CYR:гац]andя | https://example.com |
| click | Клandto | button#submit |
| type | Вinод теtowithта | input#search\|hello |
| scroll | [CYR:Про]to[CYR:рут]toа | up / down |
| extract | Изin[CYR:лечен]andе | main heading |
| done | Заin[CYR:ершен]andе | result |
| fail | Error | прandчandon |

## [CYR:Выбор] [CYR:модел]and

```bash
# По [CYR:умолчан]andю (3b - on[CYR:дёж]onя)
./scripts/agent_loop.sh "task" "url"

# Быwith[CYR:трая] (1.5b - for теwithтоin)
VIBEE_MODEL="qwen2.5:1.5b" ./scripts/agent_loop.sh "task" "url"
```

## [CYR:Метр]andtoand v21

| [CYR:Метр]andtoа | Зon[CYR:чен]andе |
|---------|----------|
| [CYR:Латен]withand on step | ~6-10with |
| Уwith[CYR:пешно]withть [CYR:про]with[CYR:тых] [CYR:задач] | ~95% |
| Уwith[CYR:пешно]withть [CYR:много]stepоinых | ~80% |
| [CYR:Модель] по [CYR:умолчан]andю | qwen2.5:3b |

## [CYR:Арх]andтеto[CYR:тура]

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
