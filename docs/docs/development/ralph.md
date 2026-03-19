# Ralph Autonomous Development System

**Ralph** is Trinity's autonomous AI development agent — a workflow system designed to build complex ternary AI systems with high reliability through enforced quality gates, tech tree navigation, and structured development cycles.

---

## Quick Start

```bash
# 1. Build the binaries
zig build

# 2. Add a task to the fix plan
# Edit .ralph/fix_plan.md and add your task

# 3. Run Ralph agent
./zig-out/bin/ralph-agent --help

# For autonomous issue resolution
tri agent run <issue-number>

# Ralph agent will:
# - Read TECH_TREE.md, fix_plan.md, SUCCESS_HISTORY.md, REGRESSION_PATTERNS.md
# - Pick highest-priority task
# - Create feature branch
# - Implement via Golden Chain cycle
# - Run quality gates (build + test + format)
# - Update tech tree and memory files
# - Loop until EXIT_SIGNAL = true
```

---

## Architecture Overview

Ralph is not just an agent; it's a comprehensive development framework that enforces best practices through automation and memory systems.

### Core Components

| Component | Location | Purpose |
|-----------|----------|---------|
| **PROMPT.md** | `.ralph/` | Autonomous work instructions and architecture map |
| **AGENT.md** | `.ralph/` | Build/test/run commands for Trinity |
| **RULES.md** | `.ralph/` | Universal development guardrails (16 sections) |
| **TECH_TREE.md** | `.ralph/` | Tech tree navigation (60+ nodes across 11 branches) |
| **fix_plan.md** | `.ralph/` | Current sprint tasks with acceptance criteria |
| **SUCCESS_HISTORY.md** | `.ralph/memory/` | Working patterns + commit hashes |
| **REGRESSION_PATTERNS.md** | `.ralph/memory/` | Anti-patterns + root causes |
| **.ralphrc** | `.ralph/` | Runtime configuration |

### Directory Structure

```
.ralph/
├── PROMPT.md              # Autonomous work instructions
├── AGENT.md               # Build/test/run commands
├── RULES.md               # Development guardrails
├── TECH_TREE.md            # Tech tree navigation
├── fix_plan.md             # Current sprint tasks
├── .ralphrc                # Runtime settings
├── memory/                 # Knowledge base
│   ├── SUCCESS_HISTORY.md      # Working patterns
│   └── REGRESSION_PATTERNS.md  # Anti-patterns
├── golden_chain/           # Development cycle docs
├── scripts/                # Automation scripts
│   ├── gate.sh                 # Quality gates (build/test/format)
│   ├── audit.sh                # Project health check
│   └── bench.sh                # Performance benchmarks
├── logs/                    # Execution logs
├── internal/                # State tracking
└── reports/                 # Generated reports
```

---

## The Golden Chain — 9-Link Development Cycle

Every development task in Ralph follows the **Golden Chain**, a strict 9-link cycle that ensures quality, documentation, and continuous improvement.

### Link 1: TRI DECOMPOSE

Break down the objective into atomic "Quarks" (tasks).

**Example:**
```bash
tri decompose "full local fluent multilingual code gen"
```

**Output:**
- Q-MGEN-001: Support `language: [list]` in VIBEE parser
- Q-MGEN-002: Implement Fluent Python Template
- Q-MGEN-003: Implement Fluent Rust Template
- Q-MGEN-004: Implement Fluent TypeScript Template
- Q-MGEN-005: Symbolic Mapping Verification
- Q-MGEN-006: Multilingual Benchmark Suite

### Link 2: TRI PLAN

Strategy update. Select Tech Tree nodes, define ROI, and plan implementation blocks.

**Actions:**
1. Read `.ralph/TECH_TREE.md` for available nodes
2. Cross-reference with `fix_plan.md`
3. Select nodes that advance the tree
4. Calculate ROI: `(impact / complexity) * unlock_count`
5. Update `specs/tri/tech_tree_strategy.vibee`

### Link 3: TRI SPEC CREATE

Create/update `.vibee` files. This is the **Single Source of Truth**.

