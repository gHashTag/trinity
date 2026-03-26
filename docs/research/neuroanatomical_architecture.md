# Neuroanatomical Architecture — Trinity Research Layer

> **Disclaimer**: All parcellations described in this document are Trinity-specific mappings aligned with TRI-27/Coptic design, not with any specific empirical parcellations from human connectomics. (Senden et al. 2024; Yeo et al. 2011)

## Overview

Trinity's architecture is inspired by neuroanatomy but uses a **Trinity-specific parcellation** based on the 27-letter Coptic alphabet. Each letter zone corresponds to:
- A brain region (functional analogy)
- A codebase path (`src/{LETTER}/`)
- A TRI-27 register bank

This is **not** intended to match any specific empirical brain atlas.

---

## NA-R1: Cortical Hierarchy (2026-03-20)

**Status**: Canon

**Statement**: Trinity follows a cortical hierarchy model where sensory input flows through thalamus to higher cortical areas.

**Implementation**: R-agent → X-agent → Q-agent hierarchy.

---

## NA-R2: Complementary Learning Systems (2026-03-21)

**Status**: Canon

**Statement**: Hippocampus (H) stores fast episodic memories; neocortex (T) consolidates slow semantic rules.

**Implementation**: H-agent writes `.jsonl` episodes; T-agent updates `.md` rules.

---

## NA-R3: Meta-Control Loop (2026-03-22)

**Status**: Canon

**Statement**: Queen (Q) implements meta-control — not solving tasks directly, but deciding WHICH specialist to activate.

**Implementation**: Q-agent reads reports, assigns tasks, monitors progress.

---

## NA-R4: Thalamocortical Loops (2026-03-23)

**Status**: Canon

**Statement**: Peripheral zones communicate via thalamus (`.trinity/thalamus/agent_reports/`), not direct calls.

**Implementation**: Agents write JSON reports; Queen reads as "sensory input".

---

## NA-R5: Stigmergic Coordination (2026-03-24)

**Status**: Canon

**Statement**: Agents communicate through shared environment (files), not direct messages.

**Implementation**: Shared `.trinity/` directory, lock protocol for coordination.

---

## NA-R6: Basal Ganglia Action Selection (2026-03-24)

**Status**: Canon

**Statement**: B-agent implements action selection via disinhibition model.

**Implementation**: `src/B/action_selection.zig` — winner-take-all competition.

---

## NA-R7: Dopaminergic Reward Prediction (2026-03-24)

**Status**: Canon

**Statement**: A-agent (Accumens) computes reward prediction errors for learning.

**Implementation**: `src/A/reward_prediction.zig` — TD learning.

---

## NA-R8: Hippocampal Replay (2026-03-25)

**Status**: Canon

**Statement**: H-agent replays experiences during rest periods for consolidation.

**Implementation**: `.trinity/hippocampus/episodes/*.jsonl` → T-agent semantic rules.

---

## NA-R9: Reticular Watch-Daemon (2026-03-25)

**Status**: Canon

**Statement**: R-agent monitors system health, triggers alerts on anomalies.

**Implementation**: `src/R/watch_daemon.zig` — health checks, Telegram alerts.

---

## NA-R10: Cortical Column Microarchitecture (2026-03-25)

**Status**: Canon

**Statement**: Each letter-zone functions as a cortical column (microcolumn) with layers I-VI.

**Implementation**: Each zone has `state.jsonl` (internal), `HIVELOG.md` (output), lock protocol (input).

---

## NA-R11: Alphabet Canon Law (2026-03-25)

**Status**: Canon

**Statement**: Each Trinity module belongs to one of 27 letter zones. Letter determines place in brain, codebase, and TRI-27 space. Zone T (Temple) is core, protected by TTT Seal.

**Reference**: `docs/research/ALPHABET_CANON_27.md`, `.trinity/canonmap.json`

**Implementation**: See TDGS-4.

---

## Agent Roles by Zone

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

---

## References

- Senden, M., et al. (2024). "Anatomy of the human cerebral cortex."
- Yeo, B., et al. (2011). "The organization of the human cerebral cortex."
- `src/tri27/coptic.zig` — Coptic 27-register system
- `.trinity/canonmap.json` — Official canon mapping
