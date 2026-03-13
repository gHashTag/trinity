# Trinity Autonomous Self-Improvement Loop

## Guide for Autonomous Agent Development on Railway

> Version 1.0 | 2026-03-13
> Repository: github.com/gHashTag/trinity

---

## Architecture: Perception -> Reasoning -> Action -> Feedback -> Learning

```
┌─────────────────────────────────────────────────────────────┐
│                    TRINITY SELF-IMPROVEMENT LOOP             │
│                                                             │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌─────────┐ │
│  │ PERCEIVE │──→│  REASON  │──→│   ACT    │──→│ REFLECT │ │
│  │ tri obs  │   │ tri plan │   │ tri gen  │   │tri verd │ │
│  └────┬─────┘   └──────────┘   └──────────┘   └────┬────┘ │
│       │                                              │      │
│       └──────────── LEARNING DB ←────────────────────┘      │
│                  .trinity/learning_db.json                   │
│                                                             │
│  Circuit Breaker: 3 fails → OPEN → 30min cooldown → retry  │
│  Rate Limiter:    100 calls/hour per agent                  │
│  Needle Check:    compile_rate + test_ok + benchmark delta  │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 0: Bootstrap (one-time)

### 0.1 Railway Service Setup

Env vars (must be set via Railway Dashboard, NOT in code):
- ANTHROPIC_API_KEY
- GITHUB_TOKEN
- TELEGRAM_BOT_TOKEN
- MONITOR_TOKEN (random hex, NOT default!)
- AGENT_TIMEOUT=3600
- AGENT_POOL_SIZE=2

### 0.2 State Structure

```
.trinity/
├── learning_db.json        # Error patterns and fixes (MU memory)
├── swarm_state.json        # Agent state (idle/busy/tasks)
├── pipeline_state.json     # Current pipeline step
├── compact_prev.raw        # Previous snapshot for delta-detection
├── circuit_breaker.json    # CB state: closed/open/half_open
├── metrics/
│   ├── benchmarks.jsonl    # Historical benchmarks
│   └── audit.jsonl         # Append-only audit log
└── jobs/
    ├── job-001.json        # Task execution result
    └── ...
```

---

## Phase 1: The Loop (main cycle)

### Step 1 — PERCEIVE (Observation)

```
tri faculty --raw > .trinity/current_snapshot.raw
```

Data collected:
- compile_pass/total/rate/delta
- build_ok, test_ok
- dirty files count
- agent statuses (ralph, mu, scholar, oracle)
- pipeline state + age
- swarm state (idle/busy/pending)
- v_number, v_zone, branch
- open_issues count
- last 3 commits

**Rule**: Never act without a fresh snapshot. Stale data = wrong decisions.

### Step 2 — REASON (Analysis + Planning)

Delta-detection: what changed since last run?

Change categorization:
- EMERGENCY: build_ok false, compile_rate drop >5%, agent DOWN
- IMPORTANT: new commits, dirty files change, pipeline stuck >2h
- ROUTINE: v_number shift, open_issues count, mu_rules growth
- NOISE: seconds_ago, wake counters (ignore)

**Task prioritization** (automatic):
1. EMERGENCY -> immediate fix, pause everything else
2. Failing tests -> agent mu repair loop (up to 3 attempts)
3. Compilation regression -> find guilty commit, revert
4. Stale pipeline (>2h on one link) -> restart or skip
5. Pending swarm tasks -> assign to idle agent
6. Improvement experiments -> only when everything is green

### Step 3 — ACT (Execute via tri pipeline)

**RULE: Do NOT write .zig directly — generate from .tri specs!**

Full pipeline for each task:
```
tri decompose "task description"    # break into subtasks
tri plan                            # build plan
tri spec create                     # create .tri specification
tri gen                             # generate .zig from .tri
tri test                            # zig build + zig build test
tri bench                           # benchmark before/after
tri verdict                         # toxic verdict (pass/fail/regress)
tri git                             # git add + commit + push
```

Single source of truth: .tri spec -> .zig code.
If gen doesn't produce 100% working code:
```
tri loop decision                   # Needle check
agent mu refactoring                # MU fixes generated code
```

### Step 4 — REFLECT (Evaluate result)

After each ACT cycle:
```
tri bench --compare-previous        # compare with previous version
```

Needle Check (continuation criteria):
- compile_rate >= previous
- test_ok == true
- benchmark did not degrade >5%
- no new security vulnerabilities

If ALL pass -> continue.
If ANY fail -> rollback + repair loop.

**Toxic verdict** (example):
```
TRINITY VERDICT v3.0
====================
TASK: SEC-04 command injection fix
COMPILE: 334/334 (100%) — no regression
TESTS:   42/42 pass
BENCH:   tool_executor 1.2ms → 1.1ms (-8%)
SECURITY: path traversal blocked
VERDICT: PASS — merge allowed
```

### Step 5 — LEARN (Training)

MU records pattern in learning_db.json:
```json
{
  "pattern": "sh_c_command_injection",
  "category": "SECURITY",
  "error": "tool_executor uses sh -c with unsanitized input",
  "fix": "replace sh -c with whitelist + execve array",
  "confidence": 0.95,
  "applied_count": 1,
  "first_seen": "2026-03-12T22:00:00Z"
}
```

Scholar researches best practices and creates issues.
Oracle predicts next problems based on patterns.

---

## Phase 2: Circuit Breaker (infinite loop protection)

```
┌────────────────────────────────────────────────┐
│            CIRCUIT BREAKER FSM                  │
│                                                │
│  CLOSED ──[3 fails]──→ OPEN                    │
│    ↑                      │                    │
│    │                  [30 min cooldown]         │
│    │                      ↓                    │
│    └──[1 success]── HALF_OPEN                  │
│                                                │
│  Triggers:                                     │
│  - 3 consecutive loops with no file changes    │
│  - 5 loops with the same error                 │
│  - compile_rate drop >10pp in one cycle        │
│  - Output volume decline >70%                  │
│                                                │
│  Recovery:                                     │
│  - OPEN: stop all agents, alert Telegram       │
│  - HALF_OPEN: run 1 task, verify success       │
│  - CLOSED: resume normal operation             │
└────────────────────────────────────────────────┘
```

### Zig Implementation:

```zig
const CircuitState = enum { closed, open, half_open };

