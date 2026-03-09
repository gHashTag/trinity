# Trinity Development Guide

Complete guide for contributing to Trinity — Sacred Intelligence System.

---

## Quick Start

```bash
# Clone
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Requires Zig 0.15.x
zig build                # Build all targets
zig build tri            # Build TRI CLI
zig build test           # Run tests
```

---

## Table of Contents

- [Architecture](#architecture)
- [VIBEE Workflow](#vibee-workflow)
- [TRI CLI Commands](#tri-cli-commands)
- [Ralph Autonomous Development](#ralph-autonomous-development)
- [Testing](#testing)
- [Code Style](#code-style)
- [Deployment](#deployment)

---

## Architecture

### Core VSA System

| Module | Purpose | Location |
|--------|---------|----------|
| `vsa.zig` | Vector Symbolic Architecture: bind, unbind, bundle, similarity | `src/` |
| `vm.zig` | Ternary Virtual Machine (stack-based bytecode) | `src/` |
| `hybrid.zig` | HybridBigInt: packed 1.58 bits/trit with unpacked cache | `src/` |
| `packed_trit.zig` | Bit-packed ternary encoding | `src/` |
| `sdk.zig` | High-level API (Hypervector, Codebook) | `src/` |

### Key VSA Operations

```zig
bind(a, b)           // Bind two vectors (association)
unbind(bound, key)   // Retrieve from binding
bundle2(a, b)        // Majority vote of 2 vectors
bundle3(a, b, c)     // Majority vote of 3 vectors
cosineSimilarity()   // Measure similarity [-1, 1]
hammingDistance()    // Count differing trits
permute(v, count)    // Cyclic permutation
```

### Project Structure

```
trinity-w1/
├── src/                    # Core Zig library
│   ├── vsa.zig             # VSA operations
│   ├── vm.zig              # Ternary VM
│   ├── tri/                # TRI CLI commands
│   ├── firebird/           # LLM engine
│   └── vibeec/             # VIBEE compiler CLI
├── specs/tri/              # .vibee specifications (SOURCE OF TRUTH)
├── trinity/output/         # Generated code (NEVER EDIT)
├── trinity-nexus/          # Workspace modules
│   ├── lang/src/           # VIBEE compiler
│   ├── network/src/        # DePIN
│   └── canvas/src/         # UI
├── test/                   # Test files
├── deploy/                 # Docker, K8s configs
└── docs/                   # Documentation
```

---

## VIBEE Workflow

**ALL application code MUST be generated from .vibee specifications.**

### Specification Format

```yaml
name: module_name
version: "1.0.0"
language: zig          # or: varlog (Verilog), python, rust, typescript
module: module_name

types:
  MyType:
    fields:
      field1: String
      field2: Int

behaviors:
  - name: my_function
    given: Input
    when: Action
    then: Result
```

### Development Cycle

```bash
# 1. Create specification
cat > specs/tri/feature.vibee << 'EOF'
name: feature
version: "1.0.0"
language: zig
module: feature

types:
  Greeting:
    fields:
      message: String

behaviors:
  - name: sayHello
    given: Greeting
    when: Called
    then: Prints greeting
EOF

# 2. Generate code
zig build vibee -- gen specs/tri/feature.vibee

# 3. Test
zig test trinity/output/feature.zig

# 4. Run quality gates
./zig-out/bin/tri verify
```

### Allowed to Edit

| Path | Description |
|------|-------------|
| `specs/tri/*.vibee` | Specifications (SOURCE OF TRUTH) |
| `src/vibeec/*.zig` | Compiler source ONLY |
| `src/*.zig` | Core library (vsa, vm, etc.) |
| `docs/*.md` | Documentation |

### Never Edit (Auto-generated)

| Path | Reason |
|------|--------|
| `trinity/output/*.zig` | Generated from .vibee |
| `trinity/output/fpga/*.v` | Generated from .vibee |

---

## TRI CLI Commands

**TRI** is the Unified Trinity Command Line Interface (134+ commands).

### Core Commands

| Command | Description |
|---------|-------------|
| `tri chat` | Interactive chat (vision + voice + tools) |
| `tri code` | Generate code with typing effect |
| `tri gen <spec.vibee>` | Compile VIBEE spec to Zig/Verilog |
| `tri pipeline run <task>` | Execute 17-link Golden Chain |
| `tri decompose <task>` | Break task into sub-tasks |
| `tri plan <task>` | Generate implementation plan |
| `tri spec_create <name>` | Create .vibee spec template |
| `tri loop-decide [mode]` | Loop decision: CONTINUE/EXIT |

### Verification Commands

| Command | Description |
|---------|-------------|
| `tri verify` | Run tests + benchmarks |
| `tri bench` | Performance benchmarks |
| `tri verdict` | Generate toxic verdict |

### SWE Agent Commands

| Command | Description |
|---------|-------------|
| `tri fix <file>` | Detect and fix bugs |
| `tri explain <file>` | Explain code |
| `tri test <file>` | Generate tests |
| `tri doc <file>` | Generate documentation |
| `tri refactor <file>` | Suggest refactoring |
| `tri reason <prompt>` | Chain-of-thought reasoning |

### Sacred Mathematics

| Command | Description |
|---------|-------------|
| `tri constants` | Show φ, π, e, μ, χ, σ, ε... |
| `tri phi <n>` | Compute φⁿ |
| `tri fib <n>` | Fibonacci with BigInt |
| `tri lucas <n>` | Lucas L(n) — L(2)=3=TRINITY |
| `tri spiral <n>` | φ-spiral coordinates |

---

## Ralph Autonomous Development

**ALL development should go through Ralph for quality gates.**

### Installation

```bash
git clone https://github.com/frankbria/ralph-claude-code.git
cd ralph-claude-code
./install.sh
```

### Usage

```bash
cd /path/to/trinity
ralph --monitor        # Start with live tmux dashboard
```

### Ralph Configuration

```
.ralph/
├── PROMPT.md              # Work instructions
├── RULES.md               # Development guardrails
├── TECH_TREE.md           # Tech tree navigation
├── fix_plan.md            # Current sprint tasks
├── SUCCESS_HISTORY.md     # Working patterns
└── REGRESSION_PATTERNS.md # Anti-patterns
```

### Quality Gates

Ralph automatically enforces:
- Build success (`zig build`)
- Tests pass (`zig build test`)
- Code formatted (`zig fmt src/`)
- Feature branch enforcement

---

## Testing

### Running Tests

```bash
# All tests
zig build test

# Specific module
zig test src/vsa.zig
zig test src/vm.zig

# With filter
zig test src/vsa.zig --filter "bind"
```

### Writing Tests

```zig
test "bind creates association" {
    const allocator = std.testing.allocator;
    var a = try Hypervector.init(allocator, 10000);
    defer a.deinit(allocator);
    var b = try Hypervector.init(allocator, 10000);
    defer b.deinit(allocator);

    const bound = try bind(&a, &b);
    const retrieved = try unbind(&bound, &a);

    // Similarity should be high
    const sim = cosineSimilarity(&b, &retrieved);
    try std.testing.expect(sim > 0.8);
}
```

### Benchmarks

```bash
zig build bench
```

---

## Code Style

### Zig Code

- 4-space indentation
- Max line length: 100 characters
- Doc comments for public functions

```zig
/// Binds two hypervectors via element-wise trit multiplication.
/// Properties:
///   - bind(a, a) = all +1 (self-inverse)
///   - bind(a, bind(a, b)) = b (unbind)
pub fn bind(a: *const Hypervector, b: *const Hypervector) !Hypervector {
    // Implementation
}
```

### Commit Messages

Use Conventional Commits:

```
feat: Add cosine similarity to VSA module

- Implement normalized dot product
- Add SIMD acceleration for large vectors
- Include tests for edge cases

φ² + 1/φ² = 3 = TRINITY
```

---

## Deployment

### Package Distribution

Trinity v1.0.1 is available via:

| Platform | Command |
|----------|---------|
| npm | `npm install -g @playra/tri` |
| Homebrew | `brew tap gHashTag/trinity && brew install trinity` |
| AUR | `yay -S trinity-cli` |
| Docker | `docker pull ghcr.io/ghashtag/trinity:latest` |

### Website Deployment

**IMPORTANT: Website and Docsite share ONE gh-pages branch.**

```bash
# 1. Build website
cd website && npx vite build

# 2. Build docsite
cd docsite && npm run build

# 3. Assemble gh-pages: website root + docsite in docs/
rm -rf /tmp/gh-pages-deploy
mkdir -p /tmp/gh-pages-deploy
cp -r website/dist/* /tmp/gh-pages-deploy/
mkdir -p /tmp/gh-pages-deploy/docs
cp -r docsite/build/* /tmp/gh-pages-deploy/docs/

# 4. Deploy
cd /tmp/gh-pages-deploy
git init && git checkout -b gh-pages
git add -A && git commit -m "Deploy"
git remote add origin git@github.com:gHashTag/trinity.git
git push origin gh-pages --force
```

### Documentation

| Resource | URL |
|----------|-----|
| **Dashboard** | https://ghashtag.github.io/trinity/ |
| **Docs** | https://ghashtag.github.io/trinity/docs/ |
| **API** | https://ghashtag.github.io/trinity/docs/api |

---

## Mathematical Foundation

### Trinity Identity

```
φ² + 1/φ² = 3 = TRINITY
where φ = (1 + √5) / 2 = 1.6180339887498948482...
```

### Why Ternary?

| Metric | Float32 | Ternary | Improvement |
|--------|---------|---------|-------------|
| Memory per weight | 32 bits | 1.58 bits | 20x |
| Compute | Multiply + Add | Add only | 10x |
| 70B model RAM | 280 GB | 14 GB | 20x |

---

## Getting Help

| Resource | Link |
|----------|------|
| **Issues** | https://github.com/gHashTag/trinity/issues |
| **Discussions** | https://github.com/gHashTag/trinity/discussions |
| **CLAUDE.md** | Project instructions for AI assistants |
| **AGENTS.md** | Autonomous development protocols |

---

```
φ² + 1/φ² = 3 = TRINITY
```
