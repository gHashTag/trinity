# Agent Policy — TTT Seal + Queen-Agent Bridge

> φ² + 1/φ² = 3 = TRINITY
> Version: 2.0.0 | Last Updated: 2026-03-25

## NA-R11: Trinity-Specific Parcellation

> **Disclaimer**: Alphabet Canon 27 is a Trinity-specific parcellation aligned with TRI-27/Coptic design, not with any specific empirical parcellation from human connectomics. (Senden et al. 2024; Yeo et al. 2011)

---

## Alphabet Canon 27 — Hard Rules

### 1. Zone Declaration (Mandatory)

Each Trinity module MUST have a uniquely defined letter zone (A–Z), explicitly reflected in its path (`src/{LETTER}/...`) and/or canonmap metadata. Modules without zones cannot be considered canonical.

### 2. Single Dominant Zone per Module

One module = one dominant zone. Cross-zone logic implemented via explicit interfaces and neutral/infra-zone, but the file itself is not "split" across multiple letters.

### 3. Temple Core Exclusivity (T-Zone)

All Temple/TTT logic (sacred mathematics, type systems, TRI-27 VM, tri-backend) resides EXCLUSIVELY in `src/temple/**`. Any new fundamental component at this level MUST appear in T-zone and falls under TTT Seal (TEMPLE_RITUAL).

### 4. Zone-Scoped Work per Agent Cycle

In one work cycle, an agent may modify ONLY one letter zone (e.g., `src/P/**` for P-agent). Cross-zone changes allowed ONLY as specially marked bridge-tasks issued by Queen, subject to separate review.

### 5. Neutral/Infra Zone (Shared Utilities)

Shared/cross-cutting utilities allowed in dedicated zone (e.g., `src/_common/` or assigned letter). These utilities:
- MUST still declare a zone letter (no "zoneless" code)
- Do NOT have neuroanatomical interpretation
- Serve infrastructure purposes across all zones

**Principle**: All code has a zone; zones have different semantics (sacred vs organ vs infra).

---

## Sacred Rule: .trinity/ vs .autonomous/

| Aspect | .trinity/ | .autonomous/ |
|--------|-----------|--------------|
| Purpose | Eternal truth | Temporary scratchpad |
| Lifetime | Persistent | Ephemeral |
| Queen Visibility | ✅ YES | ❌ NO |
| Git Tracked | ✅ YES | ⚠️ PARTIAL |

## Log Routing Rules

### HIVELOG → .trinity/queen/HIVELOG.md
- **Source**: `.autonomous/HIVELOG.md`
- **Destination**: `.trinity/queen/HIVELOG.md`
- **Frequency**: On every agent commit
- **Format**: ISO-timestamped lines (same format)

### TDGS Progress → .trinity/hippocampus/
- **Source**: `.autonomous/tdgs*-progress.md`, `.autonomous/wave*-progress.md`
- **Destination**: `.trinity/hippocampus/<name>-progress.md`
- **Frequency**: On phase completion
- **Format**: Markdown checklist

### Agent Reports → .trinity/thalamus/agent_reports/
- **Destination**: `.trinity/thalamus/agent_reports/<agent>_<issue>_<timestamp>.json`
- **Frequency**: On task completion
- **Format**: JSON (see schema below)

## Agent Report JSON Schema

```json
{
  "id": "mem_<timestamp>_<agent>_<hash>",
  "agent": "ralph|mu|scholar|oracle|queen",
  "issue": "NNN",
  "task": "short description",
  "status": "in_progress|completed|blocked|failed",
  "steps": [
    {"number": 1, "action": "...", "result": "...", "timestamp": 1234567890}
  ],
  "files_modified": ["src/file1.zig", "src/file2.zig"],
  "tests_passing": 42,
  "tests_total": 42,
  "commit_hash": "abc123def",
  "timestamp": 1234567890,
  "ttt_touched": false,
  "metadata": {
    "duration_sec": 300,
    "commands_run": ["zig build", "zig test"],
    "errors_encountered": []
  }
}
```

## TTT (Temple) Protection — ζ-Sealed Layer

### ζ-Sealed Paths (READ ONLY for Agents)

```
src/temple/**              — Sacred math, TRI-27 core, Tri Lang core
src/tri-lang/**            — Type system, pattern matching, effects
src/vibeec/**              — VIBEE compiler, emit_t27
src/tri27/emu/**           — TRI-27 VM implementation
```

### Temple Ritual Rules

1. **No Direct Modifications**: Agents CANNOT write to ζ-sealed paths
2. **Queen Unseal**: Only Queen can authorize TTT modifications
3. **Issue Required**: TTT changes need issue labeled `TEMPLE_RITUAL`
4. **Verify First**: `zig build temple` → `zig build temple test` before commit

