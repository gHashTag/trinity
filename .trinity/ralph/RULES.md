# Ralph Development Rules (22 Sections)

## 1. Source of Truth
- `specs/tri/*.vibee` governs ALL application code
- Manual editing of generated files is FORBIDDEN
- Generated output: `var/trinity/output/*.zig`, `var/trinity/output/fpga/*.v`, `generated/*.zig`

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

## 17. Swarm Architecture (Zig-Only)
- ALL swarm orchestration logic lives in Zig MCP server (`tools/mcp/trinity_mcp/swarm_tools.zig`)
- Go bridge (`telegram-bridge/`) is a THIN PROXY — no business logic
- Source of truth: `specs/tri/swarm_*.vibee` → Zig implementation
- Go swarm prototype is TEMPORARY — delete after Zig swarm verified working
- 11 MCP tools: swarm_status, swarm_agents, swarm_register, swarm_heartbeat,
  swarm_task_get, swarm_task_add, swarm_task_cancel, swarm_tasks,
  swarm_pause, swarm_resume, swarm_assign

## 18. Push Protocol (MANDATORY)
- НЕТ PUSH = НЕТ РАБОТЫ. Code that exists only locally does not exist.
- Every implementation session MUST end with: `git add` → `git commit` → `git push`
- After push: verify via `gh api repos/{owner}/{repo}/contents/{path}` — file must return 200
- If push fails (rejected): `git pull --rebase` → resolve → push again
- NEVER report "done" without confirmed push + GitHub API verification
- Pattern: implement → test → commit → push → verify → THEN report done

## 20. PR Metadata (MANDATORY)
Every PR created by agent MUST have:
1. Assignee — who created the PR
2. Labels — same as linked issue + status:in-progress
3. Milestone — same as linked issue
4. Reviewer — gHashTag (General) for all agent PRs
5. Linked issues — "Closes #N" in body (auto-populated)
6. Project — same board as linked issue

PR without metadata = invisible work = violation.

## 21. No Work Without Issue (MANDATORY)
Agent MUST NOT:
1. Write code without an assigned GitHub Issue
2. Push commits without a PR linked to an issue
3. Create branches without issue number in name (`ralph/w{N}/{slug}`)
4. Close issues manually — only via PR merge with `Closes #N`
5. Report "done" without confirmed `git push` + GitHub API verification

No issue = no task = no code = no PR. Period.

## 22. GitHub Issues = Source of Truth (MANDATORY)
- ALL tasks come from `gh issue list --label assign:ralph`
- `fix_plan.md` is DEPRECATED as primary task source
- If no pending issues exist → agent is IDLE (do not invent work)
- New work requires: create GitHub Issue first → then branch → then code
- GitHub Projects board (VIBECODER #6) is the canonical view of all work
- GitHub Actions auto-add issues to project and auto-update status on merge
- Oracle Watchdog monitors GitHub API and reports to Telegram 24/7
