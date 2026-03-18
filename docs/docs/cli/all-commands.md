---
sidebar_position: 99
sidebar_label: All Commands
---

# TRI CLI — Complete Command Reference

**310+ commands across 25 groups.** Single source of truth for every `tri` subcommand.

---

## 1. tri git — Git Workflow

**File:** `src/tri/tri_commands.zig:229-326`

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri git status` | — | `git status --short` |
| `tri git diff` | — | `git diff --stat` |
| `tri git log [N]` | N=10 | Last N commits |
| `tri git branch <name>` | branch name | Create + switch branch |
| `tri git add <files>` | file1 [file2...] | Stage files (no `-A`/`.` allowed) |
| `tri git commit "<msg>"` | "type(scope): desc" | Conventional commit, auto `zig fmt` |
| `tri git push` | — | Push to origin (blocks main/master) |

**Safety:** Conventional commit format enforced. Force-push to main blocked.

---

## 2. tri issue — GitHub Issues

**File:** `src/tri/github_commands.zig:61-87`

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri issue list` | — | List open issues |
| `tri issue view <N>` | issue number | View issue details |
| `tri issue create "<title>"` | title, --body | Create issue |
| `tri issue comment <N>` | issue, --body | Add comment |
| `tri issue close <N>` | issue number | Close issue |
| `tri issue assign <N>` | issue, --assignee | Assign issue |
| `tri issue decompose <N>` | issue number | Break into sub-issues |

---

## 3. tri farm — Training Farm

**File:** `src/tri/tri_farm.zig`

Manages Railway training farm across 3 accounts (PRIMARY, FARM-2, FARM-3), up to 75 services total.

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri farm status` | — | All services across 3 accounts with status icons |
| `tri farm idle` | — | Show finished/idle services |
| `tri farm recycle` | `[options]` | Set training vars + redeploy idle/crashed |
| `tri farm fill` | `[options]` | Create NEW services to fill empty slots |
| `tri farm evolve` | — | ASHA+PBT evolution step |

### Options (recycle & fill)

| Option | Default | Description |
|--------|---------|-------------|
| `--lr <value>` | `3e-4` | Learning rate |
| `--batch <value>` | `128` | Batch size |
| `--ctx <value>` | `81` | Context length |
| `--optimizer <type>` | `lamb` | lamb/adamw/adam |
| `--warmup <value>` | `2000` | Warmup steps |
| `--wd <value>` | `0.01` | Weight decay |
| `--steps <value>` | `100000` | Total steps |
| `--include-primary` | off | Include PRIMARY account |

### Additional fill options

| Option | Default | Description |
|--------|---------|-------------|
| `--max <N>` | `37` | Max new services |
| `--dry-run` | off | Preview without creating |

**Env:** `RAILWAY_TOKEN`, `RAILWAY_TOKEN_2`, `RAILWAY_TOKEN_3`

---

## 4. tri cloud — Cloud Orchestration

**File:** `src/tri/tri_cloud.zig`

Native Railway integration + Cloud Dev agent orchestration.

### Infrastructure

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri cloud status` | — | Railway services + SSH status |
| `tri cloud logs [service]` | service name | Deployment logs via GraphQL |
| `tri cloud vars [service]` | service name or `set K=V [id]` | List/set env vars |
| `tri cloud deploy [service]` | service id | Trigger redeployment |
| `tri cloud redeploy` | — | Manual redeploy |
| `tri cloud restart [service]` | service id | Restart service |
| `tri cloud delete-service <id>` | service id | Delete service (DESTRUCTIVE) |

### SSH & Remote

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri cloud exec <command>` | command string | Run via SSH |
| `tri cloud pull` | — | Pull code on Railway |
| `tri cloud ssh-status` | — | SSH server status |
| `tri cloud tmux` | — | Tmux session control |

### Agent Containers

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri cloud spawn <N>` | issue number, --account | Spawn agent container |
| `tri cloud spawn-all` | — | Spawn for all agent:spawn issues |
| `tri cloud kill <N>` | issue number | Kill agent container |
| `tri cloud agents` | — | List active agents (max 10) |
| `tri cloud cleanup` | — | Remove finished containers |
| `tri cloud sync` | — | Reconcile Railway state |
| `tri cloud history <N>` | issue number | Event timeline |

