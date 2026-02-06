---
sidebar_position: 110
---

# FAQ

Frequently asked questions about the Trinity framework.

---

### What is Trinity?

Trinity is a high-performance computing framework built on balanced ternary arithmetic \{-1, 0, +1\}. It provides a Vector Symbolic Architecture (VSA) for hyperdimensional computing, a BitNet-compatible LLM inference engine called Firebird, a specification-driven code generator called VIBEE, and a stack-based Ternary Virtual Machine. The entire system is written in Zig for maximum performance and minimal dependencies.

---

### Why ternary instead of binary?

Ternary is the mathematically optimal integer base for representing information. Each ternary digit (trit) carries log2(3) = 1.585 bits of information -- 58.5% more than a binary digit. The radix economy of base-3 is lower (better) than any other integer base, meaning ternary uses fewer total "resources" (digits times states-per-digit) to represent a given range of values. See [Ternary Computing Concepts](/docs/concepts) for a full explanation.

---

### What is BitNet b1.58?

BitNet b1.58 is a neural network architecture where model weights are quantized to ternary values \{-1, 0, +1\}. The "1.58" refers to the information content of a trit: log2(3) = 1.58 bits. This quantization eliminates floating-point multiplication during inference -- matrix-vector products become pure addition and subtraction. Trinity's [Firebird engine](/docs/api/firebird) implements native BitNet inference, achieving approximately 20x memory savings compared to float32 weights.

---

### What is VSA/HDC?

Vector Symbolic Architecture (VSA), also called Hyperdimensional Computing (HDC), is a computational framework that represents information as high-dimensional vectors and manipulates them with simple algebraic operations. In Trinity, VSA uses ternary hypervectors with operations like [bind](/docs/api/vsa) (element-wise trit multiplication for association), bundle (majority vote for superposition), and permute (cyclic shift for sequence encoding). These operations are fast, parallelizable, and noise-tolerant.

---

### What hardware does Trinity run on?

Trinity runs on standard CPUs -- it does not require specialized ternary hardware. The framework is written in Zig and compiles natively for x86_64, ARM64 (Apple Silicon, Linux ARM), and WebAssembly. For large-model LLM inference, GPU acceleration or cloud instances (such as RunPod) may be used. Cross-platform release builds target macOS, Linux, and Windows.

---

### What is the VIBEE language?

VIBEE is a specification-first approach to code generation. You write `.vibee` files in a YAML-like format that define types, behaviors, and module structure. The [VIBEE compiler](/docs/api/vibee) then generates implementation code in Zig, Verilog (for FPGAs), or other target languages. This ensures that specifications remain the single source of truth and that generated code is always consistent with its spec. See the [VIBEE specification format](/docs/vibee/specification) for details.

---

### How do I build Trinity?

Trinity uses the Zig build system. To build and test:

```bash
git clone https://github.com/gHashTag/trinity.git
cd trinity
zig build          # compile the project
zig build test     # run all tests
```

For more detailed instructions, see the [Installation guide](/docs/getting-started/installation) and [Quick Start](/docs/getting-started/quickstart).

---

### What Zig version do I need?

Trinity requires **Zig 0.13.0**. Using a different version may produce build errors (such as missing API functions). You can download the correct version from the [Zig downloads page](https://ziglang.org/download/) or install it with:

```bash
curl -LO https://ziglang.org/download/0.13.0/zig-macos-aarch64-0.13.0.tar.xz
tar -xf zig-macos-aarch64-0.13.0.tar.xz
export PATH="$PWD/zig-macos-aarch64-0.13.0:$PATH"
```

See [Troubleshooting](/docs/troubleshooting) if you encounter version-related build failures.

---

### Can I use Trinity for LLM inference?

Yes. The Firebird engine provides native LLM inference with ternary BitNet weights. You can run it via the command line:

```bash
zig build firebird
```

Firebird supports GGUF model loading, WebAssembly extensions, and decentralized inference via the DePIN subsystem. See the [Firebird API reference](/docs/api/firebird) for full details.

---

### What is the development cycle?

Trinity uses a structured 16-step development cycle. It enforces a specification-first workflow: create a `.vibee` specification, generate code from it, test the output, write a critical self-assessment, and propose three options for the next iteration. This process ensures that all code is specification-driven and that each development cycle is self-documenting. See the [Contributing guide](/docs/contributing) for details.

---

### How do I contribute?

Contributions follow the 16-step development cycle. Start by writing or modifying a `.vibee` specification under `specs/tri/`, generate the code, test it, and submit a pull request. Never edit auto-generated files directly (anything under `trinity/output/` or `generated/`). See the [Contributing guide](/docs/contributing) for full guidelines.

---

### What platforms are supported?

Trinity supports three platforms via cross-compilation:

- **macOS** (x86_64 and ARM64/Apple Silicon)
- **Linux** (x86_64 and ARM64)
- **Windows** (x86_64)

Build cross-platform release binaries with `zig build release`. The framework also compiles to WebAssembly for browser and edge deployment.

---

### What is HybridBigInt?

HybridBigInt is Trinity's core storage type for ternary vectors. It maintains two internal representations: a **packed** form that encodes each trit in 2 bits (achieving near-optimal 1.58 bits/trit density) and an **unpacked** form (an array of individual trit values) for fast element-wise operations. Conversions between the two are lazy and cached, so you get both memory efficiency and computational speed. See the [HybridBigInt API reference](/docs/api/hybrid).

---

### What is the Trinity Identity?

The Trinity Identity is the algebraic identity phi^2 + 1/phi^2 = 3, where phi is the golden ratio (1 + sqrt(5)) / 2. It follows directly from the defining equation phi^2 = phi + 1. The identity links the golden ratio to the number 3, which is the optimal integer radix for number representation. A full proof can be found on the [Trinity Identity page](/docs/concepts/trinity-identity).

---

### Where can I get help?

If you encounter issues, check the [Troubleshooting page](/docs/troubleshooting) first. For bugs and feature requests, open an issue on [GitHub](https://github.com/gHashTag/trinity/issues). You can also run `zig version` to verify your Zig installation and `zig build test` to check that your build environment is working correctly.
