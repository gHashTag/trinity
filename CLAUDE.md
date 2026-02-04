# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Build & Test Commands

```bash
# Build
zig build                    # Compile library and executables
zig build firebird           # Build Firebird LLM CLI (ReleaseFast)
zig build release            # Cross-platform release builds (linux/macos/windows)

# Test
zig build test               # Run ALL tests (trinity, vsa, vm, firebird, wasm, depin)
zig test src/vsa.zig         # Run single test file
zig test src/vm.zig          # VM tests only
zig test src/firebird/b2t_integration.zig  # Firebird integration tests

# Benchmark
zig build bench              # Run benchmarks

# Examples
zig build examples           # Build and run all examples

# Format
zig fmt src/                 # Format Zig code
```

---

## Architecture

### Core VSA System (src/)

| Module | Purpose |
|--------|---------|
| `trinity.zig` | Library exports, version |
| `vsa.zig` | Vector Symbolic Architecture: bind, unbind, bundle, similarity |
| `vm.zig` | Ternary Virtual Machine (stack-based bytecode) |
| `hybrid.zig` | HybridBigInt: packed (1.58 bits/trit) ↔ unpacked cache |
| `packed_trit.zig` | Bit-packed ternary encoding |
| `sdk.zig` | High-level API (Hypervector, Codebook) |

### Key VSA Operations (src/vsa.zig)

```zig
bind(a, b)           // Bind two vectors (association)
unbind(bound, key)   // Retrieve vector from binding
bundle2(a, b)        // Majority vote of 2 vectors
bundle3(a, b, c)     // Majority vote of 3 vectors
cosineSimilarity()   // Measure similarity [-1, 1]
hammingDistance()    // Count differing trits
dotSimilarity()      // Inner product
permute(v, count)    // Cyclic permutation
```

### Firebird LLM Engine (src/firebird/)

| File | Purpose |
|------|---------|
| `cli.zig` | Command-line interface |
| `b2t_integration.zig` | BitNet-to-Ternary conversion |
| `wasm_parser.zig` | WebAssembly module loading |
| `extension_wasm.zig` | Extension system |
| `depin.zig` | Decentralized Physical Infrastructure |

### VIBEE Compiler (src/vibeec/)

| File | Purpose |
|------|---------|
| `vibee_parser.zig` | Parse .vibee specifications |
| `zig_codegen.zig` | Generate Zig code |
| `verilog_codegen.zig` | Generate Verilog (FPGA) |
| `gen_cmd.zig` | CLI entry point |
| `gguf_chat.zig` | GGUF model interface |
| `http_server.zig` | HTTP API server |

### Other Subsystems

| Directory | Purpose |
|-----------|---------|
| `src/b2t/` | BitNet inference (21 files) |
| `src/phi-engine/` | Quantum-inspired computation |
| `src/tvc/` | Ternary Vector Computing |
| `src/maxwell/` | Constraint solving |

---

## Golden Chain Development Cycle

**MANDATORY** 16-link cycle. Run `./bin/vibee koschei` to see all links.

### Minimal Cycle

```bash
# 1. Create specification
cat > specs/tri/feature.vibee << 'EOF'
name: feature
version: "1.0.0"
language: zig
module: feature

types:
  MyType:
    fields:
      name: String

behaviors:
  - name: my_func
    given: Input
    when: Action
    then: Result
EOF

# 2. Generate code
./bin/vibee gen specs/tri/feature.vibee  # → trinity/output/feature.zig

# 3. Test
zig test trinity/output/feature.zig

# 4. Write TOXIC VERDICT (harsh self-criticism)
# 5. Propose 3 TECH TREE options for next iteration
```

### For Hardware (Verilog/FPGA)

```bash
# Use language: varlog
./bin/vibee gen specs/tri/feature_fpga.vibee  # → trinity/output/fpga/feature_fpga.v
```

---

## Code Generation Rules

### ANTI-PATTERN: Writing code manually

```
ALL CODE MUST BE GENERATED FROM .vibee SPECIFICATIONS!
```

### Allowed to edit

| Path | Description |
|------|-------------|
| `specs/tri/*.vibee` | Specifications (SOURCE OF TRUTH) |
| `src/vibeec/*.zig` | Compiler source ONLY |
| `docs/*.md` | Documentation |

### Never edit (auto-generated)

| Path | Reason |
|------|--------|
| `trinity/output/*.zig` | Generated from .vibee |
| `trinity/output/fpga/*.v` | Generated from .vibee |
| `generated/*.zig` | Generated from .vibee |

---

## CLI Commands

```bash
# VIBEE Compiler
./bin/vibee gen <spec.vibee>         # Generate Zig code
./bin/vibee gen-multi <spec> all     # Generate for 42 languages
./bin/vibee run <file.999>           # Run via bytecode VM
./bin/vibee koschei                  # Show Golden Chain
./bin/vibee chat --model <path>      # Chat with model
./bin/vibee serve --port 8080        # Start HTTP server
```

---

## .vibee Specification Format

```yaml
name: module_name
version: "1.0.0"
language: zig          # or: varlog (Verilog), python, etc.
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

---

## Mathematical Foundation

```
φ = (1 + √5) / 2 ≈ 1.618      (Golden Ratio)
φ² + 1/φ² = 3 = TRINITY       (Trinity Identity)
3²¹ = 10,460,353,203          (Phoenix Number - Total $TRI supply)
V = n × 3^k × π^m × φ^p × e^q (Sakra Formula)
```

Ternary {-1, 0, +1} is mathematically optimal:
- Information density: 1.58 bits/trit (vs 1 bit/binary)
- Memory savings: 20x vs float32
- Compute: Add-only (no multiply)

---

## Telegram Bot Rules

```
FORBIDDEN: InlineKeyboardMarkup (buttons in message)
ONLY: ReplyKeyboardMarkup (buttons at bottom of screen)
```

Specifications: `specs/tri/telegram_bot/`

---

## Website Deployment

```
Canonical URL: https://trinity-site-ghashtag.vercel.app
GitHub Repo:   gHashTag/trinity
Root:          website/
Framework:     Vite (React SPA)
```

DO NOT create new Vercel projects. Push to main branch auto-deploys.

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

## Ralph Autonomous Development

Ralph enables continuous autonomous development cycles for Claude Code.

### Configuration

```
.ralph/
├── PROMPT.md      # Main prompt for autonomous work
├── AGENT.md       # Agent configuration (build/test/run)
├── fix_plan.md    # Fix plan tracking
├── specs/         # Specifications
├── examples/      # Examples
├── logs/          # Execution logs
└── docs/generated/
.ralphrc           # Ralph settings
```

### Commands

```bash
ralph --monitor          # Start with live monitoring dashboard
ralph --help             # Show options
ralph-enable             # Enable Ralph in project (interactive)
ralph-import prd.md      # Convert PRD to Ralph tasks
ralph-migrate            # Migrate to .ralph/ structure
```

### Usage

1. Edit `.ralph/PROMPT.md` with requirements
2. Run `ralph --monitor`
3. Ralph will loop Claude Code until task completion

### Safeguards

- Rate limiting: 100 calls/hour (configurable)
- Circuit breaker for error detection
- Intelligent exit detection (completion + explicit confirmation)
- Session continuity across iterations

Repository: https://github.com/frankbria/ralph-claude-code

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**
