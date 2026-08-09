# CLAUDE.md

## Pinned Zig version — 0.15.2

**Every workflow uses `0.15.2`.** Before 2026-08-10 they did not: 22 places said 0.15.2,
five said 0.15.0, and three that actually run `zig build` — `build-compiler-release.yml`,
`extension-tests.yml`, `extension-release.yml` — said 0.13.0, two majors behind.

This document previously carried migration rules for 0.14 and 0.15 at once, which is how a
reader ends up applying the wrong one.

**A locally installed Zig is not the CI toolchain.** On 0.16 a clean checkout of `main`
fails at `build.zig:67` with `no field or member function named 'linkLibC'` — an error CI
never sees, because `linkLibC` still exists in 0.15. A green local build proves nothing
about CI, and a red one says nothing about your change. Match 0.15.2 locally before drawing
any conclusion from a build.

---

## Zig 0.15 API Compatibility and Migration Rules

**Reference**: docs/zig-migration-rules.md — https://ziglang.org/download/0.15.1/

---

## SplitIterator API Changes (Zig 0.15)

⚠️ **IMPORTANT**: `SplitIterator` semantics changed significantly in Zig 0.15:
- `.first()` and `.next()` now return `?[]const u8` (optional) instead of direct slices
- Multiple `orelse` calls fail when left side is not optional
- Direct slice access pattern requires using `?[0..N]` or iterator index notation

**Rules**:
1. ✅ Используйте `if (iterator_expr) |capture|` для optionals, `orelse` для non-optionals
2. ✅ Не полагайтесь на поведение `next()`/`first()` из Zig 0.14 — они могут не работать в Zig 0.15
3. ✅ Проверяйте типы с помощью `@as()`, `@intCast()`, или явной аннотации типа

### ArrayList.init() API Changes

⚠️ **IMPORTANT**: `ArrayList.init()` now uses error union return types:
- Return type is `!ArrayList(Header, null)` or similar error unions
- Cannot use `.append()` or `.writer()` with error returns

**Rules**:
1. ✅ Используйте `ArrayList(Header).initCapacity(allocator, capacity)` вместо `ArrayList(Header).init(allocator)`
2. ✅ Обрабатывайте error union из `init()` явно с помощью `if` или `switch`
3. ✅ Не пытайтесь присвоить результат `init()` переменной до проверки ошибок

### orelse Keyword (Zig 0.15)

⚠️ **IMPORTANT**: `orelse` now requires optional on LEFT side:
```zig
if (optional_expr) |capture| else_expr
```

**Rules**:
1. ✅ Левая сторона `orelse` ДОЛЖНА быть optional (т.е. `if` или `while`)
2. ✅ Для получения среза из optional: `if (opt) |val| opt.? else default_value`
3. ✅ Не используйте `orelse` для простых развилок без захвата ошибок

---

## PostgreSQL Protocol Read Patterns

✅ `stream.read(buffer)` возвращает количество прочитанных байтов
- Используйте `if (bytes_read > 0)` проверки
- Не используйте `readAll()` — эта функция была удалена в Zig 0.15

---

**Ссылка на правила миграции**

Миграция API: **Zig 0.15 Compatibility**
- Типы данных: optional, error unions
- Ссылка на: docs/zig-migration-rules.md

---
**Дата добавления**: 2026-04-03

---

## Queen Trinity Orchestrator Law

### SOUL.md — Mandatory Agent Soul

**Every container/agent MUST have `SOUL.md` at its root.**

**SOUL.md contains:**
- Agent type (Ralph / Mu / Scholar / Copywright / Oracle / Swarm / Custom)
- Bound GitHub issue number
- Mission statement
- Allowed commands
- Stop conditions
- Reporting format (Protocol v2)
- References to CLAUDE.md and AGENTS.md

**Template**: `templates/SOUL.md`

### Issue-Bound Containers

**Every container MUST be bound to exactly one GitHub issue.**

**Canonical registry**: `.trinity/issue_bindings.json`

```json
{
  "issue_number": 505,
  "agent_id": "ralph-505-a1",
  "soul_file": ".trinity/souls/issue-505-ralph-505-a1/SOUL.md",
  "session_id": "sess_123",
  "railway_service_id": "svc_abc",
  "deployment_id": "dep_xyz",
  "experience_file": ".trinity/experience/issue-505-run-001.jsonl",
  "status": "ACTIVE"
}
```

### Akashic Journaling — GitHub Issues as Immutable Record

**Every significant agent action MUST be reflected as a GitHub issue comment.**

**Comment format (Protocol v2):**
- `🔍 [RESEARCH] Step 1/8`
- `📜 [SPEC] Reused nearest template`
- `⚙️ [CODEGEN] .tri -> .zig`
- `🧪 [TEST] 6/7 passed`
- `☣️ [VERDICT] Past: 3/7. Now: 7/7`
- `✅ [DONE] Build clean. Commit pushed`

### Single Source of Truth

- **`.tri` spec** — Logic and algorithms
- **`.trinity/experience/`** — Episodes and learnings
- **GitHub issue** — Immutable event thread
- **`.trinity/issue_bindings.json`** — Issue ↔ session ↔ service ↔ soul mapping

### Agent Lifecycle Commands

- `tri agent spawn <issue>` — Create container + SOUL.md + register binding
- `tri agent run <issue>` — Execute 8-step cycle with journaling
- `tri agent stop <issue>` — Delete service + final comment

### 8-Step Agent Cycle

1. `tri dev scan` — Read issues + experience
2. `tri dev pick --smart` — Priority + MNL (avoid 3+ fails)
3. `tri spec create` — .tri spec from experience template
4. `tri gen` — .tri → .t27 + .zig
5. `tri test` — Compare outputs
6. `tri verdict --toxic` — "Past: 3/7. Now: 7/7"
7. `tri experience save` — Episode + learnings + mistakes
8. `tri git commit` — [DONE] + push
9. `tri loop decide` — Continue or Done?

**Each step writes to:**
- GitHub issue (comment)
- `.trinity/agent_events.jsonl`
- `.trinity/experience/...`

### MNL Pattern (Mistake → Not-repeat → Learning)

- Task X: 3 consecutive fails → SKIP (toxic)
- Task Y: 0 fails, similar to solved Z → PICK
- Task Z: 1 fail, but fix found → PICK with learning

### Hard Rules

- ❌ No direct `.zig` writing where `.tri -> tri gen` should be used
- ❌ No logic duplication between spec and code
- ✅ Every container must have `SOUL.md`
- ✅ Every container must be bound to exactly one issue
- ✅ Every significant action must be reflected as issue comment