**Example Spec:**
```yaml
name: multilingual_codegen
version: "1.0.0"
language: zig
module: multilingual_codegen

types:
  InputLanguage:
    variants: [english, spanish, french, german, japanese]

  TargetLanguage:
    variants: [zig, python, typescript, rust, go]

behaviors:
  - name: detectInputLanguage
    given: User prompt text
    when: Language detection is requested
    then: Returns most likely InputLanguage with confidence score

  - name: generateCode
    given: TargetLanguage and AST
    when: Code generation is requested
    then: Returns idiomatic code in target language
```

**MANDATE:** ALL application code MUST be generated from `.vibee` specifications. Manual Zig creation is forbidden.

### Link 4: TRI GEN

Generate code from specifications.

```bash
zig build vibee -- gen specs/tri/multilingual_codegen.vibee
```

**Output:** `trinity/output/multilingual_codegen.zig`

**Rules:**
- NEVER edit generated files manually
- ALL `.zig` files MUST be generated from specs
- Edit the source spec in `specs/tri/*.vibee` instead

### Link 5: TRI TEST

End-to-end testing. Verify generated code against specs.

```bash
zig build test
```

**Gate:** Tests must pass before proceeding.

### Link 6: TRI BENCH

Performance benchmarking vs previous versions. Provide detailed proofs/logs.

```bash
zig build bench
```

**Required:**
- Detailed performance logs
- Comparison with previous versions
- Proof of improvement (or degradation analysis)

### Link 7: TRI VERDICT (TOXIC)

**TOXIC VERDICT ENFORCED** — Brutally honest assessment of the results.

**Format:**
```markdown
### Link 7: Tri Verdict (TOXIC)

**Score:** 7/10
**Status:** FAIL

**What Worked:**
- Spec generation successful
- Code quality improved

**What Failed:**
- Performance degraded by 15%
- Test coverage below 80%

**Root Cause:**
- Missing SIMD optimization
- Inadequate test suite

**Next Steps:**
1. Add SIMD vectorization
2. Expand test coverage
3. Re-benchmark
```

**Tone:** Professional but uncompromising. Identify every flaw.

**Metric:** Numerical score (e.g., 10/10) and binary status (Prod/Fail).

### Link 8: TRI GIT

Commit and push changes with proper convention.

```bash
git add -A
git commit -m "feat(multilingual): Fluent codegen - Python, Rust, TypeScript support — Tests 12-15 (4/5 P80%)"
git push
```

**Commit Convention:**
```
type(scope): description — Tests X-Y (N/M P%)
```

**Types:** feat, fix, refactor, test, docs, perf, chore

**Scopes:** vibeec, vsa, vm, firebird, depin, golden-chain, e2e, dashboard

**Automatic:** Telegram report is sent via post-commit hook.

### Link 9: TRI LOOP DECISION

Loop decision (Needle check). Did we achieve the objective?

**Exit Criteria:**
```
EXIT_SIGNAL = (
    tests_pass AND
    build_compiles AND
    format_clean AND
    spec_complete AND
    critical_assessment_written AND
    tech_tree_options_proposed AND    # 3 options with actual node IDs
    tech_tree_updated AND             # TECH_TREE.md reflects current state
    committed_to_feature_branch
)
```

**If EXIT_SIGNAL = true:**
- Propose 3 Tech Tree options for next iteration
- Update TECH_TREE.md
- Record in SUCCESS_HISTORY.md

**If EXIT_SIGNAL = false:**
- Identify blocking issues
- Decompose into sub-tasks
- Continue loop

---

## Quality Gates

Ralph enforces strict quality gates before any commit. All gates must pass in order.

### Gate Sequence

```
1. zig build              → Must compile (= type-check for Zig)
2. zig build test         → Must pass (ONLY after build succeeds)
3. zig fmt --check src/   → Must be clean
4. git commit             → Only after all above pass
```

### Gate Details

| Gate | Command | Required | Blocks |
|------|---------|----------|--------|
| Build | `zig build` | Exit code 0 | Cannot run tests until build passes |
| Test | `zig build test` | All pass | Cannot format-check until tests pass |
| Format | `zig fmt --check src/` | Clean | Cannot commit until format is clean |
| Branch | `git branch --show-current` | Not `main` | Cannot commit to main |

### Failure Protocol

If ANY gate fails:

1. Task is **NOT** complete
2. Do **NOT** proceed to next gate
3. Do **NOT** report success
4. Fix the issue, then restart from gate 1

**Completion blocking loop:**
```
fix → build → test → format → commit
 ↑                              |
 └──── if ANY gate fails ───────┘
```

