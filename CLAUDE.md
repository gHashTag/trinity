# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Build & Test Commands

**Requires Zig 0.15.x**

```bash
# Build
zig build                    # Compile library and executables
zig build tri                # Run TRI - Unified Trinity CLI (recommended)
zig build cli                # Run Trinity CLI (Interactive AI Agent)
zig build vibee              # Run VIBEE Compiler CLI
zig build firebird           # Build Firebird LLM CLI (ReleaseFast)
zig build b2t                # Build BitNet-to-Ternary CLI
zig build claude-ui          # Build Claude UI Demo
zig build release            # Cross-platform builds (linux/macos/windows x64, macos arm64)

# Test
zig build test               # Run ALL tests (trinity, vsa, vm, firebird, wasm, depin)
zig test src/vsa.zig         # Run single test file
zig test src/vm.zig          # VM tests only

# Run
zig build bench              # Run benchmarks
zig build examples           # Run all examples

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

### AGENT MU (src/agent_mu/) — Post-Generation Auto-Fixer v8.12

| File | Purpose | Lines |
|------|---------|-------|
| `fixer.zig` | Auto-fix implementations (6 fixes) | 659 |
| `pattern_matcher.zig` | Semantic search with fuzzy matching | 396 |
| `agent_mu.zig` | Main loop + generator feedback | 363 |
| `logger.zig` | Logging + μ tracking (0.0382) | 308 |
| `diagnostic.zig` | Error parsing + FixType classification | 450+ |
| `verifier.zig` | Build/test/format verification | 200+ |

**AGENT MU Phases:**
1. **V01** — Verification (build + test + format)
2. **Phi02** — Pattern Search (REGRESSION_PATTERNS.md)
3. **Pi03** — Diagnostic (FixType classification)
4. **Mu05** — Auto-Fix (apply correction)
5. **Sigma07** — Success (log to SUCCESS_HISTORY.md)
6. **Chi06** — Regress (log to REGRESSION_PATTERNS.md)

**FixType Implementations:**
- `IMPORT_FIX` — Auto-add missing imports (0.9 confidence)
- `ALLOCATOR_FIX` — Inject allocator parameter (0.7 confidence)
- `ERROR_UNION_FIX` — Add error handling (0.75 confidence)
- `TYPE_FIX` — Fix type mismatches (0.95 confidence)
- `TEMPLATE_FIX` — Fix codegen templates
- `GENERATOR_PATCH` — Patch VIBEE compiler

**Intelligence Gain:** μ = 0.0382 per successful fix
- After 100 fixes: **×47 intelligence multiplier**

### Other Subsystems

| Directory | Purpose |
|-----------|---------|
| `src/b2t/` | BitNet inference |
| `src/phi-engine/` | Quantum-inspired computation |
| `src/tvc/` | Ternary Vector Computing |
| `src/maxwell/` | Constraint solving |

---

## Development Cycle

Run `zig build vibee -- koschei` to display the full development cycle.

### Minimal Workflow

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
zig build vibee -- gen specs/tri/feature.vibee  # → trinity/output/feature.zig

# 3. Test
zig test trinity/output/feature.zig

# 4. Write Critical Assessment (honest self-criticism)
# 5. Propose 3 TECH TREE options for next iteration
```

### For Hardware (Verilog/FPGA)

```bash
# Use language: varlog
zig build vibee -- gen specs/tri/feature_fpga.vibee  # → trinity/output/fpga/feature_fpga.v
```

---

## Code Generation Rules

**ALL APPLICATION CODE MUST BE GENERATED FROM .vibee SPECIFICATIONS**

### Allowed to edit

| Path | Description |
|------|-------------|
| `specs/tri/*.vibee` | Specifications (SOURCE OF TRUTH) |
| `src/vibeec/*.zig` | Compiler source ONLY |
| `src/*.zig` | Core library (vsa, vm, etc.) |
| `docs/*.md` | Documentation |

### Never edit (auto-generated)

| Path | Reason |
|------|--------|
| `trinity/output/*.zig` | Generated from .vibee |
| `trinity/output/fpga/*.v` | Generated from .vibee |
| `generated/*.zig` | Generated from .vibee |

---

## VIBEE CLI Commands

