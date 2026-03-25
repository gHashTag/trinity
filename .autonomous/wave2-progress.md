# Wave 2: Type System + emit_t27

## Goal
Build a production-ready type system and TRI-27 bytecode emitter on top of Wave 1 runtime (VM + ADT).

## Precondition ✅
- Wave 1 COMPLETE: VM stable, Copic registers working, ADT enum + match implemented
- All builds green: L0 ✅ L1 ✅ tri ✅

---

## Phase 1: Type System Core

### 1.1 Type Representation ✅ COMPLETE
- [x] `src/tri-lang/types.zig` — core type definitions
  - [x] `Type` enum — Unit, Bool, Int, Float, Fn, ADT, Var
  - [x] `TypeEq` — type equality with variance
  - [x] `Type.subst()` — substitution for type variables
  - [x] `Type.ftv()` — free type variables

**Solution:** Used `std.array_list.Managed(T)` instead of `std.ArrayList(T)` for Zig 0.15 compatibility.

### 1.2 Type Environment
- [ ] `src/tri-lang/type_env.zig` — typing context
  - [ ] `TypeEnv` — map from names to Type schemes
  - [ ] `TypeEnv.extend()` — add binding
  - [ ] `TypeEnv.lookup()` — resolve name
  - [ ] `TypeEnv.instantiate()` — instantiate scheme

### 1.3 Unification
- [ ] `src/tri-lang/unify.zig` — Hindley-Milner unification
  - [ ] `unify(t1, t2)` — unify two types
  - [ ] `Occurs check` — prevent infinite types
  - [ ] Error reporting with type diff

---

## Phase 2: Typechecker

### 2.1 Expression Typing
- [ ] `src/tri-lang/typechecker.zig`
  - [ ] `infer(expr, env)` — infer expression type
  - [ ] Lit<int> → Int
  - [ ] Lit<bool> → Bool
  - [ ] Var(x) → lookup in env
  - [ ] Binop(e1, op, e2) → unify
  - [ ] If(cond, t, f) — bool cond, unify branches
  - [ ] Let(x, v, body) — generalize + extend

### 2.2 Function Typing
- [ ] Fn(params, body) — ∀-quantification
- [ ] FnCall(fn, args) — check arity, unify args
- [ ] Closure capture typing

### 2.3 ADT Typing
- [ ] ADT value typing — check variant exists
- [ ] Match exhaustiveness — compile-time check
- [ ] Pattern typing — bind vars in branches

---

## Phase 3: emit_t27 (Bytecode Generation)

### 3.1 Codegen Interface
- [ ] `src/tri27/codegen.zig`
  - [ ] `Codegen` struct — holds code buffer, env
  - [ ] `emit(opcode)` — append bytecode
  - [ ] `emit_word(value)` — append immediate

### 3.2 Expression Compilation
- [ ] `compile_expr(expr, cg)` → code + stack delta
  - [ ] Lit<int> → LOADI
  - [ ] Lit<bool> → LOADB
  - [ ] Var(x) → MOV reg, [offset]
  - [ ] Binop → load args, OP, store result
  - [ ] If → JGT/JLT for branches

### 3.3 Function Compilation
- [ ] `compile_fn(fn, cg)` — entry + body + ret
- [ ] Call convention — stack or reg-based
- [ ] Closure layout — code + env ptr

### 3.4 Match Compilation
- [ ] Jump tables for ADT variants
- [ ] Pattern guards → JGT/JLT chains
- [ ] Default case for exhaustiveness

---

## Phase 4: End-to-End Integration

### 4.1 Pipeline
- [ ] `src/tri-lang/pipeline.zig`
  - [ ] Parse → Typecheck → Emit → Link
  - [ ] Error aggregation (multi-error)
  - [ ] Source map for debugging

### 4.2 Testing
- [ ] `tests/wave2/typecheck_test.tri` — type inference
- [ ] `tests/wave2/emit_test.tri` — bytecode roundtrip
- [ ] `tests/wave2/e2e_test.tri` — full pipeline

---

## Phase 5: Documentation

### 5.1 Spec
- [ ] `docs/tri-lang/type-system.md` — formal typing rules
- [ ] `docs/tri27/emit_t27.md` — bytecode encoding
- [ ] `docs/wave2/progress.md` — track completion

### 5.2 Examples
- [ ] `examples/wave2/fib.tri` — typed fibonacci
- [ ] `examples/wave2/adt.tri` — Option<T> usage
- [ ] `examples/wave2/match.tri` — exhaustive patterns

---

## Invariants

- L0 (Temple): ✅ MUST NOT TOUCH
- L1 (Queens): ✅ MUST BUILD GREEN
- Wave 1 runtime: ✅ MUST NOT BREAK

## Metrics

| Phase | Est. LOC | Tests | Status |
|-------|----------|-------|--------|
| 1. Type Core | ~200 | 15 | ⏳ TODO |
| 2. Typechecker | ~300 | 25 | ⏳ TODO |
| 3. emit_t27 | ~250 | 20 | ⏳ TODO |
| 4. Integration | ~150 | 10 | ⏳ TODO |
| 5. Docs | ~100 | — | ⏳ TODO |
| **Total** | **~1000** | **70** | ⏳ TODO |

## Success Criteria

1. `zig build tri` ✅ (no regression)
2. `zig test src/tri-lang/type*` ✅ (all pass)
3. `zig test src/tri27/codegen*` ✅ (all pass)
4. Full `examples/wave2/*.tri` → `.tbin` → VM execution ✅

## References

- Wave 1: `.autonomous/wave1-progress.md`
- Issue #418: TDGS-3 tracking
- Temple: `src/temple/tri_lang_core.zig` (do NOT modify)
