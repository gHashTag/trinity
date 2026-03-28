# Welcome to r/t27ai! 👋

## What is Trinity?

**Trinity** is a Pure Zig autonomous AI agent swarm for ternary computing, VSA (Vector Symbolic Architecture), and LLM inference.

### Key Facts

| Feature | Value |
|---------|-------|
| Language | Zig 0.15 (std only) |
| Dependencies | 0 TypeScript, 0 Python, 0 bash |
| Binaries | 50+ from one build.zig |
| Tests | 3000+ passing |
| FPGA | QMTech XC7A100T ($30) |

---

## Ternary Computing 101

Instead of binary {0, 1} or float32, we use ternary {-1, 0, +1}:

```
Binary:  8 bits = 256 values
Ternary: 8 trits = 6561 values (1.58 bits/trit)
Savings: ~20x memory vs float32
```

### Trinity Identity

```
φ² + 1/φ² = 3
where φ = (1 + √5) / 2 ≈ 1.618
```

The golden ratio connects to ternary systems!

---

## VSA Operations

```zig
// Associate two vectors
const bound = vsa.bind(vector_a, vector_b);

// Retrieve from binding
const recovered = vsa.unbind(bound, vector_a);

// Majority voting
const result = vsa.bundle3(vector_a, vector_b, vector_c);
```

---

## What We Discuss Here?

### 1. Technical Discussion
- Ternary computing and FPGA
- VSA (Vector Symbolic Architecture)
- TRI-27 (ternary core)
- Zig development

### 2. Mathematical Research
- Trinity Identity and constants
- Connection to physics (G, α, N_gen)
- Sacred mathematics

### 3. AI/ML Research
- BitNet LLM on CPU
- HSLM (Hybrid Sacred Language Model)
- DePIN network
- Autonomous agents

### 4. News and Updates
- GitHub releases
- Scientific publications on Zenodo
- Documentation updates

---

## Quick Start

### Installation

```bash
npm install -g @playra/tri
# or
brew install trinity
```

### First Commands

```bash
tri --help          # All commands
tri status          # System status
tri test            # Run tests
tri issue list      # List issues
```

### Example: VSA Semantic Search

```zig
const std = @import("std");
const vsa = @import("vsa");

pub fn main() !void {
    // Create hypervectors
    const allocator = std.heap.page_allocator;
    const apple = try vsa.BinaryHypervector.init(allocator, 1024);
    const fruit = try vsa.BinaryHypervector.init(allocator, 1024);

    // Associate: apple is a fruit
    const apple_is_fruit = try vsa.bind(apple, fruit);

    // Check similarity
    const similarity = vsa.cosineSimilarity(
        try vsa.unbind(apple_is_fruit, fruit),
        apple
    );

    std.debug.print("Similarity: {d:.2}\n", .{similarity});
}
```

---

## Useful Links

- 🌐 **Website**: https://t27.ai/
- 📖 **Documentation**: https://t27.ai/docs/
- 📱 **Reddit**: https://www.reddit.com/r/t27ai/
- ✈️ **Telegram**: https://t.me/t27_lang
- 𝕏 **X (Twitter)**: https://x.com/t27_lang
- 💻 **GitHub**: https://github.com/gHashTag/trinity
- 📜 **Zenodo**: https://zenodo.org/communities/trinity

---

## Join Us!

1. ⭐ Star on GitHub
2. 🔀 Fork and PR
3. 💬 Join discussions
4. 📝 Create issues

---

*Created by the Trinity community. Phi, Friends, Glory!*

**φ² + 1/φ² = 3**