```bash
# Run VIBEE compiler (builds and runs)
zig build vibee -- gen <spec.vibee>         # Generate Zig code
zig build vibee -- chat --model <path>      # Chat with model
zig build vibee -- serve --port 8080        # Start HTTP server
zig build vibee -- help                     # Show all commands

# Or use the built binary directly
./zig-out/bin/vibee gen <spec.vibee>
./zig-out/bin/vibee chat --model <path>
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

## Zig 0.15 Idioms and Patterns

### Key Idioms for Generated Code

| Idiom | Description | Example |
|-------|-------------|---------|
| **ArrayListUnmanaged** | Use instead of ArrayList when allocator is passed | `var list = std.ArrayListUnmanaged(Type){};` |
| **Inferred Error Sets** | Use `!T` instead of explicit error sets | `fn foo() !void` |
| **Inline Loops** | Use `inline for` for compile-time iteration | `inline for enums.fields |` |
| **@Type() Dynamic** | Create types at compile time | `@Type(.{.Struct = ...})` |
| **ArenaAllocator** | Use for temporary allocations | `var arena = std.heap.ArenaAllocator.init(allocator);` |
| **Packed Structs** | Use for memory optimization | `const Packed = packed struct { ... };` |
| **Error Return Traces** | Enable with `-freturn-addr` | See stack traces |

### Before/After Examples

#### ArrayList → ArrayListUnmanaged

```zig
// ❌ BEFORE (v8.10)
var list = std.ArrayList(Type).init(allocator);
defer list.deinit();

// ✅ AFTER (v8.11+)
var list = std.ArrayListUnmanaged(Type){};
defer list.deinit(allocator);
```

#### Explicit Error Set → Inferred

```zig
// ❌ BEFORE
const Error = error{ NotFound, PermissionDenied };
fn foo() !Error { ... }

// ✅ AFTER
fn foo() !void { ... }  // Error set inferred from body
```

### Common Patterns in AGENT MU

#### FixType Detection

```zig
pub const FixType = enum {
    IMPORT_FIX,
    ALLOCATOR_FIX,
    ERROR_UNION_FIX,
    TYPE_FIX,
    TEMPLATE_FIX,
    GENERATOR_PATCH,
    // ...
};
```

#### Sacred Constants

```zig
pub const PHI: f64 = 1.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const MU: f64 = 1.0 / (PHI * PHI) / 10.0; // = 0.0382
```

#### Pattern Matching with Fuzzy Search

```zig
fn fuzzySimilarity(a: []const u8, b: []const u8) f64 {
    // Character bigram matching
    var matches: usize = 0;
    for (0..@min(a.len, b.len) - 1) |i| {
        if (a[i] == b[i] and a[i+1] == b[i+1]) matches += 1;
    }
    return @as(f64, @floatFromInt(matches)) / @as(f64, @floatFromInt(@min(a.len, b.len)));
}
```

---

## Zig 0.15.1 Idioms Mastery — Trinity Standard

### 1. Comptime Metaprogramming

| Idiom | Description | Example | Usage |
|-------|-------------|---------|-------|
| **@Type dynamic struct** | Create types at compile time | `@Type(.{.Struct = .{.fields = &fields}})` | VIBEE codegen |
| **Type Functions + @This()** | Generic type helpers | `fn List(comptime T: type) type` | Generic templates |
| **Comptime Assertions** | Compile-time validation | `comptime assert(phi * phi + 1.0 / (phi * phi) == 3.0)` | Sacred math |
| **Comptime String Building** | Dynamic code generation | `@fmt("pub fn {s}(...)", .{name})` | Template expansion |
| **Inline Loops + Branch Quota** | Unroll loops at comptime | `inline for (0..32) \|i\| { @setEvalBranchQuota(100000); }` | Fast struct gen |

```zig
// Type function pattern (used in VIBEE codegen)
fn Vec(comptime T: type, comptime n: usize) type {
    return extern struct {
        data: [n]T,
        const Self = @This();

        pub fn init() Self {
            return .{ .data = undefined };
        }
    };
}

