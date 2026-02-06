---
sidebar_position: 100
---

# Contributing to Trinity

Thank you for your interest in contributing to Trinity. This guide covers everything you need to know -- from our specification-first philosophy to the 16-step development cycle.

---

## 1. Overview

<div class="green-card">
<h4>Specification-First Development</h4>

Trinity follows a **strict specification-first paradigm**. Every line of production code is generated from `.vibee` specifications. You never write implementation code by hand.

> **ALL CODE MUST BE GENERATED FROM `.vibee` SPECIFICATIONS**

</div>

The philosophy is simple:

- **Specifications are the source of truth.** If you want to change behavior, change the spec.
- **Code generation is deterministic.** The same spec always produces the same output.
- **Testing is automatic.** Behaviors defined in specs produce tests by construction.
- **Manual code is forbidden.** The only hand-written code lives in the VIBEE compiler itself (`src/vibeec/`), documentation, and specification files.

This approach guarantees type safety, test coverage for all specified behaviors, and consistency across all 42+ supported language targets.

---

## 2. The 16-Step Development Cycle

<div class="theorem-card">
<h4>MANDATORY 16-Link Development Cycle</h4>

Every contribution -- no matter how small -- must follow the 16-step development cycle. Run `./bin/vibee koschei` to display the full cycle at any time.

**All steps are mandatory. No step may be skipped.**

</div>

The 16 steps are:

