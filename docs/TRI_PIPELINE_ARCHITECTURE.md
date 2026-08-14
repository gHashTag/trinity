# TRI Pipeline Architecture — Phase 1 Design

## Overview

The TRI pipeline is a 9-phase autonomous development loop:

```
decompose → plan → spec → gen → test → bench → verdict → git → loop
```

Each phase is backed by a `.tri` specification that defines types, behaviors, tests, and invariants.

## Phase Specifications

| Phase | Spec | Purpose |
|-------|------|---------|
| decompose | `specs/tri/decompose.tri` | Parse issue into atomic sub-tasks with DAG |
| plan | `specs/tri/plan.tri` | Schedule tasks into parallel execution groups |
| spec | `specs/tri/spec_create.tri` | Create/edit `.tri` or `.vibee` specification |
| gen | `specs/tri/generation_pipeline.vibee` | Generate Zig/Verilog/C from specs |
| test | `specs/tri/testing/repl_tests.tri` | Run generated tests |
| bench | `specs/tri/benchmark.tri` | Performance benchmarks |
| verdict | `specs/tri/verdict.tri` | PASS/FAIL/WARN/TOXIC_FAIL verdict |
| git | `specs/tri/github_commands.tri` | Git commit, PR create, issue update |
| loop | `specs/tri/loop_decide.tri` | Decide next action based on system state |

## Agent Interface Types

```tri
AgentMessage {
  from: AgentID    // Source agent (T, N, P, etc.)
  to: AgentID      // Target agent
  task: SubTask    // What to do
  status: Status   // pending/in_progress/done/failed
  result: ?Result  // Output data
}
```

## Parallel Execution

Tasks in the same parallel group run concurrently via independent agent instances. Dependencies are enforced by the DAG:

```
Group 1: [A, B, C]    // 3 independent tasks
Group 2: [D]           // depends on A
Group 3: [E, F]        // depends on B and C
```

## Architecture Diagram

```
┌──────────┐
│  Issue    │
│  GitHub   │
└────┬─────┘
     │
     ▼
┌──────────┐     ┌──────────┐
│ Decompose│────▶│   Plan   │
└──────────┘     └────┬─────┘
                      │
              ┌───────┼───────┐
              ▼       ▼       ▼
          ┌──────┐┌──────┐┌──────┐
          │Spec  ││Spec  ││Spec  │  (parallel)
          │  A   ││  B   ││  C   │
          └──┬───┘└──┬───┘└──┬───┘
             ▼       ▼       ▼
          ┌──────┐┌──────┐┌──────┐
          │ Gen  ││ Gen  ││ Gen  │
          └──┬───┘└──┬───┘└──┬───┘
             ▼       ▼       ▼
          ┌──────┐┌──────┐┌──────┐
          │Test  ││Test  ││Test  │
          └──┬───┘└──┬───┘└──┬───┘
             └───────┼───────┘
                     ▼
              ┌──────────┐
              │ Verdict   │
              └────┬─────┘
                   ▼
              ┌──────────┐
              │   Git    │
              └────┬─────┘
                   ▼
              ┌──────────┐
              │   Loop   │───▶ (next cycle)
              └──────────┘
```

## Agent Domain Map

| Agent | Domain | File patterns |
|-------|--------|---------------|
| T (Queen) | Orchestration | `graph.tri`, `loop_decide.tri` |
| A (Arch) | Architecture | `specs/tri/*.tri`, `architecture/` |
| N (Numeric) | Number formats | `specs/numeric/`, `ffi/` |
| P (Physics) | Physics formulas | `specs/physics/`, `research/` |
| F (FPGA) | Hardware | `specs/fpga/`, `fpga/` |
| C (Compiler) | Code generation | `specs/tri/gen*.tri`, `src/vibeec/` |
| B (Brain) | Neural architecture | `specs/brain/`, `src/b2t/` |

## Constitutional Compliance

- **L1 TRACEABILITY**: Every spec change links to an issue
- **L2 GENERATION**: `gen/` output is never hand-edited
- **L4 TESTABILITY**: Every spec has test/invariant blocks
- **L7 UNITY**: No shell scripts on critical path — use `tri` CLI
