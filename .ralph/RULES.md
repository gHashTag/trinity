# Ralph Development Rules (16 Sections)

## 1. Source of Truth
- `specs/tri/*.vibee` governs ALL application code
- Manual editing of generated files is FORBIDDEN
- Generated output: `trinity/output/*.zig`, `trinity/output/fpga/*.v`, `generated/*.zig`

## 2. Branch Safety
- NEVER commit to `main` or `master`
- Always use `ralph/<task-slug>` branches
- For swarm: `ralph/<agent-id>/<task-slug>`

## 3. Quality Gates (Blocking)
```
1. zig build              → Exit code 0
2. zig build test         → All tests pass
3. zig fmt --check src/   → Clean formatting
4. Branch check           → Not main/master
```
If ANY gate fails: fix → restart from gate 1. No skipping.

## 4. Commit Convention
```
type(scope): description — Tests X-Y (N/M P%)
```
Types: feat, fix, refactor, test, docs, perf, chore
Scopes: vibeec, vsa, vm, firebird, depin, golden-chain, e2e, dashboard

## 5. Golden Chain (9 Links)
1. TRI DECOMPOSE — Break into atomic quarks
2. TRI PLAN — Strategy, tech tree, ROI
3. TRI SPEC CREATE — .vibee specification
4. TRI GEN — `zig build vibee -- gen`
5. TRI TEST — `zig build test`
6. TRI BENCH — Performance vs baseline
7. TRI VERDICT — Toxic assessment (honest)
8. TRI GIT — Commit to feature branch
9. TRI LOOP — Continue/exit decision

## 6. Toxic Verdict
- Brutally honest assessment
- Numerical score (e.g., 10/10) + binary (Prod/Fail)
- No task complete without verdict

## 7. Tech Tree Navigation
- Read `.ralph/TECH_TREE.md` before task selection
- ROI formula: `(impact / complexity) * unlock_count`
- Propose 3 options with actual node IDs after each task
- Update TECH_TREE.md after completing a node

## 8. Memory Consultation
- Check `SUCCESS_HISTORY.md` for working patterns
- Check `REGRESSION_PATTERNS.md` for anti-patterns
- Search codebase for similar implementations before writing new code

## 9. Failure Protocol
| Attempt | Action |
|---------|--------|
| 1st | Debug root cause, fix, retry |
| 2nd | Alternative approach, search SUCCESS_HISTORY |
| 3rd | Mark BLOCKED, decompose into sub-steps |

## 10. Modularity
- Max 300 lines per source file
- One responsibility per module
- Decompose complex logic into sub-functions

## 11. Testing
- Limit to ~20% of total effort per loop
- Priority: Implementation > Documentation > Tests
- Only test NEW functionality

## 12. Dashboard Widget Mandate
Every module needs a Canvas Mirror widget:
- RAZUM (Gold #ffd700) — Mind: routing, intelligence
- MATERIYA (Cyan #00ccff) — Matter: infrastructure, data
- DUKH (Purple #aa66ff) — Spirit: actions, proofs

## 13. Status Reporting
Include `---RALPH_STATUS---` block at end of every response:
STATUS, BRANCH, BUILD_STATUS, TESTS_STATUS, FORMAT_CHECK, EXIT_SIGNAL

## 14. Circuit Breaker
- 5 no-progress loops → COOLDOWN
- Same error 7 times → HALT
- Manual reset via status_report.json

## 15. Telegram Pulse
- Always send pulses to keep user informed
- 6 types: thought, action, state_change, error, milestone, heartbeat
- Never hardcode bot tokens — use env vars

## 16. Git Worktree (Swarm Agents)
- One worktree = one agent = one branch
- Create: `git worktree add -b ralph/w1/task /data/worktrees/agent-w1 origin/main`
- Cleanup: `git worktree remove` + `git worktree prune`
- Never work in the main repo directory — only in worktrees
- `git fetch origin` from main repo before creating worktree
