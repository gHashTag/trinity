# Development Rules — Trinity v0.11.0

Universal guardrails for autonomous and manual development. These rules survive context resets.

**All development MUST go through Ralph (`.ralph/PROMPT.md`).** Direct ad-hoc changes outside the Ralph workflow lead to untracked state, missed quality gates, and undocumented patterns. See §18 for the full mandate.

---

## 1. Commands & Tooling

| Requirement | Value |
|-------------|-------|
| Target | Zig 0.15.x |
| Core Script | `.ralph/scripts/gate.sh` (Unified Quality Gate) |
| Sync Script | `.ralph/scripts/sync_tree.sh` (Tech Tree Sync) |

### Build & Run
```bash
zig build                         # Full build
zig build vibee -- gen <spec>     # Code generation (SOURCE OF TRUTH)
zig build bench                   # Performance check
```

### Verification
```bash
.ralph/scripts/gate.sh            # PRE-COMMIT MANDATORY (Build + Test + Format + Branch)
zig build test                    # All tests
```

---

## 2. File Safety & Generation

| Role | Path | Editable |
|------|------|----------|
| Specs | `specs/tri/*.vibee` | YES (Primary Source) |
| Logic | `src/*.zig`, `src/vibeec/*.zig` | YES |
| Output | `trinity/output/` | NEVER (Auto-generated) |

**Golden Rule:** If a feature exists in a `.vibee` spec, edit the spec, not the generated Zig code.

---

## 3. Branch & Commit Policy

| Rule | Detail |
|------|--------|
| Forbidden | Committing directly to `main` |
| Feature Branch | `ralph/<task-slug>` |
| Parallel Work | Use Git Worktree (see §17) |
| Commit Format | `type(scope): description — Tests X-Y (N/M P%)` |

**Pre-Commit Template:**
```
1. Run .ralph/scripts/gate.sh
2. Add successful pattern to .ralph/memory/SUCCESS_HISTORY.md
3. git add -A && git commit -m "..."
```

**For parallel tasks:** Use `git worktree add -b ralph/<task> ../trinity-<task> main` (see §17).

---

## 4. Failure & Blocker Protocol

1. **Attempt 1**: Debug root cause.
2. **Attempt 2**: Try alternative architecture.
3. **Attempt 3**: Mark BLOCKED in `fix_plan.md`, decompose into smaller tasks, and record in `.ralph/memory/REGRESSION_PATTERNS.md`.

---

## 5. Phase 2 (Optimization) Mandate

As we are in **Phase 2**, all changes must favor:
- **Ternary Efficiency**: 1.58 bits/trit density.
- **Speed**: Performance parity with C++ implementations.
- **Modularity**: Small files (~300 lines), single responsibility.
- **VSA Centricity**: Use Hypervectors for state and identity.

---

## 6. Security Rules

| Rule | Detail |
|------|--------|
| No secrets in commits | Never stage `.env`, `credentials.*`, API keys, tokens |
| No safety bypasses | Never use `--no-verify`, `--force`, `--no-gpg-sign` |
| No force push | Never `git push --force` to protected branches |
| No destructive ops | Never `git reset --hard`, `git clean -fd` on main |
| Auth/payment code | Always requires human review before commit |

---

## 7. VIBEE Specification Workflow

```
1. Create/edit spec  →  specs/tri/<name>.vibee
2. Generate code     →  zig build vibee -- gen specs/tri/<name>.vibee
3. Output            →  trinity/output/<name>.zig (auto-generated)
4. Test              →  zig build test
5. Assess            →  Write critical assessment (honest self-criticism)
6. Tech Tree         →  Propose 3 options for next iteration
7. Commit            →  git commit with metrics (Gate via .ralph/scripts/gate.sh)
```

**Spec format:**
```yaml
name: module_name
version: "1.0.0"
language: zig           # zig | varlog | python | go | rust
module: module_name

types:
  TypeName:
    fields:
      field: Type       # String | Int | Bool | Float | List<T> | Option<T>

behaviors:
  - name: function_name
    given: Precondition
    when: Action
    then: Expected result
```

---

