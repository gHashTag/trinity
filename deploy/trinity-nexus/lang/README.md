# trinity-lang

**VIBEE Compiler** — Specification-driven multi-language code generation

```
phi² + 1/phi² = 3 = TRINITY
```

---

## Overview

`trinity-lang` is the **VIBEE compiler module** — a specification-driven code generator that transforms `.vibee` YAML specifications into production code for **42+ target languages**.

**Philosophy:** *ALL application code MUST be generated from .vibee specifications.*

### Key Features

- **.vibee Parser** — YAML-like specification format
- **Multi-language Codegen** — Zig, Verilog, Python, Rust, C++, JavaScript, etc.
- **Pattern-based Generation** — 141+ reusable code patterns
- **Type System** — Generic types, nested generics, options
- **Test Generation** — Auto-generate tests from behaviors
- **Safety Guards** — Math safety, null checks, bounds validation

---

## Quick Start

### Create a Specification

```yaml
# specs/tri/feature.vibee
name: my_feature
version: "1.0.0"
language: zig
module: my_feature

types:
  MyType:
    fields:
      name: String
      count: Int
      items: List<String>

behaviors:
  - name: process
    given: MyType input
    when: processing is requested
    then: returns processed result
```

### Generate Code

```bash
# Using VIBEE CLI
zig build vibee -- gen specs/tri/feature.vibee

# Output: var/trinity/output/my_feature.zig
```

### Generated Code

```zig
// ═════════════════════════════════════════════════════════════════════════
// my_feature v1.0.0 - Generated from .vibee specification
// ═════════════════════════════════════════════════════════════════════════

const std = @import("std");

pub const MyType = struct {
    name: []const u8,
    count: i64,
    items: []const []const u8,
};

pub fn process(input: MyType) !void {
    // TODO: implement — returns processed result
    _ = input;
}
```

---

## Module Structure

```
trinity-nexus/lang/src/
├── root.zig                    # Module exports
├── vibee_parser.zig            # .vibee YAML parser
├── lexer.zig                   # Lexical analysis
├── ast.zig                     # Abstract syntax tree
├── parser_v3.zig               # Parser v3
├── semantic.zig                # Semantic analysis
├── type_system.zig             # Type system
├── zig_codegen.zig             # Zig code generator
├── verilog_codegen.zig         # Verilog/FPGA codegen
├── multi_lang_codegen.zig      # Multi-language engine
├── lang_generators.zig         # 42+ language generators
├── multilingual_engine.zig     # Multilingual orchestration
├── bytecode_compiler.zig       # Bytecode compiler
├── vm_runtime.zig              # VM runtime support
├── sacred_math.zig             # Phi-based math helpers
├── simd_ternary.zig            # SIMD ternary operations
└── codegen/                    # Code generation subsystem
    ├── emitter.zig             # Main emitter engine
    ├── builder.zig             # Code builder
    ├── utils.zig               # Type mapping utilities
    ├── patterns.zig            # Pattern registry
    └── tests_gen.zig           # Test generator
```

---

## VIBEE Specification Format

### Basic Structure

```yaml
name: module_name           # Module identifier
version: "1.0.0"            # Semantic version
language: zig               # Target language
module: module_name         # Zig module name

# Type definitions
types:
  TypeName:
    fields:
      field_name: FieldType

# Behavior specifications
behaviors:
  - name: function_name
    given: Precondition
    when: Action
    then: Expected result
    implementation: |       # Optional: inline implementation
      // Zig code here
```

### Supported Types

| VIBEE Type | Zig Type | Notes |
|------------|----------|-------|
| `String` | `[]const u8` | String slice |
| `Int` | `i64` | 64-bit integer |
| `Float` | `f64` | 64-bit float |
| `Bool` | `bool` | Boolean |
| `List<T>` | `[]const T` | Slice |
| `Option<T>` | `?T` | Optional |
| `Map<K,V>` | `std.StringHashMap(V)` | Hash map |

### Nested Generics

```yaml
types:
  DoubleList:
    fields:
      items: List<List<String>>  # Generates: []const []const u8

  TripleNested:
    fields:
      data: List<List<List<Int>>>  # 3 levels deep
```

### Implementation Blocks