// Comptime assertion for sacred constants
comptime {
    const phi: f64 = 1.618033988749895;
    const result = phi * phi + 1.0 / (phi * phi);
    if (result != 3.0) @compileError("Trinity identity violated!");
}
```

### 2. Memory & Allocators

| Idiom | Description | Example | Usage |
|-------|-------------|---------|-------|
| **ArrayListUnmanaged** | No embedded allocator | `var list = std.ArrayListUnmanaged(u8){};` | AGENT MU, logger |
| **ArenaAllocator** | Temporary allocations | `var arena = std.heap.ArenaAllocator.init(allocator);` | Log analysis |
| **Packed Structs** | Memory optimization | `const PackedVSA = packed struct { value: u3, flag: u1 };` | VSA structures |
| **Sentinel-terminated slices** | Safe C string handling | `const path: [:0]const u8 = "specs/...";` | File paths |
| **FixedBufferAllocator** | Stack-based allocation | `var buf: [1024]u8 = undefined; var fba = std.heap.FixedBufferAllocator.init(&buf);` | Temporary buffers |

```zig
// ArrayListUnmanaged pattern (AGENT MU standard)
var list = std.ArrayListUnmanaged(u8){};
defer list.deinit(allocator);

try list.append(allocator, 42);
try list.appendSlice(allocator, &.{1, 2, 3});

// Arena for temporary allocations
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
const arena_allocator = arena.allocator();

const temp1 = try arena_allocator.alloc(u8, 100);
const temp2 = try arena_allocator.alloc(u8, 200);
// All freed at once when arena.deinit() is called
```

### 3. Error Handling & Safety

| Idiom | Description | Example | Usage |
|-------|-------------|---------|-------|
| **Inferred Error Sets** | `!T` infers from body | `fn foo() !void { return error.OutOfMemory; }` | All AGENT MU |
| **Error Return Traces** | Debug error sources | `std.debug.print("{}", .{@errorReturnTrace()});` | Diagnostic |
| **Explicit Error Sets** | Defined error types | `const Error = error{OutOfMemory, InvalidVibee};` | VIBEE parser |
| **try vs catch** | Propagate vs handle | `const val = try foo();` vs `const val = foo() catch null;` | Error propagation |
| **errdefer** | Cleanup on error | `errdefer freeAlloc(ptr);` | Resource cleanup |

```zig
// Inferred error set (Zig 0.15+ standard)
fn parseVibee(allocator: std.mem.Allocator, source: []const u8) !VibeeSpec {
    const tokens = try tokenize(allocator, source);
    errdefer allocator.free(tokens);

    return try parseSpec(allocator, tokens);
}

// Error return traces for debugging
fn diagnosticDebug() !void {
    std.debug.print("Error trace:\n{}\n", .{@errorReturnTrace()});
}
```

### 4. Performance & SIMD

| Idiom | Description | Example | Usage |
|-------|-------------|---------|-------|
| **@Vector + @reduce** | SIMD operations | `const sum = @reduce(.Add, @Vector(8, f32){...});` | Sacred math |
| **@splat** | Broadcast scalar to vector | `const vec = @splat(@as(f32, 1.0));` | Vector init |
| **@prefetch** | Memory prefetching | `@prefetch(&data[i], .{.cache = .data, .rw = .read});` | Hot loops |
| **@shuffle** | Vector permutation | `@shuffle(f32, v1, v2, mask)` | VSA permutations |
| **Inline assembly** | CPU-specific instructions | `asm volatile ("nop" ::: "memory");` | Optimized paths |

```zig
// SIMD for sacred math calculations
const Vec4 = @Vector(4, f64);

fn sacredSIMD(a: Vec4, b: Vec4) Vec4 {
    // Parallel multiply-add
    const prod = a * b;
    const sum = @reduce(.Add, prod);
    return @splat(sum);
}

// Prefetch for hot loops (VSA operations)
fn fastBundle(vectors: []const VSAVector) VSAVector {
    var result: VSAVector = undefined;
    for (vectors, 0..) |v, i| {
        if (i + 4 < vectors.len) {
            @prefetch(&vectors[i + 4], .{.cache = .data, .rw = .read});
        }
        result = bundle2(result, v);
    }
    return result;
}
```

### 5. Build System & Project Structure

| Idiom | Description | Example | Usage |
|-------|-------------|---------|-------|
| **Lazy Modules** | On-demand module loading | `const mu = b.dependency("agent_mu", .{}).module("agent_mu");` | Modular arch |
| **Custom Build Steps** | Define build phases | `const mu_test = b.step("mu-test", "Run AGENT MU tests");` | Automated tests |
| **Conditional compilation** | Platform-specific code | `if (builtin.os.tag == .linux) ...` | Cross-platform |
| **b.addExecutable** | Create binaries | `const exe = b.addExecutable(.{ .name = "vibee", .root_source_file = "src/main.zig" });` | Build targets |

```zig
// build.zig: AGENT MU integration
const agent_mu = b.dependency("agent_mu", .{
    .target = target,
    .optimize = optimize,
});

