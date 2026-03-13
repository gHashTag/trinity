---
name: sec-monitor
description: Security monitoring daemon — checks for new secrets in commits, unsafe patterns in changed files, Docker/CI drift, and policy violations. Lightweight recurring scan for /loop usage.
argument-hint: [quick|diff|full] (default: quick)
---

# Security Monitor — Continuous Scan

## Mode: $ARGUMENTS

### Quick Scan (default) — check recent changes only

**New commits since last check (secrets in diffs):**
!`git log --oneline -5 --diff-filter=AM --name-only`

**Secrets in staged/unstaged changes:**
!`git diff HEAD --unified=0 | grep -i "sk-\|ghp_\|Bearer \|password.*=\|api_key.*=\|token.*=" | grep -v "test\|example\|getEnv\|secrets\." | head -10`

**New .sh files (BANNED):**
!`git diff HEAD --name-only --diff-filter=A | grep "\.sh$" | head -5`

**Modified security-critical files:**
!`git diff HEAD --name-only | grep -E "(Dockerfile|\.yml|\.json|server\.zig|auth|token|secret|permission)" | head -10`

### Diff Scan — compare working tree vs main

**Files with potential security changes:**
!`git diff main --name-only | grep -E "\.(zig|yml|json|toml)$" | head -20`

**New hardcoded strings in diff:**
!`git diff main -- "*.zig" | grep "^+" | grep -i "http://\|password\|secret\|0\.0\.0\.0\|chmod\|unsafe" | grep -v "^+++" | head -10`

**New environment variable usage:**
!`git diff main -- "*.zig" | grep "^+" | grep "getEnvVarOwned\|getenv" | head -10`

### Full Scan — comprehensive check

Run `/security-audit full` for the complete vulnerability scan.

### Automated Checks

**1. Docker image freshness:**
!`grep "^FROM " Dockerfile* docker/Dockerfile* deploy/Dockerfile* 2>/dev/null | head -8`

**2. GitHub Actions — untrusted action versions:**
!`grep -rn "uses:" .github/workflows/*.yml 2>/dev/null | grep -v "@v[0-9]\|@main\|@master" | head -5`

**3. Open ports in code:**
!`grep -rn "0\.0\.0\.0\|INADDR_ANY" --include="*.zig" src/ tools/ | head -5`

**4. File permission issues:**
!`find .claude .ralph .trinity -name "*.json" -perm +o+r 2>/dev/null | head -5`

### Report Format

Output a compact status:

```
SECURITY MONITOR — {timestamp}
==================================
Secrets in diff:    {count} {OK/ALERT}
New .sh files:      {count} {OK/VIOLATION}
Critical files mod: {count} {list}
Docker drift:       {OK/STALE}
Policy violations:  {count}
==================================
Status: {CLEAN / WARNINGS / ALERT}
```

If any ALERT found, recommend running `/security-audit full`.

### Integration with /loop

This skill is designed for recurring use:
```
/loop 60m /sec-monitor quick
```

Runs every hour, checks only recent changes, fast execution (~5s).
For deeper scans before deploy: `/sec-monitor full`
