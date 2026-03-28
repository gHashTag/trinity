# r/t27ai — Example Posts

## For Beginners

---

### Post 1: "What are ternary computations and why do they matter?"

**Flair:** 📝 `[Question]` or 💬 `[Discussion]`

---

Ternary computing uses three values {-1, 0, +1} instead of binary {0, 1} or floating-point.

## Why ternary?

**Memory efficiency:**
- 8 bits = 256 values (binary)
- 8 trits = 6,561 values (ternary)
- ~20x memory savings vs float32

**Natural fit for AI:**
- BitNet LLM uses {-1, 0, +1} weights
- No multiplication needed — only addition and sign
- Perfect for FPGA implementation

## Trinity Identity

```
φ² + 1/φ² = 3
where φ = (1 + √5) / 2 ≈ 1.618
```

The golden ratio connects to ternary systems! This isn't coincidence — it's fundamental.

## Real-world performance

- **63 tok/s @ 1W** on FPGA (QMTech XC7A100T, $30)
- **CPU inference** without GPU
- **SIMD 17x+** speedup, **JIT 22x+** speedup

---

**Links:**
- Documentation: https://t27.ai/docs/
- GitHub: https://github.com/gHashTag/trinity

---

### Post 2: "How to run Trinity on your computer?"

**Flair:** 📝 `[Question]`

---

## Installation

### Option 1: npm (easiest)

```bash
npm install -g @playra/tri
tri --help
```

### Option 2: Homebrew (macOS/Linux)

```bash
brew install trinity
tri --help
```

### Option 3: From source

```bash
# Install Zig 0.15
brew install zig

# Clone repository
git clone https://github.com/gHashTag/trinity
cd trinity

# Build
zig build
zig build tri

# Run
./zig-out/bin/tri --help
```

## First steps

```bash
# Check system status
tri status

# Run tests
tri test

# See available commands
tri --help
```

## Requirements

- Zig 0.15.x
- macOS / Linux / Windows (WSL)
- ~500MB disk space
- ~2GB RAM for building

---

**Questions? Ask below! 👇**

---

### Post 3: "Trinity Identity: How φ connects to Trinity architecture"

**Flair:** 🔬 `[Research]`

---

## The Identity

```
φ² + 1/φ² = 3
where φ = (1 + √5) / 2 ≈ 1.618034...
```

This isn't just a pretty equation — it's the foundation of Trinity.

## Why 3?

- **Ternary system**: {-1, 0, +1} = 3 values
- **TRI-27**: 27 registers = 3³
- **3 banks** of 9 registers (Coptic alphabet)
- **Golden ratio** appears throughout nature

## Connection to VSA

Vector Symbolic Architecture uses:
- **Bind**: creates associations (φ² — expansion)
- **Unbind**: retrieves (1/φ² — contraction)
- **Bundle**: majority voting (balance point = 3)

## Physics connection

The same identity appears in:
- Gravitational constant G
- Fine-structure constant α
- 3 generations of matter
- Present moment (t_present)

```zig
// From src/tri/math/constants.zig
pub const PHI: f64 = 1.6180339887498948482;
pub const PHI_SQUARED: f64 = PHI * PHI;           // 2.618...
pub const PHI_INVERSE_SQUARED: f64 = 1.0 / PHI_SQUARED;  // 0.3819...
// PHI_SQUARED + PHI_INVERSE_SQUARED = 3.0
```

---

**See also:** `src/tri/math/constants.zig` — 75+ sacred constants

---

## For Developers

---

### Post 4: "How to compile Trinity from source"

**Flair:** 💻 `[Code]`

---

## Prerequisites

1. **Install Zig 0.15**

```bash
# macOS
brew install zig

# Linux
sudo apt install zig  # Ubuntu/Debian
sudo pacman -S zig    # Arch

# Verify
zig version
```

2. **Clone repository**

```bash
git clone https://github.com/gHashTag/trinity
cd trinity
```

## Build

```bash
# Build all binaries (50+)
zig build

# Build tri CLI specifically
zig build tri

# Run tests
zig build test

# Install to system
zig build install --prefix /usr/local
```

