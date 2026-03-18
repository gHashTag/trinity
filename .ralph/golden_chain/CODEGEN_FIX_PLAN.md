# Code Generator Fix Plan

## 🚨 Problems Found:

### 1. Type Mapping Bugs
```zig
// WRONG:
List<Float> → []const u8
Option<List<Float>> → ?[]const u8

// CORRECT:
List<Float> → []f64
Option<List<Float>> → ?[]f64
```

### 2. Missing Behavior Generation
- Behaviors from .vibee are not generated
- Only type definitions are created

### 3. Extra Code Added
- Trit types added even when not in spec
- φ-spiral functions added when not requested

---

## 📋 Fix Tasks:

### Task 1: Fix mapType in utils.zig
**File:** `src/vibeec/codegen/utils.zig`
**Fix:** Extract inner type from `List<T>` and `Option<T>`

```zig
// Before:
if (std.mem.startsWith(u8, type_name, "List<")) {
    return "[]const u8";
}

// After:
if (std.mem.startsWith(u8, type_name, "List<")) {
    const inner = extractInnerType(type_name, "List<", ">");
    const inner_zig = mapType(inner);
    return std.fmt.allocPrint(allocator, "[]{s}", .{inner_zig});
}
```

### Task 2: Add Behavior Generation
**File:** `src/vibeec/codegen/emitter.zig`
**Add:** Generate function stubs from behaviors

```zig
fn generateBehavior(self: *Self, behavior: *const Behavior) ![]const u8 {
    // Generate function signature from given/when/then
    // Add doc comments
    // Add TODO implementation
}
```

### Task 3: Remove Extra Code
**Fix:** Only generate what's in the spec
- Don't add Trit unless specified
- Don't add φ functions unless specified

### Task 4: Add Test Generation
**File:** `src/vibeec/codegen/tests_gen.zig`
**Add:** Generate test cases from .vibee test_cases section

---

## 🧪 Test Cases:

### Test 1: ml_tensor.vibee
```bash
zig build vibee -- gen specs/tri/ml_tensor.vibee test_output.zig
zig build test test_output.zig
```

Expected:
- Tensor struct with correct types
- Functions for matmul, relu, softmax
- Tests for each behavior

### Test 2: Type Mapping
Input: `List<Float>`, `Option<List<Int>>`
Expected: `[]f64`, `?[]i64`

---

## 📊 Workflow for LLM:

### Step 1: LLM Creates Spec
- LLM creates .vibee spec from requirements
- Spec is reviewed and validated

### Step 2: Generate Code
- Run: `zig build vibee -- gen spec.vibee output.zig`
- Check for errors

### Step 3: LLM Reviews Output
- LLM checks generated code
- Identifies issues
- Suggests fixes to generator

### Step 4: Fix Generator
- Apply fixes to generator
- Re-run generation
- Verify output

### Step 5: Run Tests
- `zig build test output.zig`
- 100% test coverage required

---

## 🎯 Success Criteria:

1. ✅ `List<Float>` → `[]f64`
2. ✅ `Option<List<Float>>` → `?[]f64`
3. ✅ Behaviors generate function stubs
4. ✅ Test cases generate test functions
5. ✅ No extra code not in spec
6. ✅ All generated code compiles
7. ✅ All tests pass

---

## 📝 Next Steps:

1. Fix `mapType` function
2. Add behavior generation
3. Test with ml_tensor.vibee
4. Iterate until 100% coverage

---

**Priority:** CRITICAL
**Reason:** Code generator is the main product
**Owner:** VIBEE