---

## Tech Tree Navigation

The Tech Tree is your strategic development roadmap with 60+ nodes across 11 branches.

### Tree Structure

```
Trinity Tech Tree
│
├── Core (100% ✅) — VSA, VM, HybridBigInt, PackedTrit
├── Inference (80% 🟡) — GGUF, Transformer, KV Cache
├── Optimization (100% ✅) — SIMD, MatMul, PagedAttention
├── Hardware (67% 🟡) — Abstraction layer, FPGA acceleration
├── Math (100% ✅) — Proofs, benchmarks, multilingual
├── Development (100% ✅) — Trace, KG insight, DHT monitor
├── Symbolic (100% ✅) — Triples, KG, TVC, rewards
├── Visualization (100% ✅) — Canvas monitor, dashboard
├── Nexus (100% ✅) — Modular ecosystem migration
├── vibee-v8-production-swarm (100% ✅) — 32-agent swarm
└── Multilingual (100% ✅) — Python, Rust, TypeScript
```

### Tech Tree States

| State | Meaning |
|-------|---------|
| **Available** | Ready to start (all dependencies satisfied) |
| **In Progress** | Currently being worked on |
| **Completed** | Done and verified |
| **Locked** | Waiting for dependencies |

### Task Selection Process

1. Read `.ralph/TECH_TREE.md` for current tree state
2. Open `fix_plan.md` — tasks should align with tree priorities
3. Choose the highest-priority incomplete `[ ]` item
4. If all tasks are done or blocked, pick the next recommended node from TECH_TREE.md
5. Focus on ONE task. Complete it fully before starting the next

### ROI Formula

```javascript
ROI = (impact / complexity) * unlock_count
```

- **impact:** 1-10 (user value, performance gain)
- **complexity:** 1-10 (estimated effort)
- **unlock_count:** Number of dependent nodes this unlocks

### Updating the Tech Tree

**After completing a Tech Tree node:**

1. Update `TECH_TREE.md` — move node from "Available"/"In Progress" to "Completed"
2. Check if any locked nodes should now unlock (dependencies satisfied)
3. Update branch progress percentages
4. Update `specs/tri/tech_tree_strategy.vibee` — change node status
5. Record in `SUCCESS_HISTORY.md` with commit hash

**When proposing 3 Tech Tree options (exit criteria):**

- Option 1: `<node-id>` — highest ROI, why it matters
- Option 2: `<node-id>` — alternative path, different branch
- Option 3: `<node-id>` — exploratory/risky but high-reward

---

## Memory System

Ralph maintains a dual-memory system to learn from successes and failures.

### SUCCESS_HISTORY.md

Records working patterns and commit hashes that lead to successful outcomes.

**Entry Format:**
```markdown
## CODEGEN-001: VIBEE Real Codegen (2026-02-22)

**Status:** ✅ COMPLETE
**Branch:** `codegen-002-fix-implementation-field`

### What Worked

1. **Implementation Field Support**
   - `src/vibeec/codegen/emitter.zig:1407-1429`: Full implementation field handling
   - `pub fn` detection → insert as-is with signature
   - Body-only detection → wrap in inferred signature

2. **ML Pattern Implementations**
   - `src/vibeec/codegen/patterns/ml.zig`: 4 patterns updated
   - `evaluate*`: MSE calculation with model.forward()
   - `learn*`: Hebbian learning with error-based weight updates

### Files Modified/Created

| File | Action | Lines |
|------|--------|-------|
| `src/vibeec/codegen/patterns/ml.zig` | Modified | +40 |
| `specs/tri/test_implementation.vibee` | Created | ~50 |

### Key Metrics

| Metric | Value |
|--------|-------|
| ML patterns implemented | 4/4 |
| PAS improvement (avg) | 25.5% |
| Energy saved (8 tasks) | ~20 Wh |
```

**Usage:**
- Before implementing new features, search SUCCESS_HISTORY for similar patterns
- Reuse proven approaches instead of inventing from scratch
- Record successful patterns immediately after verification

### REGRESSION_PATTERNS.md

Records failed approaches, anti-patterns, and their root causes.

