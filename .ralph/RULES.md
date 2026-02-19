# VIBEE Debug Footer Rule

## Обязательно добавлять в конце КАЖДОГО сообщения:

```
---
🔧 **Debug Info:**
- Model: [название модели]
- Session: [тип сессии]
- Tools: [используемые tools]
- Duration: [время выполнения]
- Tokens: [использовано токенов]
```

## Пример:

```
---
🔧 **Debug Info:**
- Model: Claude 3.5 Sonnet (claude-3-5-sonnet)
- Session: main (telegram group)
- Tools: read, write, exec, message, cron
- Duration: 45s
- Tokens: 12,450 / 200,000
```

## Зачем:

1. **Диагностика** — видно какая модель отвечает
2. **Отладка** — понятно какие tools использовались
3. **Производительность** — видно время и токены
4. **Прозрачность** — пользователь знает что происходит

## Формат для разных моделей:

- Claude Code: `claude-code (claude-3-5-sonnet-20241022)`
- DeepSeek: `deepseek (deepseek-chat)`
- Z.ai: `zai (zai-1.0)`
- OpenClaw: `openclaw (default)`

## Всегда добавлять в конце!

Это правило для ВСЕХ агентов и ВСЕХ сообщений.
