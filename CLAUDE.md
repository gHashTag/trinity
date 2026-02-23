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

## TRI COMMANDER

TRI COMMANDER is the primary human-AI interface for Trinity development — a tmux-based chat dashboard with sacred mathematics.

**Launch:**
```bash
bash bin/ralph-dashboard-v4      # Start tmux dashboard
tmux attach -t ralph               # Attach to running session
```

**Interface Layout:**
| Window | Key | Purpose |
|--------|-----|---------|
| HOME | `Ctrl+b 0` | Chat interface with AI (▲ user, ▼ agent) |
| Loop | `Ctrl+b 1` | Development cycle status |
| Tasks | `Ctrl+b 2` | Task queue and progress |
| Memory | `Ctrl+b 3` | Success history + regression patterns |
| Log | `Ctrl+b 4` | Real-time logs |

**Trit Pyramid Banner (4 levels):**
```
                    +1
                   -1 +1
                  +1  0 +1
                 -1 +1 +1 -1
             ═════════════════════
            ▐ T R I N I T Y ▌  φ² + 1/φ² = 3
             ═════════════════════

    Trit:  -1   0   +1    |  Base: 3  |  φ = 1.6180339...
    μ = φ^(-4) = 0.0382   |  χ = 0.0618  |  σ = φ  |  ε = 1/3
    Lucas: 2,1,3,4,7,11,18,29,47,76,123
```

**Keyboard Shortcuts:**
- `Ctrl+b 0-4` — Switch windows
- `Ctrl+b d` — Detach (keep running in background)
- `Ctrl+b [` — Scroll/copy mode (q to exit, arrows to scroll)
- `Ctrl+b c` — Create new window
- `Ctrl+b ,` — Rename window

**Trit Symbols:**
- `▲` = +1 (positive trit) — User input
- `▼` = -1 (negative trit) — AI response
- `●` = 0 (zero trit) — System/neutral

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

### VIBEE Compiler

**Source of truth:** `trinity-nexus/lang/src/` (imported as `trinity-lang` module)

| File | Location | Purpose |
|------|----------|---------|
| `root.zig` | `trinity-nexus/lang/src/` | Module exports (v0.2.0) |
| `vibee_parser.zig` | `trinity-nexus/lang/src/` | Parse .vibee specifications |
| `zig_codegen.zig` | `trinity-nexus/lang/src/` | Generate Zig code |
| `verilog_codegen.zig` | `trinity-nexus/lang/src/` | Generate Verilog (FPGA) |
| `lang_generators.zig` | `trinity-nexus/lang/src/` | Multi-language generators |
| `codegen/` | `trinity-nexus/lang/src/` | Pattern-based code generation (141+ patterns) |
| `gen_cmd.zig` | `src/vibeec/` | CLI entry point (thin wrapper) |
| `gguf_chat.zig` | `src/vibeec/` | GGUF model interface |
| `http_server.zig` | `src/vibeec/` | HTTP API server |

**Architecture:** `src/vibeec/gen_cmd.zig` imports `trinity-lang` module. No compiler code lives in `src/vibeec/` — only CLI tools.

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

## TRI CLI Commands (v8.27 - STRICT MODE)

**TRI** is the Unified Trinity Command Line Interface — the primary orchestrator for all development workflows.

```bash
# Build and run
zig build tri                    # Build TRI binary
./zig-out/bin/tri                # Interactive REPL mode
./zig-out/bin/tri <command>      # Run specific command
./zig-out/bin/tri help           # Show all commands
```

### Core Commands (Link 1-6)

| Command | Description | Link |
|---------|-------------|------|
| `tri chat [--stream] <msg>` | Interactive chat (vision + voice + tools) | - |
| `tri code [--stream] <prompt>` | Generate code with typing effect | - |
| `tri gen <spec.vibee>` | Compile VIBEE spec to Zig/Verilog | - |
| `tri pipeline run <task>` | Execute 17-link Golden Chain (incl TVC) | 0-17 |
| `tri decompose <task>` | Break task into sub-tasks (Link 4) | 4 |
| `tri plan <task>` | Generate implementation plan (Link 5) | 5 |
| `tri spec_create <name>` | Create .vibee spec template (Link 6) | 6 |
| `tri loop-decide [mode]` | Loop decision: CONTINUE/EXIT (Link 17) | 17 |

### Verification Commands (Link 7-13)

| Command | Description |
|---------|-------------|
| `tri verify` | Run tests + benchmarks (Links 7-11) |
| `tri bench` | Run performance benchmarks |
| `tri verdict` | Generate toxic verdict (Link 14) |

### SWE Agent Commands

| Command | Description |
|---------|-------------|
| `tri fix <file>` | Detect and fix bugs |
| `tri explain <file\|prompt>` | Explain code or concept |
| `tri test <file>` | Generate tests |
| `tri doc <file>` | Generate documentation |
| `tri refactor <file>` | Suggest refactoring |
| `tri reason <prompt>` | Chain-of-thought reasoning |

### Git Commands

| Command | Description |
|---------|-------------|
| `tri status` | Git status --short |
| `tri diff` | Git diff |
| `tri log` | Git log --oneline -10 |
| `tri commit <message>` | Git add -A && commit |