### Diagnostics

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri cloud api-check` | — | Test API key + model routing |
| `tri cloud diagnose` | — | Diagnose Railway issues |
| `tri cloud metrics` | — | Aggregate fitness metrics |
| `tri cloud record-metrics` | — | Record metrics |
| `tri cloud monitor` | — | Live monitoring dashboard |
| `tri cloud metal` | — | Metal infrastructure status |

### Delegation

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri cloud farm` | — | Delegates to `tri farm` |
| `tri cloud train` | — | Training-specific commands |
| `tri cloud train-batch` | — | Batch training operations |
| `tri cloud bridge` | — | Bridge protocol commands |
| `tri cloud issue-create` | — | Create GitHub issue |
| `tri cloud pipeline` | — | Pipeline orchestration |
| `tri cloud verify` | — | Verify agent work |
| `tri cloud merge` | — | Merge agent PR |

**Env:** `RAILWAY_TOKEN`, `AGENT_GH_TOKEN`

---

## 5. tri dev — SWE Agent Farm

**File:** `src/tri/tri_dev.zig`

Each GitHub issue = 1 Railway service = 1 autonomous Claude Code agent.

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri dev status` | — | Table of all dev agents |
| `tri dev spawn <N>` | issue number | Spawn agent for issue |
| `tri dev kill <N>` | issue number | Kill agent |
| `tri dev recycle` | — | Reassign idle agents |
| `tri dev fill` | — | Spawn for all agent:dev issues |
| `tri dev metrics` | — | Aggregate fitness metrics |
| `tri dev leaderboard` | — | Rank agents by fitness |
| `tri dev evolve` | — | ASHA+PBT evolution step |
| `tri dev scan` | — | Scan for new work |
| `tri dev pick` | — | Pick next task |

---

## 6. tri train — HSLM Training

**File:** `src/tri/tri_train.zig`

Monitor and control HSLM training runs (local + Railway).

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri train status` | `[--json] [--host railway]` | Live dashboard or JSON |
| `tri train start` | `[options] [--host railway]` | Launch training |
| `tri train logs` | `[--host railway]` | Tail training logs |
| `tri train loss [dir]` | checkpoint dir | Parse loss curve |
| `tri train diagnose [dir]` | checkpoint dir | Auto-diagnose anomalies |
| `tri train compare <d1> <d2>` | two dirs | Side-by-side comparison |
| `tri train checkpoint list [dir]` | checkpoint dir | List checkpoints |

### Options for `tri train start`

| Option | Default | Description |
|--------|---------|-------------|
| `--steps <N>` | `100000` | Total steps |
| `--lr <value>` | `3e-4` local / `1e-4` railway | Learning rate |
| `--warmup <N>` | `5000` | Warmup steps |
| `--batch <N>` | `64` | Batch size |
| `--optimizer <type>` | `adamw` | adamw/lamb |
| `--ste <mode>` | `none` | none/vanilla/twn/progressive |
| `--wd <value>` | `0.1` | Weight decay |
| `--checkpoint-dir <path>` | `data/checkpoints` | Checkpoint directory |
| `--resume <path>` | — | Resume from checkpoint |
| `--data <path>` | `data/tinystories/real_tinystories.txt` | Data file |
| `--grad-accum <N>` | `1` | Gradient accumulation |
| `--context <N>` | `81` | Context length |

**Env:** `HSLM_OPTIMIZER`, `HSLM_LR`, `HSLM_LR_SCHEDULE` (ALWAYS cosine)

---

## 7. tri loop — Autonomous Dev Loop

**File:** `src/tri/tri_loop.zig`

Ralph pattern: wake → scan → decide → act → report → sleep.

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri loop` | — | Single iteration (default) |
| `tri loop once` | — | Single iteration |
| `tri loop step` | — | Alias for once |
| `tri loop status` | — | Show last loop state |
| `tri loop continuous` | `[-i <seconds>]` | Run continuously (default 5min) |
| `tri loop daemon` | — | Alias for continuous |
| `tri loop retry` | `[options]` | Build-test-retry with experience |

### Options for `tri loop retry`

| Option | Default | Description |
|--------|---------|-------------|
| `--issue <N>` | — | GitHub issue for progress |
| `--max-iter <N>` | `10` | Max iterations |
| `--task "<desc>"` | — | Task description |

---

## 8. tri research — Scholar Agent

**File:** `src/tri/tri_research.zig`

Web research, error analysis, code quality verification.

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri research "<query>"` | search query | Web research via Perplexity |
| `tri research explain "<error>"` | error message | Offline error analysis |
| `tri research --cache` | — | Show cached answers |
| `tri research idempotency` | — | 100-cycle idempotency audit |
| `tri research idem` | — | Alias |
| `tri research duplication` | — | Code duplication scan |
| `tri research dup` | — | Alias |
| `tri research sacred` | — | Sacred constants verification |
| `tri research constants` | — | Alias |

