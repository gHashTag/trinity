---
sidebar_position: 6
---

# VIBEE API

Specification-Driven Code Generator.

**Module:** `src/vibeec/`

## CLI Commands

```bash
./bin/vibee gen <spec.vibee>       # Generate Zig
./bin/vibee run <program.999>      # Execute via VM
./bin/vibee koschei                # Development cycle
```

## Specification Format

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
    then: Expected result
```

## Supported Types

| Type | Description |
|------|-------------|
| `String` | Text string |
| `Int` | Integer |
| `Float` | Floating point |
| `Bool` | Boolean |
| `List<T>` | Array |
| `Option<T>` | Nullable |
