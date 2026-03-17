# MCP Tools Reference

Complete reference for all Trinity MCP server tools, organized by group.

## Tool Groups Overview

| Group | Tools | Description |
|-------|-------|-------------|
| tri_* (core) | 20 | Core CLI commands (execute, gen, test, commit, etc.) |
| needle_* | 20 | AST-aware code editing, search, refactoring |
| swarm_* | 14 | Agent swarm management |
| cloud_* | 16 | Cloud infrastructure + farm management |
| chain_* | 27 | Golden Chain pipeline links |
| fpga_* | 8 | FPGA synthesis, UART, flash |
| doctor_* | 5 | Health/doctor system |
| job_* | 6 | Background job management |
| issue_* | 7 | GitHub issue management |
| deploy_* | 5 | Deployment management |
| experience_* | 3 | Experience/learning system |
| patent_* | 2 | Patent portfolio |
| depin_* | 3 | DePIN node protocol |
| research_* | 1 | Research queries |
| experiment_* | 2 | Training experiments |
| chimera_* | 1 | Fused commands |
| ouroboros_* | 2 | Self-evolution |
| self_* | 2 | Self-test/health |
| context_* | 2 | Context management |
| faculty_* | 1 | Faculty Board |
| mu_* | 2 | MU agent |
| zenodo_* | 1 | Zenodo publishing |
| farm_* | 7 | Training farm management |
| oracle_* | 3 | Telegram watchdog |
| tri_train_* | 5 | Training monitor |
| **Total** | **~195** | |

---

## Core Tools (tri_*)

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `tri_execute` | `tri <command> [args]` | Universal executor — run ANY tri command |
| `tri_code` | `tri code <prompt>` | Generate code with typing effect |
| `tri_gen` | `tri gen <spec>` | Compile VIBEE spec to Zig/Verilog |
| `tri_spec_create` | `tri spec-create <name>` | Create new .tri specification template |
| `tri_decompose` | `tri decompose <task>` | Break task into sub-tasks |
| `tri_plan` | `tri plan <task>` | Generate implementation plan |
| `tri_verify` | `tri verify` | Run tests + benchmarks |
| `tri_bench` | `tri bench [suite]` | Run performance benchmarks |
| `tri_verdict` | `tri verdict` | Generate toxic verdict |
| `tri_test` | `tri test <file>` | Generate tests for code |
| `tri_test_run` | `tri test [pattern]` | Run specific test suite |
| `tri_fix` | `tri fix <file>` | Detect and fix bugs |
| `tri_explain` | `tri explain <target>` | Explain code or concept |
| `tri_refactor` | `tri refactor <file>` | Suggest refactoring |
| `tri_doc` | `tri doc <file>` | Generate documentation |
| `tri_reason` | `tri reason <prompt>` | Chain-of-thought reasoning |
| `tri_status` | `tri git status` | Git status --short |
| `tri_diff` | `tri git diff` | Git diff |
| `tri_log` | `tri git log` | Git log --oneline |
| `tri_commit` | `tri git commit <msg>` | Git add -A && commit |
| `tri_notify` | `tri notify <text>` | Send Telegram message |
| `tri_pipeline` | `tri pipeline <task>` | Execute Golden Chain pipeline |
| `tri_chat` | `tri chat <msg>` | Interactive chat |

## Utility Tools (tri_*)

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `tri_analyze` | `tri analyze` | Analyze codebase quality |
| `tri_clean` | `tri clean` | Clean build artifacts |
| `tri_fmt` | `tri fmt` | Format all Zig source files |
| `tri_stats` | `tri stats` | Project statistics (LOC, files) |
| `tri_lint` | `tri lint` | Run linter |
| `tri_search` | `tri search <query>` | Search codebase |
| `tri_metrics` | `tri metrics` | Project metrics dashboard |
| `tri_trace` | `tri trace` | Execution trace |
| `tri_eval` | `tri eval` | Evaluate expression |

