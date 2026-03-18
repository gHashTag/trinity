---
sidebar_position: 6
---

# VIBEE API

Specification-Driven Code Generator.

**Module:** `src/vibeec/`

## CLI Commands

```bash
tri gen <spec.vibee>               # Generate Zig code
tri strict check                   # VIBEE compliance check
tri improve                        # Self-improvement engine
tri validate <file>                # Validate specs or code
```

> **See also:** [TRI CLI Reference](/cli/) for the full unified CLI, and [VIBEE Tools](/cli/vibee-tools) for all VIBEE-related commands.

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
