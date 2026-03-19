# VIBEE Examples

Practical examples of `.vibee` specifications for different use cases.

## 1. Simple Trit Type

The foundational ternary type:

```yaml title="specs/core/trit.vibee"
name: trit
version: "1.0.0"
language: zig
module: trit

types:
  Trit:
    fields:
      value: Int
    constraints:
      - "value >= -1"
      - "value <= 1"

behaviors:
  - name: neg
    given: A trit value
    when: Negating
    then: Returns -value
    params:
      - name: t
        type: Trit
    returns: Trit

  - name: mul
    given: Two trit values
    when: Multiplying
    then: Returns a * b (ternary multiplication)
    params:
      - name: a
        type: Trit
      - name: b
        type: Trit
    returns: Trit
    test_cases:
      - name: mul_positive
        input: {a: 1, b: 1}
        expected: 1
      - name: mul_negative
        input: {a: 1, b: -1}
        expected: -1
      - name: mul_zero
        input: {a: 0, b: 1}
        expected: 0
```

## 2. VSA Operations

Vector Symbolic Architecture operations:

```yaml title="specs/vsa/operations.vibee"
name: vsa_operations
version: "1.0.0"
language: zig
module: vsa

constants:
  DEFAULT_DIM: 10000

types:
  HyperVector:
    fields:
      data: List<Int>
      dimension: Int

behaviors:
  - name: bind
    given: Two vectors a and b of same dimension
    when: Binding (element-wise multiplication)
    then: Returns vector c where c[i] = a[i] * b[i]
    params:
      - name: a
        type: HyperVector
      - name: b
        type: HyperVector
    returns: HyperVector

  - name: unbind
    given: Bound vector and key
    when: Unbinding
    then: Returns bind(bound, key) since ternary bind is self-inverse

  - name: bundle
    given: List of vectors
    when: Bundling via majority voting
    then: Returns vector where each element is majority vote

  - name: similarity
    given: Two vectors
    when: Computing cosine similarity
    then: Returns similarity in range [-1, 1]
```

## 3. Hardware Adder (Verilog)

FPGA-targeted specification:

```yaml title="specs/tri/fpga/adder.vibee"
name: full_adder
version: "1.0.0"
language: varlog
module: full_adder

types:
  AdderInput:
    fields:
      a: Bool
      b: Bool
      carry_in: Bool

signals:
  - name: clk
    width: 1
    direction: input
  - name: a
    width: 1
    direction: input
  - name: b
    width: 1
    direction: input
  - name: cin
    width: 1
    direction: input
  - name: sum
    width: 1
    direction: output
  - name: cout
    width: 1
    direction: output

behaviors:
  - name: compute_sum
    given: Inputs a, b, carry_in
    when: Computing sum bit
    then: sum = a XOR b XOR carry_in

  - name: compute_carry
    given: Inputs a, b, carry_in
    when: Computing carry out
    then: cout = (a AND b) OR (cin AND (a XOR b))
```

Generated Verilog:

```verilog
module full_adder (
    input wire clk,
    input wire a,
    input wire b,
    input wire cin,
    output wire sum,
    output wire cout
);

assign sum = a ^ b ^ cin;
assign cout = (a & b) | (cin & (a ^ b));

endmodule
```

## 4. Binary Loader

Multi-format binary parser:

```yaml title="specs/tri/b2t/loader.vibee"
name: binary_loader
version: "1.0.0"
language: zig
module: b2t_loader

constants:
  PE_MAGIC: 0x5A4D
  ELF_MAGIC: 0x7F454C46
  MACHO_MAGIC: 0xFEEDFACF
  WASM_MAGIC: 0x6D736100

types:
  BinaryFormat:
    enum:
      - pe64
      - elf64
      - macho64
      - wasm
      - unknown

  LoadedBinary:
    fields:
      format: BinaryFormat
      entry_point: Int
      sections: List<Section>

  Section:
    fields:
      name: String
      address: Int
      size: Int
      data: List<Int>

behaviors:
  - name: detect_format
    given: Raw binary data bytes
    when: Checking magic numbers
    then: Returns detected BinaryFormat or unknown

  - name: load_pe64
    given: Path to Windows PE64 executable
    when: Parsing PE headers
    then: Returns LoadedBinary with sections and symbols

  - name: load_elf64
    given: Path to Linux ELF64 executable
    when: Parsing ELF headers
    then: Returns LoadedBinary with sections and symbols
```

## 5. Ternary Matrix Multiplication

BitNet-style operations:

```yaml title="specs/tri/matmul.vibee"
name: ternary_matmul
version: "1.0.0"
language: zig
module: ternary_matmul

types:
  TritWeight:
    encoding:
      ZERO: 0b00
      PLUS_ONE: 0b01
      MINUS_ONE: 0b10

  TernaryMatrix:
    fields:
      data: List<Int>
      rows: Int
      cols: Int

behaviors:
  - name: ternary_matvec
    given: Packed weight matrix and input vector
    when: Computing matrix-vector product
    then: Output with dot products (no multiplications)

  - name: simd_ternary_matvec
    given: Packed weights, input vector, SIMD width 8
    when: Computing with AVX2 vectors
    then: 8x speedup via vectorized sign lookup
```

## 6. GGUF Model Inference

LLM inference specification:

```yaml title="specs/tri/gguf_inference.vibee"
name: gguf_inference
version: "1.0.0"
language: zig
module: gguf_inference

constants:
  MAX_CONTEXT: 4096
  VOCAB_SIZE: 32000

types:
  GGUFModel:
    fields:
      vocab_size: Int
      hidden_dim: Int
      n_layers: Int
      weights: List<TernaryMatrix>

  InferenceContext:
    fields:
      tokens: List<Int>
      position: Int
      kv_cache: List<Float>

behaviors:
  - name: load_model
    given: Path to GGUF file
    when: Loading model weights
    then: Returns GGUFModel with quantized weights

  - name: forward
    given: Model and input tokens
    when: Running forward pass
    then: Returns logits for next token

  - name: sample
    given: Logits and temperature
    when: Sampling next token
    then: Returns token ID via nucleus sampling
```

## Generation Workflow

1. **Write spec** in `specs/tri/`
2. **Generate code**: `./bin/vibee gen specs/tri/feature.vibee`
3. **Test**: `zig test trinity/output/feature.zig`
4. **Iterate** if tests fail

```bash
# Example workflow
./bin/vibee gen specs/tri/matmul.vibee
zig test trinity/output/ternary_matmul.zig
```

## Best Practices

1. **One concern per spec** - Keep specifications focused
2. **Use constraints** - Validate input ranges
3. **Write test cases** - Include in behaviors
4. **Document with given/when/then** - Clear semantics
5. **Use constants** - Avoid magic numbers
