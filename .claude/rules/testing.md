---
paths:
  - "src/**/*test*"
  - "src/**/tests/**"
---

# Testing Rules

- Tests live in the same file as source (Zig convention): `test "description" { ... }`
- Run tests: `zig build test` or `tri test`
- Pipeline Link 9 (test_run) runs tests automatically
- Pipeline Link 11 (swe_fix) auto-retries 3x on failure with spec regeneration
- Manual test fix only after 3x pipeline retry failure
- Never skip failing tests — fix the root cause
