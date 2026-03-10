---
name: bridge
description: Trinity Bridge manual — architecture, endpoints, commands, patterns for Perplexity-Railway-Mac-Claude Code channel. Reference for all AI agents.
argument-hint: [status|test|manual]
allowed-tools: Bash(curl *), Bash(pgrep *), Bash(tail *), Bash(cat *), Bash(echo *), Bash(date *), Read
---

# TRINITY BRIDGE — Instruction for Claude Code Control
## Reference for AI Agents (Perplexity, Scholar, MU, Swarm)

---

## 1. ARCHITECTURE

```
AI Agent (Perplexity/other)
    |
    | GET /px/exec?cmd=<command>&token=<TOKEN>
    v
Railway Server (trinity-production-a1d4.up.railway.app)
    | perplexity_bridge.zig -> creates job -> queue
    v
Mac Bridge Agent (tri-bridge-agent.sh, PID on Mac)
    | poll every 3s -> picks up job
    | if cmd starts with "claude:" -> env -u CLAUDECODE claude --print "<prompt>"
    | else -> shell exec (diag, status, build, test...)
    v
Claude Code (autonomous session, timeout 600s)
    | executes prompt -> stdout
    v
Bridge Agent -> POST /px/done -> result saved
    v
AI Agent -> GET /px/result?id=<job_id> -> reads result
```

---

## 2. ENDPOINTS

### Base URL
```
https://trinity-production-a1d4.up.railway.app
```

### Token
```
PX_BRIDGE_TOKEN=d9d42042ada98a9557c9cb5b1609edd88447d72ecda16f2ce723a6bca4718df5
```

### API Reference

| Endpoint | Method | Description | Example |
|----------|--------|-------------|---------|
| `/px/status` | GET | Server health + queue | `?token=TOKEN` |
| `/px/exec` | GET | Submit command | `?cmd=diag&token=TOKEN` |
| `/px/jobs` | GET | List all jobs | `?token=TOKEN` |
| `/px/result` | GET | Result of specific job | `?id=JOB_ID&token=TOKEN` |
| `/px/done` | POST | Write result (bridge-agent) | body: raw text, id+exit in query |

---

## 3. COMMANDS (WHITELIST)

### Shell commands (instant, <5s)

| Command | What it does | When to use |
|---------|-------------|-------------|
| `diag` | zig build + compile rate + dirty files | Quick health check |
| `status` | git status --short + git log -5 | What changed? |
| `build` | zig build 2>&1 | Check compilation |
| `test` | zig build test 2>&1 | Run tests |
| `issues` | gh issue list --limit 20 | List open issues |
| `log` | git log --oneline -20 | Recent commits |
| `branch` | git branch --show-current | Current branch |
| `help` | List available commands | Help |

### Claude commands (autonomous, up to 600s)

Format: `claude:<prompt>`

| Example | What it does |
|---------|-------------|
| `claude:Fix 5 broken specs` | Find and fix broken specs |
| `claude:Run /scholar scan` | Launch Scholar research |
| `claude:Run /scholar full` | Full Scholar cycle |
| `claude:Run /scholar topic:"quantum computing"` | Deep research on topic |
| `claude:Execute Protocol v2 on issue 79` | Full development cycle |
| `claude:Run /tri` | Full system diagnostic |
| `claude:git add -A && git commit -m "msg" && git push` | Commit and push |

---

## 4. PROTOCOL V2 (Development Management)

To create a feature via Claude Code:

```
claude:Execute Protocol v2 on issue {N}.
Create sub-issues RESEARCH PLAN IMPLEMENT TEST VERIFY.
Implement code, run tests, close all sub-issues.
```

Phases:
1. **RESEARCH** — study the problem, gather context
2. **PLAN** — create implementation plan
3. **IMPLEMENT** — write code
4. **TEST** — run tests
5. **VERIFY** — final check, close issue

---

## 5. SCHOLAR SKILL (Research Agent)

| Command | Action |
|---------|--------|
| `/scholar scan` | Scan: open issues + broken specs + TODOs -> call perplexity_research MCP |
| `/scholar eval` | Evaluate findings: HIGH (>0.8) / MEDIUM (>0.5) / LOW |
| `/scholar apply` | HIGH -> gh issue create, MEDIUM -> MU DB, LOW -> archive |
| `/scholar full` | scan -> eval -> apply sequentially |
| `/scholar errors` | Focus on current compile failures |
| `/scholar report` | Show cached results (no API calls) |
| `/scholar topic:"query"` | Deep research on specific topic |

Via bridge:
```
/px/exec?cmd=claude:Run /scholar full&token=TOKEN
```

---

## 6. USAGE PATTERNS

### Monitoring (every 30 min)
```
1. GET /px/exec?cmd=diag        -> compile rate, dirty files
2. GET /px/result?id=<id>       -> read result
3. If compile < 90%             -> send fix command
4. If dirty > 0                 -> send commit command
```

### Bug fixing (autonomous)
```
1. GET /px/exec?cmd=claude:Find and fix all zig ast-check failures. Commit fixes.
2. Wait 5-10 min
3. GET /px/result?id=<id>       -> read what was fixed
4. GET /px/exec?cmd=diag        -> confirm new compile rate
```

