# Trinity Specifications

VIBEE specification files for Trinity Network components.

## Structure

```
specs/
├── core/           # Core VSA operations
├── vsa/            # Vector Symbolic Architecture
├── network/        # Trinity Network protocols
└── examples/       # Example specifications
```

## Format

```yaml
name: module_name
version: "1.0.0"
language: zig
module: module_name

types:
  TypeName:
    fields:
      field1: String
      field2: Int

behaviors:
  - name: function_name
    given: Precondition
    when: Action
    then: Result
```

## Usage

```bash
# Generate Zig code from spec
./bin/vibee gen specs/core/trit_vector.vibee

# Output: trinity/output/trit_vector.zig
```

## Type Mapping

| VIBEE Type | Zig Type |
|------------|----------|
| String | `[]const u8` |
| Int | `i64` |
| Float | `f64` |
| Bool | `bool` |
| List<T> | `[]const T` |
| Option<T> | `?T` |
