---
paths:
  - "src/**/*.zig"
  - "tools/**/*.zig"
---

# Zig Source Rules

- Format with `zig fmt` before committing
- Every public function needs a test: `test "description" { ... }`
- Use `zig test src/file.zig` for single-file testing, `zig build test` for full suite
- Prefer comptime over runtime where possible for ternary operations
- VSA operations use {-1, 0, +1} trits — never mix with binary
- Memory: use allocators explicitly, no hidden allocations
- Error handling: return error sets, not optional where the caller needs the reason
- Module imports: `@import` standard library first, then project modules
- Pipeline-first: for new features, prefer `tri pipeline run "<task>"` over direct .zig edits
- Files in `generated/` and `var/trinity/output/` are read-only — edit the .tri spec and regenerate
- If a .tri spec exists for a module, edit the spec and run `tri gen <spec>` instead