### TVC (Distributed Learning)

| Command | Description |
|---------|-------------|
| `tri tvc-demo` | Run TVC chat demo (distributed learning) |
| `tri tvc-stats` | Show TVC corpus statistics |

### Demo & Benchmark Commands

Each cycle has `-demo` and `-bench` variants:

| Cycle | Commands | Description |
|-------|----------|-------------|
| Multi-Agent | `tri agents-demo`, `tri agents-bench` | Coordination |
| Long Context | `tri context-demo`, `tri context-bench` | Sliding window |
| RAG | `tri rag-demo`, `tri rag-bench` | Retrieval |
| Voice I/O | `tri voice-demo`, `tri voice-bench` | STT+TTS |
| Code Sandbox | `tri sandbox-demo`, `tri sandbox-bench` | Safe execution |
| Streaming | `tri stream-demo`, `tri stream-bench` | Multi-modal pipeline |
| Vision | `tri vision-demo`, `tri vision-bench` | Image analysis |
| Fine-tuning | `tri finetune-demo`, `tri finetune-bench` | Model adaptation |
| Multi-Modal | `tri multimodal-demo`, `tri multimodal-bench` | Unified |
| Tool Use | `tri tooluse-demo`, `tri tooluse-bench` | Tools from any modality |
| Unified Agent | `tri unified-demo`, `tri unified-bench` | All capabilities |
| Autonomous | `tri auto-demo`, `tri auto-bench` | Self-directed |
| Orchestration | `tri orch-demo`, `tri orch-bench` | Coordinator+specialists |
| MM Orchestration | `tri mmo-demo`, `tri mmo-bench` | Multi-modal agents |
| Memory | `tri memory-demo`, `tri memory-bench` | Cross-modal learning |
| Persistent | `tri persist-demo`, `tri persist-bench` | Disk serialization |
| Spawn | `tri spawn-demo`, `tri spawn-bench` | Dynamic agents |
| Cluster | `tri cluster-demo`, `tri cluster-bench` | Multi-node |
| Work-Stealing | `tri worksteal-demo`, `tri worksteal-bench` | Adaptive scheduler |
| Plugin | `tri plugin-demo`, `tri plugin-bench` | Extension system |
| Comms | `tri comms-demo`, `tri comms-bench` | Communication protocol |
| Observe | `tri observe-demo`, `tri observe-bench` | Observability |
| Consensus | `tri consensus-demo`, `tri consensus-bench` | Coordination |
| Spec Exec | `tri specexec-demo`, `tri specexec-bench` | Speculative execution |
| Governor | `tri governor-demo`, `tri governor-bench` | Resource governor |
| Fed Learn | `tri fedlearn-demo`, `tri fedlearn-bench` | Federated learning |
| Event Src | `tri eventsrc-demo`, `tri eventsrc-bench` | Event sourcing |
| Cap Sec | `tri capsec-demo`, `tri capsec-bench` | Capability security |
| DTXN | `tri dtxn-demo`, `tri dtxn-bench` | Distributed transactions |
| Cache | `tri cache-demo`, `tri cache-bench` | Adaptive caching |
| Contract | `tri contract-demo`, `tri contract-bench` | Agent negotiation |
| Workflow | `tri workflow-demo`, `tri workflow-bench` | Temporal workflows |

### Sacred Mathematics (v2.0)

| Command | Description |
|---------|-------------|
| `tri math` | Sacred math dispatcher |
| `tri constants` | Show φ, π, e, μ, χ, σ, ε... |
| `tri phi <n>` | Compute φⁿ |
| `tri fib <n>` | Fibonacci with BigInt |
| `tri lucas <n>` | Lucas L(n) — L(2)=3=TRINITY |
| `tri spiral <n>` | φ-spiral coordinates |

### Info Commands

| Command | Description |
|---------|-------------|
| `tri info` | System information |
| `tri version` | Show version |
| `tri help` | This help message |

### Sacred Logging

All TRI CLI calls are logged to `trinity-nexus/.ralph/sacred_tool_calls.log`:
```
[φ] 1 | tri spec-create test_module
[φ] 2 | tri loop-decide auto
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


## V7 Self-Improving Codegen (19.02.2026)

VIBEE v7 adds self-improvement capability — VIBEE analyzes its own generated code, finds weak spots, and automatically patches itself.

### Components

- `specs/tri/vibee_self_improver.vibee` — 20 behaviors for self-improvement loop
- `src/vibeec/self_improver.zig` — Engine with CLI (366 loc)
- `src/vibeec/codegen/tests_gen.zig` — Test generator with spec-level test support

### Usage

```bash
# Generate code with self-improvement
zig build vibee -- gen specs/tri/vibee_self_improver.vibee

# Run self-improvement engine (dry-run)
./zig-out/bin/vibee-self-improve specs/tri/vibee_self_improver.vibee --dry-run --verbose

# Run full improvement loop
./zig-out/bin/vibee-self-improve --iterations 5 --threshold 95.0
```

### Metrics

- 73.5% real patterns (fixed from 138.2% overcount bug)
- 27/27 tests pass
- Self-improvement loop: analyze → suggest → patch → regenerate → validate