**Env:** `PERPLEXITY_API_KEY` (optional, offline analysis works without it)

---

## 9. tri experiment — Experiment Tracking

**File:** `src/tri/tri_experiment.zig`

HSLM experiment visualization and leaderboard.

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri experiment chart [dirs...]` | checkpoint dirs | ASCII PPL vs Step chart |
| `tri experiment list [dirs...]` | checkpoint dirs | Leaderboard by best PPL |
| `tri experiment compare <d1> <d2>` | two dirs | Side-by-side comparison |
| `tri experiment export` | — | Generate docs/EXPERIMENTS.md |

Auto-scans: `data/checkpoints`, `data/checkpoints/real`, `data/checkpoints_v3`, `data/checkpoints_v13_lamb128`

---

## 10. tri zenodo — Academic Publishing

**File:** `src/tri/tri_zenodo.zig`

DOI publishing to Zenodo.

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri zenodo publish <version>` | version tag | Create, upload, publish |
| `tri zenodo status` | — | Show current record |
| `tri zenodo draft <version>` | version tag | Create draft only |

**Env:** `ZENODO_TOKEN`

---

## 11. tri job — Async Job System

**File:** `src/tri/tri_job.zig`

Long-running commands with status tracking.

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri job start <command>` | command + args | Start async job |
| `tri job status <id>` | job id | Check status |
| `tri job logs <id>` | job id | Get stdout/stderr |
| `tri job artifacts <id>` | job id | Collect outputs |
| `tri job cancel <id>` | job id | Cancel running job |
| `tri job list` | — | List all jobs |

---

## 12. tri experience — Memory & Learning

**File:** `src/tri/tri_experience.zig`

Episode storage + mistake patterns + ExpeL log.

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri experience save` | `[options]` | Save episode |
| `tri experience recall` | `--task/--type/--category` | Recall episodes |
| `tri experience mistakes` | — | Show mistakes by frequency |

### Options for `tri experience save`

| Option | Default | Description |
|--------|---------|-------------|
| `--issue <N>` | — | GitHub issue |
| `--task "<desc>"` | required | Task description |
| `--verdict <v>` | UNKNOWN | PASS/FAIL/PARTIAL |
| `--iterations <N>` | 1 | Iteration count |
| `--mistake "<text>"` | — | Add mistake (up to 8) |
| `--learning "<text>"` | — | Add learning (up to 8) |

---

## 13. tri faculty — Agent Faculty Board

**File:** `src/tri/faculty_board.zig`

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri faculty` | — | Compact board |
| `tri faculty full` | — | Full detailed board |
| `tri faculty --raw` | — | Raw JSON output |
| `tri faculty --lang ru/en` | — | Override language |

---

## 14. tri fpga — FPGA Synthesis & Inference

**File:** `src/tri/tri_register.zig`

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri fpga status` | — | FPGA device status |
| `tri fpga build` | — | Build FPGA project |
| `tri fpga synth` | — | Run synthesis |
| `tri fpga flash` | — | Flash bitstream |
| `tri fpga verify` | — | Verify bitstream |
| `tri fpga uart` | — | UART test |
| `tri fpga snap` | — | Snapshot state |
| `tri fpga eye` | — | Eye diagram |
| `tri fpga infer` | — | Ternary inference on FPGA |

**Hardware:** Xilinx 7-series, 135 BRAM36-eq, 0 DSP, 5000 tok/s

---

## 15. tri doctor — Pipeline Health

**File:** `src/tri/tri_commands.zig:1706`

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri doctor` | — | One-line health status |
| `tri doctor init` | — | Scan + mark + report |
| `tri doctor scan` | — | Classify all .zig files |
| `tri doctor mark` | — | Add @origin/@regen markers |
| `tri doctor report` | — | Health dashboard |
| `tri doctor plan` | — | Create migration queue |
| `tri doctor heal` | — | Regenerate via pipeline |
| `tri doctor enforce` | — | Hook setup instructions |
| `tri doctor enforce-check` | — | Hook permit/deny binary |

**Health:** `100 × (0.4×generated + 0.3×compliance + 0.2×specs + 0.1×tests)`
90+ HEALTHY | 70-89 RECOVERING | 50-69 INFECTED | 0-49 CRITICAL

---

## 16. tri notify — Telegram

**File:** `src/tri/tri_commands.zig:393`

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri notify "<message>"` | message text | Send notification |
| `tri notify "<msg>" --pin` | — | Send and pin |
| `tri notify "<msg>" --chat <id>` | chat id | Send to specific chat |
| `tri notify "<msg>" --edit <id>` | message id | Edit existing message |

