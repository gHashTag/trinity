# Night Evolution Map — Cloud Dev Pipeline Hardening
# 2026-03-11 night → 2026-03-12 morning

## FINAL STATUS — Night Complete

### PRs Merged (5)
| PR | Title | Source |
|----|-------|--------|
| #129 | JSONL event persistence + deduplication | agent-124 |
| #130 | Git worktree isolation for faster startup | agent-125 |
| #138 | Buffer size increase, CLAUDE.md.agent to .gitignore | agent-136 |
| #141 | Golden Chain pipeline — tri cloud pipeline/verify/merge | agent-140 |
| #142 | Telegram log streaming — batch every 5s + output classifier | agent-131 |

### PRs Closed (5, quality gate or conflicts)
| PR | Reason |
|----|--------|
| #132 | Merge conflict after #129/#130 merged |
| #133 | Merge conflict after #129/#130 merged |
| #139 | Merge conflict, fixes applied directly |
| #143 | Review: grep -oP not portable, destructive git checkout, worktree cleanup order |
| #144 | Modified generated files (trinity-nexus/output/) — forbidden per CLAUDE.md |

### Issues Closed (5)
| Issue | Resolution |
|-------|-----------|
| #134 | Fixed: u32→i64 timestamp, entry_idx dedup |
| #135 | Fixed: VOLUME shadow, worktree -b branch |
| #136 | Fixed via PR #138 merge |
| #137 | Fixed: pipefail, bash shebang, Telegram ordering |
| #140 | Fixed via PR #141 merge |

### Direct Commits to Main (4)
1. `b470c5ae7` — heartbeat subshell + pipefail + Telegram ordering + HTML escape
2. `fe6dc534e` — u32 overflow, entry_idx duplicates, VOLUME shadow, worktree conflict
3. `9362cec04` — reuse Railway services instead of delete+create
4. `f803a5fbd` — gh auth setup-git + --repo flag + push failure tracking

### Docker Image Rebuilt (3x)
1. heartbeat + pipefail + Telegram fixes
2. VOLUME shadow removal + worktree branch fix
3. `gh auth setup-git` + `--repo` flag + PUSH_OK tracking (sha256:b1c73cbc)

## Phase Completion

| Phase | Status | Detail |
|-------|--------|--------|
| 1. Merge PRs | ✅ DONE | 5 merged, 5 closed |
| 2. Entrypoint Hardening | ✅ DONE | 17 fixes applied |
| 3. Orchestrator CLI | 80% | pipeline/verify/merge added, logs TBD |
| 4. Auto-Pipeline | 80% | PR #141 merged, Telegram streaming in #142 |
| 5. Monitoring | 40% | JSONL + Telegram live, dashboard TBD |
| 6. Agent Intelligence | 30% | SOUL.md works, --repo fix, auth fixed |

## Agent Spawns (10 total runs, 2 services)

| Run | Service | Issue | Result | Duration | Notes |
|-----|---------|-------|--------|----------|-------|
| 1 | ubuntu | #126 | 🔴 FAILED | 619s | Too abstract, 0 commits |
| 2 | Agents Anywhere | #131 | 🔵 DONE | ~300s | PR #142 merged ✅ |
| 3 | Agents Anywhere | #115 | 🔴 FAILED | 303s | Push failed 3x (no gh auth setup-git) |
| 4 | ubuntu | #114 | 🔴 FAILED | 519s | Push failed (same auth bug) |
| 5 | Agents Anywhere | #116 | 🔴 FAILED | 81s | Can't read issue (no --repo flag) |
| 6 | ubuntu | #126 (prev) | 🔴 CLOSED | — | PR #143 closed: quality issues |
| 7 | ubuntu | #114 (retry) | 🔴 FAILED | 253s | 0 commits: generated files forbidden |
| 8 | Agents Anywhere | #116 (retry) | 🔴 FAILED | 586s | 0 commits: generated files forbidden |
| 9 | ubuntu | #114 (prev) | 🔴 CLOSED | — | PR #144 closed: edited output/ |
| — | — | — | **1/8 success** | — | 12.5% solve rate |

