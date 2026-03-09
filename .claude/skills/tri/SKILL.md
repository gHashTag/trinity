---
name: tri
description: Full TRI swarm diagnostic — builds, binaries, issues, agent status, code metrics. Run for system health check.
argument-hint: [focus-area]
allowed-tools: Bash(zig *), Bash(ls *), Bash(wc *), Bash(grep *), Bash(gh *), Bash(pgrep *), Bash(cat *), Bash(find *), Bash(git *), Bash(date *), Bash(test *), Read
---

Run a complete diagnostic of the TRI system. Output a beautifully formatted
report with tables, metrics, and status indicators.

If $ARGUMENTS is provided, focus the diagnostic on that area.

## Data Collection

Run these commands and collect ALL output:

### Build Health
```bash
zig build 2>&1; echo "EXIT:$?"
ls -lh zig-out/bin/tri zig-out/bin/tri-bot zig-out/bin/tri-api zig-out/bin/trinity-mcp zig-out/bin/needle-mcp zig-out/bin/ralph-agent zig-out/bin/ralph-hook zig-out/bin/vibee zig-out/bin/firebird 2>&1
```

### Code Metrics
```bash
find src/ tools/ -name "*.zig" | wc -l
find src/ tools/ -name "*.zig" | xargs wc -l | tail -1
grep -r "test \"" src/ tools/ --include="*.zig" | wc -l
wc -l src/tri-api/*.zig | tail -1
ls .claude/skills/ | wc -l
```

### Git Status
```bash
git branch --show-current
git log --oneline -5
git status --short | wc -l
git status --short | head -10
gh pr list --state merged --limit 5 --json number,title,mergedAt 2>/dev/null
gh issue list --state open --json number,title,labels --limit 10 2>/dev/null
```

### System Status
```bash
pgrep -f tri-bot && echo "RUNNING" || echo "STOPPED"
pgrep -f ralph-agent && echo "RUNNING" || echo "STOPPED"
ls ~/.tri-api/sessions/*.json 2>/dev/null | wc -l
test -f CLAUDE.md && echo "EXISTS" || echo "MISSING"
test -f .tri-api/settings.json && echo "EXISTS" || echo "MISSING"
```

## Output Format

Format ALL collected data into this report. Use REAL data — never placeholders.

### Report Structure

```
═══════════════════════════════════════════════════
   TRI SWARM DIAGNOSTIC REPORT
   {current date and time}
═══════════════════════════════════════════════════

BUILD HEALTH
┌───────────────────┬────────┬──────────┐
│ Binary            │ Status │ Size     │
├───────────────────┼────────┼──────────┤
│ trinity-mcp       │ OK/ERR │ X.X MB   │
│ ralph-agent       │ OK/ERR │ X.X MB   │
│ ralph-hook        │ OK/ERR │ X.X MB   │
│ tri-bot           │ OK/ERR │ X.X MB   │
│ tri-api           │ OK/ERR │ X.X MB   │
│ vibee             │ OK/ERR │ X.X MB   │
│ firebird          │ OK/ERR │ X.X MB   │
│ needle-mcp        │ OK/ERR │ X.X MB   │
│ tri               │ OK/ERR │ X.X MB   │
├───────────────────┼────────┼──────────┤
│ TOTAL             │ X/9    │ XX.X MB  │
└───────────────────┴────────┴──────────┘

CODE METRICS
┌─────────────────────┬───────────┐
│ Metric              │ Value     │
├─────────────────────┼───────────┤
│ Zig source files    │ X,XXX     │
│ Total LOC           │ XXX,XXX   │
│ Test blocks         │ XX,XXX    │
│ tri-api LOC         │ X,XXX     │
│ Skills              │ XX        │
└─────────────────────┴───────────┘

GIT STATUS
  Branch:     {branch}
  Last 5 commits:
    {hash} {message}
    ...
  Uncommitted: {count} changes

MERGED PRs (recent)
  #{num}  {title}

OPEN ISSUES
  #{num}  {title}  [{labels}]

SYSTEM STATUS
┌─────────────────────┬───────────┐
│ Component           │ Status    │
├─────────────────────┼───────────┤
│ tri-bot             │ UP/DOWN   │
│ ralph-agent         │ UP/DOWN   │
│ CLAUDE.md           │ OK/MISS   │
│ Permissions         │ OK/MISS   │
│ Sessions saved      │ X         │
│ Skills available    │ XX        │
└─────────────────────┴───────────┘
```

### Problems Section

After the main report, analyze the data and output a PROBLEMS section.
Flag any of these conditions:

- Uncommitted changes > 0: "Dirty files — commit or lose work!"
- tri-bot STOPPED: "tri-bot DOWN — no phone control"
- ralph-agent STOPPED: "ralph-agent DOWN — no autonomous agent"
- Permissions MISSING: "Permissions MISSING — unprotected tools"
- Sessions = 0: "tri-api never tested end-to-end"
- Build failed: "BUILD BROKEN — fix before anything else"

Format:
```
PROBLEMS DETECTED
  1. {problem description}
  2. {problem description}
  ...
```

If no problems: "ALL SYSTEMS NOMINAL"

### Priority Section

After problems, show current priority based on open issues:

```
CURRENT PRIORITY
  NOW:  {highest priority action based on problems}
  NEXT: {next open issue by priority label}

TECH TREE (from open issues)
  #{parent}  {title}  [P0 EPIC]
  ├── #{num}  {title}  [{priority}, {status}]
  │   └── #{num}  {title}  [{priority}, {status}]
  └── #{num}  {title}  [{labels}]
```

Build the tech tree from the open GitHub issues, using labels to determine
parent-child relationships and priorities (P0 > P1 > P2).

Always show the COMPLETE report. Never truncate or summarize.
