---
sidebar_position: 5
sidebar_label: Pipeline
---

# Golden Chain Pipeline

The 17-link Golden Chain development cycle — spec-driven, benchmark-gated, self-assessing.

## pipeline

Execute the full Golden Chain development cycle.

**Aliases:** `chain`

```bash
tri pipeline run <task>        # Execute full 17-link cycle
tri pipeline status            # Show current pipeline state
tri pipeline resume            # Resume from checkpoint
```

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `run [task]` | Execute full 17-link Golden Chain cycle |
| `status` | Show current pipeline state |
| `resume` | Resume from last checkpoint |

### The 17 Links

| # | Link | Description | Critical |
|---|------|-------------|----------|
| 0 | `TVC_GATE` | Search corpus, return cached or continue | Yes |
| 1 | `BASELINE` | Analyze previous version v(n-1) | |
| 2 | `METRICS` | Collect v(n-1) performance metrics | |
| 3 | `PAS_ANALYZE` | Research patterns and science | |
| 4 | `TECH_TREE` | Build technology dependency graph | |
| 5 | `SPEC_CREATE` | Create `.vibee` specifications | |
| 6 | `CODE_GENERATE` | Generate code from specs (`vibee gen`) | |
| 7 | `TEST_RUN` | Run test suite (`zig build test`) | Yes |
| 8 | `BENCHMARK_PREV` | Compare to v(n-1) — regression gate | Yes |
| 9 | `BENCHMARK_EXTERNAL` | Compare to llama.cpp / vLLM | |
| 10 | `BENCHMARK_THEORETICAL` | Gap to theoretical maximum | |
| 11 | `DELTA_REPORT` | Generate improvement report | |
| 12 | `OPTIMIZE` | Fix if needed (optional) | |
| 13 | `DOCS` | Generate documentation + proofs | |
| 14 | `TOXIC_VERDICT` | Self-assessment (Russian) | |
| 15 | `GIT` | Commit + push changes | |
| 16 | `LOOP_DECISION` | Decide next iteration | Yes |

**Example output:**

```
Golden Chain Pipeline - 16 Links
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Link  0: TVC_GATE [CRITICAL]
  [OK] TVC_GATE (50ms)

Link  1: BASELINE
  [OK] BASELINE (100ms)

...

Link 14: TOXIC_VERDICT [CRITICAL]
  [OK] TOXIC_VERDICT (25ms)

================================================================
              GOLDEN CHAIN CLOSED
================================================================

Completed: 15/17 links
Improvement: 1.23%
Threshold: 61.80% (phi^-1)

KOSCHEI IMMORTAL! Needle is sharp.
```

### Needle Status (Immortality Check)

The pipeline uses the **Koschei Needle** metaphor. Improvement rate is measured against the golden threshold (phi^-1 = 0.618):

| Status | Condition | Message |
|--------|-----------|---------|
| Immortal | rate &gt; 61.8% | KOSCHEI BESSMERTEN! Igla ostra. |
| Mortal | 0 &lt; rate &lt; 61.8% | Uluchshenie est', no Igla tupitsya. |
| Regression | rate &lt;= 0 | REGRESSIYA! Igla slomana. |

### Improvement Rate Formula

Weighted across four dimensions:

| Dimension | Weight | Metric |
|-----------|--------|--------|
| Performance | 40% | `current_tps / prev_tps - 1` |
| Memory | 30% | `prev_mem / curr_mem - 1` |
| Test Coverage | 20% | `curr_tests / prev_tests - 1` |
| Accuracy | 10% | `curr_accuracy - prev_accuracy` |

## decompose

Break a task into sub-tasks (Links 3-4 of the pipeline).

```bash
tri decompose <task description>
tri decompose "add user authentication"
```

**Example output:**

```
Task Decomposition (Links 3-4)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Task: add user authentication

Sub-tasks identified:
  1. Analyze existing codebase
  2. Create .vibee specification
  3. Generate code from spec
  4. Write tests
  5. Run benchmarks
  6. Document changes

Use 'tri pipeline run' to execute full cycle
```

## plan

Generate `.vibee` specifications from sub-tasks (Link 5).

```bash
tri plan
tri plan --file tasks.json
```

## verify

Run tests + benchmarks (Links 7-11).

```bash
tri verify
```

**Example output:**

```
Verification (Links 7-11)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Link 7: Running Tests...
  [OK] Tests passed

Link 8: Running Benchmarks...
  [OK] Benchmark: 125us (1000 iterations)

Verification complete
  Tests: PASS
  Benchmarks: No regression detected
```

## verdict

Generate a toxic self-assessment verdict (Link 14).

```bash
tri verdict
```

Produces a structured Russian-style self-critique:

**Example output:**

```
TOXIC VERDICT (Link 14)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  WHAT WAS DONE:
    - Implemented VSA bind/unbind optimization
    - Added 12 new test cases
    - Benchmark: 1.4 Gops/s (↑23%)

  WHAT FAILED:
    - Memory usage still 2x theoretical minimum
    - No WASM target coverage

  TECH TREE OPTIONS:
    A) Optimize memory layout (packed trits)
    B) Add WASM compilation target
    C) Implement GPU offload via Metal

  NEEDLE STATUS:
    Improvement: 23.4%
    Threshold:   61.8% (phi^-1)
    Status:      Igla tupitsya (needle dulling)
```

### Error Recovery

The pipeline handles errors with different strategies:

| Error Type | Strategy | Example |
|------------|----------|---------|
| Critical link failure | Abort | Tests fail, benchmark regression |
| Benchmark timeout | Retry | External benchmark slow |
| Non-critical failure | Skip | External benchmark unavailable |
| Git conflict | Manual | Wait for user intervention |

### Constants

```
PHI           = 1.618033988749895
PHI_INVERSE   = 0.618033988749895   (Needle threshold)
TRINITY       = 3.0                 (phi^2 + 1/phi^2)
```
