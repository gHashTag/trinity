# VIBEE Specification Format

Complete reference for `.vibee` specification files.

## File Structure

Every `.vibee` file follows this YAML structure:

```yaml
name: module_name
version: "1.0.0"
language: zig          # Target language
module: module_name    # Output module name

constants:
  KEY: value

types:
  TypeName:
    fields:
      field1: Type
    constraints:
      - "validation rule"

behaviors:
  - name: function_name
    given: Precondition
    when: Action
    then: Expected result
    params:
      - name: param1
        type: Type
    test_cases:
      - name: test_name
        input: {...}
        expected: {...}
```

## Header Section

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Specification name (lowercase, underscores) |
| `version` | String | Semantic version ("1.0.0") |
| `language` | String | Target: `zig`, `varlog`, `python`, etc. |
| `module` | String | Output module name |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `description` | String | Human-readable description |
| `author` | String | Author name |
| `license` | String | License identifier |

## Constants Section

Define compile-time constants:

```yaml
constants:
  PHI: 1.6180339887498948
  TRINITY: 3
  DIMENSION: 10000
  PE_MAGIC: 0x5A4D
```

Constants can be:
- **Numbers**: Integer or floating-point
- **Strings**: Quoted text
- **Hex**: Prefixed with `0x`

## Types Section

### Basic Types

| VIBEE Type | Zig | Verilog | Python |
|------------|-----|---------|--------|
| `String` | `[]const u8` | N/A | `str` |
| `Int` | `i64` | `integer` | `int` |
| `Float` | `f64` | `real` | `float` |
| `Bool` | `bool` | `reg` | `bool` |
| `Option<T>` | `?T` | N/A | `Optional[T]` |
| `List<T>` | `[]T` | N/A | `List[T]` |

### Struct Definition

```yaml
types:
  Point:
    fields:
      x: Float
      y: Float
      z: Float
```

Generates (Zig):
```zig
pub const Point = struct {
    x: f64,
    y: f64,
    z: f64,
};
```

### Enum Definition

```yaml
types:
  BinaryFormat:
    enum:
      - pe64
      - elf64
      - macho64
      - wasm
```

Generates (Zig):
```zig
pub const BinaryFormat = enum {
    pe64,
    elf64,
    macho64,
    wasm,
};
```

### Constraints

```yaml
types:
  TritValue:
    fields:
      value: Int
    constraints:
      - "value >= -1"
      - "value <= 1"
```

### Hardware Types (Verilog)

For `language: varlog`:

```yaml
types:
  Register:
    fields:
      data: Int
    width: 8          # Bit width
    direction: input  # input/output/inout
```

## Behaviors Section

Behaviors follow **Given-When-Then** (BDD) semantics:

```yaml
behaviors:
  - name: bind
    given: Two vectors a and b of same dimension
    when: Binding (element-wise multiplication)
    then: Returns vector c where c[i] = a[i] * b[i]
```

### Full Behavior Structure

```yaml
behaviors:
  - name: function_name
    given: Precondition description
    when: Action description
    then: Expected result
    params:
      - name: input
        type: Vector
      - name: dimension
        type: Int
    returns: Vector
    test_cases:
      - name: test_basic
        input:
          input: [1, 0, -1]
          dimension: 3
        expected: [1, 0, -1]
```

### Hardware Signals (Verilog)

```yaml
signals:
  - name: clk
    width: 1
    direction: input
  - name: data_out
    width: 8
    direction: output
  - name: data_bus
    width: 32
    direction: inout
```

## Language Targets

### Zig (Default)

```yaml
language: zig
```
Output: `trinity/output/*.zig`

### Verilog (FPGA)

```yaml
language: varlog
```
Output: `trinity/output/fpga/*.v`

### Multi-language

```bash
./bin/vibee gen-multi specs/tri/feature.vibee all
```

Generates for all 42 supported languages.

## Example: Complete Specification

```yaml
name: trit_vector
version: "1.0.0"
language: zig
module: trit_vector
description: High-dimensional ternary vector operations

constants:
  DEFAULT_DIM: 10000
  VALID_VALUES: [-1, 0, 1]

types:
  Trit:
    fields:
      value: Int
    constraints:
      - "value >= -1"
      - "value <= 1"

  TritVector:
    fields:
      data: List<Int>
      dimension: Int

behaviors:
  - name: create
    given: A dimension size
    when: Creating a new vector
    then: Returns zeroed TritVector of given dimension
    params:
      - name: dim
        type: Int
    returns: TritVector

  - name: bind
    given: Two TritVectors of same dimension
    when: Performing element-wise multiplication
    then: Returns bound vector
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

## CLI Commands

```bash
# Generate Zig code
./bin/vibee gen specs/tri/feature.vibee

# Generate for all languages
./bin/vibee gen-multi specs/tri/feature.vibee all

# Validate specification
./bin/vibee validate specs/tri/feature.vibee

# Show Golden Chain workflow
./bin/vibee koschei
```
