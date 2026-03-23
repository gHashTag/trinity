# AGENTS.md — Agent Work Rules (GitHub Issues = Source of Truth)

## Core Principle

> Agents do NOT work without a GitHub Issue.
> No issue = no task = no code = no PR.

## Agent Lifecycle

1. **IDLE** — Poll `gh issue list --label assign:ralph --label status:pending`
2. **CLAIM** — Add `status:in-progress` label, assign self
3. **BRANCH** — `git worktree add ../trinity-w{N} -b ralph/w{N}/{issue-slug} origin/main`
4. **WORK** — VIBEE-first: spec → gen → test → bench → assess
5. **PR** — `gh pr create --base main --body "Closes #N"` with ALL metadata (RULE #20)
6. **REPORT** — Comment on issue with results, metrics, assessment
7. **DONE** — General merges PR → issue auto-closes → board updates

## Issue as Workspace

All communication happens ON THE ISSUE:
- Progress updates → issue comments
- Blockers → issue comment with warning
- Benchmarks → issue comment with table
- Questions → issue comment mentioning @gHashTag
- Final report → issue comment with summary

## Rules

### RULE #19: Issue Metadata
Every issue MUST have: assignee, labels (`assign:ralph` + `priority:P0-P3` + `status:*`), milestone, project (VIBECODER #6), relationship (linked to parent epic).

### RULE #20: PR Metadata
Every PR MUST have: assignee, labels (same as linked issue + `status:in-progress`), milestone, reviewer (gHashTag), linked issues (`Closes #N` in body), project (VIBECODER #6).

### RULE #21: No Work Without Issue
Agent MUST NOT:
- Write code without an assigned issue
- Push commits without PR linked to issue
- Create branches without issue number in name
- Close issues manually (only via PR merge)

### RULE #22: GitHub Issues = Source of Truth
- All tasks come from `gh issue list --label assign:ralph`
- `fix_plan.md` is DEPRECATED as task source
- If no pending issues exist, agent is IDLE
- New work = new GitHub Issue first, then branch + code

## Sub-agents

Parent agent creates sub-issues for sub-agents:
```
Parent Issue #38 (epic, label: swarm:parent)
  |- Sub-issue #39 -> Agent-W1
  |- Sub-issue #40 -> Agent-W2
  +- Sub-issue #41 -> Agent-W3
```

Sub-agent follows same lifecycle: claim → branch → work → PR → done.
Parent issue progress bar updates automatically via sub-issues.

## Forbidden

- Working on main branch
- Working without issue
- Creating PR without "Closes #N"
- Empty issue metadata (no labels, no milestone)
- Manual issue close (only via PR merge)
- Editing generated files (`var/trinity/output/`, `generated/`)
- Pushing to main directly
- Reporting "done" without confirmed push

## Monitoring

Oracle Watchdog monitors all agents 24/7:
- Telegram alerts on commit, stop, circuit breaker
- GitHub Projects board (VIBECODER #6) shows real-time status
- `/god-mode` skill shows full dashboard
- GitHub Actions auto-update board on PR merge / issue close

---

*This file is part of the Ralph Autonomous Development System.*
*GitHub Issues = single source of truth. No exceptions.*