**Env:** `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`

---

## 17. tri deploy — Railway Deployment

**File:** `src/tri/tri_commands.zig:365`

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri deploy push` | — | Deploy to Railway |
| `tri deploy status` | — | Deployment status |
| `tri deploy logs` | — | Deployment logs |
| `tri deploy domain` | — | Domain management |

**Env:** `RAILWAY_TOKEN`

---

## 18. tri gen — Code Generation

**File:** `src/tri/tri_commands.zig:40-100`

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri gen <spec.tri>` | spec path | Generate Zig/Verilog from .tri spec |

---

## 19. tri convert — Format Conversion

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri convert <from> <to>` | format pair | Convert: b2t, wasm, gguf |

---

## 20. tri serve — HTTP Server

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri serve [options]` | — | Start HTTP server + API gateway |

---

## 21. tri bench — Benchmarks

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri bench` | — | VSA/network benchmarks |

---

## 22. tri evolve — Self-Improvement

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri evolve [N]` | iterations (default 10) | Self-improvement analysis |

---

## AI & Chat (5 commands)

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri chat` | `[--stream]` | Interactive chat |
| `tri code` | `[--stream]` | Code generation |
| `tri fix <file>` | file path | Bug detection + fix |
| `tri explain <file>` | file path | Explain code |
| `tri reason <prompt>` | prompt | Chain-of-thought |

---

## Sacred Math (8 commands)

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri math` | — | Sacred math dispatcher |
| `tri constants` | — | Show phi, pi, e, mu, chi, sigma, epsilon |
| `tri phi <N>` | exponent | Compute phi^N |
| `tri fib <N>` | index | Fibonacci with BigInt |
| `tri lucas <N>` | index | Lucas L(N) — L(2)=3=TRINITY |
| `tri spiral <N>` | index | Phi-spiral coordinates |
| `tri gematria <text>` | text | Calculate gematria value |
| `tri sacred` | — | Sacred mathematics overview |

---

## Sacred Science (25 commands)

### Biology
| Command | Description |
|---------|-------------|
| `tri bio dna` | DNA sequence analysis |
| `tri bio rna` | RNA sequence analysis |
| `tri bio protein` | Protein structure |
| `tri bio codon` | Codon lookup |

### Cosmology
| Command | Description |
|---------|-------------|
| `tri cosmos hubble` | Hubble tension via phi |
| `tri cosmos dark` | Dark energy pi-patterns |
| `tri cosmos expand` | Universe expansion |

### Neuroscience
| Command | Description |
|---------|-------------|
| `tri neuro waves` | Brain wave patterns |
| `tri neuro consciousness` | Psi consciousness formula |
| `tri neuro regions` | Brain regions mapping |
| `tri neuro network` | Neural network phi-patterns |

### Music (8 commands)
| Command | Description |
|---------|-------------|
| `tri music` | Music theory analysis |
| `tri frequency` | Frequency to note |
| `tri scale` | Scale construction |
| `tri chord` | Chord analysis |
| `tri resonance` | Resonance patterns |
| `tri waveform` | Waveform visualization |
| `tri harmony` | Harmonic analysis |
| `tri phi-series` | Phi-based music series |

---

## Development Tools (20+ commands)

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri test <file>` | file path | Generate tests |
| `tri doc <file>` | file path | Generate docs |
| `tri refactor <file>` | file path | Suggest refactoring |
| `tri analyze` | — | Analyze codebase |
| `tri search <query>` | query | Search code |
| `tri context-info` | — | Context information |
| `tri clean` | — | Clean build artifacts |
| `tri fmt` | — | Format code |
| `tri stats` | — | Project statistics |
| `tri igla` | — | IGLA hybrid operations |

---

## Pipeline — Golden Chain (8 commands)

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri pipeline run "<task>"` | task description | Execute full Golden Chain |
| `tri pipeline demo` | — | Demo pipeline run |
| `tri decompose "<task>"` | task | Break into sub-tasks |
| `tri plan "<task>"` | task | Generate implementation plan |
| `tri spec-create "<name>"` | name | Create .tri spec template |
| `tri loop-decide` | — | Loop decision: CONTINUE/EXIT |
| `tri verify` | — | Run tests + benchmarks |
| `tri verdict` | — | Generate toxic verdict |