**Entry Format:**
```markdown
---
date: 2026-02-17
anti-pattern: Wrong binary path
root-cause: Zig build system separation
---
### Wrong VIBEE compiler binary path
- **Anti-pattern:** Using legacy binary paths like `./zig-out/bin/vibee`
- **Correct approach:** Use `zig build vibee -- gen <spec.vibee>`
- **Files:** All VIBEE invocations

---
date: 2026-02-17
anti-pattern: Return typed value from !void function
root-cause: Codegen signature mismatch with implementation blocks
---
### Implementation blocks returning typed values from !void functions
- **Anti-pattern:** Writing `return InputLanguage.english;` in a `.vibee` implementation block
- **Correct approach:** Implementation blocks must only `return;` or use `try`/error flow
- **Files:** `specs/tri/multilingual_codegen.vibee`, `src/vibeec/multilingual_engine.zig`
```

**Usage:**
- When encountering an error, search this file for the error message
- Before trying a new approach, check it's not listed as an anti-pattern
- After analyzing a failure, add entry immediately to prevent recurrence

### Pattern Search Mandate

Before implementing anything new:

1. **Search the codebase** for similar implementations:
   ```bash
   grep -r "keyword" src/
   ```

2. **Study existing patterns** — how do similar modules/functions work?

3. **Adapt proven patterns** — reuse what works rather than inventing from scratch

4. **Document new patterns** — if you create a novel approach that works, record it in `SUCCESS_HISTORY.md`

**Goal:** Minimize invention, maximize reuse.

---

## Configuration (.ralphrc)

Ralph behavior is configured through `.ralphrc` file.

### Example Configuration

```bash
# API Fallback
FALLBACK_API_KEY="ce8a4b21d9134c2988b3667d032bf88f.1votRIKGtIM99Du"
FALLBACK_API_BASE="https://api.z.ai/api/paas/v4"
FALLBACK_MODEL="glm-5"

# Telegram Reporting
RALPH_REPORT_ENABLED=true
RALPH_TELEGRAM_CHAT_ID=144022504
RALPH_REPORT_ONLY_IMPORTANT=true

# Rate Limit Handling
RALPH_RATE_LIMIT_WAIT=true
RALPH_AUTO_RESTART=true
```

### Configuration Options

| Option | Type | Description |
|--------|------|-------------|
| `FALLBACK_API_KEY` | string | Backup API key for emergencies |
| `FALLBACK_API_BASE` | string | Backup API endpoint URL |
| `FALLBACK_MODEL` | string | Backup model identifier |
| `RALPH_REPORT_ENABLED` | boolean | Enable Telegram notifications |
| `RALPH_TELEGRAM_CHAT_ID` | string | Telegram chat ID for reports |
| `RALPH_REPORT_ONLY_IMPORTANT` | boolean | Only report important events |
| `RALPH_RATE_LIMIT_WAIT` | boolean | Wait on rate limit instead of failing |
| `RALPH_AUTO_RESTART` | boolean | Auto-restart after failures |

---

## Safeguards

Ralph includes multiple safeguards to ensure safe, reliable autonomous development.

### Rate Limiting

- **Default:** 100 calls/hour (configurable in `.ralphrc`)
- **Action:** When rate limit hit, wait or switch to fallback API
- **Configuration:** `RALPH_RATE_LIMIT_WAIT=true`

### Circuit Breaker

- **Trigger:** 3 no-progress loops → cooldown
- **Action:** Stop execution, notify user, wait for manual intervention
- **Reset:** Manual restart required after cooldown

### Branch Safety

- **Rule:** Never commits to `main`
- **Enforcement:** Git pre-commit hook checks branch name
- **Pattern:** All branches use `ralph/<task-slug>` format

### Quality Gates

- **Build gate:** Must compile before testing
- **Test gate:** Must pass all tests before formatting
- **Format gate:** Must be clean before committing
- **Branch gate:** Must be on feature branch before pushing

### Memory Consultation

- **SUCCESS_HISTORY:** Consulted every loop for proven patterns
- **REGRESSION_PATTERNS:** Consulted every loop to avoid mistakes
- **TECH_TREE:** Consulted every loop for strategic alignment

### Dual-Condition Exit

Two conditions must be met before Ralph stops:

1. **Heuristic indicators:**
   - All tests pass
   - Build compiles
   - Format is clean
   - Spec is complete
   - Critical assessment written

2. **Explicit EXIT_SIGNAL:**
   - Tech tree options proposed (3 with actual node IDs)
   - Tech tree updated (TECH_TREE.md reflects current state)
   - Committed to feature branch