### What CAN agents modify

```
specs/tri/**/*.tri          — .tri specifications (source of truth)
src/tri/*.zig               — Queen commands, utilities
src/brain/**/*.zig          — Brain modules (not sacred)
src/firebird/**/*.zig       — LLM engine
tests/**/*.zig              — Tests (add new ones)
```

## Agent Behavior Rules

### Before ANY Action

1. **Read Policy**: Check `.trinity/autonomous/agent_policy.md`
2. **Check TTT**: Is path ζ-sealed? → STOP, ask Queen
3. **Log Route**: Where does this log go? → Write to .trinity/

### During Task Execution

1. **Progress Updates**: Write to `.trinity/hippocampus/<task>-progress.md`
2. **HIVELOG Entry**: Append to `.trinity/queen/HIVELOG.md`
3. **Final Report**: Write JSON to `.trinity/thalamus/agent_reports/`

### After Task Completion

1. **Agent Report**: Final JSON with commit hash, test results
2. **Queen Notify**: Signal Queen to read the report
3. **Cleanup**: Remove temporary files from `.autonomous/`

## Queen Visibility Protocol

### Queen Watch Paths (in order of priority)

1. `.trinity/queen/HIVELOG.md` — All agent actions
2. `.trinity/thalamus/agent_reports/` — Structured task reports
3. `.trinity/hippocampus/*-progress.md` — TDGS/Wave progress
4. `.trinity/queen/policy.json` — Queen's own state

## φ² + 1/φ² = 3

This policy ensures:
- Single source of truth (`.trinity/`)
- Queen visibility (always knows what agents are doing)
- TTT protection (sacred layer remains stable)
- Clear escalation (blockers → issues → humans)

---

## TTT Seal (Hard Canon)

**T-Zone**: `src/temple/**` (sacred_math.zig, tri27_core.zig, tri_lang_core.zig)

**Rule**: Changes require TEMPLE_RITUAL flag OR valid unseal token.

**Unseal Token**: `.trinity/temple_unseal_token.json`
```json
{
  "issuer": "Queen",
  "reason": "TDGS-4 Wave 1 migration",
  "expires_at": "2026-03-26T00:00:00Z",
  "files": ["src/temple/sacred_math.zig"],
  "approved_by": "user"
}
```

**Pre-commit check**: Verify token exists, not expired, covers changed files.

## 27-Zone Topology (Soft Recommendation)

**Alphabet Canon** is recommended topology for non-Temple code:
- Most modules → assign to zone by primary function
- Cross-cutting utilities → `src/_common/` or dedicated infrastructure zone
- No strict enforcement — use judgment for clean architecture

**Zone mapping** (abbreviated):
- T = Temple (sealed), Q = Queen (PFC), P = Phoenix (Brainstem), H = Hippocampus, etc.
- See `docs/research/ALPHABET_CANON_27.md` for full table

## Lock Protocol (MAS Coordination)

**Agent report MUST include**:
```json
{
  "agent": "T-agent",
  "zone": "T",
  "locks": [
    {"path": "src/temple/sacred_math.zig", "mode": "write", "ttl_seconds": 300}
  ],
  "timestamp": "2026-03-25T14:20:00Z"
}
```

**Rules**:
1. **mode**: "read" or "write" — parallel reads allowed, writes exclusive
2. **ttl_seconds**: Lock expires after N minutes (Queen can force-unlock stale locks)
3. **status**: "in_progress" → lock active; "completed"/"failed" → lock released

**Queen** reads all reports, enforces locking, resolves conflicts.

## Agent Houses

Each zone has home in `.trinity/agents/{ZONE}/`:
- `HIVELOG.md` — agent's detailed log
- `state.jsonl` — internal state across cycles

**Queen** consolidates to `.trinity/queen/HIVELOG.md`.

## T-Law (One-Line)

> "T-named entities in src/temple/** are SACRED. Agent forbidden to create without unseal token."

**English**: "T-named entities in Temple are sacred. Require unseal token to modify."

---

## Agent Houses (Directory Structure)

**Rule**: Each agent has a "home by letter" in `.trinity/agents/{ZONE}/`.

