# Trinity Examples

> Practical examples demonstrating Trinity's capabilities

---

## Quick Start

```bash
# Run Zig example
zig run examples/memory.zig

# Run via VM
./bin/vibee run examples/ternary_demo.999

# Build and test all
zig build examples
```

---

## Zig Examples

### memory.zig
Demonstrates HybridBigInt memory operations and packed/unpacked modes.

```bash
zig run examples/memory.zig
```

### sequence.zig
Sequence encoding with permutation operations.

```bash
zig run examples/sequence.zig
```

### vm.zig
VSA Virtual Machine usage with opcodes.

```bash
zig run examples/vm.zig
```

### sdk_basics.zig
High-level SDK usage (Hypervector, Codebook).

```bash
zig run examples/sdk_basics.zig
```

### knowledge_graph.zig
Building knowledge graphs with VSA vectors.

```bash
zig run examples/knowledge_graph.zig
```

### nlp_classifier.zig
Text classification using hyperdimensional computing.

```bash
zig run examples/nlp_classifier.zig
```

### science_analysis.zig
Scientific data analysis with ternary vectors.

```bash
zig run examples/science_analysis.zig
```

---

## VM Examples (.999 format)

### ternary_demo.999
Basic ternary operations demonstration.

```bash
./bin/vibee run examples/ternary_demo.999
```

### rl_frozen_lake.999
Reinforcement learning example (Frozen Lake).

```bash
./bin/vibee run examples/rl_frozen_lake.999
```

---

## Trilang Examples (.tri format)

### hello_world.tri
Hello World in Trinity language.

```bash
./bin/vibee run examples/hello_world.tri
```

### ternary_logic.tri
Ternary logic operations (AND, OR, NOT).

```bash
./bin/vibee run examples/ternary_logic.tri
```

### trinity_calculator.tri
Calculator using ternary arithmetic.

```bash
./bin/vibee run examples/trinity_calculator.tri
```

### distributed_consensus.tri
Distributed consensus algorithm demo.

```bash
./bin/vibee run examples/distributed_consensus.tri
```

### self_evolution.tri
Self-modifying code demonstration.

```bash
./bin/vibee run examples/self_evolution.tri
```

### uncertainty_propagation.tri
Uncertainty handling in ternary logic.

```bash
./bin/vibee run examples/uncertainty_propagation.tri
```

---

## VIBEE Specification Examples

### simple_adder.vibee
Simple adder specification.

```bash
./bin/vibee gen examples/simple_adder.vibee
```

### adder.vibee / adder2.vibee
Adder circuit specifications.

```bash
./bin/vibee gen examples/adder.vibee
```

---

## Coptic Examples (.coptic format)

### hello.coptic
Hello World in Coptic notation.

### fibonacci.coptic
Fibonacci sequence generator.

### functions.coptic
Function definitions in Coptic.

### trit_logic.coptic
Trit operations in Coptic notation.

---

## HDC Examples (hdc/ directory)

Hyperdimensional computing examples.

```bash
cd examples/hdc
zig run basic_hdc.zig
```

---

## Running All Examples

```bash
# Build all example executables
zig build examples

# Run example suite
zig build examples && ./zig-out/bin/example-memory
```

---

## Creating New Examples

1. Choose appropriate format:
   - `.zig` — Native Zig code
   - `.999` — VM bytecode
   - `.tri` — Trinity language
   - `.vibee` — Specification

2. Add to this README

3. Test before committing:
   ```bash
   zig run examples/your_example.zig
   ```

---

## See Also

- [docs/getting-started/TUTORIAL.md](../docs/getting-started/TUTORIAL.md)
- [docs/api/VSA_API.md](../docs/api/VSA_API.md)
- [docs/api/VM_API.md](../docs/api/VM_API.md)
