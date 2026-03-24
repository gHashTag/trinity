# 🐝 Multi-Agent Coordination — HIVELOG

Все агенты делят репозиторий и видят действия друг друга через общий рой-лог.

## Формат строки

```
2026-03-25T02:44:00Z | agent:claude-opus | task:TDGS-3 | scope:tri27.coptic | action:"created src/tri27/coptic.zig enum" | commit:pending
```

## Правила

1. **В начале КАЖДОГО цикла:**
   - прочитать последние 20 строк HIVELOG.md
   - НЕ делать то, что недавно сделал другой агент в том же scope

2. **Перед КАЖДЫМ коммитом:**
   - добавить строку в HIVELOG.md с:
     - ISO-временем (`date -u +%Y-%m-%dT%H:%M:%SZ`)
     - agent:<NAME_OR_ID>
     - task:TDGS-X или tri:dev-YYY
     - scope (директория/подсистема)
     - кратким action
     - commit hash (если есть)

3. **Local Task Progress:**
   - `.autonomous/<TASK_ID>/progress.md` — единый для всех агентов на задаче
   - перед работой: прочитать progress.md, выбрать первый незакрытый шаг
   - после работы: обновить progress.md

4. **Запрет на пересечения:**
   - Один TDGS/tri:dev issue — по умолчанию один coding-агент
   - Если два агента работают над одним TASK_ID:
     - второй агент НЕ меняет код, а гоняет тесты/улучшает документацию

## Пример

```bash
# В начале цикла
tail -20 .autonomous/HIVELOG.md

# Перед коммитом
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | agent:claude-opus | task:TDGS-3 | scope:tri27.coptic | action:\"created coptic enum\" | commit:pending" >> .autonomous/HIVELOG.md
```
2026-03-24T20:14:08Z | agent:claude-opus | task:TDGS-3 | scope:tri27.coptic | action:"created coptic.zig enum with 26 registers + bank model" | commit:402cec4551
2026-03-24T20:18:34Z | agent:claude-opus | task:TDGS-3 | scope:tri27.asm_parser | action:"lexer recognizes Coptic names as Register tokens" | commit:0a55229623