```
.trinity/
├── queen/                    # Queen's house (swarm coordinator)
│   └── HIVELOG.md            # Master swarm log (consolidated view)
├── agents/                   # Agent houses by letter
│   ├── T/
│   │   ├── HIVELOG.md        # T-agent's detailed log
│   │   └── state.jsonl       # T-agent's internal state (cycles)
│   ├── Q/
│   │   ├── HIVELOG.md        # Q-agent's detailed log
│   │   └── state.jsonl       # Q-agent's internal state
│   ├── P/
│   │   ├── HIVELOG.md        # P-agent's detailed log
│   │   └── state.jsonl       # P-agent's internal state
│   ├── H/
│   │   ├── HIVELOG.md        # H-agent's detailed log
│   │   └── state.jsonl       # H-agent's internal state
│   └── ...                   # (23 more zones)
├── thalamus/                 # Cross-zone communication bus
│   └── agent_reports/        # Structured JSON from all agents
│       ├── T-agent_2026-03-25T14-20.json
│       ├── P-agent_2026-03-25T14:25.json
│       └── ...
├── hippocampus/              # Long-term memory
│   ├── tdgs3-progress.md     # TDGS-3 tracking
│   └── episodes/            # Stored experiences (.jsonl)
└── autonomous/
    └── agent_policy.md       # Laws for all agents
```

**Agent Logging Rule**:
- Each agent writes detailed logs to `.trinity/agents/{ZONE}/HIVELOG.md`
- Each agent writes cycle summary to `.trinity/queen/HIVELOG.md` (consolidated)
- Each agent writes JSON report to `.trinity/thalamus/agent_reports/`
- Agent's zone determined by its letter (T/Q/P/H/...)

**Queen reads**:
- All `.trinity/agents/*/HIVELOG.md` for detailed per-agent status
- All `.trinity/thalamus/agent_reports/*.json` for structured data
- Writes consolidated view to `.trinity/queen/HIVELOG.md`

## Log Law — Lettered Homes

### 1. Each Agent Has a Home

Each agent writes detailed logs to its lettered home:
```
.trinity/agents/{ZONE}/HIVELOG.md
```