### Research loop (every 24h)
```
1. GET /px/exec?cmd=claude:Run /scholar full
2. Wait 10-15 min
3. GET /px/exec?cmd=issues      -> see new research issues
```

### Feature development (30-60 min)
```
1. GET /px/exec?cmd=claude:Execute Protocol v2 on issue {N}
2. Wait 10-30 min
3. GET /px/result?id=<id>       -> status
4. GET /px/exec?cmd=diag        -> build health after changes
```

---

## 7. ERROR HANDLING

| Error | Cause | Solution |
|-------|-------|---------|
| `{"error":"unknown command"}` | Command not in whitelist | Use `claude:` prefix |
| `404` on /px/result | Job cleaned or doesn't exist | Job may have expired, resend |
| `status: pending` | Bridge-agent not running on Mac | Start: `./deploy/tri-bridge-agent.sh` |
| `nested session error` | CLAUDECODE env var not unset | In agent.sh: `env -u CLAUDECODE` |
| `timeout` | Claude Code thinking >600s | Break task into smaller pieces |
| `failed to post result` | Railway didn't accept POST | Check /px/done endpoint |
| Empty `/px/jobs` | Railway redeploy cleared queue | Normal — send new job |

---

## 8. COMPONENT STATUS

### How to check everything works
```
GET /px/status -> {"status":"ok","queue_pending":N,"queue_running":N}
```

| Component | Check | Expected |
|-----------|-------|----------|
| Railway Server | GET /px/status | `{"status":"ok"}` |
| Bridge Agent | `pgrep -f tri-bridge-agent` on Mac | PID exists |
| Claude Code | Send `claude:echo hello` | Result: "hello" |
| Perplexity MCP | `claude:Run perplexity_search "test"` | Search results |
| GitHub Board | https://github.com/users/gHashTag/projects/6 | Issues visible |

---

## 9. GITHUB INTEGRATION

### Repository
```
https://github.com/gHashTag/trinity
```

### Project Board
```
https://github.com/users/gHashTag/projects/6/views/1
```

### Board Columns
| Column | Meaning |
|--------|---------|
| Backlog | New/pending issues |
| Ready | P0/P1, ready to work |
| In Progress | Currently in development |
| In Review | Code written, needs review |
| Done | Closed and verified |

### Labels
| Label | Meaning |
|-------|---------|
| P0 | Critical priority |
| P1 | High priority |
| P2 | Medium priority |
| agent:ralph | For Ralph Agent |
| agent:mu | For MU Agent |
| agent:swarm | For Swarm Agent |
| research:high | Scholar finding, high relevance |

---

## 10. FACULTY (TRI UNIVERSITY)

| Agent | Role | How to invoke |
|-------|------|--------------|
| Ralph | Engineer — build, fix, implement | `claude:Execute Protocol v2 on issue N` |
| Scholar | Researcher — search, analyze | `claude:Run /scholar scan` |
| MU | Memory — error patterns, learning | `claude:Run /tri` (MU section) |
| Oracle | phi-Analyst — metrics, harmony | `claude:Run /tri` (Oracle section) |
| Swarm | Coordinator — task decomposition | `claude:tri swarm run N` |
| Linter | QA — vibee check, ast-check | `claude:zig build 2>&1` |
| Bridge | Comms — Perplexity <-> Trinity | `/px/status` |

---

## 11. KEY METRICS

| Metric | Command | Target |
|--------|---------|--------|
| Compile Rate | `diag` -> COMPILE:X/Y | >= 90% |
| Build Status | `build` | EXIT:0 |
| Dirty Files | `diag` -> DIRTY:N | 0 |
| Open Issues | `issues` | Decreasing |
| Task Success | `/tri` -> job success % | > 50% |
| V (Oracle) | phi * (compile%)^2 | -> 1.618 (phi) |

---

## 12. URL ENCODING

Spaces in commands:
- `+` -> space (preferred)
- `%20` -> space
- `%3A` -> `:` (for claude:)

Full URL example:
```
https://trinity-production-a1d4.up.railway.app/px/exec?cmd=claude:Fix+broken+specs&token=TOKEN
```

---

## 13. AUTONOMOUS MODE (AGI LOOP)

```
+-----------------------------------------------------+
|                   AGI LOOP (24h)                     |
|                                                      |
|  06:00 UTC  Scholar /scholar full                    |
|       |     -> scan -> eval -> apply                 |
|       v                                              |
|  06:30 UTC  New research issues on board             |
|       |                                              |
|       v                                              |
|  07:00 UTC  Ralph: Protocol v2 on each HIGH issue    |
|       |     -> RESEARCH -> PLAN -> IMPLEMENT -> TEST |
|       v                                              |
|  12:00 UTC  MU: analyze morning errors               |
|       |     -> update Learning DB                    |
|       v                                              |
|  18:00 UTC  Scholar /scholar errors                  |
|       |     -> fix what broke                        |
|       v                                              |
|  00:00 UTC  Diag -> report -> Telegram               |
|       |     -> daily metrics                         |
|       v                                              |
|  Repeat                                              |
+-----------------------------------------------------+
```

---

## Skill Modes

If $ARGUMENTS is provided:

- `status` — Run quick bridge health check: curl /px/status, pgrep bridge-agent, show results
- `test` — Send a test command (`claude:echo bridge test ok`) and poll for result
- `manual` — Display this full manual

Default (no args): show `status`.