---

## Swarm (6+ commands)

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri swarm` | — | Swarm status |
| `tri govern` | — | Governance |
| `tri omega` | — | Omega convergence |
| `tri quantum` | — | Quantum operations |
| `tri conscious` | — | Consciousness formula |
| `tri identity` | — | Identity affirmation |
| `tri intelligence` | — | Intelligence metrics |

---

## System (12 commands)

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri info` | — | System information |
| `tri version` | — | Show version |
| `tri help` | `[--category] [--search]` | Show commands |
| `tri deps` | — | List dependencies |
| `tri tvc-stats` | — | TVC corpus statistics |
| `tri distributed` | — | Distributed inference |
| `tri multi-cluster` | — | Multi-cluster management |
| `tri hardware` | — | Hardware info |
| `tri time` | — | Time utilities |
| `tri install` | — | Installation utilities |
| `tri build` | — | Build utilities |

---

## Demos (37 commands)

```
tvc-demo, agents-demo, context-demo, rag-demo, voice-demo,
sandbox-demo, stream-demo, vision-demo, finetune-demo,
batched-demo, priority-demo, deadline-demo, multimodal-demo,
tooluse-demo, unified-demo, autonomous-demo, orchestration-demo,
mm-orch-demo, memory-demo, persist-demo, spawn-demo,
cluster-demo, worksteal-demo, plugin-demo, comms-demo,
observe-demo, consensus-demo, specexec-demo, governor-demo,
fedlearn-demo, eventsrc-demo, capsec-demo, dtxn-demo,
cache-demo, contract-demo, workflow-demo, fpga-demo,
sacred-full-cycle
```

---

## Benchmarks (36 commands)

```
agents-bench, context-bench, rag-bench, voice-bench,
sandbox-bench, stream-bench, vision-bench, finetune-bench,
batched-bench, priority-bench, deadline-bench, multimodal-bench,
tooluse-bench, unified-bench, autonomous-bench, orchestration-bench,
mm-orch-bench, memory-bench, persist-bench, spawn-bench,
cluster-bench, worksteal-bench, plugin-bench, comms-bench,
observe-bench, consensus-bench, specexec-bench, governor-bench,
fedlearn-bench, eventsrc-bench, capsec-bench, dtxn-bench,
cache-bench, contract-bench, workflow-bench
```

---

## DePIN (4 commands)

| Command | Description |
|---------|-------------|
| `tri wallet` | Wallet management |
| `tri mesh` | Mesh networking |
| `tri reputation` | Reputation system |
| `tri hardware` | Hardware registration |

---

## 23. tri chimera — Fused Multi-Step Commands

**File:** `src/tri/tri_chimera.zig`

| Command | Steps | Description |
|---------|-------|-------------|
| `tri chimera farm-cycle` | 4 | status → idle → recycle → evolve |
| `tri chimera train-cycle` | 5 | status → loss → diagnose → chart → leaderboard |
| `tri chimera deploy-full` | 5 | commit → push → deploy → verify → notify |
| `tri chimera doctor-full` | 4 | scan → mark → report → heal |
| `tri chimera research-deep` | 4 | query → recall → idempotency → dedup |

---

## 24. tri agent run — Flagship Autonomous Cycle

**File:** `src/tri/tri_agent_run.zig`

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri agent run <N>` | issue number | 8-step: view → recall → spec → gen → verify → verdict → save → commit |

---

## 25. tri depin — DePIN Node Protocol

**File:** `src/tri/tri_depin.zig`

| Command | Arguments | Description |
|---------|-----------|-------------|
| `tri depin status` | — | Network overview dashboard |
| `tri depin nodes` | — | List all nodes with type/status |
| `tri depin fitness` | — | Aggregate fitness by node type |

---

## Critical Rules

1. **ALWAYS** `tri <cmd>` — no direct git/gh/curl
2. Conventional commits: `type(scope): message`
3. NO force-push to main
4. NO `git add .` or `git add -A`
5. Schedule = ALWAYS cosine (never flat)
6. 3 Railway accounts: PRIMARY, FARM-2, FARM-3
7. Max 10 concurrent agents
8. GitHub issue tracking mandatory