## Doctor Tools (doctor_*)

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `doctor_status` | `tri doctor` | One-line health status |
| `doctor_scan` | `tri doctor scan` | Classify all .zig files |
| `doctor_report` | `tri doctor report` | Health score dashboard |
| `doctor_plan` | `tri doctor plan` | Create migration queue |
| `doctor_heal` | `tri doctor heal` | Regenerate manual files |

## Job Tools (job_*)

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `job_start` | `tri job start <cmd>` | Start a background job |
| `job_status` | `tri job status [id]` | Get job status |
| `job_logs` | `tri job logs [id]` | Get job logs |
| `job_list` | `tri job list` | List all background jobs |
| `job_cancel` | `tri job cancel <id>` | Cancel a running job |
| `job_artifacts` | `tri job artifacts <id>` | Get job artifacts |

## Issue Tools (issue_*)

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `issue_list` | `tri issue list` | List open GitHub issues |
| `issue_view` | `tri issue view <N>` | View specific issue |
| `issue_create` | `tri issue create <title>` | Create new issue |
| `issue_comment` | `tri issue comment <N> <body>` | Add comment |
| `issue_close` | `tri issue close <N>` | Close issue |
| `issue_assign` | `tri issue assign <N> <user>` | Assign user |
| `issue_decompose` | `tri issue decompose <N>` | Decompose into sub-tasks |

## Deploy Tools (deploy_*)

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `deploy_status` | `tri deploy status` | Deployment status |
| `deploy_logs` | `tri deploy logs` | Deployment logs |
| `deploy_vars` | `tri deploy vars` | Environment variables |
| `deploy_start` | `tri deploy start` | Start deployment |
| `deploy_stop` | `tri deploy stop` | Stop deployment |

## Experience Tools (experience_*)

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `experience_save` | `tri experience save <key> <value>` | Save learning |
| `experience_recall` | `tri experience recall <key>` | Recall by key |
| `experience_mistakes` | `tri experience mistakes` | List anti-patterns |

## FPGA Tools (fpga_*)

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `fpga_uart_scan` | `tri fpga uart scan` | Scan USB-UART devices |
| `fpga_uart_ping` | `tri fpga uart ping` | PING/PONG test |
| `fpga_uart_send` | `tri fpga uart send <hex>` | Send raw hex bytes |
| `fpga_synth` | `tri fpga synth` | Run synthesis pipeline |
| `fpga_status` | `tri fpga status` | Hardware status |
| `fpga_build` | `tri fpga build` | Build bitstream |
| `fpga_verify` | `tri fpga verify` | Verify bitstream |
| `fpga_flash` | `tri fpga flash <bit>` | Flash to board |

## Cloud Tools (cloud_*)

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `cloud_spawn` | `tri cloud spawn <N>` | Spawn agent container |
| `cloud_kill` | `tri cloud kill <N>` | Kill agent container |
| `cloud_list` | `tri cloud agents` | List active containers |
| `cloud_status` | `tri cloud status` | Infrastructure status |
| `cloud_logs` | `tri cloud logs` | Agent logs |
| `cloud_spawn_all` | `tri cloud spawn-all` | Spawn for all agent:spawn issues |
| `cloud_cleanup` | `tri cloud cleanup` | Remove inactive entries |
| `cloud_history` | `tri cloud history [N]` | Event history |
| `cloud_api_check` | `tri cloud api-check` | Test API connectivity |
| `cloud_redeploy` | `tri cloud redeploy <sid> <N>` | Reuse service |
| `cloud_diagnose` | `tri cloud diagnose <N>` | Diagnose failure |
| `cloud_issue_create` | `tri cloud issue-create <title>` | Create auto-spawn issue |
| `cloud_decompose` | `tri decompose <N>` | Decompose issue into roles |
| `cloud_farm` | `tri cloud farm` | Farm dashboard |
| `cloud_farm_sync` | `tri cloud farm sync` | Sync accounts |
| `cloud_farm_capacity` | `tri cloud farm capacity` | Farm capacity |
| `cloud_farm_rebalance` | `tri cloud farm rebalance` | Rebalance services |
| `cloud_train` | `tri cloud train <name>` | Spawn training experiment |
| `cloud_train_batch` | `tri cloud train-batch` | Spawn all experiments |