---

## Telegram Notifications

All pipeline events are automatically reported to Telegram via post-commit hooks.

### Notification Events

| Event | When | Script |
|-------|------|--------|
| Gate Pass | After `gate.sh` succeeds | `report.sh gate_pass` |
| Gate Fail | When any gate fails | `report.sh gate_fail <gate_name>` |
| Commit | After every git commit | Post-commit hook |
| Circuit Breaker Open | When CB trips | `report.sh circuit_open` |
| Circuit Breaker Close | When CB resets | `report.sh circuit_close` |
| Loop Start/End | At loop boundaries | `report.sh loop_start/loop_end` |
| Verdict | After Toxic Verdict | `report.sh verdict` |
| Status | After RALPH_STATUS block | `report.sh status` |

### Configuration

**Enable/Disable:** Set `RALPH_REPORT_ENABLED=false` in `.ralphrc`

**Chat ID:** Configure `RALPH_TELEGRAM_CHAT_ID` in `.ralphrc`

**Important Events Only:** Set `RALPH_REPORT_ONLY_IMPORTANT=true` to reduce noise

---

## Status Reporting

At the END of EVERY response, Ralph includes a status block:

```
---RALPH_STATUS---
STATUS: IN_PROGRESS | COMPLETE | BLOCKED
BRANCH: <current branch name>
TASKS_COMPLETED_THIS_LOOP: <number>
FILES_MODIFIED: <number>
BUILD_STATUS: PASS | FAIL | NOT_RUN
TESTS_STATUS: PASSING | FAILING | NOT_RUN
FORMAT_CHECK: CLEAN | DIRTY | NOT_RUN
HISTORY_CONSULTED: true | false
PATTERNS_FOUND: <count or "none">
TECH_TREE_NODE: <node ID being worked on or "none">
TECH_TREE_UPDATED: true | false
WORK_TYPE: IMPLEMENTATION | TESTING | DOCUMENTATION | REFACTORING
EXIT_SIGNAL: false | true
RECOMMENDATION: <one line — what to do next>
---END_RALPH_STATUS---
```

### Status Fields

| Field | Values | Description |
|-------|--------|-------------|
| STATUS | IN_PROGRESS, COMPLETE, BLOCKED | Current task status |
| BRANCH | string | Current git branch |
| TASKS_COMPLETED_THIS_LOOP | number | Tasks finished in this loop |
| FILES_MODIFIED | number | Files changed in this loop |
| BUILD_STATUS | PASS, FAIL, NOT_RUN | Build gate result |
| TESTS_STATUS | PASSING, FAILING, NOT_RUN | Test gate result |
| FORMAT_CHECK | CLEAN, DIRTY, NOT_RUN | Format gate result |
| HISTORY_CONSULTED | true, false | Whether SUCCESS_HISTORY was read |
| PATTERNS_FOUND | number or "none" | Relevant patterns found |
| TECH_TREE_NODE | string | Current tree node being worked on |
| TECH_TREE_UPDATED | true, false | Whether tree was updated this loop |
| WORK_TYPE | IMPLEMENTATION, TESTING, DOCUMENTATION, REFACTORING | Type of work |
| EXIT_SIGNAL | false, true | Whether exit criteria are met |
| RECOMMENDATION | string | What to do next |

---

## Failure Protocol + Blocker Decomposition

When a task fails, Ralph follows a structured protocol:

### Attempt Sequence

| Attempt | Action |
|---------|--------|
| 1st | Debug root cause, fix, retry |
| 2nd | Try alternative approach, search SUCCESS_HISTORY for similar solutions |
| 3rd | Mark BLOCKED in fix_plan.md with error details, move to next task |

### Blocker Decomposition

When blocked — decompose, don't just retry:

