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
[INFO] 2026-03-25 09:35:05: Created ANTI_IDLE.md with filesystem safety rules
[OK] 2026-03-25 10:03:49: Fixed result_type.zig for Zig 0.15 - 8/8 tests passing, committed to #410
[OK] 2026-03-25 10:24:42: Wave2 Step1 progress - added match() and TRI-27 lowering to Result type, 12/12 tests, 2 commits to #410
2026-03-25T04:20:58Z | agent:claude-opus | task:TRI27-encoding | scope:executor.zig,tri_asm.zig | action:"Simplified JGT/JLT encoding to use dst field" | commit:c36ed7a4ad
2026-03-25T04:23:21Z | agent:claude-opus | task:autonomous-loop | scope:cycle-status | action:"Build verification: L0✅ L1✅ tri✅, all core tests passing" | commit:none
2026-03-25T12:00:00Z | agent:claude-opus | task:TDGS-3 | scope:wave1,wave2 | action:"Wave1 COMPLETE, created Wave2 checklist (type-system + emit_t27)" | commit:6e533339a1
2026-03-25T04:34:10Z | agent:claude-opus | task:tri-lang-compat | scope:tri-lang | action:"Fixed Zig 0.15 compatibility issues" | commit:pending
2026-03-25T04:36:36Z | agent:claude-opus | task:TDGS-3 | scope:tri-lang.parser | action:"Fixed Zig 0.15 defer compatibility in parsePrimaryExpr" | commit:004ba8e227
2026-03-25T04:43:08Z | agent:claude-opus | task:TDGS-3 | scope:tri-lang.types | action:"Created Wave 2 Type System Core (Hindley-Milner)" | commit:7702517c48
2026-03-25T04:45:49Z | agent:claude-opus | task:TDGS-3 | scope:tests.tri27 | action:"Added reticular_raphe expected output test" | commit:f6e11b810c
2026-03-25T04:49:36Z | agent:claude-opus | task:TDGS-3 | scope:zig-0.15-compat | action:"Fixed std.sort.sort, std.log.scoped across storm/bsd modules" | commit:c601b5a7c9
2026-03-25T04:49:38Z | agent:claude-opus | task:TDGS-3 | scope:wave2,types | action:"Wave2 checklist created, types.zig blocked by Zig 0.15 ArrayList API issue" | commit:none
2026-03-25T05:03:19Z | agent:claude-opus | task:TDGS-3 | scope:tri_depin | action:"Fixed BrainRegion enum + format args, tri build green" | commit:3a6ba1109c