## Farm Tools (farm_*)

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `farm_status` | `tri farm status` | Farm status overview |
| `farm_idle` | `tri farm idle` | List idle workers |
| `farm_recycle` | `tri farm recycle` | Recycle underperformers |
| `farm_fill` | `tri farm fill` | Fill empty slots |
| `farm_evolve_health` | `tri farm evolve status` | Evolution health dashboard |
| `farm_evolve_notify` | `tri farm evolve notify` | Insight scan + Telegram |
| `farm_evolve_watch` | `tri farm evolve watch` | Evolution sweep |

## DevOps Tools

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `patent_status` | `tri patent status` | Patent portfolio status |
| `patent_analysis` | `tri patent analysis` | Patent analysis |
| `depin_status` | `tri depin status` | DePIN protocol status |
| `depin_nodes` | `tri depin nodes` | List network nodes |
| `depin_fitness` | `tri depin fitness` | Node fitness scores |
| `research_query` | `tri research <query>` | Research via Perplexity |
| `experiment_list` | `tri experiment list` | List experiments |
| `experiment_compare` | `tri experiment compare <a> <b>` | Compare experiments |
| `chimera_run` | `tri chimera <name>` | Run fused command |
| `ouroboros_status` | `tri ouroboros status` | Self-evolution score |
| `ouroboros_run` | `tri ouroboros run` | Run evolution cycle |
| `self_test` | `tri self test` | Self-test suite |
| `self_health` | `tri self health` | Health check |
| `context_info` | `tri context info` | Current context info |
| `context_load` | `tri context load <path>` | Load context file |
| `faculty_status` | `tri faculty` | Faculty Board dashboard |
| `mu_status` | `tri mu status` | MU agent status |
| `mu_patterns` | `tri mu patterns` | MU learned patterns |
| `zenodo_status` | `tri zenodo status` | Zenodo publication status |

## Sacred Math Tools (tri_*)

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `tri_constants` | — | Show sacred constants (phi, pi, e) |
| `tri_phi` | — | Compute phi^n |
| `tri_fib` | — | Fibonacci with BigInt |
| `tri_lucas` | — | Lucas L(n) |
| `tri_spiral` | — | Phi-spiral coordinates |
| `tri_formula` | — | V = n * 3^k * pi^m * phi^p * e^q |

## Science Tools (tri_*)

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `tri_chem_periodic` | — | Periodic table by category |
| `tri_chem_element` | — | Element lookup |
| `tri_chem_mass` | — | Molar mass calculation |
| `tri_chem_moles` | — | Moles/molecules from mass |
| `tri_bio_dna` | — | DNA sequence analysis |
| `tri_bio_codon` | — | RNA codon lookup |
| `tri_bio_protein` | — | Protein sequence analysis |
| `tri_quantum_constants` | — | Quantum physics constants |
| `tri_quantum_states` | — | Quantum basis states |
| `tri_bell_states` | — | Bell entangled states |

## Swarm Tools (swarm_*)

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `swarm_status` | — | Swarm status summary |
| `swarm_agents` | — | List registered agents |
| `swarm_register` | — | Register new agent |
| `swarm_heartbeat` | — | Agent heartbeat |
| `swarm_task_get` | — | Get next pending task |
| `swarm_task_add` | — | Add task to queue |
| `swarm_task_cancel` | — | Cancel a task |
| `swarm_tasks` | — | List all tasks |
| `swarm_pause` | — | Pause all agents |
| `swarm_resume` | — | Resume agents |
| `swarm_assign` | — | Assign task to agent |
| `swarm_github_sync` | — | Convert issue to task |
| `swarm_github_on_start` | — | Notify task started |
| `swarm_github_on_complete` | — | Notify task completed |

