# PreToolUse Hook — Temple Protection

**BLOCKS**: Write, Edit operations on `src/temple/**` files without TEMPLE_RITUAL

## Logic

```python
def pre_tool_use(tool_name, tool_input):
    # Check if operation affects TTT
    if tool_name in ["write", "edit"] and "src/temple/" in tool_input.get("file_path", ""):
        # Check for TEMPLE_RITUAL flag
        ritual = os.environ.get("TEMPLE_RITUAL", "0")
        ritual_label = has_label("TEMPLE_RITUAL")

        if ritual != "1" and not ritual_label:
            return {
                "allowed": False,
                "reason": "TTT (Trusted Tri Temple) is sacred. Use TEMPLE_RITUAL=1 or #TEMPLE_RITUAL label."
            }

    return {"allowed": True}
```

## Blocked Operations

- ❌ Writing to `src/temple/sacred_math.zig`
- ❌ Writing to `src/temple/tri27_core.zig`
- ❌ Writing to `src/temple/tri_lang_core.zig`
- ❌ Writing to `src/temple/tests.zig`
- ❌ Writing to `src/temple/README.md`

## Allowed Operations (with TEMPLE_RITUAL=1)

```bash
export TEMPLE_RITUAL=1
# Теперь можно редактировать
```

## Or with GitHub Label

Issue/PR must have `TEMPLE_RITUAL` label.

## Verification Required

After any TTT modification:
```bash
zig build temple
zig build temple test
```

## Implementation

This hook should be integrated into:
1. `.claude/settings.json` → `hooks.preToolUse`
2. GitHub Actions → check for `#TEMPLE_RITUAL` in commit message
3. Pre-commit hook → verify `TEMPLE_RITUAL` env var

---

**Remember**: φ² + 1/φ² = 3 | TTT is sacred 🏛