const agent_mu_module = agent_mu.module("agent_mu");
exe.root_module.addImport("agent_mu", agent_mu_module);

// Custom build step for AGENT MU tests
const mu_test = b.step("agent-mu-test", "Run AGENT MU tests");
const mu_test_run = b.addRunArtifact(mu_test_exe);
mu_test.dependOn(&mu_test_run.step);
```

### 6. Raygui & UI (Glassmorphism)

| Idiom | Description | Example | Usage |
|-------|-------------|---------|-------|
| **Rounded + Glow + Alpha** | Glassmorphism cards | `rl.DrawRectangleRounded(bounds, 16, 8, glass_bg);` + glow | Cards, bubbles |
| **Scissor + Virtual List** | Efficient scrolling | `rl.BeginScissorMode(...)` + visible rows only | Chat panels |
| **Font loading** | Custom fonts | `const font = rl.LoadFontFromMemory(...)` | UI typography |
| **Render texture** | Offscreen rendering | `const texture = rl.LoadRenderTexture(width, height);` | Compositing |

```c
// Glassmorphism card (Trinity UI standard)
Color glass_bg = { 255, 255, 255, 20 };   // 8% opacity
Color glow = { 255, 215, 0, 40 };         // Gold glow

void DrawGlassCard(Rectangle bounds, const char* text) {
    // Card background
    DrawRectangleRounded(bounds, 16, 8, glass_bg);

    // Border glow
    DrawRectangleRoundedLines(bounds, 16, 8, 2, glow);

    // Text
    DrawTextEx(FONT, text, (Vector2){ bounds.x + 12, bounds.y + 8 }, 12, 0, WHITE);
}
```

### 7. Sacred Math in Comptime

| Idiom | Description | Example | Usage |
|-------|-------------|---------|-------|
| **Comptime φ, π, e** | Compile-time constants | `const golden = phi * phi + 1.0 / (phi * phi); // = 3` | All sacred calc |
| **Lucas Numbers** | Comptime sequence | `comptime var L = [_]f64{2, 1};` | VSA dimension |
| **Fibonacci @embedFile** | Precomputed tables | `const fib = @embedFile("fib_table.bin");` | Fast lookup |

```zig
// Sacred constants at comptime
const PHI: f64 = 1.618033988749895;
const MU: f64 = 1.0 / (PHI * PHI) / 10.0; // = 0.0382

comptime {
    // Verify Trinity identity
    const identity = PHI * PHI + 1.0 / (PHI * PHI);
    if (@abs(identity - 3.0) > 0.0001) {
        @compileError("φ² + 1/φ² ≠ 3");
    }
}

// Lucas numbers at comptime (VSA dimensions)
fn lucas(comptime n: usize) usize {
    comptime var a: usize = 2;
    comptime var b: usize = 1;
    comptime var i: usize = 0;
    inline while (i < n) : (i += 1) {
        const tmp = a + b;
        a = b;
        b = tmp;
    }
    return a;
}
```

---

## Exit Criteria

```
EXIT_SIGNAL = (
    tests_pass AND
    spec_complete AND
    critical_assessment_written AND
    tech_tree_options_proposed AND
    achievement_documented AND
    dashboard_widget_updated AND
    committed
)
```

---

## Mandatory Achievement Documentation

When completing significant milestones, AUTOMATICALLY document them:

### What Requires Documentation

| Type | Location | Action |
|------|----------|--------|
| Feature integration | `docsite/docs/research/` | Create report |
| Benchmark improvement | `docsite/docs/benchmarks/` | Update metrics |
| Node milestone | `docsite/docs/research/` | Create report |
| Performance proof | `docsite/docs/benchmarks/` | Add data |

### Documentation Steps (ALWAYS DO)

