# VIBEE Multi-Language Codegen

Generate production code for **9+ languages** from a single `.vibee` specification.

## Supported Languages

| Language | Extension | Status |
|----------|-----------|--------|
| Zig | `.zig` | ✅ Production |
| Python | `.py` | ✅ Production |
| TypeScript | `.ts` | ✅ Production |
| Rust | `.rs` | ✅ Production |
| Go | `.go` | ✅ Beta |
| Swift | `.swift` | ✅ Beta |
| Kotlin | `.kt` | ✅ Beta |
| Java | `.java` | ✅ Beta |
| C | `.h` | ✅ Beta |

## Quick Start

### 1. Create Specification

```yaml
# specs/tri/my_module.vibee
name: my_module
version: "1.0.0"
language: python  # or zig, typescript, rust, etc.
module: my_module

types:
  Vector:
    fields:
      x: Float
      y: Float

behaviors:
  - name: add
    given: two vectors
    when: adding them
    then: return sum
    implementation: |
        def add(a: Vector, b: Vector) -> Vector:
            return Vector(x=a.x + b.x, y=a.y + b.y)
```

### 2. Generate Code

```bash
zig build vibee -- gen specs/tri/my_module.vibee
```

### 3. Use Generated Code

```python
from my_module import Vector, add

v1 = Vector(x=1.0, y=2.0)
v2 = Vector(x=3.0, y=4.0)
result = add(v1, v2)
```

## Implementation Field

The `implementation:` field contains **native code** for the target language:

### Python Implementation
```yaml
implementation: |
    def add(a: Vector, b: Vector) -> Vector:
        return Vector(x=a.x + b.x, y=a.y + b.y)
```

### TypeScript Implementation
```yaml
implementation: |
    export function add(a: Vector, b: Vector): Vector {
        return { x: a.x + b.x, y: a.y + b.y };
    }
```

### Rust Implementation
```yaml
implementation: |
    pub fn add(a: &Vector, b: &Vector) -> Vector {
        Vector { x: a.x + b.x, y: a.y + b.y }
    }
```

## Type Mapping

| VIBEE Type | Python | TypeScript | Rust | Go |
|------------|--------|------------|------|-----|
| `String` | `str` | `string` | `String` | `string` |
| `Int` | `int` | `number` | `i64` | `int64` |
| `Float` | `float` | `number` | `f64` | `float64` |
| `Bool` | `bool` | `boolean` | `bool` | `bool` |
| `List<T>` | `List[Any]` | `any[]` | `Vec<Value>` | `[]interface{}` |
| `Option<T>` | `Optional[Any]` | `any \| null` | `Option<Value>` | `*interface{}` |

## Demo

```bash
./demo/vibee_multilang_demo.sh
```

## Production Examples

- **vsa_swarm_cluster_16.vibee** — 16-agent swarm cluster (24 behaviors, Zig)
- **llm_full_inference.vibee** — LLM inference engine (14 behaviors, Zig)
- **vsa_multilang_python.vibee** — VSA operations (Python)