const CircuitBreaker = struct {
    state: CircuitState = .closed,
    consecutive_failures: u32 = 0,
    last_failure_time: i64 = 0,
    cooldown_seconds: u64 = 1800, // 30 min

    pub fn recordResult(self: *CircuitBreaker, success: bool) void {
        if (success) {
            self.consecutive_failures = 0;
            self.state = .closed;
        } else {
            self.consecutive_failures += 1;
            if (self.consecutive_failures >= 3) {
                self.state = .open;
                self.last_failure_time = std.time.timestamp();
                // → alert to Telegram
            }
        }
    }

    pub fn canProceed(self: *CircuitBreaker) bool {
        return switch (self.state) {
            .closed => true,
            .open => blk: {
                const elapsed = std.time.timestamp() - self.last_failure_time;
                if (elapsed >= self.cooldown_seconds) {
                    self.state = .half_open;
                    break :blk true;
                }
                break :blk false;
            },
            .half_open => true, // allow one attempt
        };
    }
};
```

---

## Phase 3: Swarm Orchestration (parallel agents)

### Parallel Mode

```
POOL SIZE = 2 (Railway limit)
DRAIN INTERVAL = 15 min
AGENT TIMEOUT = 3600s (60 min)

Throughput:
- 2 agents x 60 min = 2 tasks/hour
- Drain every 15 min = smooth load balancing
- 12 tasks → ~6 hours fully autonomous
- Night batch (22:00 → 06:00) = up to 16 tasks
```

### Queue Prioritization

```
Priority labels → drain order:
1. priority:P0 + agent:spawn → immediate
2. priority:P1 + agent:spawn → next slot
3. agent:spawn (no priority) → FIFO
4. enhancement → only when queue is empty
```

---

## Phase 4: Self-Improvement Targets

### 4.1 tri CLI (iterative improvement)

```
Current state (v5.2):
tri faculty --raw          — working
tri decompose              — working
tri plan                   — working
tri spec create            — working
tri gen                    — working
tri test                   — working
tri bench                  — basic
tri verdict                — basic
tri git                    — working
tri loop decision          — stub
tri pipeline               — in development (#302, #304-#307)

Improvement goals:
1. tri bench → real numbers, history comparison, delta %
2. tri verdict → structured JSON verdict, not text
3. tri loop decision → automatic Needle check
4. tri pipeline → full Zig-native pipeline (replacing bash)
5. tri observe → delta-aware observatory (compact_prev.raw)
```

### 4.2 tri MCP (iterative improvement)

```
Improvement goals:
1. Audit logging on EVERY MCP call → append-only JSONL
2. Rate limiting per-tool (not just per-IP)
3. Structured error responses (not raw stderr)
4. Tool composition: chain MCP tools into pipelines
5. Rollback capability: undo last writeFile
```

### 4.3 Technology Tree (long-term strategy)

```
Level 0 (now):       tri CLI + MCP basics + agent-spawn.yml
    │
Level 1 (week 1):    tri pipeline (Zig-native) + security fixes
    │                 + delta-aware observatory
    │
Level 2 (week 2):    Self-healing loop + benchmark history
    │                 + MU learning rules >50
    │                 + FPGA Level 2 experiments
    │
Level 3 (week 3):    Multi-agent coordination protocol
    │                 + Cross-issue learning transfer
    │                 + Predictive task scheduling (Oracle)
    │
Level 4 (month 2):   Full autonomous mode
                      + Agent spawns improvement issues for ITSELF
                      + tri CLI generates tri CLI improvements
                      + Zero human intervention for routine tasks
```

---

## Phase 5: Monitoring and Alerts

### Observatory Dashboard

```
tri faculty --raw → Claude narration → delta detection
```

Run monitoring every 5 minutes via `tri observe` (Zig binary).

### Telegram Alerts

EMERGENCY alerts (immediate):
- build_ok: true -> false
- compile_rate drop >5pp
- circuit breaker OPEN
- agent container crashed
- security vulnerability detected

WARNING alerts (batched hourly):
- pipeline stuck >2h
- all agents idle with pending tasks
- dirty files >50
- MU learning stagnation (no new rules 24h)

STATUS reports (daily 09:00 UTC):
- Tasks completed/failed/pending
- Benchmark trends
- Agent utilization %
- Learning rules growth

---

## Phase 6: Autonomous Loop Safety Rules

### Halting Guarantees

1. **TIMEOUT**: every agent has hard timeout (3600s)
2. **CIRCUIT BREAKER**: 3 fails -> stop -> 30min cooldown
3. **BUDGET CAP**: max API calls per hour (100)
4. **ROLLBACK**: every commit auto-reverted if test fails
5. **HUMAN GATE**: PR review required for main branch
6. **KILL SWITCH**: Telegram /stop -> immediate stop of all agents

### What agents CANNOT do

- Merge to main without PR review
- Delete files outside working directory
- Modify .env or secrets
- Disable circuit breaker
- Increase their own timeout
- Create issues to bypass restrictions
- Execute commands not in whitelist

### What agents CAN do

- Create branches and PRs
- Run zig build and zig build test
- Read/write files in working directory
- Create issues with label agent:spawn
- Send status to Telegram
- Write to learning_db.json
- Run benchmarks

---

## Success Metrics

| Metric | Baseline | Goal (1 month) | Goal (3 months) |
|--------|----------|-----------------|------------------|
| Tasks/day (autonomous) | 2-3 | 8-10 | 15-20 |
| Success rate | 60% | 80% | 90% |
| MU learning rules | 12 | 50 | 200 |
| Mean time to fix | 45 min | 20 min | 10 min |
| Human intervention/day | 10+ | 3-5 | 1-2 |
| Compile rate | 100% | 100% | 100% |
| Security vulnerabilities | 13 | 0 | 0 |
| Circuit breaker trips/week | ? | <5 | <2 |

---

## Core Principles

1. **Single source of truth**: .tri spec -> .zig code. Never duplicate logic.
2. **Fail fast, learn always**: Every error -> learning_db entry -> prevention in the future.
3. **Observable by default**: Every action logged, every result measured.
4. **Safe by design**: Circuit breaker + timeout + whitelist + rollback = agent cannot destroy the system.
5. **Iterative improvement**: Each loop cycle makes the next cycle slightly better.

---

*Created: 2026-03-13*
*Author: Trinity Observatory + Security Audit Pipeline*
*Next revision: after first full autonomous night*