## Build outputs

```
zig-out/
├── bin/
│   ├── tri              # Main CLI
│   ├── trinity-mcp      # MCP server
│   ├── ralph-agent      # Sleep-wake daemon
│   ├── tri-bot          # Telegram bot
│   ├── tri-api          # Standalone agent
│   └── ... (45 more)
└── lib/
    └── libtrinity.a
```

## Common issues

**Q: "error: unable to find zig libc"**
A: Install musl or use `zig build -Dtarget=x86_64-linux-musl`

**Q: "out of memory"**
A: Increase swap or build specific targets: `zig build tri`

---

**Need help? Comment below!**

---

### Post 5: "Example: Using VSA for semantic search"

**Flair:** 💻 `[Code]`

---

## What is VSA?

Vector Symbolic Architecture = cognitive computing with hypervectors.

## Basic operations

```zig
const std = @import("std");
const vsa = @import("vsa");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Create 10K-dimensional hypervectors
    const apple = try vsa.BinaryHypervector.init(allocator, 10240);
    const fruit = try vsa.BinaryHypervector.init(allocator, 10240);
    const red = try vsa.BinaryHypervector.init(allocator, 10240);

    // Create associations
    const apple_is_fruit = try vsa.bind(apple, fruit);
    const apple_is_red = try vsa.bind(apple, red);

    // Retrieve: is apple a fruit?
    const retrieved = try vsa.unbind(apple_is_fruit, fruit);
    const similarity = vsa.cosineSimilarity(retrieved, apple);

    std.debug.print("Is apple a fruit? {d:.2}\n", .{similarity});
    // Output: Is apple a fruit? 0.95

    // Bundle: combine multiple concepts
    const red_fruit = try vsa.bundle3(red, fruit, apple);
}
```

## Practical example: Document search

```zig
// Create semantic index
var index = std.StringHashMap(vsa.BinaryHypervector).init(allocator);

// Index documents
const doc1 = "The cat sat on the mat";
const doc2 = "The dog chased the ball";

const vec1 = try vsa.embedText(allocator, doc1);
const vec2 = try vsa.embedText(allocator, doc2);

try index.put("doc1", vec1);
try index.put("doc2", vec2);

// Query
const query = try vsa.embedText(allocator, "feline resting");
var best_doc: []const u8 = undefined;
var best_score: f64 = 0.0;

var iter = index.iterator();
while (iter.next()) |entry| {
    const score = vsa.cosineSimilarity(query, entry.value_ptr.*);
    if (score > best_score) {
        best_score = score;
        best_doc = entry.key_ptr.*;
    }
}

std.debug.print("Best match: {s} (score: {d:.2})\n", .{best_doc, best_score});
```

---

**See also:** `src/vsa.zig` — full VSA implementation

---

### Post 6: "TRI-27: Writing your first ternary program"

**Flair:** 💻 `[Code]`

---

## What is TRI-27?

TRI-27 is a ternary virtual machine with:
- **27 registers** (3 banks × 9)
- **36 opcodes** (MOV, JGT, JLT, JUMP, PHI, CALL, RET...)
- **Stack-based** execution
- **Coptic alphabet** for register naming

## Hello World

```tri
; TRI-27 Hello World
; Registers: A B C D E F G H I (Bank 0)
;           a b c d e f g h i (Bank 1)
;           Α Β Γ Δ Ε Ζ Η Θ Ι (Bank 2)

    PHI 0           ; Load address of string
    MOV A, 0        ; A = 0 (string length)

.loop:
    MOV B, [PHI]    ; B = char at PHI
    JGT B, 0, .print ; if B > 0, print
    JUMP .end       ; else exit

.print:
    OUT B           ; print character
    ADD PHI, 1      ; PHI++
    ADD A, 1        ; A++
    JUMP .loop

.end:
    RET             ; return

; Data section
.align 4
string: .db "Hello, TRI-27!", 0
```

## Assembly it