| Link | Name | Description |
|------|------|-------------|
| 1 | <span class="badge-golden">ANALYZE</span> | Study the problem domain. Read existing specs, understand the architecture, identify what needs to change. |
| 2 | <span class="badge-golden">RESEARCH</span> | Investigate prior art, mathematical foundations, and relevant algorithms. Document findings. |
| 3 | <span class="badge-golden">SPEC</span> | Write or update the `.vibee` specification in `specs/tri/`. This is the **creative step** -- all design decisions happen here. |
| 4 | <span class="badge-golden">VALIDATE</span> | Run `./bin/vibee validate specs/tri/your_spec.vibee` to check the specification for syntactic and semantic correctness. |
| 5 | <span class="badge-green">GENERATE</span> | Run `./bin/vibee gen specs/tri/your_spec.vibee` to produce implementation code in the target language. |
| 6 | <span class="badge-green">COMPILE</span> | Build the generated output: `zig build` or `zig build test` to verify it compiles without errors. |
| 7 | <span class="badge-green">TEST</span> | Run the full test suite: `zig build test`. Every behavior's test cases must pass. |
| 8 | <span class="badge-green">BENCH</span> | Run `zig build bench` to measure performance. Record baseline metrics for comparison. |
| 9 | <span class="badge-golden">ITERATE</span> | If tests fail or performance regresses, return to link 3 (SPEC) and refine. Repeat links 3-8 until green. |
| 10 | <span class="badge-golden">REVIEW</span> | Self-review the specification and generated output. Verify the design matches requirements. |
| 11 | <span class="badge-golden">VERDICT</span> | Write a **Critical Assessment** -- a brutally honest self-criticism of the work (see [Section 10](#10-critical-assessment)). |
| 12 | <span class="badge-golden">TREE</span> | Propose exactly **3 TECH TREE options** for the next iteration (see [Section 8](#8-tech-tree)). |
| 13 | <span class="badge-green">DOCUMENT</span> | Update relevant documentation if the change affects public APIs or user-facing behavior. |
| 14 | <span class="badge-green">COMMIT</span> | Create a single atomic commit following [Conventional Commits](#9-commit-convention). |
| 15 | <span class="badge-green">PR</span> | Submit a pull request referencing the relevant issue. Include the Critical Assessment and Tech Tree. |
| 16 | <span class="badge-golden">CLOSE</span> | Once merged, verify the chain is closed. All exit criteria must be satisfied. |

### Minimal Quick Cycle

For small changes, the essential links are:

```bash
# Link 3: Write specification
cat > specs/tri/feature.vibee << 'EOF'
name: feature
version: "1.0.0"
language: zig
module: feature

types:
  MyType:
    fields:
      name: String

behaviors:
  - name: my_func
    given: Input
    when: Action
    then: Result
EOF

# Link 5: Generate code
./bin/vibee gen specs/tri/feature.vibee  # -> trinity/output/feature.zig

# Link 7: Test
zig test trinity/output/feature.zig

# Link 11: Write Critical Assessment (honest self-criticism)
# Link 12: Propose 3 TECH TREE options for next iteration
```

### For Hardware (Verilog/FPGA)

```bash
# Use language: varlog in your spec
./bin/vibee gen specs/tri/feature_fpga.vibee  # -> trinity/output/fpga/feature_fpga.v
```

### Exit Criteria

<div class="formula formula-green">

**EXIT_SIGNAL = ( tests_pass AND spec_complete AND critical_assessment_written AND tech_tree_options_proposed AND committed )**

</div>

The cycle is only complete when every condition in the exit signal is true.

---

## 3. VIBEE Specification Format

<div class="green-card">
<h4>The .vibee File</h4>

`.vibee` files are YAML-based specifications that serve as the single source of truth for all generated code. One spec can target Zig, Verilog, Python, and 39 other languages.

</div>

### Complete Structure

<div class="vibee-spec">

```yaml
name: module_name            # Required: lowercase with underscores
version: "1.0.0"            # Required: semantic version
language: zig                # Required: target language (zig, varlog, python, etc.)
module: module_name          # Required: output module name
description: "Description"   # Optional: human-readable summary
author: "Name"               # Optional: author
license: "MIT"               # Optional: license identifier

constants:
  PHI: 1.6180339887498948
  TRINITY: 3
  DIMENSION: 10000
  PE_MAGIC: 0x5A4D

types:
  # Struct definition
  TypeName:
    fields:
      field1: String
      field2: Int
      field3: Bool
      field4: Float
      field5: List<String>
      field6: Option<Int>
    constraints:
      - "field2 >= 0"
      - "field2 <= 100"

  # Enum definition
  Status:
    enum:
      - active
      - inactive
      - pending

behaviors:
  - name: function_name
    given: Precondition description
    when: Action description
    then: Expected result description
    params:
      - name: input
        type: TypeName
      - name: dimension
        type: Int
    returns: TypeName
    test_cases:
      - name: test_basic
        input:
          input: {field1: "hello", field2: 42}
          dimension: 3
        expected: {field1: "result", field2: 42}
```

</div>

### Type Mappings

| VIBEE Type | Zig | Verilog | Python | Description |
|------------|-----|---------|--------|-------------|
| `String` | `[]const u8` | N/A | `str` | Text data |
| `Int` | `i64` | `integer` | `int` | Integer |
| `Float` | `f64` | `real` | `float` | Floating point |
| `Bool` | `bool` | `reg` | `bool` | Boolean |
| `Option<T>` | `?T` | N/A | `Optional[T]` | Optional value |
| `List<T>` | `[]T` | N/A | `List[T]` | Dynamic list |

### Behaviors: Given-When-Then

All behaviors use **BDD (Behavior-Driven Development)** semantics based on Given-When-Then, which maps directly to Hoare logic:

```
Given: P (precondition)    -->  {P}
When:  A (action)          -->   A
Then:  Q (postcondition)   -->  {Q}
```

Example:

```yaml
behaviors:
  - name: bind
    given: Two vectors a and b of same dimension
    when: Element-wise ternary multiplication
    then: Returns bound vector c where c[i] = a[i] * b[i]
    params:
      - name: a
        type: TritVector
      - name: b
        type: TritVector
    returns: TritVector
    test_cases:
      - name: test_bind_identity
        input:
          a: {data: [1, 0, -1], dimension: 3}
          b: {data: [1, 1, 1], dimension: 3}
        expected: {data: [1, 0, -1], dimension: 3}
```

See the full [VIBEE Specification Reference](./vibee/specification) for more detail.

---

## 4. What You Can Edit

<div class="theorem-card">
<h4>Source of Truth</h4>

The only code you should ever write by hand lives in specifications, the compiler itself, and documentation. Everything else is generated.

</div>

### Allowed to Edit

| Path | Description |
|------|-------------|
| `specs/tri/*.vibee` | **Specifications (SOURCE OF TRUTH)** -- all design work happens here |
| `src/vibeec/*.zig` | VIBEE compiler source -- the only hand-written Zig |
| `docs/*.md` | Documentation files |
| `docsite/**` | Documentation website |
| `examples/*.tri` | Example programs |
| `CLAUDE.md` | AI assistant instructions |

### Never Edit (Auto-Generated)

| Path | Reason |
|------|--------|
| `trinity/output/*.zig` | Generated from `.vibee` specs -- will be overwritten |
| `trinity/output/fpga/*.v` | Generated from `.vibee` specs -- will be overwritten |
| `generated/*.zig` | Generated from `.vibee` specs -- will be overwritten |

If you find a bug in generated code, fix the **specification** or the **compiler** -- never the output.

---

## 5. Code Style Guide

### Zig Conventions

- Use **4-space indentation** (no tabs).
- Follow the official [Zig Style Guide](https://ziglang.org/documentation/master/#Style-Guide).
- Prefer `const` over `var` whenever possible.
- Add doc comments (`///`) for all public functions.
- Use `@import("std")` -- do not alias standard library submodules at file scope unless necessary.
- Run `zig fmt src/` before committing to ensure consistent formatting.

### VIBEE Specification Conventions

- Use **lowercase_with_underscores** for module and behavior names.
- Use **PascalCase** for type names.
- Every behavior must include meaningful `given`, `when`, and `then` descriptions -- not placeholders.
- Include at least one `test_case` per behavior.
- Add `constraints` to types where invariants exist.
- Keep specifications focused: one module per `.vibee` file.

### Given/When/Then Best Practices

| Quality | Bad | Good |
|---------|-----|------|
| Specificity | `given: Input` | `given: A non-empty vector of dimension N` |
| Action clarity | `when: Processing` | `when: Computing element-wise ternary product` |
| Verifiability | `then: Returns result` | `then: Returns vector where each trit is product of corresponding input trits` |

---

## 6. Mathematical Foundation

Trinity is built on a rigorous mathematical foundation connecting the golden ratio, ternary arithmetic, and information theory.

### The Trinity Identity

<div class="formula">

**phi^2 + 1/phi^2 = 3**

</div>

Where phi = (1 + sqrt(5)) / 2 ~ 1.618 (the golden ratio). This algebraic identity connects the golden ratio to the number 3, which is the optimal integer radix.

### Parametric Constant Approximation

<div class="formula">

**V = n * 3^k * pi^m * phi^p * e^q**

</div>

Several physical constants can be closely approximated using this parameterization. See [Constant Approximation Formulas](/docs/math-foundations/formulas) for details and error analysis.

### Why Ternary?

| Property | Binary | Ternary | Advantage |
|----------|--------|---------|-----------|
| Values per digit | 2 | 3 | -- |
| Information density | 1.00 bits/digit | 1.58 bits/trit | **+58.5%** |
| Memory (vs float32) | 1x | 1/20x | **20x savings** |
| Compute model | Multiply-accumulate | Add-only | **No multiply** |
| Optimal radix | -- | Closest integer to *e* | **Mathematically optimal** |

See the full [Mathematical Foundations](./math-foundations/) section for proofs and derivations.

---

## 7. Genetic Algorithm Parameters

<div class="theorem-card">
<h4>Evolutionary Optimization Constants</h4>

The evolutionary optimization engine in Trinity uses four constants derived from the golden ratio for genetic algorithm optimization. These govern the genetic algorithm that evolves specifications and optimizes generated code.

</div>

| Constant | Symbol | Value | Derivation | Purpose |
|----------|--------|-------|------------|---------|
| **Mutation Rate** | mu | 0.0382 | 1 - 1/phi^(phi+1) | Controls random perturbation of candidate solutions. Low value ensures stability -- only ~3.8% of genes mutate per generation, preventing catastrophic loss of good traits. |
| **Crossover Rate** | chi | 0.0618 | 1/phi^3 | Governs recombination of parent solutions. At ~6.2%, crossover is selective, combining only the strongest traits from each parent while preserving individual structure. |
| **Selection Pressure** | sigma | 1.618 | phi | Determines how aggressively the fittest individuals are favored. Ensures a balanced tournament where strong candidates win but diversity is maintained. |
| **Elitism Fraction** | epsilon | 0.333 | 1/3 | The fraction of the population that survives unchanged into the next generation. Guarantees that the best third of solutions persist while leaving room for evolution. |

These constants are derived from the golden ratio and ternary base to provide a coherent set of hyperparameters. Their effectiveness should be validated empirically for each specific optimization problem.

---

## 8. Tech Tree

<div class="green-card">
<h4>Interactive Tech Tree</h4>

The Tech Tree maps all development paths in Trinity. View the full interactive version at the [Architecture Overview](./architecture/overview).

Every development cycle ends with proposing **3 TECH TREE options** -- one from each of three different branches -- giving reviewers meaningful choices for the project's direction.

</div>

### The 5 Branches

| Branch | Focus | Key Areas |
|--------|-------|-----------|
| <span class="badge-green">CORE</span> | Foundation | VSA operations, ternary VM, packed trit encoding, HybridBigInt, SDK primitives |
| <span class="badge-green">INFERENCE</span> | AI/ML | Firebird LLM engine, BitNet b1.58 integration, GGUF model loading, tokenization, transformer layers |
| <span class="badge-golden">OPTIMIZATION</span> | Performance | SIMD vectorization (AVX2/NEON), cache-friendly layouts, zero-allocation patterns, benchmark suite |
| <span class="badge-golden">DEPLOYMENT</span> | Distribution | WebAssembly targets, DePIN infrastructure, cross-platform release builds, HTTP API server, Telegram bot |
| <span class="badge-golden">HARDWARE</span> | Physical | Verilog code generation, FPGA synthesis, ternary ALU design, quantum-ready qutrit mappings, phi-engine |

### How to Propose Tech Tree Options

At the end of each development cycle (step 12), propose exactly 3 options:

```markdown
## TECH TREE

### Option A: [CORE] Extend VSA with sparse vector support
- Add sparse encoding to reduce memory for high-dimensional vectors
- Estimated effort: 2 days
- Risk: Low

### Option B: [OPTIMIZATION] AVX-512 path for trit bundling
- 2x throughput on supported hardware
- Estimated effort: 3 days
- Risk: Medium (hardware-specific)

### Option C: [DEPLOYMENT] WebAssembly streaming compilation
- Enable browser-based inference without full download
- Estimated effort: 5 days
- Risk: Medium
```

---

## 9. Commit Convention

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/) format.

### Prefixes

| Prefix | Usage | Example |
|--------|-------|---------|
| `feat:` | New feature or specification | `feat: add ternary matrix multiplication spec` |
| `fix:` | Bug fix in spec or compiler | `fix: correct off-by-one in trit packing` |
| `docs:` | Documentation changes | `docs: update VSA API reference` |
| `refactor:` | Code restructuring (compiler only) | `refactor: simplify codegen pipeline` |
| `test:` | Test additions or changes | `test: add edge cases for bind operation` |
| `perf:` | Performance improvements | `perf: SIMD-accelerate bundle3 operation` |
| `chore:` | Build, CI, tooling changes | `chore: update Zig to 0.13.0` |

### Commit Message Format

```
<type>: <short summary in imperative mood>

<optional body: explain WHY, not WHAT>

<optional footer: references, breaking changes>
```

### Example

```
feat: add ternary matrix multiplication spec

- Add specs/tri/matmul.vibee with SIMD-aware behaviors
- Includes test cases for AVX2 and NEON paths
- Supports dimensions up to 10000x10000

Refs: #42
```

### Rules

- Use **imperative mood** in the summary line ("add", not "added" or "adds").
- Keep the summary line under 72 characters.
- Reference related issues in the footer.
- One logical change per commit. Do not combine unrelated changes.

---

## 10. Critical Assessment

<div class="theorem-card">
<h4>Mandatory Self-Criticism</h4>

Every development cycle **must** include a Critical Assessment -- a brutally honest assessment of the work's weaknesses. This is not optional. No PR will be accepted without one.

</div>

The Critical Assessment serves three purposes:

1. **Intellectual honesty** -- forces you to confront what you glossed over.
2. **Review efficiency** -- reviewers know exactly where to look for problems.
3. **Iteration fuel** -- weaknesses identified here feed directly into the next cycle's Tech Tree options.

### Format

```markdown
## CRITICAL ASSESSMENT

### What went wrong
- [Specific technical weakness #1]
- [Specific technical weakness #2]
- [What was left incomplete or hacky]

### What I would do differently
- [Concrete alternative approach]
- [Better design decision]

### Honest assessment
[1-3 sentences of unflinching self-evaluation. No hedging, no softening.]
```

### Example

```markdown
## CRITICAL ASSESSMENT

### What went wrong
- The sparse vector encoding wastes 12% memory on vectors with density > 0.4
- No benchmarks for the NEON path -- only tested on x86_64
- The constraint validation generates O(n^2) checks; should be O(n)

### What I would do differently
- Use run-length encoding instead of index lists for dense regions
- Set up CI with ARM runners before claiming cross-platform support

### Honest assessment
This implementation works but is mediocre. The happy path is solid, but edge
cases around zero-heavy vectors are undertested and the performance claims are
unsubstantiated on ARM. Needs another full iteration before production use.
```

---

## 11. CLI Commands

Quick reference for all Trinity CLI commands used during development.

### Build Commands

| Command | Description |
|---------|-------------|
| `zig build` | Compile library and all executables |
| `zig build firebird` | Build Firebird LLM CLI (ReleaseFast) |
| `zig build release` | Cross-platform release builds (linux/macos/windows) |

### Test Commands

| Command | Description |
|---------|-------------|
| `zig build test` | Run ALL tests (trinity, vsa, vm, firebird, wasm, depin) |
| `zig test src/vsa.zig` | Run VSA tests only |
| `zig test src/vm.zig` | Run VM tests only |
| `zig test src/firebird/b2t_integration.zig` | Firebird integration tests |

### Benchmark and Examples

| Command | Description |
|---------|-------------|
| `zig build bench` | Run performance benchmarks |
| `zig build examples` | Build and run all examples |

### Format

| Command | Description |
|---------|-------------|
| `zig fmt src/` | Format all Zig source code |

### VIBEE Compiler

| Command | Description |
|---------|-------------|
| `./bin/vibee gen <spec.vibee>` | Generate code from specification |
| `./bin/vibee gen-multi <spec> all` | Generate for all 42 supported languages |
| `./bin/vibee validate <spec.vibee>` | Validate specification syntax and semantics |
| `./bin/vibee run <file.999>` | Execute via bytecode VM |
| `./bin/vibee koschei` | Display the full development cycle |
| `./bin/vibee chat --model <path>` | Interactive chat with a model |
| `./bin/vibee serve --port 8080` | Start the HTTP API server |

---

## 12. Community

### Getting Help

- **GitHub Issues**: [github.com/gHashTag/trinity/issues](https://github.com/gHashTag/trinity/issues) -- bug reports, feature requests, and questions.
- **GitHub Discussions**: [github.com/gHashTag/trinity/discussions](https://github.com/gHashTag/trinity/discussions) -- open-ended conversations and ideas.
- **Telegram**: Join the Trinity community chat for real-time discussion and support.

### Submitting a Pull Request

1. **Fork** the repository and clone your fork.
2. **Create a branch**: `git checkout -b feat/my-feature`
3. **Follow the 16-step development cycle**.
4. **Push** your branch: `git push origin feat/my-feature`
5. **Open a PR** against `main` with the following template:

```markdown
## Summary
Brief description of changes.

## Specification
Link to the .vibee file(s) added or modified.

## Testing
How the changes were tested. Include test output.

## CRITICAL ASSESSMENT
[Your honest self-criticism]

## TECH TREE
[Your 3 options for next iteration]
```

### Code of Conduct

- Be respectful and constructive.
- Focus criticism on code and design, never on people.
- The Critical Assessment is for **self**-criticism only -- never direct it at others.
- Assume good intent. Ask clarifying questions before judging.

### Documentation Website

The documentation site is hosted at [https://trinity-site-ghashtag.vercel.app](https://trinity-site-ghashtag.vercel.app). It auto-deploys from the `main` branch. The site source lives in `docsite/` and uses Docusaurus.

### Useful Links

| Resource | Link |
|----------|------|
| Repository | [github.com/gHashTag/trinity](https://github.com/gHashTag/trinity) |
| Documentation | [trinity-site-ghashtag.vercel.app](https://trinity-site-ghashtag.vercel.app) |
| VIBEE Guide | [/docs/vibee](./vibee/) |
| Mathematical Foundations | [/docs/math-foundations](./math-foundations/) |
| API Reference | [/docs/api](./api/) |
| Architecture | [/docs/architecture/overview](./architecture/overview) |

