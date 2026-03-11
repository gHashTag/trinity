# Night Evolution Map — Cloud Dev Pipeline Hardening
# 2026-03-11 night → 2026-03-12 morning

## Final Status

### PRs Merged (5) + Closed (2 quality)
| PR | Title | Source |
|----|-------|--------|
| #129 | JSONL event persistence + deduplication | agent-124 |
| #130 | Git worktree isolation for faster startup | agent-125 |
| #138 | Buffer size increase, CLAUDE.md.agent to .gitignore | agent-136 |
| #141 | Golden Chain pipeline — tri cloud pipeline/verify/merge | agent-140 |
| #142 | Telegram log streaming — batch every 5s + output classifier | agent-131 |

### PRs Closed (3, superseded by direct fixes)
| PR | Reason |
|----|--------|
| #132 | Merge conflict after #129/#130 merged |
| #133 | Merge conflict after #129/#130 merged |
| #139 | Merge conflict, fixes applied directly |

### Issues Closed (5)
| Issue | Resolution |
|-------|-----------|
| #134 | Fixed: u32→i64 timestamp, entry_idx dedup |
| #135 | Fixed: VOLUME shadow, worktree -b branch |
| #136 | Fixed via PR #138 merge |
| #137 | Fixed: pipefail, bash shebang, Telegram ordering |
| #140 | Fixed via PR #141 merge |

### Direct Commits to Main (3)
1. `b470c5ae7` — heartbeat subshell + pipefail + Telegram ordering + HTML escape
2. `fe6dc534e` — u32 overflow, entry_idx duplicates, VOLUME shadow, worktree conflict
3. Merge commits for PRs #129, #130, #138, #141

### Docker Image Rebuilt (2x)
- First: heartbeat + pipefail + Telegram fixes
- Second: VOLUME shadow removal + worktree branch fix

## Phase Completion

| Phase | Status | Detail |
|-------|--------|--------|
| 1. Merge PRs | DONE | 4 merged, 3 closed |
| 2. Entrypoint Hardening | DONE | 6 fixes applied |
| 3. Orchestrator CLI | 80% | pipeline/verify/merge added, logs TBD |
| 4. Auto-Pipeline | 70% | In PR #141, needs testing |
| 5. Monitoring | 30% | JSONL working, dashboard TBD |
| 6. Agent Intelligence | 20% | SOUL.md works, branch reuse TBD |

## Remaining Open Issues
- #131 feat(cloud): Stream all container logs to Telegram in realtime
- #126 Cloud Dev: Structured ACI protocol
- #128, #127 FPGA/pipeline TODOs (lower priority)

## Key Fixes Applied
1. Heartbeat reads from temp file (subshell isolation solved)
2. Telegram gets notifications on every status change (ordering fix)
3. HTML escaping + safe JSON via temp files
4. `#!/bin/bash` + `set -eo pipefail`
5. `i64` timestamps (no more u32 overflow)
6. No duplicate JSONL entries
7. No VOLUME shadowing bare repo
8. Concurrent agents get unique branches
9. Golden Chain: `tri cloud pipeline <N>` automates full cycle
10. Telegram `editMessageText` — 1 dashboard message updated in place
11. `NO_COLOR=1` in containers for clean output
12. Worktree lock/unlock prevents accidental pruning
13. Workflow reuses services instead of delete+create (avoids 25/day limit)

## Active Agents (latest cycle — 16:33 UTC)
- **ubuntu** service → #126 — 🔴 FAILED (0 commits, 619s — issue too abstract for autonomous agent)
- **Agents Anywhere** service → #131 — 🔵 DONE → PR #142 merged
- **Agents Anywhere** service → #115 (VIBEE eqlPrimitive fix) — 🔴 DONE but push failed 3x, no PR created
- **ubuntu** service → #114 (VIBEE undefined Field type) — 🔴 DONE but push failed (git auth bug)
- **Agents Anywhere** service → #116 (Re-verify stale ast-check) — 🔴 FAILED (gh can't read issue — missing --repo)
- PR #143 from agent-126 — 🔴 CLOSED (review: grep -oP not portable, worktree cleanup order)
- **Docker rebuild #3** — fixes: `gh auth setup-git`, `--repo` on all gh commands, PUSH_OK tracking
- **ubuntu** service → #114 (RETRY) — 🚀 REDEPLOYED 16:55 UTC with fixed image
- **Agents Anywhere** service → #116 (RETRY) — 🚀 REDEPLOYED 16:55 UTC with fixed image

## Bug Found & Fixed This Cycle
14. `sleepApplication: true` on "Agents Anywhere" service — Railway was sleeping container before entrypoint ran. Fixed via `serviceInstanceUpdate` + redeploy.

## Lessons Learned
1. Railway MCP `deploy` uploads source, NOT Docker image — use GraphQL API
2. `startCommand` overrides Docker ENTRYPOINT — must set via serviceInstanceUpdate
3. 25 service/day creation limit — never delete+create, always reuse
4. `variableCollectionUpsert` needs actual values, not empty shell vars
5. Service names with spaces break Railway CLI — avoid spaces in service names
6. `sleepApplication: true` silently kills agent containers — always set to false for batch jobs
7. Abstract/design issues (#126 "Structured ACI protocol") produce 0 commits — agents need concrete, code-level tasks with specific files/functions to modify
8. `retry "git push ... 2>/dev/null" || true` silently swallows push failures — agent reports DONE with no PR. Fixed: track PUSH_OK, skip PR creation if push fails, report FAILED explicitly
9. **CRITICAL**: `gh auth login` only configures `gh` CLI, NOT `git push`. Fixed: `gh auth setup-git`
10. **CRITICAL**: All `gh issue/pr` commands lack `--repo` flag — bare-repo worktrees have no git remote context. Fixed: extract `GH_REPO` from `REPO_URL`, add `--repo` to all gh calls
11. Docker rebuild #3 deployed with fixes #8-10. Both services redeployed 16:55 UTC
