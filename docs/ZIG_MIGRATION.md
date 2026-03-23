# Zig 0.15 Migration Guide

> **Trinity Project** — Pure Zig autonomous AI agent swarm
> **Target:** Zig 0.15.x compatibility
> **Updated:** 2026-03-23

## Overview

This document tracks Zig 0.14 → 0.15 migration issues found during development
and provides fixes for each breaking change.

---

## Breaking Changes

### 1. While Loop Continuation Syntax

**Zig 0.14:**
```zig
while (condition) : (update_expr) : (else_update_expr) {
    // body
}
```

**Zig 0.15:**
```zig
while (condition) {
    // body
    update_expr;
    else_update_expr;  // if needed
}
```

**Affected files:**
- `src/tri27/tri27_cli.zig` (line 163) - uses ternary continuation syntax

**Fix:**
```zig
// Before (0.14):
while (offset + 4 <= bytecode.len) : (offset += 4) : (addr += 1) {

// After (0.15):
while (offset + 4 <= bytecode.len) {
    offset += 4;
    addr += 1;
    // body continues
}
```

---

### 2. std.process.argsAlloc Signature

**Zig 0.14:**
```zig
var args = std.process.argsAlloc(allocator, std.process.RetainCollapse) catch |e| {
```

**Zig 0.15:**
```zig
var args = std.process.argsAlloc(allocator) catch |e| {
```

**Affected files:**
- `src/tri27/tri27_cli.zig` (line 461)

**Fix:**
Remove `std.process.RetainCollapse` parameter.

---

### 3. std.mem.readInt Type Parameter

**Zig 0.14:**
```zig
const value = std.mem.readInt(u16, bytes[0..2], .little) catch 0;
```

**Zig 0.15:**
The function signature changed - type parameter is now explicit comptime.

**Affected files:**
- `src/tri27/tri27_cli.zig` (line 153) - `std.mem.readInt(u16, ...)`

**Fix:**
```zig
// If the function expects error union, wrap in try/catch or use proper signature
const code_size = std.mem.readInt(u16, bytecode[8..10], .little);
// Note: readInt cannot fail in Zig 0.15, so remove 'catch 0'
```

---

### 4. Variable Redeclaration in Same Scope

**Issue:** Multiple `var i` declarations in same function scope cause redeclaration errors.

**Affected files:**
- `src/tri27/tri27_cli.zig` (lines 264, 303, 311)

**Fix:** Use different variable names for different loop contexts:
```zig
// Flag parsing loop
var flag_idx: usize = 1;
while (flag_idx < args.len) : (flag_idx += 1) { ... }

// Register dump loop
var reg_idx: u8 = 0;
while (reg_idx < 27) : (reg_idx += 1) { ... }

// Non-zero register loop
var nz_idx: u8 = 0;
while (nz_idx < 27) : (nz_idx += 1) { ... }
```

---

## Files Requiring Migration

| File | Status | Issues |
|------|--------|--------|
| `src/tri27/tri27_cli.zig` | ⚠️ PARTIAL | 4 issues documented above |
| `src/tri/main.zig` | ✅ OK | No 0.15 issues |
| `src/tri/queen_trinity.zig` | ✅ OK | No 0.15 issues |
| `build.zig` | ✅ OK | No 0.15 issues |

---

## Migration Checklist

When migrating a file from Zig 0.14 to 0.15:

- [ ] Update `while` loop continuation syntax
- [ ] Remove `std.process.RetainCollapse` from `argsAlloc`
- [ ] Check `std.mem.readInt` usage (remove `catch` for non-failing functions)
- [ ] Check for variable redeclaration in same scope
- [ ] Run `zig fmt` on file
- [ ] Run `zig build test` to verify
- [ ] Test all CLI commands

---

## Resources

- Zig 0.15 Release Notes: https://ziglang.org/download/0.15.2/release-notes.html
- Zig Standard Library Docs: https://ziglang.org/documentation/master/std/
- Trinity Build: `zig build` (uses Zig 0.15.2)

---

## Notes

- All new code should be written for Zig 0.15+ compatibility
- Legacy code may remain in 0.14 state until explicitly migrated
- This document should be updated as new 0.15 issues are discovered