Where ZONE = T/Q/P/H/... (matches agent's zone letter).

### 2. Mandatory Cycle Report

After each work cycle, agent MUST:
1. Append detailed log to `.trinity/agents/{ZONE}/HIVELOG.md`
2. Append summary line to `.trinity/queen/HIVELOG.md`
3. Write JSON report to `.trinity/thalamus/agent_reports/{agent}_{timestamp}.json`

### 3. Single Source of Truth

- `.autonomous/*` is scratchpad only — NOT source of truth.
- All truth lives in `.trinity/**`:
  - Per-agent: `.trinity/agents/{ZONE}/HIVELOG.md`
  - Consolidated: `.trinity/queen/HIVELOG.md`
  - Structured: `.trinity/thalamus/agent_reports/*.json`

### 4. Queen's View

Queen parses agent homes to:
- See who's working on what (by reading `.trinity/agents/*/HIVELOG.md`)
- Detect stale/inactive agents (no recent entries)
- Aggregate swarm status into `.trinity/queen/HIVELOG.md`

## Multi-Agent Rules

### 1. One Agent — One Zone

**LAW**: Agent takes ONLY one letter-zone (T/Q/P/...) per cycle.

```json
{
  "agent": "P-agent",
  "zone": "P",
  "locks": ["src/P/**"]
}
```

### 2. Lock Rule

**Before starting**: Agent declares which files/dirs it's working on (`locks` field).

**Other agents**: Check `locks` in existing reports — avoid overlapping paths.

**Queen**: Reads all reports, prevents conflicting task assignment.

### 3. Small PRs

**RULE**: One PR = one zone max. No cross-zone changes unless explicitly a "bridge-task".

```json
{
  "agent": "H-agent",
  "zone": "H",
  "cross_zone": false,
  "files_changed": ["src/H/memory.zig", "src/H/hippocampus_api.zig"]
}
```

### 4. Mandatory Cycle Report

**After each cycle**: Agent MUST:
1. Write JSON to `.trinity/thalamus/agent_reports/`
2. Write summary to `.trinity/queen/HIVELOG.md`

**Queen reads**:
- Who's working on what (`agent`, `zone`, `locks`)
- Which zones are empty (`status: "completed"`)
- Where conflicts exist (overlapping `locks`)

## Neuroscience Analogy: 27 Cortical Columns

Each letter-zone = cortical column (microcolumn), agent = "processing unit" within it.

**Neural mapping**:
```
T-agent  = medial PFC (values, rules, TTT Seal)          — stores laws
Q-agent  = dorsolateral PFC (coordination, planning)     — meta-control
P-agent  = Brainstem (vitality, heartbeats, sleep)       — survival
H-agent  = Hippocampus (episodic memory)                — fast experience
R-agent  = Reticular (alertness, arousal)                — watch-daemon
K-agent  = Kaggle/benchmark (evaluation)                — metrics
E-agent  = Eval (scoring, validation)                   — quality gate
...      = (21 more specialized zones)
```

**Communication via Thalamus** (thalamic-cortical loops):
```
Peripheral zones → Thalamus (agent_reports/) → PFC (Queen) → back to zones
```

This mirrors:
- **Stigmergy**: Agents communicate through shared environment (files), not direct calls
- **Complementary learning**: H-agent stores fast episodes, T-agent updates slow rules
- **Meta-control**: Q-agent doesn't solve tasks, it decides WHICH specialist to activate

---

## Agent Roles by Zone

### Queen-Agent (Q-Zone)

**Responsibilities**:
- Read all agent reports from `.trinity/thalamus/agent_reports/`
- Divide TDGS-4 into zone-specific subtasks
- Assign tasks to zonal agents (via issues/CLI)
- Aggregate status in `.trinity/queen/HIVELOG.md`
- Resolve conflicts (overlapping locks)

**Does NOT touch**: Temple files (src/temple/) without TTT-UNSEAL

### T-Agent (Temple)

**Responsibilities**:
- Create/update `docs/research/ALPHABET_CANON_27.md`
- Update `.trinity/canonmap.json`
- Create `src/T/` structure (symlinks to existing)
- Write pre-commit hook for TTT Seal

**Locked files**: `src/T/**`, `docs/research/ALPHABET_CANON_27.md`, `.trinity/canonmap.json`

### Zonal Agents (P/H/R/A/B/C/D/etc.)

**Responsibilities**:
- Prepare their zone directory (`src/P`, `src/H`, etc.)
- Migrate existing files to zone
- Update imports within zone
- Fix build.zig for zone-specific rules

**Locked files**: Only `src/{ZONE}/**`

### Governance Agent

**Responsibilities**:
- Create `.trinity/` structure
- Create `.trinity/autonomous/agent_policy.md`
- Move logs from `.autonomous/` to `.trinity/`
- Create `.trinity/thalamus/agent_reports/`

**Locked files**: `.trinity/**`

## Swarm Synergy

**Example Parallel Execution**:

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  T-agent    │  │  P-agent    │  │ Gov-agent   │
│  Zone: T    │  │  Zone: P    │  │  Zone: .tri │
├─────────────┤  ├─────────────┤  ├─────────────┤
│ ALPHABET_   │  │ Move Phoenix│  │ .trinity/   │
│ CANON_27.md │  │ to src/P/   │  │ structure   │
│ canonmap    │  │ Fix imports │  │ agent_policy│
└─────────────┘  └─────────────┘  └─────────────┘
       │                 │                 │
       └─────────────────┴─────────────────┘
                         │
                  ┌──────▼──────┐
                  │ Queen-agent │
                  │ Zone: Q     │
                  ├─────────────┤
                  │ Read reports│
                  │ Assign tasks│
                  │ Resolve     │
                  │ conflicts   │
                  └─────────────┘
```

**Queen reads**:
```bash
# Queen checks locks
find .trinity/thalamus/agent_reports -name "*.json" -exec cat {} \; \
  | jq -r '.locks[]' | sort | uniq -c
```

Output shows which paths are locked → prevents double-assignment.

## Swarm Synergy: Shared Resources

### Common Temple (T-Zone) — Physics

All agents recognize `src/temple/**` as "physics of the world":
- They READ and USE it (types, VM, tri language)
- They DO NOT MODIFY without TTT-UNSEAL
- This gives **common foundation**: one type system, one VM, one language

### Thalamus as Bus — Communication

Agents write reports to `.trinity/thalamus/agent_reports/`:
- No direct inter-agent communication
- Queen reads as "sensory input" from 27 columns
- Mirrors thalamocortical loops: periphery → Thalamus → PFC → zones

### Hippocampus as Long-Term Storage

Cycle results stored in `.trinity/hippocampus/episodes/*.jsonl`:
- Any agent can READ past episodes
- Brain reuses episodic memory for future tasks
- H-agent manages fast learning; T-agent updates slow rules

### Queen as Global Moderator

Queen:
- Assigns tasks to each zone
- Tracks locks (who holds T, Q, P, etc.)
- Resolves conflicts (two agents want same file)
- Runs final checks before merge (zig build, tri t27-test, tri canon-scan)

## Starting Swarm: Core 7 Agents

For initial launch, define these core roles:

| Agent | Zone | Brain Analog | Core Tasks |
|-------|------|--------------|------------|
| **T-agent** | T | medial PFC | Create canon, seal Temple, write pre-commit hook |
| **Q-agent** | Q | dorsolateral PFC | Read reports, assign tasks, resolve conflicts |
| **P-agent** | P | Brainstem | Migrate Phoenix, fix heartbeats, sleep cycles |
| **H-agent** | H | Hippocampus | Manage episodes, store experiences, track TDGS progress |
| **R-agent** | R | Reticular | Watch-daemon, alertness, health checks |
| **K-agent** | K | (special) | Kaggle dataset, benchmark metrics |
| **E-agent** | E | (special) | Eval, scoring, validation, quality gates |

These 7 form the initial "cortical foundation". Other 20 agents can be spawned as needed.
