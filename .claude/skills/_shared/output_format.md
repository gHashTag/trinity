## Output Format (shared module)

### Usage in SKILL.md
Reference this module for consistent dashboard formatting:
> For output formatting conventions, follow `.claude/skills/_shared/output_format.md`.

### Severity Indicators

| Level | Emoji | Usage |
|-------|-------|-------|
| PASS / OK | ✅ | Check passed, healthy |
| WARNING | ⚠️ | Non-critical issue, degraded |
| CRITICAL / FAIL | ❌ | Broken, needs immediate fix |
| INFO | ℹ️ | Neutral information |
| SKIP | ⏭️ | Intentionally skipped |
| UP | 🟢 | Process/service running |
| DOWN | 🔴 | Process/service stopped |
| STALE | 🟡 | Data outdated |

### Section Structure

All dashboard skills follow this pattern:

1. **Verdict line** — single-line summary with emoji + score/status
2. **Data sections** — grouped by topic, each with header emoji
3. **Tables** — for structured data (metrics, services, issues)
4. **Recommendations** — actionable next steps at the bottom
5. **Signature** — skill identifier in brackets: `[emoji skill-name]`

### Quick vs Full Mode

| Aspect | Quick | Full |
|--------|-------|------|
| Length | 10-20 lines | 50-200 lines |
| Tables | Summary only | Detailed per-item |
| History | Last value | Trend/sparkline |
| Recommendations | Top 1-2 | All with rationale |
| Telegram | Always send | Optional |

### Telegram Constraints

- Max message length: 4096 characters (Telegram API limit)
- Parse mode: HTML (set automatically by `tri notify`)
- No markdown in Telegram — use plain text or HTML tags
- Strip mood signature before sending (handled by telegram.md)
- Use dedup mode for recurring dashboards to avoid spam

### Table Formatting

```
| Column | Column | Column |
|--------|--------|--------|
| value  | value  | value  |
```

- Align columns with spaces
- Use emoji prefixes for status columns: ✅/❌/⚠️
- Keep column count ≤ 5 for readability
- Truncate long values with `...`