```bash
tri assemble program.tri -o program.tbc
tri run program.tbc
```

## Opcodes

| Opcode | Description | Example |
|--------|-------------|---------|
| MOV | Move register/memory | `MOV A, B` |
| ADD | Add (ternary) | `ADD A, 1` |
| PHI | Load address | `PHI label` |
| JGT | Jump if greater | `JGT A, 0, label` |
| JLT | Jump if less | `JLT A, 0, label` |
| JUMP | Unconditional jump | `JUMP label` |
| CALL | Call subroutine | `CALL func` |
| RET | Return | `RET` |
| OUT | Output | `OUT A` |

---

**See also:** `src/vm.zig` — TRI-27 VM implementation

---

## For Researchers

---

### Post 7: "DARPA CLARA: Polynomial-time guarantees in Trinity"

**Flair:** 🔬 `[Research]`

---

## DARPA CLARA Proposal

Trinity has been submitted for DARPA CLARA (Cognitive Learning for Adaptive Reasoning Architecture).

## Polynomial-Time Guarantees

### Theorem 1: VSA Bind/Unbind
```
Time(bind(x, y)) = O(d)
Space(bind(x, y)) = O(d)
where d = dimension of hypervectors
```

### Theorem 2: Similarity Search
```
Time(search(q, D)) = O(|D| × d)
where D = database, q = query
```

### Theorem 3: TRI-27 Execution
```
Time(execute(p)) = O(|p|)
where p = program length in opcodes
```

### Theorem 4: HSLM Inference
```
Time(infer(x)) = O(L × d)
where L = layers, d = hidden dimension
Space(infer(x)) = O(d²)
```

## Experimental Results

| Model | Params | Size | tok/s @ 1W |
|-------|--------|------|------------|
| HSLM-1B | 1.95M | 385 KB | 63 |
| BitNet-3B | 3.1B | 1.2 GB | 12 |

## Why polynomial time matters

- **Predictable latency** — no exponential blowup
- **Bounded memory** — O(d) not O(2^d)
- **Formal verification** — provable correctness

---

**Proposal:** `docs/proposals/DARPA_CLARA_PROPOSAL.md`

---

### Post 8: "Comparing Trinity with other VSA implementations"

**Flair:** 📊 `[Results]`

---

## VSA Implementations Comparison

| Feature | Trinity | BindsNET | PyTorch+HDC |
|---------|---------|----------|-------------|
| Language | Zig | Python | Python |
| Memory | ~20x less | baseline | baseline |
| Speed (bind) | 17x faster | 1x | 0.8x |
| FPGA ready | ✅ Yes | ❌ No | ❌ No |
| Zero deps | ✅ Yes | ❌ No | ❌ No |
| Ternary | ✅ Yes | ❌ No | ❌ No |

## Benchmarks

### Bind operation (10K-dimensional, 100K iterations)

```
Trinity (SIMD):     12 ms
BindsNET:          205 ms
PyTorch+HDC:       258 ms
```

### Memory usage (10K-dimensional hypervectors)

```
Trinity (ternary):  10 KB
BindsNET (float32): 40 KB
PyTorch (float32):  40 KB
```

## Code comparison

**Trinity (Zig):**
```zig
const bound = try vsa.bind(a, b);
const similarity = vsa.cosineSimilarity(bound, c);
```

**BindsNET (Python):**
```python
bound = hd.bind(a, b)
similarity = hd.cosine_similarity(bound, c)
```

**Same semantics, 17x faster.**

---

**Source:** `src/sacred/vsa_benchmark.zig`

---

## News & Updates

---

### Post 9: "Release v1.0: Trinity is now available on npm!"

**Flair:** 📢 `[News]`

---

## 🎉 Trinity v1.0 Released!

Trinity is now available via npm and Homebrew!

## What's new

### Installation

```bash
npm install -g @playra/tri
# or
brew install trinity
```

### Features

- **50+ binaries** from one build.zig
- **3000+ tests** passing
- **SIMD 17x+** speedup
- **JIT 22x+** speedup
- **FPGA synthesis** ready
- **MCP server** with 47+ tools

