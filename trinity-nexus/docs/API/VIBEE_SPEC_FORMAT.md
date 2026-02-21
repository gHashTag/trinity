# VIBEE Specification Format

## Basic Structure

```yaml
name: module_name
version: "1.0.0"
language: zig | varlog
module: module_name

types:
  TypeName:
    fields:
      field1: Type

behaviors:
  - name: behavior_name
    given: Precondition
    when: Action
    then: Result
```

---

## Language Targets

| Target | Output |
|--------|--------|
| `language: zig` | `trinity/output/*.zig` |
| `language: varlog` | `trinity/output/fpga/*.v` |

---

## Type Mapping

| VIBEE | Zig | Verilog |
|-------|-----|---------|
| String | `[]const u8` | N/A |
| Int | `i64` | `integer` |
| Float | `f64` | `real` |
| Bool | `bool` | `reg` |
| Option<T> | `?T` | N/A |
| List<T> | `[]T` | N/A |

---

## Hardware Types (Verilog)

```yaml
types:
  DataWord:
    fields:
      value: Int
    width: 32
    signed: true
```

---

## Ports (FPGA)

```yaml
ports:
  inputs:
    clk: {width: 1}
    data_in: {width: 8}
  outputs:
    data_out: {width: 8}
```

---

## Behaviors

```yaml
behaviors:
  - name: ternary_mac
    given: "Weight w in {-1, 0, +1}"
    when: "MAC requested"
    then: "accumulator += w * x"
    implementation: |
      always @(posedge clk) begin
        case (weight)
          2'b01: result <= result + activation;
          2'b10: result <= result - activation;
        endcase
      end
```

---

## Code Generation

```bash
./bin/vibee gen specs/fpga/module.vibee
```