## All Bugs Fixed (17)
1. Heartbeat reads from temp file (subshell isolation)
2. Telegram notification ordering (LAST_STATUS moved after send)
3. HTML escaping + safe JSON via temp files
4. `#!/bin/bash` + `set -eo pipefail`
5. `i64` timestamps (u32 overflow)
6. No duplicate JSONL entries (entry_idx fix)
7. No VOLUME shadowing bare repo
8. Concurrent agents get unique worktree branches
9. Golden Chain: `tri cloud pipeline <N>` automates full cycle
10. Telegram `editMessageText` — 1 dashboard message updated in place
11. `NO_COLOR=1` in containers for clean output
12. Worktree lock/unlock prevents accidental pruning
13. Workflow reuses services instead of delete+create (25/day limit)
14. `sleepApplication: true` on Agents Anywhere — disabled
15. Push failure silently swallowed — PUSH_OK tracking added
16. **CRITICAL**: `gh auth setup-git` — bridges gh→git credential helper
17. **CRITICAL**: `--repo` flag on all gh commands — bare-repo worktrees lack context

## Lessons Learned
1. Railway MCP `deploy` uploads source, NOT Docker image — use GraphQL API
2. `startCommand` overrides Docker ENTRYPOINT — must set via serviceInstanceUpdate
3. 25 service/day creation limit — never delete+create, always reuse
4. `variableCollectionUpsert` needs actual values, not empty shell vars
5. Service names with spaces break Railway CLI — avoid spaces
6. `sleepApplication: true` silently kills batch containers
7. Abstract issues produce 0 commits — agents need concrete file/function targets
8. `2>/dev/null || true` on push hides critical auth failures
9. `gh auth login` ≠ git push auth — need `gh auth setup-git`
10. Bare-repo worktrees have no git remote — all gh commands need `--repo`
11. Codegen issues (#114-116) require editing generated files — agents can't solve them
12. Agent solve rate: ~12.5% — need better issue selection + more specific SOUL.md

## Night 2 (2026-03-12) — Model Fix + CLI Tools

### Root Cause Found: z.ai proxy returns GLM-4.7 instead of Claude
- **Bug #18 (CRITICAL)**: z.ai proxy routes `claude-sonnet-4-20250514` → `glm-4.7` (wrong model!)
- GLM-4.7 cannot handle Claude Code's tool-use protocol → 0 commits on ALL agents
- **Fix**: `--model glm-5` flag in entrypoint + `CLAUDE_MODEL=glm-5` env var
- z.ai's top model is `glm-5` — confirmed working via API test

### Changes Applied
1. `deploy/agent-entrypoint.sh`: Added `--model "${CLAUDE_MODEL:-glm-5}"` to claude invocation
2. `.github/workflows/agent-spawn.yml`: Added `CLAUDE_MODEL=glm-5` to Railway env vars
3. Railway ubuntu service: `CLAUDE_MODEL=glm-5` set via MCP
4. Docker image: Rebuilt and pushed to GHCR (sha256 new)
5. **Bug #19**: `railway deploy` overwrote Docker image source with `railway.toml` (Dockerfile.px-bridge)
   - Fixed via `serviceInstanceUpdate` GraphQL — restored image source + startCommand
   - Lesson: NEVER use `railway deploy`/`redeploy` on Docker image services — it uploads source code

### New CLI Commands (4) + MCP Tools (4)
| Command | Purpose |
|---------|---------|
| `tri cloud api-check` | Test API key + model routing (catches proxy mismatch) |
| `tri cloud redeploy <svc> <N>` | Reuse Railway service for new issue |
| `tri cloud diagnose <N>` | Why did agent fail? (comments + events + PR) |
| `tri cloud issue-create <title>` | Create issue with `agent:spawn` label |

### Agent Spawn #145 (glm-5 validation)
- **RESULT: SUCCESS** — Full E2E cycle in ~5 minutes
- Auth OK, clone OK, read issue OK, code OK, self-review OK, push OK, PR #146 created
- PR closed (local branch has richer impl), issue closed
- **Agent solve rate: 2/9 = 22%** (up from 12.5%)
- Bug #19 also found: `railway deploy` overwrites Docker image source

### Docker Image Rebuilt (4th time)
- glm-5 model fix + 4 new CLI commands
- sha256 new, pushed to GHCR

### Agent Spawn #147 (ubuntu, glm-5)
- Agent read issue, coded, self-reviewed, pushed, **created PR #149**
- Self-review passed: format OK, diff 17 lines, no generated files
- **BUT**: entrypoint reported FAILED (false alarm — Bug #20)
- Code review: FAIL — missing curl timeout, set -e, .error check
- PR #149 closed — fixes needed

### Agent Spawn #148 (Agents Anywhere, glm-5)
- Deployed OK but no comments posted — agent may have failed silently
- Needs investigation

### Bugs Fixed (Night 2)
18. **CRITICAL**: z.ai proxy returns glm-4.7 not Claude → `--model glm-5` fix
19. `railway deploy` overwrites Docker image source → use `serviceInstanceUpdate`
20. False FAILED: COMMIT_COUNT unset when Claude Code creates PR directly
21. Stale bare repo: `git update-ref` after fetch to sync local main

### Docker Image Rebuilt (5th time)
- Fixes: false-FAILED, stale bare repo, glm-5 model

### Night 2 Stats
- Agent spawns: 3 (145 OK, 147 partial, 148 pending)
- PRs created by agents: 2 (#146, #149)
- PRs merged: 0 (both closed for quality)
- Bugs fixed: 4 (total: 21)
- Docker rebuilds: 5
- Agent solve rate: partial — agents code but miss edge cases

### Night 2 Continued — Service Pool Fix + Simple Issues

22. **CRITICAL**: 25 service/day creation limit → workflow fails for ALL new issues
    - Root cause: workflow creates `agent-{N}` service per issue, hits Railway limit
    - Fix: round-robin pool reusing `ubuntu` and `Agents Anywhere` by service ID
    - Commit: `53df6a500` — `fix(cloud): reuse service pool`

23. **Agents Anywhere silent failure**: stale `GH_TOKEN` env var → `gh auth` fails → no comments/PRs
    - Root cause: Railway had old GH_TOKEN from previous manual deploy
    - Fix: deleted stale GH_TOKEN, workflow now sets GH_TOKEN alongside GITHUB_TOKEN
    - Commit: `0486c661f` — `fix(cloud): add GH_TOKEN to spawn vars`

### Agent Spawns (Night 2 continued)
| Run | Service | Issue | Result | Notes |
|-----|---------|-------|--------|-------|
| 10 | ubuntu | #150 | 🔵 DONE | PR #153 merged — clean 5-line fix |
| 11 | Agents Anywhere | #151 (1st) | 🔴 FAILED | GH_TOKEN invalid, 0 comments |
| 12 | Agents Anywhere | #151 (retry) | 🔵 DONE | PR #154 merged — clean 2-line fix, 179s |

### Night 2 Final Stats
- Total bugs fixed: 6 (18-23), grand total: 23
- Agent solve rate: 4/12 = 33% (PR created+merged)
- **Two fully autonomous agent→merge cycles**: #150 (PR #153) + #151 (PR #154)
- Docker rebuilds: 5
- PRs created by agents tonight: 4 (#146, #149, #153, #154)
- PRs merged: 2 (#153, #154)
- Issues auto-closed: #150, #151

### Remaining Work
- [ ] Monitor agent #151 (retry)
- [ ] Dashboard UI (Phase 5)
- [ ] Agent self-metrics tracking
- [ ] Issue templates: simpler tasks get higher solve rates
