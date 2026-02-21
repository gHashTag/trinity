# AGENTS.md - AI Agent Guidelines for VIBEE Development

**Author**: Dmitrii Vasilev

## Overview

This document provides guidelines for AI agents working on the VIBEE project. All agents must follow the **Golden Chain** workflow.

---

## 🚨 AUTONOMOUS DEVELOPMENT LOOP (KOSCHEI PATTERN)

### Core Principles:

1. **Specification-First**: NEVER write implementation code directly
2. **Auto-Generation**: Code is GENERATED from specs, not written manually
3. **Continuous Improvement**: Loop until EXIT_SIGNAL or completion
4. **Self-Validation**: Run tests after each generation

### Development Loop:

```
┌─────────────────────────────────────────────────────────────────┐
│                    KOSCHEI DEVELOPMENT LOOP                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. ANALYZE task requirements                                   │
│           ↓                                                     │
│  2. CREATE .vibee specification in specs/tri/                   │
│           ↓                                                     │
│  3. RUN: ./bin/vibee gen specs/tri/feature.vibee                │
│           ↓                                                     │
│  4. TEST: zig test trinity/output/feature.zig                   │
│           ↓                                                     │
│  5. CHECK: All tests passing?                                   │
│           ↓                                                     │
│     YES → Write TOXIC VERDICT + TECH TREE SELECT → EXIT         │
│     NO  → ITERATE (go to step 2)                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⛔ CRITICAL PROHIBITIONS

### 🚫 ANTI-PATTERN #1: WRITING .zig CODE MANUALLY

```
❌ NEVER write .zig code directly - this is an ANTI-PATTERN!
❌ ALL .zig code MUST be GENERATED from .vibee specifications
❌ The only exception: src/vibeec/*.zig (compiler source code)
```

### NEVER CREATE THESE FILE TYPES MANUALLY:

```
❌ .html files (except runtime/runtime.html)
❌ .css files
❌ .js files  
❌ .ts files
❌ .jsx files
❌ .tsx files
❌ .zig files - ANTI-PATTERN! Use .vibee → gen → .zig
❌ .py files (ONLY GENERATED)
❌ .v files - ANTI-PATTERN! Use .vibee (language: varlog) → gen → .v
```

### WHY?

VIBEE uses specification-first development:

```
specs/*.vibee (language: zig)    → vibee gen → trinity/output/*.zig
specs/*.vibee (language: varlog) → vibee gen → trinity/output/fpga/*.v
```

### CORRECT WORKFLOW:

```bash
# 1. Create specification (NOT code!)
cat > specs/tri/my_feature.vibee << 'EOF'
name: my_feature
version: "1.0.0"
language: varlog  # For FPGA/Verilog
# OR
language: zig     # For software
module: my_feature
...
EOF

# 2. Generate code (NEVER write it manually!)
./bin/vibee gen specs/tri/my_feature.vibee

# 3. Test generated code
zig test trinity/output/my_feature.zig
# OR for Verilog:
iverilog trinity/output/fpga/my_feature.v
```

### ALLOWED TO EDIT:

```
src/vibeec/*.zig - Compiler source code ONLY
specs/tri/*.vibee - Specifications (NO manual code blocks!)
docs/*.md - Documentation
```

### NEVER EDIT:

```
trinity/output/*.zig - Generated code (will be overwritten)
trinity/output/fpga/*.v - Generated Verilog (will be overwritten)
generated/*.zig - Generated code (will be overwritten)
```

---

## ⚡ VIBEE PIPELINE (MANDATORY)

### Step 1: Create .vibee specification

```yaml
# specs/tri/my_feature.vibee
name: my_feature
version: "1.0.0"
language: zig
module: my_feature

types:
  MyType:
    fields:
      name: String
      count: Int

behaviors:
  - name: my_behavior
    given: Input
    when: Action
    then: Result
```

### Step 2: Generate .zig code

```bash
./bin/vibee gen specs/tri/my_feature.vibee
# Output: trinity/output/my_feature.zig
```

### Step 3: Test generated code

```bash
zig test trinity/output/my_feature.zig
```

### Type Mapping Reference:

| VIBEE Type | Zig Type |
|------------|----------|
| `String` | `[]const u8` |
| `Int` | `i64` |
| `Float` | `f64` |
| `Bool` | `bool` |
| `Option<T>` | `?[]const u8` |
| `List<T>` | `[]const u8` |
| `Map<K,V>` | `std.StringHashMap([]const u8)` |
| `Timestamp` | `i64` |
| `Object` | `[]const u8` |

---

## 🔥 MANDATORY: TOXIC VERDICT

After EVERY task completion, write harsh self-criticism:

```
╔══════════════════════════════════════════════════════════════════╗
║                    🔥 TOXIC VERDICT 🔥                           ║
╠══════════════════════════════════════════════════════════════════╣
║ WHAT WAS DONE:                                                   ║
║ - [specifically what was implemented]                            ║
║                                                                  ║
║ WHAT FAILED:                                                     ║
║ - [honest about mistakes]                                        ║
║                                                                  ║
║ METRICS:                                                         ║
║ - Before: X | After: Y | Δ = Z%                                  ║
║                                                                  ║
║ SELF-CRITICISM:                                                  ║
║ - [harsh analysis without rose-colored glasses]                  ║
║ - [what could have been done better]                             ║
║                                                                  ║
║ SCORE: [1-10]/10                                                 ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## 🌳 MANDATORY: TECH TREE SELECT

After toxic verdict, propose 3 options for next research:

```
┌─────────────────────────────────────────────────────────────────┐
│              🌳 TECH TREE - SELECT NEXT                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [A] ──────────────────────────────────────────────────────     │
│      Name: ...                                                  │
│      Complexity: ★★☆☆☆                                          │
│      Potential: +X% to metric Y                                 │
│      Dependencies: [what's needed first]                        │
│                                                                 │
│  [B] ──────────────────────────────────────────────────────     │
│      Name: ...                                                  │
│      Complexity: ★★★☆☆                                          │
│      Potential: +X% to metric Y                                 │
│      Dependencies: [what's needed first]                        │
│                                                                 │
│  [C] ──────────────────────────────────────────────────────     │
│      Name: ...                                                  │
│      Complexity: ★★★★☆                                          │
│      Potential: +X% to metric Y                                 │
│      Dependencies: [what's needed first]                        │
│                                                                 │
│  RECOMMENDATION: [A/B/C] because [reason]                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 File Organization

```
vibee-lang/
├── specs/tri/              # .vibee specifications (SOURCE)
│   ├── ai_provider.vibee
│   ├── file_operations.vibee
│   └── ...
├── trinity/output/         # Generated .zig (DO NOT EDIT)
│   ├── ai_provider.zig
│   ├── file_operations.zig
│   └── ...
├── src/vibeec/             # Compiler (CAN EDIT)
│   ├── gen_cmd.zig
│   ├── zig_codegen.zig
│   ├── vibee_parser.zig
│   └── ...
├── bin/vibee               # CLI binary
└── docs/                   # Documentation
```

---

## 🔧 Commands Reference

```bash
# PRIMARY WORKFLOW
./bin/vibee gen specs/tri/feature.vibee              # Generate single
for f in specs/tri/*.vibee; do ./bin/vibee gen "$f"; done  # Generate all

# TEST
zig test trinity/output/feature.zig            # Test single
cd trinity/output && for f in *.zig; do zig test "$f"; done  # Test all

# GOLDEN CHAIN
./bin/vibee koschei          # Show 16 links
./bin/vibee koschei chain    # Architecture
./bin/vibee koschei status   # Status
```

---

## 📝 MANDATORY: DOCUMENT ACHIEVEMENTS

After completing ANY significant milestone, agents MUST automatically document it:

### What Requires Documentation

| Achievement Type | Action Required |
|-----------------|-----------------|
| New feature working | Create `docsite/docs/research/<feature>-report.md` |
| Benchmark improvement | Update `docsite/docs/benchmarks/` |
| Integration success | Create research report with metrics |
| Node/inference milestone | Document in research section |
| Performance breakthrough | Add to benchmarks with proof |

### Documentation Workflow (MANDATORY)

```bash
# 1. CREATE report in docsite
# File: docsite/docs/research/<milestone>-report.md

---
sidebar_position: N
---

# <Milestone> Report

**Date:** YYYY-MM-DD
**Status:** Production-ready / In Progress

## Key Metrics
| Metric | Value | Status |
|--------|-------|--------|
| ... | ... | ... |

## What This Means
- For users: ...
- For node operators: ...
- For investors: ...

## Technical Details
...

# 2. UPDATE sidebar
# File: docsite/sidebars.ts
# Add new page to appropriate category

# 3. BUILD & DEPLOY
cd docsite && npm run build
USE_SSH=true npm run deploy

# 4. COMMIT & PUSH
git add docsite/
git commit -m "docs: Add <milestone> report"
git push
```

### Report Template

```markdown
---
sidebar_position: N
---

# <Feature/Milestone> Report

**Date:** February X, 2026
**Status:** Production-ready

## Executive Summary
One paragraph summary of achievement.

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Coherence | X% | Verified |
| Speed | X tok/s | CPU/GPU |
| Cost | $X/hr | vs $Y cloud |

## What This Means

### For Users
- Benefit 1
- Benefit 2

### For Node Operators
- $TRI earning potential

### For Investors
- Proof of technology

## Technical Details
Architecture, implementation, test results.

## Conclusion
Summary and next steps.

---
**Formula:** phi^2 + 1/phi^2 = 3
```

### Examples of Documented Achievements

| Achievement | Report Location |
|-------------|-----------------|
| BitNet coherence testing | `/docs/research/bitnet-report` |
| Trinity Node FFI integration | `/docs/research/trinity-node-ffi` |
| Competitor comparison | `/docs/benchmarks/competitor-comparison` |
| GPU inference benchmarks | `/docs/benchmarks/gpu-inference` |

---

## 🏆 EXIT_SIGNAL

Agent must continue iterations until:
1. All tests pass
2. Specification is complete
3. TOXIC VERDICT is written
4. TECH TREE SELECT is proposed
5. **Achievement documented** (if milestone reached)
6. Changes are committed

```yaml
EXIT_SIGNAL = (
    tests_pass AND
    spec_complete AND
    toxic_verdict_written AND
    tech_tree_options_proposed AND
    committed
)
```

---

## GIT HOOKS ENFORCEMENT

The repository has pre-commit hooks that **BLOCK** commits containing forbidden files:

```bash
# Hook location
.githooks/pre-commit

# Activate hooks
git config core.hooksPath .githooks
```

**BLOCKED EXTENSIONS:** `.html` (except runtime.html), `.css`, `.js`, `.ts`, `.jsx`, `.tsx`

**ALLOWED EXTENSIONS:** `.vibee`, `.999`, `.zig`, `.md`, `.json`, `.yaml`

---

## 🌐 WEBSITE DEPLOYMENT RULES

### CANONICAL URL (NEVER CHANGE!)

| Setting | Value |
|---------|-------|
| **Production URL** | `https://trinity-site-ghashtag.vercel.app` |
| **Vercel Project** | `trinity-site` |
| **GitHub Repo** | `gHashTag/trinity` |
| **Root Directory** | `website/` |
| **Framework** | Vite (React SPA) |

### ⛔ CRITICAL: DO NOT

- Create new Vercel projects
- Change the production URL
- Deploy to different project names
- Create duplicate website folders
- Use `vibee-lang` repo (use `trinity` only!)

### ✅ ALLOWED

- Edit files in `website/` folder
- Push to main branch (auto-deploys)
- Update translations in `website/messages/*.json`

### All GitHub Links Must Use:

```
https://github.com/gHashTag/trinity
```

---

## 🤖 AGENT MU — Post-Generation Auto-Fixer (v8.12)

**μ = 1/φ²/10 = 0.0382 — Sacred Mutation**

### Overview

AGENT MU is the post-generation guardian that runs after every `vibee gen`. It automatically detects, classifies, and fixes compilation errors in generated code.

### Phases of Self-Evolution

```
┌─────────────────────────────────────────────────────────────────┐
│                    AGENT MU SELF-EVOLUTION LOOP                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  V01 → VERIFICATION                                            │
│       zig build + zig test + zig fmt                           │
│           ↓                                                     │
│  Phi02 → PATTERN SEARCH                                         │
│       Search REGRESSION_PATTERNS.md for similar errors          │
│           ↓                                                     │
│  Pi03 → DIAGNOSTIC                                             │
│       Parse error → Classify FixType                           │
│           ↓                                                     │
│  Mu05 → AUTO-FIX                                               │
│       Apply fix based on FixType                               │
│           ↓                                                     │
│  Sigma07 → SUCCESS                                             │
│       Log to SUCCESS_HISTORY.md                                │
│           ↓                                                     │
│  Chi06 → REGRESS                                               │
│       Log to REGRESSION_PATTERNS.md (if fix failed)            │
│           ↓                                                     │
│  REPEAT (max 3 attempts)                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### FixType Classifications

| FixType | Description | Implemented | Confidence |
|---------|-------------|-------------|------------|
| IMPORT_FIX | Missing import statements | ✅ | 0.9 |
| ALLOCATOR_FIX | Missing allocator parameter | ✅ | 0.7 |
| ERROR_UNION_FIX | Error handling needed | ✅ | 0.75 |
| TYPE_FIX | Type mismatch | ✅ | 0.95 |
| TEMPLATE_FIX | Codegen template error | ✅ | 0.0 (descriptive) |
| GENERATOR_PATCH | VIBEE compiler patch | ✅ | 0.0 (descriptive) |
| SYNTAX_FIX | Syntax error | ✅ | 1.0 (fmt) |
| SPEC_FIX | Specification error | ❌ | — |

### Auto-Fix Functions

```zig
// src/agent_mu/fixer.zig

pub fn applyFix(
    allocator: std.mem.Allocator,
    err_info: *const diagnostic.ErrorInfo,
    file_path: []const u8,
) !FixResult;
```

**Implemented fixes:**
1. `applyImportFix()` — Auto-add missing std library imports
2. `applyAllocatorFix()` — Replace ArrayList.init with ArrayListUnmanaged
3. `applyErrorUnionFix()` — Add `try` prefix to error-returning calls
4. `applyTypeFix()` — Remove const from []const u8 for type mismatches
5. `applyFormatFix()` — Run `zig fmt` on the file

### Semantic Pattern Search

```zig
// src/agent_mu/pattern_matcher.zig

pub fn semanticPatternMatch(
    allocator: std.mem.Allocator,
    error_message: []const u8,
    error_type: diagnostic.FixType,
    top_k: usize,
    threshold: f64,
) ![]PatternMatch;
```

**Features:**
- Fuzzy similarity matching (character bigrams)
- Confidence scoring (0.0 to 1.0)
- Top-k pattern retrieval
- Keyword matching with 6 common error patterns

### Generator Feedback Loop

```zig
// src/agent_mu/agent_mu.zig

pub const GeneratorFeedback = struct {
    template_name: []const u8,
    issue_type: []const u8,
    suggested_fix: []const u8,
    priority: u32,
    before_hash: []const u8,
    after_hash: []const u8,
};

pub fn createGeneratorFeedback(
    allocator: std.mem.Allocator,
    err_info: *const diagnostic.ErrorInfo,
    fix_result: *const fixer.FixResult,
) !GeneratorFeedback;
```

### Mutation Statistics (μ Tracking)

```zig
// src/agent_mu/logger.zig

pub const MU: f64 = 0.0382; // Sacred constant

pub const MutationStats = struct {
    total_fixes: u32,
    successful_fixes: u32,
    failed_fixes: u32,
    intelligence_gain: f64,
};
```

**Intelligence Growth:**
- Per fix: +μ = +0.0382%
- After 100 fixes: **×47 intelligence multiplier**
- Formula: `intelligence × (1 + μ)^100`

### Usage

```bash
# Run AGENT MU verification (no auto-fix)
zig build agent-mu-verify

# Run AGENT MU with auto-fix enabled
zig build agent-mu-fix

# View mutation statistics
cat .ralph/memory/MUTATION_STATS.md

# View regression patterns
cat .ralph/memory/REGRESSION_PATTERNS.md
```

### Files

| File | Purpose | Lines |
|------|---------|-------|
| `src/agent_mu/fixer.zig` | Auto-fix implementations | 659 |
| `src/agent_mu/pattern_matcher.zig` | Semantic search | 396 |
| `src/agent_mu/agent_mu.zig` | Main loop + feedback | 363 |
| `src/agent_mu/logger.zig` | Logging + μ tracking | 308 |
| `src/agent_mu/diagnostic.zig` | Error parsing | 450+ |
| `src/agent_mu/verifier.zig` | Build/test verification | 200+ |

### Test Results

```
fixer.zig:        9/9 tests passed ✅
agent_mu.zig:     2/2 tests passed ✅
diagnostic.zig:   4/4 tests passed ✅
Total:           15/15 (100%)
```

### Exit Criteria

AGENT MU completes when:
1. All checks pass (build + test + format)
2. Auto-fix applied successfully (if needed)
3. Success logged to SUCCESS_HISTORY.md
4. Mutation statistics updated

```yaml
AGENT_MU_EXIT = (
    verification_passed OR
    (max_retries_exhausted AND regression_logged)
)
```

---

## 🔧 Zig 0.15 Idioms in AGENT MU

AGENT MU actively applies these idioms when fixing code:

| Idiom | Before Fix | After Fix | Why |
|-------|-----------|-----------|-----|
| **ArrayListUnmanaged** | `ArrayList(T).init(allocator)` | `ArrayListUnmanaged(T){}` | No allocator capture needed |
| **Inferred errors** | `const Error = error{...}; fn foo() !Error` | `fn foo() !void` | Simpler, auto-inferred |
| **Packed structs** | `struct { x: u8, y: u8, z: u8 }` | `packed struct { xyz: u24 }` | Memory optimization |
| **ArenaAllocator** | Multiple allocs | Single arena block | Faster temp allocations |
| **Error Return Traces** | Silent failure | `@errorReturnTrace()` in logs | Better diagnostics |
| **Comptime assertions** | Runtime checks | `comptime assert(...)` | Catch errors at compile time |
| **errdefer** | Manual cleanup | `errdefer freeAlloc(ptr)` | Guaranteed cleanup |

### Example: ArrayListUnmanaged Fix

```zig
// ❌ BEFORE (causes ALLOCATOR_FIX)
var list = std.ArrayList(u8).init(allocator);
defer list.deinit();
try list.append(42);

// ✅ AFTER (AGENT MU applies)
var list = std.ArrayListUnmanaged(u8){};
defer list.deinit(allocator);
try list.append(allocator, 42);
```

### Example: Inferred Error Set Fix

```zig
// ❌ BEFORE (causes ERROR_UNION_FIX)
const ParseError = error{ InvalidSyntax, UnexpectedEOF };
fn parse(data: []const u8) !ParseError {
    // ...
}

// ✅ AFTER (AGENT MU applies)
fn parse(data: []const u8) !void {
    // Error set inferred from body
    return error.InvalidSyntax;
}
```

### Sacred Constants in AGENT MU

```zig
// src/agent_mu/logger.zig
pub const MU: f64 = 1.0 / (1.618033988749895 * 1.618033988749895) / 10.0; // = 0.0382

pub const MutationStats = struct {
    total_fixes: u32 = 0,
    successful_fixes: u32 = 0,
    failed_fixes: u32 = 0,
    intelligence_gain: f64 = 0.0,

    pub fn calculateGain(self: *const MutationStats) f64 {
        return @as(f64, @floatFromInt(self.successful_fixes)) * MU;
    }
};
```

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**
