# Trinity Development Priorities

Last updated: 2026-03-11

## P0 — Critical Path (This Week)

Must-do for first live agent spawn.

| # | Task | Blocker? | Detail |
|---|------|----------|--------|
| 1 | Docker GHCR Image | YES | Push `Dockerfile.agent` to ghcr.io/gHashTag/trinity-agent |
| 2 | GitHub Secrets | YES | `RAILWAY_TOKEN`, `ANTHROPIC_API_KEY`, `GH_TOKEN` in repo secrets |
| 3 | CLI Flags for Scaling | NO | `tri cloud spawn --timeout 2h --role scholar` |
| 4 | First Live Spawn | YES | Open real issue → container boots → agent solves → PR created |

**Exit criteria**: One issue fully solved by an agent container, PR merged.

## P1 — Next Sprint (This Month)

Experiments, papers, polish.

| # | Task | Layer | Detail |
|---|------|-------|--------|
| 1 | Seed Experiments | L5 | Fixed seeds for reproducible v4R baseline |
| 2 | arXiv Draft | L5 | HSLM paper: ternary LLM, 1.58 bits/trit, PPL=125 |
| 3 | Scaling Experiments | L5 | 4M→8M params, does PPL break 100? |
| 4 | Dashboard UI | L6 | Web page showing active containers, logs, costs |
| 5 | FPGA Programmer | L3 | Auto-flash bitstream via JTAG on M1 |
| 6 | Agent Self-Metrics | L4 | Track solve rate, time-to-PR, token usage per issue |

## P2 — Backlog (This Quarter)

Nice-to-have, future architecture.

| # | Task | Layer | Detail |
|---|------|-------|--------|
| 1 | STE Training | L1 | Straight-Through Estimator for true ternary gradients |
| 2 | Multi-Repo | L6 | Agent swarm operates across multiple GitHub repos |
| 3 | Agent Memory | L6 | Cross-session learning, shared knowledge base |
| 4 | Worktree Isolation | L4 | Each agent gets git worktree, not full clone |
| 5 | Budget Guard | L6 | Railway cost alerts, auto-kill at $N/month |
| 6 | Continuous Training | L1 | HSLM trains on agent outputs (self-improvement loop) |
| 7 | FPGA Inference | L3 | On-chip forward pass, measure tok/s on XC7A100T |
| 8 | Agent Specialization | L4 | Fine-tuned SOUL.md per agent role |

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-11 | GHCR over Docker Hub | Free for public repos, GitHub-native auth |
| 2026-03-11 | P0 = live spawn first | Everything else is optimization — need proof of life |
| 2026-03-11 | P1 includes papers | Zenodo published, momentum for arXiv submission |
