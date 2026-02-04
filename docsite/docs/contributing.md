---
sidebar_position: 101
---

# Contributing

Thank you for your interest in contributing to Trinity!

## Development Philosophy

Trinity follows **specification-first development**:

> **ALL CODE MUST BE GENERATED FROM `.vibee` SPECIFICATIONS**

Never write code manually. Write specifications, generate code.

## The Golden Chain (16-Link Development Cycle)

Every contribution follows the Golden Chain workflow:

```
1. ANALYZE    → Understand the problem
2. SPEC       → Write .vibee specification
3. GENERATE   → ./bin/vibee gen spec.vibee
4. TEST       → zig test output.zig
5. ITERATE    → Fix spec if tests fail
6. VERDICT    → Write TOXIC VERDICT (self-criticism)
7. TREE       → Propose 3 TECH TREE options
8. COMMIT     → Single atomic commit
```

Run `./bin/vibee koschei` to see the full Golden Chain.

## Quick Start

### 1. Fork and Clone

```bash
git clone https://github.com/YOUR_USERNAME/trinity.git
cd trinity
```

### 2. Verify Zig Version

```bash
zig version  # Must be 0.13.0
```

### 3. Write a Specification

```yaml title="specs/tri/my_feature.vibee"
name: my_feature
version: "1.0.0"
language: zig
module: my_feature

types:
  MyType:
    fields:
      value: Int

behaviors:
  - name: process
    given: Valid input
    when: Processing
    then: Returns result
```

### 4. Generate and Test

```bash
./bin/vibee gen specs/tri/my_feature.vibee
zig test trinity/output/my_feature.zig
```

### 5. Submit Pull Request

```bash
git checkout -b feat/my-feature
git add specs/tri/my_feature.vibee
git commit -m "feat: add my_feature specification"
git push origin feat/my-feature
```

## What You Can Edit

### Allowed

| Path | Description |
|------|-------------|
| `specs/tri/*.vibee` | **Specifications (SOURCE OF TRUTH)** |
| `src/vibeec/*.zig` | Compiler source only |
| `docs/*.md` | Documentation |
| `examples/*.tri` | Example programs |

### Never Edit (Auto-Generated)

| Path | Reason |
|------|--------|
| `trinity/output/*.zig` | Generated from .vibee |
| `trinity/output/fpga/*.v` | Generated from .vibee |
| `generated/*.zig` | Generated from .vibee |

## VIBEE Specification Format

### Basic Structure

```yaml
name: module_name
version: "1.0.0"
language: zig
module: module_name

constants:
  KEY: value

types:
  TypeName:
    fields:
      field1: Type

behaviors:
  - name: function_name
    given: Precondition
    when: Action
    then: Expected result
```

### Types

| VIBEE | Zig | Description |
|-------|-----|-------------|
| `String` | `[]const u8` | Text |
| `Int` | `i64` | Integer |
| `Float` | `f64` | Floating point |
| `Bool` | `bool` | Boolean |
| `Option<T>` | `?T` | Optional |
| `List<T>` | `[]T` | List/array |

### Behaviors (Given-When-Then)

All behaviors use BDD semantics:

```yaml
behaviors:
  - name: bind
    given: Two vectors of same dimension
    when: Binding operation
    then: Returns element-wise product
```

See [VIBEE Specification](./vibee/specification) for full reference.

## Code Style

### Zig

- Use 4-space indentation
- Follow [Zig Style Guide](https://ziglang.org/documentation/master/#Style-Guide)
- Add doc comments for public functions
- Use `const` over `var` when possible

### VIBEE Specifications

- Use lowercase with underscores for names
- Include meaningful `given`/`when`/`then` descriptions
- Add test cases in behaviors
- Use constraints for validation

## Testing

```bash
# Run all tests
zig build test

# Test specific module
zig test src/vsa.zig

# Test generated code
zig test trinity/output/my_feature.zig

# Run benchmarks
zig build bench
```

## Commit Messages

Use conventional commits:

| Prefix | Usage |
|--------|-------|
| `feat:` | New feature or specification |
| `fix:` | Bug fix |
| `docs:` | Documentation changes |
| `refactor:` | Code refactoring |
| `test:` | Test additions |
| `perf:` | Performance improvements |

Example:
```
feat: add ternary matrix multiplication spec

- Add specs/tri/matmul.vibee with SIMD support
- Includes test cases for AVX2 path
```

## Pull Request Process

1. **Create issue** describing the feature/fix
2. **Write specification** in `specs/tri/`
3. **Generate code** with VIBEE
4. **Run tests** - all must pass
5. **Write TOXIC VERDICT** - honest self-criticism
6. **Propose TECH TREE** - 3 options for next steps
7. **Submit PR** with issue reference

### PR Template

```markdown
## Summary
Brief description of changes

## Specification
Link to .vibee file

## Testing
How it was tested

## TOXIC VERDICT
Honest self-criticism

## TECH TREE
Three options for future work
```

## Sacred Math Principles

Trinity development respects sacred mathematics:

<div class="formula formula-golden">

**φ² + 1/φ² = 3**

</div>

- **Ternary values**: {-1, 0, +1}
- **Information density**: 1.58 bits/trit
- **Golden ratio**: φ = 1.618...

See [Sacred Mathematics](./sacred-math/) for details.

## Getting Help

- **GitHub Issues**: [github.com/gHashTag/trinity/issues](https://github.com/gHashTag/trinity/issues)
- **Documentation**: This site
- **VIBEE Guide**: [/docs/vibee](./vibee/)

## Exit Criteria

Your contribution is complete when:

```
EXIT_SIGNAL = (
    tests_pass AND
    spec_complete AND
    toxic_verdict_written AND
    tech_tree_options_proposed AND
    committed
)
```

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**