```yaml
behaviors:
  - name: calculate_score
    given: User and Item
    when: score calculation requested
    then: returns similarity score
    implementation: |
      pub fn calculateScore(user: User, item: Item) f32 {
          const PHI: f32 = 1.618033988749895;
          var base = cosineSimilarity(user.vector, item.vector);
          return base * PHI;
      }
```

---

## API Reference

### Parser

```zig
pub const VibeeSpec = struct {
    name: []const u8,
    version: []const u8,
    language: []const u8,
    types: []TypeDefinition,
    behaviors: []Behavior,
};

pub fn parseVibeeSpec(allocator: Allocator, content: []const u8) !VibeeSpec
```

### Code Generator

```zig
pub fn generateZigCode(allocator: Allocator, spec: VibeeSpec) ![]const u8
pub fn generateVerilogCode(allocator: Allocator, spec: VibeeSpec) ![]const u8
pub fn generatePythonCode(allocator: Allocator, spec: VibeeSpec) ![]const u8
```

### Type Mapper

```zig
// Map VIBEE type to target language type
pub fn mapType(vibee_type: []const u8) []const u8

// Extract inner type from generic
pub fn extractInnerType(generic: []const u8) ?[]const u8

// Find matching bracket for nested generics
pub fn findMatchingBracket(str: []const u8, start: usize) ?usize
```

---

## Supported Languages

| Category | Languages |
|----------|-----------|
| **Systems** | Zig, Rust, C, C++, Nim, V |
| **Scripting** | Python, JavaScript, TypeScript, Lua, PHP |
| **Functional** | Haskell, OCaml, F#, Elixir, Clojure |
| **JVM** | Java, Kotlin, Scala |
| **Web** | TypeScript, JavaScript, Dart |
| **Hardware** | Verilog, VHDL, Chisel |
| **Other** | Go, Swift, C#, Ruby, Julia, R, Scheme |

---

## Code Generation Patterns

The codegen uses 141+ patterns organized by category:

- **Constants** — Phi-based sacred math constants
- **Imports** — Standard library imports per language
- **Types** — Structs, classes, enums
- **Functions** — Methods, behaviors
- **Tests** — Unit test generation
- **Memory** — WASM buffers, heap management
- **Math** — Ternary operations, VSA ops

---

## Build & Test

```bash
# From workspace root
cd trinity-nexus

# Build lang library
zig build trinity-lang

# Run lang tests
zig build test-lang

# Parse and generate from spec
zig build vibee -- gen specs/tri/example.vibee
```

---

## Safety Features (Cycle 74)

### Math Safety Guards

```yaml
behaviors:
  - name: safeStringCompare
    implementation: |
      pub fn safeStringCompare(a: []const u8, b: []const u8) bool {
          if (a.len == 0 or b.len == 0) return a.len == b.len;
          // ... byte-by-byte comparison for small strings
      }

  - name: guardPositive
    implementation: |
      pub fn guardPositive(value: f64) !f64 {
          if (value <= 0) return error.InvalidValue;
          return value;
      }
```

### Generic Type Safety

- Bracket counting for nested generics
- Bounds validation on type extraction
- Empty string guards
- Malformed input detection

---

## Examples

### Complete Example

```yaml
# specs/tri/knowledge_graph.vibee
name: knowledge_graph
version: "2.0.0"
language: zig
module: kg

types:
  Triple:
    fields:
      subject: String
      predicate: String
      object: String
      confidence: Float

  KnowledgeGraph:
    fields:
      triples: List<Triple>
      indexed: Bool

behaviors:
  - name: add_triple
    given: KnowledgeGraph and Triple
    when: adding a triple
    then: updates graph and returns new size
    implementation: |
      pub fn addTriple(self: *KnowledgeGraph, triple: Triple) !usize {
          try self.triples.append(triple);
          self.indexed = false;
          return self.triples.items.len;
      }

  - name: find_triples
    given: KnowledgeGraph and subject query
    when: searching for matching triples
    then: returns list of matching triples
```

Generate:
```bash
zig build vibee -- gen specs/tri/knowledge_graph.vibee
# → var/trinity/output/knowledge_graph.zig
```

---

## Dependencies

- **trinity-core** — VSA operations, core types

---

## Version

```
trinity-lang v0.2.0
```

---

**φ² + 1/φ² = 3**
