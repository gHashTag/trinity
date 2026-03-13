---
name: security-audit
description: Security vulnerability scanner — scans repo for hardcoded secrets, injection vectors, unsafe patterns, Docker/CI misconfigs, and policy violations. Use when checking security posture or before releases.
argument-hint: [secrets|code|infra|full] (default: full)
---

# Security Audit — Trinity Repository

## Scope: $ARGUMENTS

Run a comprehensive security audit. Default scope is `full` (all categories).

### Phase 1: Secrets & Credentials

Search for hardcoded secrets, leaked tokens, and credential mismanagement.

**Check hardcoded keys:**
!`grep -rn "sk-\|ghp_\|Bearer \|password\|api_key.*=.*['\"]" --include="*.zig" --include="*.yml" --include="*.json" src/ tools/ .github/ 2>/dev/null | grep -v "test\|example\|REDACTED\|placeholder" | head -20`

**Check .env in git:**
!`git ls-files | grep -i "\.env$\|credentials\|\.key$\|\.pem$" | head -10`

**Check gitignore coverage:**
!`cat .gitignore | grep -i "env\|secret\|key\|token\|credential" | head -10`

### Phase 2: Code Vulnerabilities

Scan Zig source for injection, buffer overflows, unsafe patterns.

**Command injection vectors (shell exec without sanitization):**
!`grep -rn "ChildProcess\|std.process\|runCommand\|spawnProcess" --include="*.zig" src/ tools/ | head -15`

**Unsafe JSON parsing (manual string search instead of std.json):**
!`grep -rn "indexOf.*\"\|mem.indexOf.*json\|extractJson" --include="*.zig" tools/mcp/ src/ | head -15`

**Unvalidated input used in file paths:**
!`grep -rn "openFileAbsolute\|createFileAbsolute\|writeFileAbsolute" --include="*.zig" src/ tools/ | head -15`

**Missing auth checks on HTTP handlers:**
!`grep -rn "0\.0\.0\.0\|listen\|bind_address" --include="*.zig" src/ tools/ | head -10`

### Phase 3: Infrastructure & Docker

**Unpinned Docker base images:**
!`grep -rn "^FROM " Dockerfile* docker/Dockerfile* deploy/Dockerfile* 2>/dev/null | grep -v "@sha256" | head -10`

**Zig download without checksum:**
!`grep -rn "wget.*zig\|curl.*zig" Dockerfile* docker/Dockerfile* deploy/Dockerfile* 2>/dev/null | grep -v "sha256" | head -10`

**GitHub Actions secret exposure:**
!`grep -rn "ANTHROPIC_API_KEY\|RAILWAY_API_TOKEN\|TELEGRAM_BOT_TOKEN" .github/workflows/*.yml 2>/dev/null | grep -v "secrets\." | head -10`

**Overly broad permissions in workflows:**
!`grep -B2 -A2 "permissions:" .github/workflows/*.yml 2>/dev/null | head -20`

### Phase 4: Policy Violations

**Bash scripts (BANNED by CLAUDE.md):**
!`find . -name "*.sh" -not -path "./.git/*" -not -path "./fpga/prjxray/*" -not -path "./fpga/nextpnr-xilinx/*" 2>/dev/null | head -15`

**Shell entrypoints in Dockerfiles:**
!`grep -rn "ENTRYPOINT.*\.sh\|CMD.*\.sh\|CMD.*bash" Dockerfile* docker/Dockerfile* deploy/Dockerfile* 2>/dev/null | head -10`

### Phase 5: Analysis

Based on the scan results above, produce a security report:

1. **CRITICAL** — immediate action required (secrets in code, injection vectors)
2. **HIGH** — should fix before next deploy (Docker, CI exposure)
3. **MEDIUM** — plan to fix (missing auth, rate limiting)
4. **LOW** — nice to have (permissions, policy cleanup)

Format as a table with: Severity | File:Line | Issue | Suggested Fix

### Known Vulnerabilities (from last audit 2026-03-13)

| ID | Severity | Component | Issue |
|----|----------|-----------|-------|
| SEC-01 | CRITICAL | git_ops.zig:29 | GitHub token embedded in git clone URL |
| SEC-02 | CRITICAL | agent-spawn-pool.yml:150 | API keys in GraphQL mutation JSON (log exposure) |
| SEC-03 | HIGH | cloud_monitor.zig:719 | Manual JSON parsing — injection risk |
| SEC-04 | HIGH | cloud_monitor.zig:480 | Race condition on shared state (no mutex) |
| SEC-05 | HIGH | Dockerfiles | Unpinned base images + no checksum on Zig download |
| SEC-06 | HIGH | deploy/*.sh | Bash entrypoints violate CLAUDE.md ban |
| SEC-07 | MEDIUM | tool_executor.zig:228 | Bash whitelist bypass via command chaining |
| SEC-08 | MEDIUM | cloud_monitor.zig:63 | Empty MONITOR_TOKEN bypasses auth |
| SEC-09 | MEDIUM | session_store.zig:55 | Session files world-readable (0644) |
| SEC-10 | MEDIUM | http_api.zig:19 | Services bind 0.0.0.0 without auth |
| SEC-11 | MEDIUM | workflows | No input sanitization on dispatch inputs |
| SEC-12 | MEDIUM | CI/CD | No container image security scanning |
| SEC-13 | LOW | grok_provider.zig:17 | Placeholder API key as fallback |
| SEC-14 | LOW | Dockerfile.px-bridge:52 | Token in HEALTHCHECK URL parameter |

Compare current scan results with this baseline. Report NEW issues and FIXED issues.
