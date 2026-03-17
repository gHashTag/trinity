# CLI ↔ MCP Mirror Mapping

Complete mapping between CLI commands (`tri <group> <subcommand>`) and MCP tools.

**Goal**: Every CLI command has an MCP mirror. Every MCP tool maps to a CLI command.

## Status Legend

- ✅ = MCP tool exists and maps to CLI command
- ❌ = CLI command has no MCP mirror yet
- 🔲 = MCP-only tool (no CLI equivalent, computed in-process)

---

## Core Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri <command>` | `tri_execute` | ✅ |
| `tri code <prompt>` | `tri_code` | ✅ |
| `tri gen <spec>` | `tri_gen` | ✅ |
| `tri spec-create <name>` | `tri_spec_create` | ✅ |
| `tri decompose <task>` | `tri_decompose` | ✅ |
| `tri plan <task>` | `tri_plan` | ✅ |
| `tri verify` | `tri_verify` | ✅ |
| `tri bench [suite]` | `tri_bench` | ✅ |
| `tri verdict` | `tri_verdict` | ✅ |
| `tri test <file>` | `tri_test` | ✅ |
| `tri test [pattern]` | `tri_test_run` | ✅ |
| `tri fix <file>` | `tri_fix` | ✅ |
| `tri explain <target>` | `tri_explain` | ✅ |
| `tri refactor <file>` | `tri_refactor` | ✅ |
| `tri doc <file>` | `tri_doc` | ✅ |
| `tri reason <prompt>` | `tri_reason` | ✅ |
| `tri notify <text>` | `tri_notify` | ✅ |
| `tri pipeline <task>` | `tri_pipeline` | ✅ |
| `tri chat <msg>` | `tri_chat` | ✅ |

## Git Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri git status` | `tri_status` | ✅ |
| `tri git diff` | `tri_diff` | ✅ |
| `tri git log` | `tri_log` | ✅ |
| `tri git commit <msg>` | `tri_commit` | ✅ |

## Doctor Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri doctor` | `doctor_status` | ✅ |
| `tri doctor scan` | `doctor_scan` | ✅ |
| `tri doctor report` | `doctor_report` | ✅ |
| `tri doctor plan` | `doctor_plan` | ✅ |
| `tri doctor heal` | `doctor_heal` | ✅ |
| `tri doctor init` | — | ❌ |
| `tri doctor enforce` | — | ❌ |
| `tri doctor enforce-check` | — | ❌ |
| `tri doctor mark` | — | ❌ |

## Job Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri job start <cmd>` | `job_start` | ✅ |
| `tri job status [id]` | `job_status` | ✅ |
| `tri job logs [id]` | `job_logs` | ✅ |
| `tri job list` | `job_list` | ✅ |
| `tri job cancel <id>` | `job_cancel` | ✅ |
| `tri job artifacts <id>` | `job_artifacts` | ✅ |

## Issue Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri issue list` | `issue_list` | ✅ |
| `tri issue view <N>` | `issue_view` | ✅ |
| `tri issue create <title>` | `issue_create` | ✅ |
| `tri issue comment <N> <body>` | `issue_comment` | ✅ |
| `tri issue close <N>` | `issue_close` | ✅ |
| `tri issue assign <N> <user>` | `issue_assign` | ✅ |
| `tri issue decompose <N>` | `issue_decompose` | ✅ |

## Deploy Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri deploy status` | `deploy_status` | ✅ |
| `tri deploy logs` | `deploy_logs` | ✅ |
| `tri deploy vars` | `deploy_vars` | ✅ |
| `tri deploy start` | `deploy_start` | ✅ |
| `tri deploy stop` | `deploy_stop` | ✅ |

## Experience Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri experience save <k> <v>` | `experience_save` | ✅ |
| `tri experience recall <k>` | `experience_recall` | ✅ |
| `tri experience mistakes` | `experience_mistakes` | ✅ |

## FPGA Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri fpga uart scan` | `fpga_uart_scan` | ✅ |
| `tri fpga uart ping` | `fpga_uart_ping` | ✅ |
| `tri fpga uart send <hex>` | `fpga_uart_send` | ✅ |
| `tri fpga synth` | `fpga_synth` | ✅ |
| `tri fpga status` | `fpga_status` | ✅ |
| `tri fpga build` | `fpga_build` | ✅ |
| `tri fpga verify` | `fpga_verify` | ✅ |
| `tri fpga flash <bit>` | `fpga_flash` | ✅ |

## Cloud Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri cloud spawn <N>` | `cloud_spawn` | ✅ |
| `tri cloud kill <N>` | `cloud_kill` | ✅ |
| `tri cloud agents` | `cloud_list` | ✅ |
| `tri cloud status` | `cloud_status` | ✅ |
| `tri cloud logs` | `cloud_logs` | ✅ |
| `tri cloud spawn-all` | `cloud_spawn_all` | ✅ |
| `tri cloud cleanup` | `cloud_cleanup` | ✅ |
| `tri cloud history [N]` | `cloud_history` | ✅ |
| `tri cloud api-check` | `cloud_api_check` | ✅ |
| `tri cloud redeploy <sid> <N>` | `cloud_redeploy` | ✅ |
| `tri cloud diagnose <N>` | `cloud_diagnose` | ✅ |
| `tri cloud issue-create <t>` | `cloud_issue_create` | ✅ |
| `tri cloud farm` | `cloud_farm` | ✅ |
| `tri cloud farm sync` | `cloud_farm_sync` | ✅ |
| `tri cloud farm capacity` | `cloud_farm_capacity` | ✅ |
| `tri cloud farm rebalance` | `cloud_farm_rebalance` | ✅ |
| `tri cloud train <name>` | `cloud_train` | ✅ |
| `tri cloud train-batch` | `cloud_train_batch` | ✅ |

