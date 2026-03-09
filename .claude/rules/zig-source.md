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