## 8. Dashboard Widget Mandate

Every new module MUST have a Canvas Mirror widget.

| Column | Color | Realm | Widget Types |
|--------|-------|-------|-------------|
| RAZUM (Gold) | `#ffd700` | Mind | Routing, intelligence, logs, decisions |
| MATERIYA (Cyan) | `#00ccff` | Matter | Infrastructure, storage, data, files |
| DUKH (Purple) | `#aa66ff` | Spirit | Actions, tools, proofs, transfers |

**Requirements:**
- TypeScript interface in `website/src/services/chatApi.ts`
- Fetch function with mock fallback
- Widget in appropriate column of `TrinityCanvas.tsx`
- Must use `glassStyle()` and column color scheme
- Must be collapsible (toggle expand/collapse)

---

## 9. Deploy Rules

**Website + Docsite deploy together. ALWAYS.**

```bash
# 1. Build website
cd website && npx vite build

# 2. Build docsite
cd docsite && npm run build

# 3. Combine
rm -rf /tmp/gh-pages-deploy && mkdir /tmp/gh-pages-deploy
cp -r website/dist/* /tmp/gh-pages-deploy/
mkdir -p /tmp/gh-pages-deploy/docs
cp -r docsite/build/* /tmp/gh-pages-deploy/docs/

# 4. Deploy
cd /tmp/gh-pages-deploy
git init && git checkout -b gh-pages
git add -A && git commit -m "Deploy: <description>"
git remote add origin git@github.com:gHashTag/trinity.git
git push origin gh-pages --force
```

| Forbidden | Why |
|-----------|-----|
| `docusaurus deploy` | Deletes website from gh-pages |
| Deploy website only | Deletes docs/ |
| Deploy docsite only | Deletes website |
| Change `baseUrl` | Breaks all asset paths |

---

## 10. Telegram Bot Rules

| Allowed | Forbidden |
|---------|-----------|
| `ReplyKeyboardMarkup` (buttons at bottom) | `InlineKeyboardMarkup` (buttons in message) |

---

## 11. Mathematical Foundation

Reference values for validation:

| Concept | Value |
|---------|-------|
| Ternary values | {-1, 0, +1} |
| Information density | 1.58 bits/trit |
| Memory savings | 20x vs float32 |
| Trinity Identity | phi^2 + 1/phi^2 = 3 |
| Golden ratio | phi = (1 + sqrt(5)) / 2 |

---

## 12. Memory Protocol

The project maintains two knowledge bases that accumulate across development sessions:

| File | Purpose | When to Read | When to Write |
|------|---------|-------------|---------------|
| `.ralph/memory/SUCCESS_HISTORY.md` | Working patterns, stable commits | Before starting complex tasks, before refactoring | After confirming a successful approach |
| `.ralph/memory/REGRESSION_PATTERNS.md` | Failed approaches, anti-patterns | Before fixing errors, before trying new approaches | After analyzing a failure |

**Rules:**

1. **Always consult before acting** — read both files before starting any non-trivial task
2. **Search for analogies** — if a similar task/error exists in history, adapt that approach
3. **Never repeat documented anti-patterns** — if something is listed in REGRESSION_PATTERNS, don't try it again
4. **Record immediately** — add entries right after confirming success or analyzing failure, not later
5. **Commit hash required** — every SUCCESS_HISTORY entry must include:
   ```
   Commit: <full_hash> (Branch: <branch_name>)
   ```
   Get with: `git rev-parse HEAD` and `git branch --show-current`
6. **Keep entries structured** — follow the format templates in each file

---

## 13. Modularity Rule

| Guideline | Detail |
|-----------|--------|
| Max file size | ~300 lines (soft limit) |
| Responsibility | One clear responsibility per file |
| Functions | Small, focused, single-purpose |
| Decomposition | Split large files into focused sub-modules |
| Naming | File name reflects its single responsibility |

**When creating new code:**
- Start with a focused, single-purpose file
- If it grows beyond ~300 lines, split into sub-modules
- Prefer many small files over few large ones

**When refactoring:**
- Always ask: "Can this be split into smaller pieces?"
- Extract reusable logic into utility modules
- Refactoring = simplification + decomposition