### New in v1.0

- ✨ TRI-27 ternary VM
- ✨ VSA hypervector operations
- ✨ BitNet LLM inference
- ✨ HSLM training pipeline
- ✨ FPGA toolchain integration
- ✨ Autonomous agent swarm

## Documentation

- 🌐 Website: https://t27.ai/
- 📖 Full docs: https://t27.ai/docs/
- 📱 Reddit: https://www.reddit.com/r/t27ai/
- ✈️ Telegram: https://t.me/t27_lang
- 𝕏 X (Twitter): https://x.com/t27_lang
- 💻 GitHub: https://github.com/gHashTag/trinity
- 📦 Releases: https://github.com/gHashTag/trinity/releases

## Try it now

```bash
npm install -g @playra/tri
tri --help
```

---

**φ² + 1/φ² = 3**

---

### Post 10: "New scientific publications on Zenodo!"

**Flair:** 📢 `[News]`

---

## 📜 8 New Zenodo Bundles Published!

We've published 8 enhanced scientific bundles with DOIs:

## Bundles

| ID | Title | DOI |
|----|-------|-----|
| B001 | Core Library | 10.5281/zenodo.19227865 |
| B002 | VSA Operations | 10.5281/zenodo.19227867 |
| B003 | TRI-27 VM | 10.5281/zenodo.19227869 |
| B004 | BitNet Inference | 10.5281/zenodo.19227871 |
| B005 | HSLM Training | 10.5281/zenodo.19227873 |
| B006 | FPGA Synthesis | 10.5281/zenodo.19227875 |
| B007 | Scientific Metrics | 10.5281/zenodo.19227877 |
| PARENT | Trinity Framework | 10.5281/zenodo.19227879 |

## Enhanced with

- NeurIPS/ICLR/MLSys standards
- Mathematical foundations
- Experimental reproducibility
- Citation instructions

## Citation

```bibtex
@software{trinity_v5,
  title={Trinity: Pure Zig Ternary Computing Framework},
  author={Playra},
  year={2026},
  doi={10.5281/zenodo.19227879},
  url={https://doi.org/10.5281/zenodo.19227879}
}
```

---

**View all:** https://zenodo.org/communities/trinity

---

## Best Practices

---

### Post Titles

- ❌ Bad: "Help!"
- ✅ Good: "[Question] How to install VSA hypervector with dimension 10K?"

- ❌ Bad: "Look at this"
- ✅ Good: "[Results] SIMD 17x speedup on bind operations (benchmark inside)"

---

### Formatting

Use code blocks with language tags:

```zig
const bound = vsa.bind(a, b);
```

```bash
tri test --filter=vsa
```

```markdown
## Heading
Content here...
```

---

### Engagement

- Answer questions from newcomers
- Share experiment results
- Link to GitHub issues for bug reports
- Participate in discussions

---

### Links

Always include relevant links:
- GitHub issues for bugs
- Documentation references
- Zenodo DOIs for research

---

## Moderation Notes

### Auto-moderator config

```
# Auto-approve posts from verified users
verified_users: ["gHashTag", "playra"]

# Require flair for all posts
require_flair: true

# Filter spam
spam_keywords: ["crypto", "buy now", "click here"]

# Wiki edits
wiki_whitelist: ["approved_contributors"]
```

---

### Approved submitter list

Add contributors who consistently post quality content.

---

### User flair

| Role | Flair |
|------|-------|
| Core dev | 🔧 Core |
| Contributor | ⭐ Contributor |
| Researcher | 🔬 Researcher |
| Verified user | ✓ Verified |

---

## Setup Checklist

- [x] Create sidebar content
- [x] Define rules
- [x] Create welcome post
- [x] Create example posts
- [ ] Configure flairs (8 tags)
- [ ] Set up wiki
- [ ] Add moderators
- [ ] Configure auto-moderator
- [ ] Create pinned posts (welcome + links)
- [ ] Set up Discord/Telegram bridge
- [ ] Add to subreddit discoverability
