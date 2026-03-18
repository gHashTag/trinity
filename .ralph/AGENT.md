# Ralph Agent — Build / Test / Run Commands

## Build

```bash
zig build                    # Full build
zig build tri                # TRI CLI only
zig build vibee              # VIBEE Compiler
zig build test               # Run ALL tests
```

## Test

```bash
zig build test               # Full test suite
zig test src/vsa.zig         # VSA tests
zig test src/vm.zig          # VM tests
zig fmt --check src/         # Format check
```

## Run TRI Pipeline (Golden Chain)

```bash
tri pipeline run "task"       # Execute 24-link Golden Chain
tri decompose "task"          # Break task into subtasks
tri plan "task"               # Create plan
tri spec_create               # Create .vibee spec
tri gen specs/tri/x.vibee     # Generate code from spec
tri verify                    # Tests + benchmarks
tri bench                     # Compare to baseline
tri verdict                   # Toxic verdict
tri commit "msg"              # Auto-commit
tri loop_decide               # Continue or exit
```

## Quality Gates (strict order)

```
1. zig build              → Must compile
2. zig build test         → All tests pass
3. zig fmt --check src/   → No dirty formatting
4. git branch check       → Never main/master
```

## Git

```bash
git checkout -b ralph/<task-slug>  # Create feature branch
git add -A && git commit           # Commit (after gates pass)
git push origin ralph/<task-slug>  # Push to remote
```

## Git Worktree (for swarm agents)

```bash
# Create worktree for new task
git worktree add -b ralph/w1/task /data/worktrees/agent-w1 origin/main

# Work in worktree
cd /data/worktrees/agent-w1

# Cleanup after task
git worktree remove /data/worktrees/agent-w1
git worktree prune
```

## VIBEE

```bash
zig build vibee -- gen <spec.vibee>    # Generate code
zig build vibee -- help                # Show commands
```

## Telegram Pulse

```bash
./ralph_pulse.sh thought "Analyzing..."
./ralph_pulse.sh action "Running: zig build test"
./ralph_pulse.sh state_change "idle -> analyzing"
./ralph_pulse.sh milestone "Task complete"
./ralph_pulse.sh heartbeat "Loop 5 | API calls: 12"
```