```bash
# 1. Create report
# docsite/docs/research/<milestone>-report.md

# 2. Update sidebars.ts
# Add entry to appropriate category

# 3. Build docsite
cd docsite && npm run build

# 4. Deploy BOTH website + docsite together (see "Deployment" section below)

# 5. Commit & push
git add docsite/
git commit -m "docs: Add <milestone> report"
git push
```

### Required Report Sections

| Section | Content |
|---------|---------|
| Key Metrics | Table with values, status |
| What This Means | For users, operators, investors |
| Technical Details | Architecture, implementation |
| Conclusion | Summary, next steps |

---

## Telegram Bot Rules

```
FORBIDDEN: InlineKeyboardMarkup (buttons in message)
ONLY: ReplyKeyboardMarkup (buttons at bottom of screen)
```

Specifications: `specs/tri/telegram_bot/`

---

## Dashboard & Visual Rules

### Canvas Mirror Widget Mandate

**EVERY new module MUST have a corresponding Canvas Mirror widget.**

When implementing a new subsystem or feature:

| Step | Action |
|------|--------|
| 1 | Identify which Mirror column it belongs to (RAZUM/MATERIYA/DUKH) |
| 2 | Add TypeScript interface in `website/src/services/chatApi.ts` |
| 3 | Add fetch function with mock fallback in `chatApi.ts` |
| 4 | Add widget to the appropriate column in `TrinityCanvas.tsx` Mirror section |
| 5 | Widget MUST use `glassStyle()` and column color scheme |
| 6 | Widget MUST be collapsible (toggle expand/collapse) |

Without a visual dashboard widget, a module is **NOT considered complete**.

### Column Assignment Guide

| Column | Color | Realm | Widget Types |
|--------|-------|-------|-------------|
| RAZUM (Gold) | `#ffd700` | Mind | Routing, intelligence, logs, decisions |
| MATERIYA (Cyan) | `#00ccff` | Matter | Infrastructure, storage, data, files |
| DUKH (Purple) | `#aa66ff` | Spirit | Actions, tools, proofs, transfers, health |

### Style Rules

```
Font:       FONT (Outfit) for labels, MONO (JetBrains Mono) for values
Sizes:      12px headers, 8-9px metrics, 7px sublabels
Opacity:    active values at 1.0, inactive at 0.3
Borders:    column-colored with 0.1-0.4 alpha
Animations: framer-motion for entry, gauge bars
```

---

## Deployment (GitHub Pages)

**CRITICAL: Website and Docsite share ONE gh-pages branch. ALWAYS deploy BOTH together.**

```
gh-pages branch structure:
├── index.html          ← website (Vite React SPA)
├── assets/             ← website assets
├── docs/               ← docsite (Docusaurus)
│   ├── index.html      ← docs landing page
│   ├── api/
│   ├── research/
│   └── assets/
└── ...
```

| Site | URL | Source | Framework | baseUrl |
|------|-----|--------|-----------|---------|
| Website | `gHashTag.github.io/trinity/` | `website/` | Vite (React SPA) | `/trinity/` |
| Docsite | `gHashTag.github.io/trinity/docs/` | `docsite/` | Docusaurus 3.x | `/trinity/docs/` |

### Deploy Process (ALWAYS use this)

```bash
# 1. Build website
cd website && npx vite build

# 2. Build docsite
cd docsite && npm run build

# 3. Assemble gh-pages: website root + docsite in docs/
rm -rf /tmp/gh-pages-deploy
mkdir /tmp/gh-pages-deploy
cp -r website/dist/* /tmp/gh-pages-deploy/
mkdir -p /tmp/gh-pages-deploy/docs
cp -r docsite/build/* /tmp/gh-pages-deploy/docs/

# 4. Force push to gh-pages
cd /tmp/gh-pages-deploy
git init && git checkout -b gh-pages
git add -A && git commit -m "Deploy: <description>"
git remote add origin git@github.com:gHashTag/trinity.git
git push origin gh-pages --force
```

### Docsite Configuration Rules

| Setting | Value | NEVER change |
|---------|-------|-------------|
| `baseUrl` | `'/trinity/docs/'` | Changing breaks all asset paths |
| `routeBasePath` | `'/'` | Docs at root of `/trinity/docs/` |
| `src/pages/index.tsx` | **MUST NOT EXIST** | Conflicts with docs `slug: /` → "Duplicate routes" → site breaks |

### FORBIDDEN deploy methods

