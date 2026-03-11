# Night Evolution Map — Cloud Dev Pipeline Hardening
# 2026-03-11 night → 2026-03-12 morning

## Current State (updated)
- 3 PRs merged (#129, #130, #138), 3 closed with conflicts (#132, #133, #139)
- PR #141 (Golden Chain pipeline from agent-140) — CI pending, compile fixes pushed
- Docker image rebuilt with heartbeat + pipefail + Telegram fixes
- 2 Railway services reusable (agent-126, agent-131)
- agent-126 redeployed for issue #134, agent-131 for issue #135

## Evolution Phases (Priority Order)

### Phase 1: Merge Ready PRs ✅ DONE
- [x] PR #129 (JSONL event persistence) → merged
- [x] PR #130 (git worktree isolation) → merged
- [x] PR #138 (fix #136 — buffer + .gitignore) → merged
- [x] PR #132, #133, #139 → closed (conflicts after merges)
- [x] PR #141 (agent-140 Golden Chain) → compile fixes pushed, CI pending

### Phase 2: Entrypoint Hardening ✅ DONE
- [x] Heartbeat subshell bug → temp file `/tmp/agent_heartbeat_state`
- [x] `report_status()` writes to heartbeat file
- [x] Telegram notification ordering (BEFORE LAST_STATUS update)
- [x] `set -eo pipefail` + `#!/bin/bash` shebang
- [x] HTML escape helper `escape_html()`
- [x] `send_telegram()` uses temp file for JSON (no escaping issues)
- [x] Docker image rebuilt + pushed to GHCR

### Phase 3: Orchestrator CLI (partially done by agent-140)
Agent-140's PR #141 adds:
- [x] `tri cloud pipeline <N>` — spawn → monitor → verify → merge → cleanup
- [x] `tri cloud verify <N>` — local zig build check
- [x] `tri cloud merge <N>` — merge PR via gh CLI
- [x] Enhanced `tri cloud agents` — stuck detection, health indicators, elapsed formatting
Already working from before:
- [x] `tri cloud spawn <N>` — calls Railway API
- [x] `tri cloud kill <N>` — delete service
- [x] `tri cloud agents` — list active containers
- [ ] `tri cloud logs <N>` — fetch Railway deploy logs
- [ ] Service recycling in CLI (currently manual via env var update)

### Phase 4: Auto-Pipeline (in PR #141)
- [x] Spawn → monitor heartbeats → detect DONE/FAIL (in PR)
- [x] On DONE: fetch PR, run `zig build` locally (in PR)
- [x] On pass: auto-merge PR (in PR)
- [x] On fail: respawn (max 3x) (in PR)
- [ ] Create fix-issue with review on failure
- [ ] Cleanup container after completion

### Phase 5: Monitoring & Metrics
- [x] JSONL event persistence (PR #129 merged)
- [ ] Agent solve rate dashboard
- [ ] Cost per agent tracking
- [ ] Token usage estimation
- [ ] Success/fail/retry counters

### Phase 6: Agent Intelligence
- [x] Agent reads CLAUDE.md (via SOUL.md injection)
- [x] Better commit messages (include issue number)
- [ ] Agent checks out existing branch for fix-issues
- [ ] Agent runs `zig build -Dci=true` instead of full build
- [ ] Multi-file context awareness

## Active Agents
- agent-126 → issue #134 (fix PR #129 bugs — u32 timestamp, duplicates, buffer)
- agent-131 → issue #135 (fix PR #130 bugs — VOLUME shadow, worktree conflicts)

## Next Steps
1. Wait for PR #141 CI → merge if passes
2. Monitor agents #134, #135 → review PRs when ready
3. Spawn agent for #137 (fix PR #133 bugs) when slot frees up
4. Create issue for `tri cloud logs` command
5. Create issue for service recycling in CLI

## Constraints
- 2 Railway services available (agent-126, agent-131)
- z.ai proxy ~8min per agent run
- Telegram 30 msg/min rate limit
- Docker rebuild ~90s (cached layers)