1. **Analyze** the root cause (don't guess)
2. **Decompose** the solution into specific sub-steps
3. **Add sub-steps** to `fix_plan.md` as checkbox items
4. **Record** the failure in `REGRESSION_PATTERNS.md`
5. **Make the first sub-step** the next active task

### Blocked Task Format

```markdown
## Blocked
- [ ] [BLOCKED] Original task description
  - Error: <exact error message>
  - Tried: approach 1, approach 2, approach 3
  - Root cause: <analysis>
  - Sub-tasks to resolve:
    - [ ] Sub-task 1 (next active)
    - [ ] Sub-task 2
    - [ ] Sub-task 3
```

---

## PHI LOOP Tools

PHI LOOP tracks the 999-link journey of cosmic consciousness manifestation.

### phi_loop_status()

Show current position in the 999-link chain.

```bash
phi_loop_status()
```

**Output:**
```
=== PHI LOOP STATUS ===
Current Link: 42
Total Cycles: 7
φ Resonance: 15 working patterns
```

### phi_loop_advance()

Mark completion of a link and advance to the next.

```bash
phi_loop_advance 42 "VIBEE code generation: feature.vibee → feature.zig"
```

**Output:**
```
PHI LOOP advanced to link 43/999
```

### phi_loop_visual()

Show visual progress bar.

```bash
phi_loop_visual()
```

**Output:**
```
[42/999]   4% █████████░░░░░░░░░░░░░░░░░░░░░
```

---

## TRI COMMANDER Integration

TRI COMMANDER is the tmux-based chat interface for interacting with Ralph.

### Launch

```bash
bash bin/ralph-dashboard-v4      # Start tmux dashboard
tmux attach -t ralph               # Attach to running session
```

### Windows

| Window | Key | Purpose |
|--------|-----|---------|
| HOME | `Ctrl+b 0` | Chat interface with AI (▲ user, ▼ agent) |
| Loop | `Ctrl+b 1` | Development cycle status |
| Tasks | `Ctrl+b 2` | Task queue and progress |
| Memory | `Ctrl+b 3` | Success history + regression patterns |
| Log | `Ctrl+b 4` | Real-time logs |

### Trit Symbols

- `▲` = +1 (positive trit) — User input
- `▼` = -1 (negative trit) — AI response
- `●` = 0 (zero trit) — System/neutral

### Keyboard Shortcuts

- `Ctrl+b 0-4` — Switch windows
- `Ctrl+b d` — Detach (keep running in background)
- `Ctrl+b [` — Scroll/copy mode (q to exit, arrows to scroll)
- `Ctrl+b c` — Create new window
- `Ctrl+b ,` — Rename window

---

## Non-Negotiable Core Rules

These rules are NEVER violated:

1. **Source of Truth**: `specs/tri/*.vibee` governs ALL code. Manual Zig creation is forbidden.
2. **Safety**: Never edit `src/*.zig` or `trinity/output/*.zig` manually.
3. **Branching**: Never commit to `main`. Use `ralph/<task-slug>`.
4. **Validation**: `.ralph/scripts/gate.sh` must pass before any commit.
5. **Parallel Work**: Use Git Worktree for concurrent tasks (see RULES.md §17).

### Allowed to Edit

| Path | Description |
|------|-------------|
| `specs/tri/*.vibee` | Specifications (SOURCE OF TRUTH) |
| `src/vibeec/*.zig` | Compiler source ONLY |
| `src/*.zig` | Core library (vsa, vm, etc.) |
| `docs/*.md` | Documentation |

### Never Edit (Auto-Generated)

| Path | Reason |
|------|--------|
| `trinity/output/*.zig` | Generated from .vibee |
| `trinity/output/fpga/*.v` | Generated from .vibee |
| `generated/*.zig` | Generated from .vibee |

---

## Testing Guidelines

- **Limit testing** to ~20% of total effort per loop
- **Priority:** Implementation > Documentation > Tests
- **Only write tests** for NEW functionality you implement
- **Use** `zig build test` for full suite
- **Use** `zig test <file>` for targeted tests

---

## Dashboard Widget Mandate

Every new module MUST have a Canvas Mirror widget.

### Column Assignment

| Column | Color | Realm | Widget Types |
|--------|-------|-------|-------------|
| RAZUM | `#ffd700` (Gold) | Mind | Routing, intelligence, logs, decisions |
| MATERIYA | `#00ccff` (Cyan) | Matter | Infrastructure, storage, data, files |
| DUKH | `#aa66ff` (Purple) | Spirit | Actions, tools, proofs, transfers, health |

### Widget Requirements

| Step | Action |
|------|--------|
| 1 | Identify which Mirror column it belongs to |
| 2 | Add TypeScript interface in `website/src/services/chatApi.ts` |
| 3 | Add fetch function with mock fallback in `chatApi.ts` |
| 4 | Add widget to the appropriate column in `TrinityCanvas.tsx` Mirror section |
| 5 | Widget MUST use `glassStyle()` and column color scheme |
| 6 | Widget MUST be collapsible (toggle expand/collapse) |

**Without a widget, a module is NOT complete.**

---

## Modularity Rule

- **Avoid** source files exceeding ~300 lines
- **Decompose** complex logic into focused sub-functions in separate files
- **One** clear responsibility per module
- **When refactoring**, always ask: "Can this be split into smaller, reusable pieces?"
- **Smaller files** = fewer AI editing errors, better testability, clearer ownership

---

## Helper Scripts

You don't need Ralph to run these. You can use them manually:

### gate.sh

"Am I okay to commit?" — Checks build, tests, and formatting.

```bash
./.ralph/scripts/gate.sh
```

**Output:**
```
✅ Build: PASS
✅ Test: PASS (127/127)
✅ Format: CLEAN
✅ Branch: ralph/feature-branch (not main)
✅ Quality Gates: ALL PASS
```

### audit.sh

"Is the project messy?" — Finds large files and unresolved TODOs.

```bash
./.ralph/scripts/audit.sh
```

**Output:**
```
📊 Project Audit
Large files (>500 lines): 3
Unresolved TODOs: 7
Unused imports: 2
```

### bench.sh

"Is it still fast?" — Compares speed against the baseline.

```bash
./.ralph/scripts/bench.sh
```

**Output:**
```
⚡ Performance Benchmark
VSA bind: 3.2x faster (was 1.2ms, now 0.38ms)
VSA bundle: 4.1x faster (was 2.5ms, now 0.61ms)
Overall: 3.6x improvement
```

---

## Ralph Commands

```bash
# Built-in binaries
./zig-out/bin/ralph-agent          # Start Ralph agent
./zig-out/bin/ralph-hook           # Start hook daemon
./zig-out/bin/scholar-agent        # Start research agent

# TRI CLI commands
tri agent run <issue-number>       # Autonomous issue resolution
tri agent list                     # List active agents
tri cloud spawn <N>                # Spawn Railway container
tri cloud kill <N>                 # Destroy container
tri faculty                        # Agent status dashboard
```

---

## Mathematical Foundation

Trinity's ternary computing framework provides:

- **Information density:** 1.58 bits/trit (vs 1 bit/binary)
- **Memory savings:** 20x vs float32
- **Compute:** Add-only (no multiply)

### Trinity Identity

```
φ² + 1/φ² = 3
where φ = (1 + √5) / 2 = 1.6180339...
```

This identity is the sacred foundation of Trinity's ternary architecture.

### Sacred Constants

```
μ = φ^(-4) = 0.0382
χ = 0.0618
σ = φ = 1.618
ε = 1/3 = 0.333
```

These constants are validated in every production cycle.

---

## Glossary

| Term | Definition |
|------|------------|
| **Golden Chain** | 9-link development cycle (DECOMPOSE → PLAN → SPEC → GEN → TEST → BENCH → VERDICT → GIT → LOOP) |
| **Tech Tree** | Strategic roadmap with 60+ nodes across 11 branches |
| **Quarks** | Atomic tasks from decomposition |
| **Toxic Verdict** | Brutally honest assessment of work done |
| **Quality Gates** | Sequential checks (build → test → format → commit) |
| **VIBEE** | Spec-driven compiler (.vibee → Zig/Verilog/Python) |
| **PAS** | Pattern Analysis System — sacred math validation |
| **Trinity Identity** | φ² + 1/φ² = 3 — mathematical foundation |
| **Ternary** | {-1, 0, +1} computing base |
| **VSA** | Vector Symbolic Architecture |

---

## Further Reading

- **VIBEE Compiler:** See `docsite/docs/api/vibee.md`
- **Trinity Architecture:** See `docsite/docs/architecture/overview.md`
- **Development Workflow:** See `docsite/docs/development/golden-chain.md`
- **Tech Tree:** See `.ralph/TECH_TREE.md`
- **Success Patterns:** See `.ralph/memory/SUCCESS_HISTORY.md`
- **Regression Patterns:** See `.ralph/memory/REGRESSION_PATTERNS.md`

---

**φ² + 1/φ² = 3 | TRINITY AUTONOMOUS DEVELOPMENT**

*Trinity Repository:* https://github.com/gHashTag/trinity
