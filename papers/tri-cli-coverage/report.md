# TRI CLI Coverage Report

> Architecture analysis + improvement proposal for unified agent gateway

**Date**: 2026-03-11
**Status**: IMPLEMENTED (Day 1 complete)
**Goal**: All agents (Ralph, MU, Scholar, Swarm) use `tri` CLI as single gateway — no direct `git`/`gh` calls

### Implemented Commands (37 total)

| Category | Commands | Status |
|----------|----------|--------|
| **Git ops** (7) | `tri git status/diff/log/branch/add/commit/push` | ✅ All real |
| **Issues** (7) | `tri issue create/comment/close/decompose/list/view/assign` | ✅ All real |
| **Agent lifecycle** (6) | `tri agent list/start/done/stop/restart/status` | ✅ All real |
| **Deploy** (4) | `tri deploy push/status/logs/domain` | ✅ All real |
| **Notify** (1) | `tri notify "<msg>"` | ✅ Telegram |
| **MU healing** (5) | `tri mu stats/learn/fix/start/stop` | ✅ Pre-existing |
| **Diagnostics** (5) | `tri faculty/audit/status/phi/constants` | ✅ Pre-existing |
| **Pipeline** (5) | `tri gen/test/decompose/plan/verify` | ✅ Pre-existing |
| **Research** (1) | `tri research` | ✅ Pre-existing |

---

## A. Current Agent → Action Map

```
┌──────────────────────────────────────────────────────────────────┐
│                    TRI CLI (единый шлюз)                         │
├──────────┬───────────┬──────────┬──────────┬─────────────────────┤
│ tri mu   │ tri issue │ tri git  │ tri test │ tri agent           │
│ ✅ 100%  │ ⚠️  70%   │ ❌ 30%   │ ⚠️  60%  │ ⚠️  30%             │
│ stats    │ create  ✅│ commit 🔴│ spec   ✅│ start(N,name)  ✅   │
│ learn    │ comment ✅│ diff   🔴│ unit   ✅│ done(N,name)   ✅   │
│ fix      │ close   ✅│ status 🔴│ json   ❌│ list           ❌   │
│ errors   │ decomp  ✅│ push   ❌│ report ❌│ stop           ❌   │
│ report   │ assign  ❌│ branch ❌│          │ status         ❌   │
│ verify   │ list    ❌│ add    ❌│          │                     │
│          │ view    ❌│ log    🔴│          │                     │
└──────────┴───────────┴──────────┴──────────┴─────────────────────┘
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
    ┌───────────┐   ┌───────────┐   ┌───────────┐
    │   Ralph   │   │    MU     │   │  Swarm    │
    │ agent_loop│   │ mu_loop   │   │ tri_swarm │
    │           │   │           │   │           │
    │ Uses:     │   │ Uses:     │   │ Uses:     │
    │ claude CLI│   │ tri mu *  │   │ gh direct │
    │ (bypasses │   │ zig build │   │ (bypasses │
    │  tri git) │   │           │   │  tri issue│
    └───────────┘   └───────────┘   └───────────┘
```

**Legend**: ✅ real implementation | 🔴 stub (prints text, no subprocess) | ❌ not implemented

---

## B. What Each Agent Needs

| Agent | Current Method | Should Be |
|-------|---------------|-----------|
| **Ralph** | Spawns `claude` CLI → Claude runs `git`/`gh` directly | `tri git branch` → `tri git commit` → `tri git push` → `tri issue close` |
| **MU** | `tri mu *` (good!) but can't commit fixes | `tri mu fix` → `tri git commit "fix(mu): ..."` → `tri git push` |
| **Scholar** | Doesn't exist yet | `tri research scan` → `tri issue create` → `tri issue comment` |
| **Swarm** | Calls `gh` directly in `tri_swarm.zig` (10+ places) | `tri issue list` → `tri agent dispatch` → `tri issue close` |

---

## C. Existing Code Reuse Map

| Existing Implementation | Location | Can Wrap |
|------------------------|----------|----------|
| `executeGitCommit()`, `createFeatureBranch()`, `stageFiles()` | `src/tri/git/auto_git_commit.zig` | `tri git commit/branch/add` |
| `runGitCommand()` (subprocess executor) | `src/tri/git/auto_git_commit.zig:590` | Internal helper for all git ops |
| `issueCreate()`, `issueComment()`, `issueClose()`, `issueDecompose()` | `src/tri/github_commands.zig` | Already exist as `tri issue create/comment/close/decompose` |
| `GitHubClient.listIssues()`, `GitHubClient.getIssue()` | `src/tri/github_client.zig:334,352` | `tri issue list` / `tri issue view` |
| `GitHubClient.addLabels()`, `GitHubClient.addAssignee()` | `src/tri/github_client.zig:178,309` | `tri issue assign` |
| `fetchIssues()` (gh JSON parsing) | `src/tri/three_paths.zig:141` | Pattern for `tri issue list` |
| `gh issue edit --add-labels` | `src/tri/tri_swarm.zig` (direct calls) | Should migrate to `tri issue assign/label` |

---

## D. Gap Analysis — Stubs vs Real

### `tri git` — `src/tri/tri_commands.zig:219-237`

Current code is **pure stubs** — prints text, never calls `git`:

```zig
pub fn runGitCommand(allocator: std.mem.Allocator, action: []const u8, args: []const []const u8) !void {
    _ = allocator;  // ← UNUSED! No subprocess call
    std.debug.print("GIT {s}\n", .{action});
    // ... prints and returns. Nothing happens.
}
```

**Irony**: `src/tri/git/auto_git_commit.zig` has a FULL working `runGitCommand()` with subprocess execution, `GitResult`, branch protection, etc. The CLI stubs don't use it.

### `tri issue` — missing 3 subcommands

| Subcommand | Status | Implementation available? |
|------------|--------|--------------------------|
| `tri issue create` | ✅ Works | `github_commands.zig:84` |
| `tri issue comment` | ✅ Works | `github_commands.zig:155` |
| `tri issue close` | ✅ Works | `github_commands.zig:268` |
| `tri issue decompose` | ✅ Works | `github_commands.zig:316` |
| `tri issue list` | ❌ Missing | `GitHubClient.listIssues()` exists — just wire it |
| `tri issue view` | ❌ Missing | `GitHubClient.getIssue()` exists — just wire it |
| `tri issue assign` | ❌ Missing | `GitHubClient.addAssignee()` + `addLabels()` exist |

### `tri agent` — only 2 of 6 subcommands

| Subcommand | Status |
|------------|--------|
| `tri agent start <N> <name>` | ✅ Works |
| `tri agent done <N> <name>` | ✅ Works |
| `tri agent list` | ❌ Missing |
| `tri agent stop <name>` | ❌ Missing |
| `tri agent status` | ❌ Missing |

---

## E. Priority Implementation Plan

### Day 1: `tri git` — real implementations (replace stubs)

**File**: `src/tri/tri_commands.zig:219-237` — replace stubs with `std.process.Child.run()`

| Command | Implementation | Safety |
|---------|---------------|--------|
| `tri git status` | `git status --porcelain` → parsed output | read-only |
| `tri git diff` | `git diff --stat` | read-only |
| `tri git log [N]` | `git log --oneline -N` | read-only |
| `tri git branch <name>` | `git checkout -b <name>` | creates branch |
| `tri git add <files>` | `git add <file1> <file2>` (never `-A`) | staging only |
| `tri git commit "<msg>"` | `zig fmt` first, conventional format enforced | pre-validated |
| `tri git push` | `git push -u origin HEAD` | blocks main/master |

**Safety rules enforced in code**:
- `tri git commit` validates `type(scope): msg` format
- `tri git push` blocks push to `main`/`master`
- `tri git add` refuses `-A` / `.` without explicit flag

### Day 1: `tri issue` — fill 3 gaps

**File**: `src/tri/github_commands.zig` — add to `runIssueSubcommand()`

| Command | Implementation |
|---------|---------------|
| `tri issue list [--label X] [--state open]` | `GitHubClient.listIssues()` with label filter |
| `tri issue view <N>` | `GitHubClient.getIssue()` formatted output |
| `tri issue assign <N> [--to user] [--label status:in-progress]` | `GitHubClient.addAssignee()` + `addLabels()` |

### Day 2: `tri agent` + `tri test` enhancements

| Command | What |
|---------|------|
| `tri agent list` | Show all agents + PID + status from `.trinity/` state files |
| `tri agent stop <name>` | Kill agent process, update state |
| `tri agent status` | Compact summary of all agent states |
| `tri test [spec\|unit\|all]` | `zig build test` with JSON report to `.trinity/test_report.json` |

### Day 3: `tri research` + `tri deploy`

| Command | What |
|---------|------|
| `tri research scan` | Perplexity API search for relevant tech |
| `tri deploy push` | `railway up` |
| `tri deploy status` | `railway status` |
| `tri deploy logs` | `railway logs` |

---

## F. Closed Loop After Day 1

```
tri faculty            → see status          (already works ✅)
tri issue list         → pick task           (Day 1 ✅)
tri issue assign 114   → claim it            (Day 1 ✅)
tri git branch feat/114 → create branch      (Day 1 ✅)
... agent writes code ...
tri git status         → check changes       (Day 1 ✅)
tri git add src/       → stage               (Day 1 ✅)
tri git commit "fix"   → commit              (Day 1 ✅)
tri git push           → push                (Day 1 ✅)
tri issue close 114    → close               (already works ✅)
```

**Zero `git` or `gh` escapes** — everything goes through `tri`, fully traceable and testable.

---

## G. Migration Path for `tri_swarm.zig`

`tri_swarm.zig` has 10+ direct `gh` calls. After Day 1, these can be replaced:

```
BEFORE: .argv = &.{ "gh", "issue", "list", "--json", ... }
AFTER:  .argv = &.{ "tri", "issue", "list", "--label", ... }

BEFORE: .argv = &.{ "gh", "issue", "edit", N, "--add-label", ... }
AFTER:  .argv = &.{ "tri", "issue", "assign", N, "--label", ... }
```

This is a separate PR — first make `tri issue list/assign` work, then migrate callers.

---

## H. Verification Checklist

```bash
# Report exists
cat papers/tri-cli-coverage/report.md

# Git commands — real subprocess output
tri git status          # shows actual git status
tri git diff            # shows actual diff --stat
tri git log 5           # shows last 5 commits

# Issue commands — real GitHub API
tri issue list                    # JSON from GitHub
tri issue list --label agent:mu   # filtered
tri issue view 114                # issue details

# Build passes
zig build && zig build test
```