## Oracle Tools (oracle_*)

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `oracle_start` | — | Start Telegram watchdog |
| `oracle_stop` | — | Stop watchdog |
| `oracle_status` | — | Watchdog status |

## Training Monitor Tools (tri_train_*)

| Tool | CLI Equivalent | Description |
|------|----------------|-------------|
| `tri_train_status` | — | Training status |
| `tri_train_diagnose` | — | Diagnose anomalies |
| `tri_train_loss_curve` | — | Loss curve from checkpoints |
| `tri_train_recommend` | — | Phi-aware recommendation |
| `tri_train_checkpoint` | — | List checkpoints |

## Chain Tools (chain_*)

26 Golden Chain links + `chain_list`. Each link maps to `tri chain <link_name> --task <task>`.

| Tool | Link | Description |
|------|------|-------------|
| `chain_cache` | 0 | TVC Gate — corpus search |
| `chain_baseline` | 1 | Analyze v(n-1) |
| `chain_metrics` | 2 | Collect metrics |
| `chain_patterns` | 3 | Research patterns (PAS) |
| `chain_tree` | 4 | Technology dependency tree |
| `chain_check_spec` | 5 | VIBEE compliance |
| `chain_spec` | 6 | Create .tri specs |
| `chain_codegen` | 7 | Generate Zig code |
| `chain_analyze` | 8 | Sacred Intelligence analysis |
| `chain_test` | 9 | Run test suite |
| `chain_bench` | 10 | Compare to baseline |
| `chain_fix` | 11 | SWE Agent error fix |
| `chain_bench_ext` | 12 | Compare to external tools |
| `chain_bench_theory` | 13 | Gap to theoretical max |
| `chain_delta` | 14 | Improvement delta |
| `chain_optimize` | 15 | Optimize (optional) |
| `chain_docs` | 16 | Generate docs |
| `chain_verdict` | 17 | Toxic self-assessment |
| `chain_git` | 18 | Commit and push |
| `chain_loop` | 19 | Next iteration decision |
| `chain_deploy` | 20 | Auto-deploy |
| `chain_evolve` | 21 | Pipeline self-evolution |
| `chain_self_ref` | 22 | Circular bootstrapping |
| `chain_fpga_test` | 23 | Camera LED verification |
| `chain_research` | 24 | Research-assisted fixing |
| `chain_lint_spec` | 25 | .tri spec validation |
| `chain_list` | — | List all links |

## Needle Tools (needle_*)

20 AST-aware code editing tools across 5 tiers:

**Tier 0-1: Basic**
- `needle_structural_replace` — AST-aware edit with fallback
- `needle_search` — Pattern search
- `needle_quality_gates` — Parse + AST analysis
- `needle_preview` — Preview diff
- `needle_batch_edit` — Multiple edits at once

**Tier 2: Graph**
- `needle_graph_build` — Build call graph with VSA
- `needle_graph_refactor` — Rename across project
- `needle_graph_extract` — Extract function
- `needle_graph_visualize` — DOT/JSON graph
- `needle_graph_affected` — Find affected files

**Tier 3: Semantic**
- `needle_graph_vsa_search` — VSA semantic search
- `needle_semantic_replace` — Replace by meaning
- `needle_vsa_index` — Build semantic index

**Tier 4: Cross-file**
- `needle_safe_cross_refactor` — Safe cross-file refactor
- `needle_vsa_rule_apply` — VSA rule validation
- `needle_cross_preview` — Cross-file impact preview
- `needle_rollback_all` — Rollback failed refactor

**Tier 5: Omega**
- `needle_omega_init` — Initialize autonomous agent
- `needle_omega_analyze` — Codebase analysis
- `needle_omega_execute` — Execute plan
- `needle_omega_detect` — Auto-detect improvements
- `needle_omega_status` — Agent health

**Phase 1: Safety**
- `needle_safety_gates_run` — Run safety gates
- `needle_atomic_refactor` — Atomic refactor with rollback
- `needle_parse_check` — Zig AST parse check
- `needle_compile_check` — zig build compile check
