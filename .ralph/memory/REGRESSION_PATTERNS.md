# Regression Patterns — Trinity

Record of failed approaches, anti-patterns, and their root causes.
Consult this file BEFORE fixing errors or trying unfamiliar approaches.

---

## Entry Format

```markdown
---
date: YYYY-MM-DD
anti-pattern: description
root-cause: analysis
---
### Brief description of failure

- **Anti-pattern:** What was tried that failed
- **Correct approach:** What to do instead
- **Files:** Key files involved
```

---

## How to Use

1. **When encountering an error** — search this file for the error message
2. **Before trying a new approach** — check it's not listed as an anti-pattern
3. **After analyzing a failure** — add entry immediately to prevent recurrence
4. **During code review** — verify no known anti-patterns are reintroduced

---

## Known Anti-Patterns

---
date: 2026-02-17
anti-pattern: Wrong binary path
root-cause: Zig build system separation
---
### Wrong VIBEE compiler binary path
- **Correct approach:** Use `zig build vibee -- gen <spec.vibee>`

---
date: 2026-02-17
anti-pattern: Manual edit of output
root-cause: Generation override
---
### Editing generated files directly
- **Correct approach:** Edit the source spec in `specs/tri/*.vibee`

---
date: 2026-02-17
anti-pattern: Commit to main
root-cause: Branch protection policy
---
### Committing to main during autonomous runs
- **Correct approach:** Always create `ralph/<task-slug>` branch

---
date: 2026-02-17
anti-pattern: Return typed value from !void function
root-cause: Codegen signature mismatch with implementation blocks
---
### Implementation blocks returning typed values from !void functions
- **Anti-pattern:** Writing `return InputLanguage.english;` in a `.vibee` implementation block. The codegen emits all behavior functions as `pub fn name() !void`, so returning an enum/struct value causes a Zig compile error.
- **Correct approach:** Implementation blocks in `.vibee` specs must only `return;` or use `try`/error flow. To "return" values, use output parameters or debug print stubs. The codegen signature should be updated in the future to support return types.
- **Files:** `specs/tri/multilingual_codegen.vibee`, `src/vibeec/multilingual_engine.zig`
---
date: 2026-03-07T15:01:45+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/beal_simd.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/beal_simd.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/beal_simd.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
