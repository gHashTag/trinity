# VIBEE API Reference

> Specification-Driven Code Generator

**Module:** `src/vibeec/`

---

## Overview

VIBEE is a specification compiler that generates code from `.vibee` declarative specifications. It supports 42+ target languages including Zig, Verilog, Python, and more.

---

## CLI Commands

### Generate Code

```bash
./bin/vibee gen <spec.vibee>           # Generate Zig (default)
./bin/vibee gen <spec.vibee> --lang py # Generate Python
./bin/vibee gen-multi <spec> all       # Generate for all 42 languages
```

### Run via VM

```bash
./bin/vibee run <file.999>             # Execute via bytecode VM
```

### Show Golden Chain

```bash
./bin/vibee koschei                    # Display development methodology
```

### Chat/Server

```bash
./bin/vibee chat --model <path>        # Interactive chat
./bin/vibee serve --port 8080          # HTTP server
```

---

## Specification Format

### Basic Structure

```yaml
name: module_name
version: "1.0.0"
language: zig          # Target: zig, varlog, python, etc.
module: module_name

types:
  TypeName:
    fields:
      field1: String
      field2: Int
      field3: Bool
      field4: Float
      field5: List<String>
      field6: Option<Int>

behaviors:
  - name: function_name
    given: Precondition description
    when: Action description
    then: Expected result
```

### Supported Types

| Type | Description |
|------|-------------|
| `String` | Text string |
| `Int` | Integer |
| `Float` | Floating point |
| `Bool` | Boolean |
| `List<T>` | Array of T |
| `Option<T>` | Nullable T |
| `Map<K,V>` | Key-value map |

### Example Specification

```yaml
name: user_service
version: "1.0.0"
language: zig
module: user

types:
  User:
    fields:
      id: Int
      name: String
      email: String
      active: Bool

  CreateUserRequest:
    fields:
      name: String
      email: String

behaviors:
  - name: create_user
    given: Valid CreateUserRequest
    when: User creation is requested
    then: Returns new User with generated ID
```

---

## Core Modules

### vibee_parser.zig

Parses `.vibee` specifications.

```zig
const parser = @import("vibeec/vibee_parser.zig");

var spec = try parser.parse(allocator, source);
defer spec.deinit();
```

### zig_codegen.zig

Generates Zig code from specifications.

```zig
const codegen = @import("vibeec/zig_codegen.zig");

const code = try codegen.generate(allocator, spec);
```

### verilog_codegen.zig

Generates Verilog for FPGA.

```zig
const vcodegen = @import("vibeec/verilog_codegen.zig");

const verilog = try vcodegen.generate(allocator, spec);
```

---

## Output Directories

| Language | Output Path |
|----------|-------------|
| Zig | `trinity/output/*.zig` |
| Verilog | `trinity/output/fpga/*.v` |
| Python | `trinity/output/py/*.py` |
| Other | `trinity/output/<lang>/*` |

---

## Golden Chain Development

The Koschei methodology (16-link cycle):

1. Create `.vibee` specification
2. Generate code: `./bin/vibee gen spec.vibee`
3. Run tests: `zig test trinity/output/module.zig`
4. Write TOXIC VERDICT (self-criticism)
5. Propose 3 TECH TREE options

```bash
# View methodology
./bin/vibee koschei
```

---

## Exit Criteria

```
EXIT_SIGNAL = (
    tests_pass AND
    spec_complete AND
    toxic_verdict_written AND
    tech_tree_options_proposed AND
    committed
)
```

---

## See Also

- [PLUGIN_API.md](PLUGIN_API.md) — Plugin extensions
- [../architecture/ARCHITECTURE.md](../architecture/ARCHITECTURE.md) — System design