| Method | Why forbidden |
|--------|--------------|
| `USE_SSH=true npm run deploy` | `docusaurus deploy` force-pushes ONLY docsite to gh-pages, **deleting website** |
| `npx gh-pages -d dist` | Unreliable, often fails silently |
| Deploying website alone without docsite | **Deletes docs/** from gh-pages |
| Deploying docsite alone without website | **Deletes website** from gh-pages |

**IMPORTANT:**
- НЕ использовать Vercel — сайт на GitHub Pages
- НИКОГДА не деплоить website или docsite по отдельности — ТОЛЬКО вместе
- После деплоя GitHub Pages обновляется через 1-2 минуты
- Для проверки: Cmd+Shift+R (хард-рефреш) в браузере
- MDX файлы: экранировать `<Tag>` → `\<Tag\>`, `{expr}` → `\{expr\}` вне блоков кода

---

### Live Documentation

| Page | URL |
|------|-----|
| Research | https://gHashTag.github.io/trinity/docs/research |
| Benchmarks | https://gHashTag.github.io/trinity/docs/benchmarks |
| API Reference | https://gHashTag.github.io/trinity/docs/api |

---

## Ralph Autonomous Development (MANDATORY)

**ALL development MUST go through Ralph.** This saves time by enforcing quality gates, tech tree navigation, memory consultation, and structured workflows automatically.

### Why Ralph-Only

| Without Ralph | With Ralph |
|--------------|-----------|
| Manual quality checks | Automated gates (build + test + format) |
| Forget to update tech tree | Tree updated every cycle |
| Repeat past mistakes | REGRESSION_PATTERNS.md consulted |
| No structured progress | fix_plan.md + TECH_TREE.md tracking |
| Commits to main | Feature branches enforced |

### Configuration

```
.ralph/
├── PROMPT.md              # Autonomous work instructions
├── AGENT.md               # Build/test/run commands
├── RULES.md               # Universal development guardrails (16 sections)
├── TECH_TREE.md            # Tech tree navigation (35 nodes, 6 branches)
├── fix_plan.md             # Current sprint tasks with acceptance criteria
├── SUCCESS_HISTORY.md      # Working patterns + commit hashes
├── REGRESSION_PATTERNS.md  # Anti-patterns + root causes
├── specs/                  # Ralph-specific specs
├── examples/               # Workflow examples
├── logs/                   # Execution logs
└── docs/generated/         # Auto-generated docs
.ralphrc                    # Runtime settings (tools, timeouts, gates)
```

### How to Use

```bash
# 1. Add task to .ralph/fix_plan.md (with acceptance criteria)
# 2. Start Ralph
ralph --monitor

# Ralph will:
#   - Read TECH_TREE.md, fix_plan.md, SUCCESS_HISTORY.md, REGRESSION_PATTERNS.md
#   - Pick highest-priority task
#   - Create ralph/<task-slug> branch
#   - Implement via Golden Chain cycle (spec → gen → test → assess → tree → commit)
#   - Run quality gates (build + test + format)
#   - Update tech tree and memory files
#   - Loop until EXIT_SIGNAL = true
```

### Commands

```bash
ralph --monitor          # Start with live monitoring dashboard
ralph --help             # Show options
ralph-enable             # Enable Ralph in project
ralph-import prd.md      # Convert PRD to Ralph tasks
```

### Safeguards

- Rate limiting: 100 calls/hour (configurable)
- Circuit breaker: 3 no-progress loops → cooldown
- Branch safety: never commits to main
- Quality gates: build + test + format before every commit
- Memory: consults SUCCESS_HISTORY and REGRESSION_PATTERNS every loop
- Dual-condition exit: heuristic indicators + explicit EXIT_SIGNAL

### Current Task (via Ralph)

**VSA Mathematical Framework** — proofs + optimizations for bind/unbind/bundle, multilingual code gen.
See `.ralph/fix_plan.md` and `.ralph/TECH_TREE.md` for details.

Repository: https://github.com/frankbria/ralph-claude-code

---

## Mathematical Foundation

Ternary {-1, 0, +1} provides:
- Information density: 1.58 bits/trit (vs 1 bit/binary)
- Memory savings: 20x vs float32
- Compute: Add-only (no multiply)

Trinity Identity: `φ² + 1/φ² = 3` where φ = (1 + √5) / 2

---