**Why this matters for autonomous development:**
- Smaller files produce fewer AI editing errors
- Focused modules are easier to test in isolation
- Clear boundaries prevent scope creep

---

## 14. Pattern Search Before Implementation

Before writing ANY new code:

1. **Search the codebase** for similar implementations
   ```bash
   grep -r "keyword" src/vibeec/    # Search compiler code
   grep -r "keyword" src/            # Search core library
   ```
2. **Study how existing modules** solve similar problems
3. **Adapt proven patterns** — reuse what works, don't reinvent
4. **If no pattern exists** — implement carefully and record the new pattern in `SUCCESS_HISTORY.md` once confirmed

| Do | Don't |
|----|-------|
| Search for existing similar code first | Jump straight to implementation |
| Adapt proven project patterns | Invent new patterns without checking |
| Record new patterns that work | Leave successful approaches undocumented |

---

## 15. Blocker Decomposition Protocol

When a task fails repeatedly, don't just retry — decompose:

```
Attempt 1: Debug → Fix → Retry
Attempt 2: Alternative approach → Retry
Attempt 3: STOP → Decompose → Document
```

**Decomposition steps:**

1. **Analyze root cause** — don't guess, investigate
2. **Search REGRESSION_PATTERNS.md** — is this a known issue?
3. **Break solution into concrete sub-steps** — each independently verifiable
4. **Add sub-steps to fix_plan.md** as checkbox items
5. **Record the failure** in `REGRESSION_PATTERNS.md` with:
   - Exact error message
   - All approaches tried
   - Root cause analysis
   - The decomposed solution plan
6. **Start the first sub-step** as the next active task

**Template for fix_plan.md:**
```markdown
- [ ] [BLOCKED] Original task
  - Error: <exact message>
  - Tried: approach 1, approach 2, approach 3
  - Root cause: <analysis>
  - Sub-tasks:
    - [ ] [P1] Sub-task 1 (next active)
    - [ ] [P1] Sub-task 2
    - [ ] [P2] Sub-task 3
```

**Goal:** Transform vague blockers into actionable sub-tasks. Every problem has a decomposition that makes it solvable.

---

## 16. Tech Tree Protocol

The Tech Tree tracks all development progress across branches. It is the strategic roadmap.

### Files Hierarchy

| File | Role | When to Update |
|------|------|---------------|
| `specs/tri/tech_tree_strategy.vibee` | Canonical source (all node definitions) | After completing any node |
| `.ralph/TECH_TREE.md` | Ralph-readable snapshot | After completing any node |
| `website/src/components/TechTree/techTreeData.ts` | React visualization data | After completing any node |
| `docs/TECH_TREE.md` | Human-readable roadmap | Periodically, after milestones |

### Node Lifecycle

```
locked → available → in_progress → completed
```

- `locked`: Dependencies not yet met
- `available`: All dependencies completed, ready to work on
- `in_progress`: Currently being implemented (max ONE at a time)
- `completed`: Done, tested, committed

### Node Selection Rules

When choosing the next node to work on, prefer (in order):

1. **Priority 1** nodes over Priority 2+
2. **Nodes that unlock the most dependents** (highest ROI)
3. **Nodes on the critical path** to the next milestone
4. **Lower complexity** when priorities are equal (quick wins)

**ROI formula:** `(impact_score / complexity) * unlock_count`

### Node Completion Checklist

After finishing work on a Tech Tree node:

- [ ] Implementation done and all code tested
- [ ] `zig build` compiles
- [ ] `zig build test` passes
- [x] `zig fmt --check src/` is clean
- [ ] Node status updated in `.ralph/TECH_TREE.md` (move to Completed)
- [ ] Node status updated in `specs/tri/tech_tree_strategy.vibee`
- [ ] Check if locked nodes should now unlock
- [ ] Branch progress percentages recalculated
- [ ] Recorded in `.ralph/memory/SUCCESS_HISTORY.md` with commit hash
- [ ] 3 Tech Tree options proposed for next iteration (with real node IDs)

### Tech Tree Options Format (Exit Criteria)