## Farm Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri farm status` | `farm_status` | ✅ |
| `tri farm idle` | `farm_idle` | ✅ |
| `tri farm recycle` | `farm_recycle` | ✅ |
| `tri farm fill` | `farm_fill` | ✅ |
| `tri farm evolve status` | `farm_evolve_health` | ✅ |
| `tri farm evolve notify` | `farm_evolve_notify` | ✅ |
| `tri farm evolve watch` | `farm_evolve_watch` | ✅ |

## Patent Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri patent status` | `patent_status` | ✅ |
| `tri patent analysis` | `patent_analysis` | ✅ |
| `tri patent claims` | — | ❌ |
| `tri patent strategy` | — | ❌ |
| `tri patent snapshot` | — | ❌ |
| `tri patent draft` | — | ❌ |
| `tri patent zenodo` | — | ❌ |

## DePIN Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri depin status` | `depin_status` | ✅ |
| `tri depin nodes` | `depin_nodes` | ✅ |
| `tri depin fitness` | `depin_fitness` | ✅ |

## Research / Experiment Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri research <query>` | `research_query` | ✅ |
| `tri experiment list` | `experiment_list` | ✅ |
| `tri experiment compare <a> <b>` | `experiment_compare` | ✅ |

## Chimera Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri chimera <name>` | `chimera_run` | ✅ |

## Ouroboros Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri ouroboros status` | `ouroboros_status` | ✅ |
| `tri ouroboros run` | `ouroboros_run` | ✅ |

## Self Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri self test` | `self_test` | ✅ |
| `tri self health` | `self_health` | ✅ |

## Context Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri context info` | `context_info` | ✅ |
| `tri context load <path>` | `context_load` | ✅ |

## Faculty / MU Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri faculty` | `faculty_status` | ✅ |
| `tri mu status` | `mu_status` | ✅ |
| `tri mu patterns` | `mu_patterns` | ✅ |

## Zenodo Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri zenodo status` | `zenodo_status` | ✅ |

## Utility Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri analyze` | `tri_analyze` | ✅ |
| `tri clean` | `tri_clean` | ✅ |
| `tri fmt` | `tri_fmt` | ✅ |
| `tri stats` | `tri_stats` | ✅ |
| `tri lint` | `tri_lint` | ✅ |
| `tri search <query>` | `tri_search` | ✅ |
| `tri metrics` | `tri_metrics` | ✅ |
| `tri trace` | `tri_trace` | ✅ |
| `tri eval` | `tri_eval` | ✅ |

## Chain Commands

| CLI Command | MCP Tool | Status |
|-------------|----------|--------|
| `tri chain` | `chain_list` | ✅ |
| `tri chain <link> --task <t>` | `chain_<link>` | ✅ (all 26) |

## MCP-Only Tools (no CLI equivalent)

| MCP Tool | Description |
|----------|-------------|
| `needle_*` (20 tools) | AST-aware editing (in-process, no CLI) |
| `swarm_*` (14 tools) | Agent swarm state machine (in-process) |
| `oracle_*` (3 tools) | Telegram watchdog (in-process thread) |
| `tri_train_*` (5 tools) | Training monitor (reads checkpoints directly) |
| `tri_constants/phi/fib/lucas` | Sacred math (computed in-process) |
| `tri_chem_*/bio_*/quantum_*` | Science tools (computed in-process) |
| `tri_formula` | Sacred formula evaluator (in-process) |

---

## Summary

| Category | CLI Commands | MCP Tools | Coverage |
|----------|-------------|-----------|----------|
| Core | 19 | 19 | 100% |
| Git | 4 | 4 | 100% |
| Doctor | 8 | 5 | 63% |
| Job | 6 | 6 | 100% |
| Issue | 7 | 7 | 100% |
| Deploy | 5 | 5 | 100% |
| Experience | 3 | 3 | 100% |
| FPGA | 8 | 8 | 100% |
| Cloud | 18 | 18 | 100% |
| Farm | 7 | 7 | 100% |
| Patent | 7 | 2 | 29% |
| DePIN | 3 | 3 | 100% |
| Research | 1 | 1 | 100% |
| Experiment | 2 | 2 | 100% |
| Chimera | 1 | 1 | 100% |
| Ouroboros | 2 | 2 | 100% |
| Self | 2 | 2 | 100% |
| Context | 2 | 2 | 100% |
| Faculty/MU | 3 | 3 | 100% |
| Zenodo | 1 | 1 | 100% |
| Utility | 9 | 9 | 100% |
| Chain | 27 | 27 | 100% |
| **Mapped Total** | **~145** | **~137** | **~94%** |
| MCP-only | — | ~58 | — |
| **Grand Total** | **~145** | **~195** | — |

### Remaining Gaps (❌)

| CLI Command | Priority | Notes |
|-------------|----------|-------|
| `tri doctor init` | Low | Combines scan + mark + report |
| `tri doctor enforce` | Low | Setup instructions only |
| `tri doctor enforce-check` | Low | Hook binary |
| `tri doctor mark` | Low | Add markers to files |
| `tri patent claims` | Medium | Claims listing |
| `tri patent strategy` | Medium | Strategy overview |
| `tri patent snapshot` | Low | Create snapshot |
| `tri patent draft` | Medium | Draft generation |
| `tri patent zenodo` | Low | Zenodo upload |

These can be added via `tri_execute` universal executor as a fallback.