When proposing 3 options, always use real node IDs:

```
Tech Tree Options:
1. [OPT-001] SIMD Vectorization — ROI: high, unlocks HW-001/HW-002, critical path to MS-002
2. [INF-003] KV Cache Optimization — ROI: medium, unlocks INF-005, advances inference branch
3. [CORE-004] JIT Compilation — ROI: risky, high reward but needs HW-001 first
```

---

## 17. Git Worktree Protocol

Git Worktree enables parallel development — work on multiple branches simultaneously without switching.

### When to Use Worktrees

| Scenario | Use Worktree? |
|----------|---------------|
| Long-running feature + urgent hotfix | YES |
| Testing in isolation while developing | YES |
| Comparing behavior across branches | YES |
| Single short task | NO — regular branch is fine |

### Creating a Worktree

```bash
# Create worktree for a new Ralph task branch
git worktree add -b ralph/<task-slug> ../trinity-<task-slug> main

# Where:
# -b ralph/<task-slug>        — new branch (follows Ralph naming)
# ../trinity-<task-slug>      — worktree directory (outside repo root)
# main                        — base branch

# Example: VSA math proofs task
git worktree add -b ralph/vsa-math-proofs ../trinity-vsa-math-proofs main
```

### Working in a Worktree

```bash
# Switch to the worktree
cd ../trinity-<task-slug>

# Verify branch
git branch

# Work normally — all git commands work as expected
zig build && zig build test
git add -A && git commit -m "feat(vsa): ..."
git push origin ralph/<task-slug>
```

### Managing Worktrees

```bash
# List all active worktrees
git worktree list

# Remove a worktree (after merging/completing work)
git worktree remove ../trinity-<task-slug>

# Clean stale worktree records
git worktree prune
```

### Rules

| Rule | Detail |
|------|--------|
| Naming | Worktree dir: `../trinity-<task-slug>`, branch: `ralph/<task-slug>` |
| One branch per worktree | Cannot checkout the same branch in two worktrees |
| Clean up after merge | Always `git worktree remove` when done |
| Never delete manually | Use `git worktree remove`, not `rm -rf` |
| Sync regularly | `git fetch origin && git rebase origin/main` in each worktree |
| Quality gates apply | Run `.ralph/scripts/gate.sh` in EACH worktree before commit |

### Advantages for Autonomous Development

- **Parallel tasks**: Prepare one task while another is in code review
- **Isolation**: Changes in one worktree never affect another
- **Safe rollback**: If a task fails, just remove the worktree — main stays clean
- **Independent builds**: Each worktree has its own `zig-out/` build artifacts

---

## 18. Ralph-Only Development Mandate

**All Claude Code development on Trinity MUST go through the Ralph autonomous workflow.**

### Why

| Without Ralph | With Ralph |
|---------------|------------|
| Ad-hoc changes, no tracking | Every change tracked in fix_plan.md |
| Forgotten quality gates | gate.sh enforced before every commit |
| No memory across sessions | SUCCESS_HISTORY + REGRESSION_PATTERNS |
| No strategic direction | Tech Tree drives task selection |
| Manual branch management | Automatic `ralph/<task-slug>` branches |

### How

1. **Read** `.ralph/PROMPT.md` — it contains full context, architecture map, constraints
2. **Consult** `.ralph/TECH_TREE.md` — pick the highest-priority available node
3. **Select task** from `fix_plan.md` — aligned with Tech Tree priorities
4. **Work** following the Golden Chain: spec → generate → verify → record → report
5. **Gate** every commit through `.ralph/scripts/gate.sh` (build → test → format → branch check)
6. **Record** outcomes in `.ralph/memory/SUCCESS_HISTORY.md` or `.ralph/memory/REGRESSION_PATTERNS.md`
7. **Report** status in RALPH_STATUS block at end of every response

### What This Means

- **Never** start implementation without reading PROMPT.md first
- **Never** commit without running gate.sh
- **Never** skip recording outcomes in memory files
- **Never** work on tasks not in fix_plan.md or TECH_TREE.md
- **Always** propose 3 Tech Tree options at task completion
