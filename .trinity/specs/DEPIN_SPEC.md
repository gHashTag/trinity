# DePIN Phase 2 Specification — Neuroanatomical Integration

> **Version**: 2.0
> **Status**: PHASE 2 — After Queen Unification
> **Created**: 2026-03-18
> **Priority**: HIGH (but follows Queen PFC completion)

---

## Directive to Future Agent

This spec contains comprehensive research on Trinity DePIN, competitive analysis, and implementation roadmap.

**DO NOT START** until Queen Unification (Phase 1) is complete. DePIN depends on Queen for L2 policy decisions.

Focus on: `src/queen/` → Queen PFC (5 cells) + Brainstem + Reticular

---

## Table of Contents

1. [Neuroanatomical Model](#neuroanatomical-model)
2. [Current Implementation](#current-implementation)
3. [Competitive Analysis](#competitive-analysis)
4. [Academic Literature](#academic-literature)
5. [Implementation Roadmap](#implementation-roadmap)
6. [File Structure](#file-structure)

---

## Neuroanatomical Model

### Trinity Organism Architecture

```
                    QUEEN (Brain)
                      │
                 THALAMUS
              Relay 14-15 │
                      ▼
    ┌─────────────────────────────────────┐
    │            DEPIN (Body)             │
    │                                     │
    │  PNS ───► Node Discovery (sensory)  │
    │  Spinal ► Job Routing (reflex)      │
    │  Amygdala ► Threat Detection        │
    │  Striatum ► Habit Learning (SEVO)   │
    │  Autonomic ► Self-Healing           │
    │  Endocrine ► $TRI Dopamine          │
    └─────────────────────────────────────┘
```

### Cell Mapping

| Biological | DePIN Function | File | Health Metric |
|-----------|----------------|------|---------------|
| **PNS** | Node discovery (UDP 9333) | `depin_pns.zig` | Nodes discovered |
| **Spinal Cord** | Job distribution (TCP 9334) | `depin_spinal.zig` | Reflex latency |
| **Amygdala** | Anomaly detection | `depin_amygdala.zig` | Threat level (0-1) |
| **Striatum** | SEVO optimization | `depin_striatum.zig` | SEVO fitness |
| **Autonomic NS** | Self-healing controller | `depin_autonomic.zig` | Recovery rate |
| **Endocrine** | $TRI tokenomics | `depin_endocrine.zig` | Dopamine level |

---

## Current Implementation

### Phase 1 Status (COMPLETE)

```
Trinity DePIN v1.0
├── src/tri/tri_depin.zig           # Railway monitoring
├── src/depin/network.zig            # UDP/TCP network
├── src/firebird/depin.zig           # $TRI tokenomics
├── specs/depin/*.tri                # Specifications
└── docs/docs/depin/*.md             # Documentation
```

### Tokenomics

```
Total Supply: 3^21 = 10,460,353,203 $TRI

Allocation:
├── Node Rewards (40%) : 4.18B — Emitted per-operation
├── Founder (20%)       : 2.09B — 12mo cliff, 48mo vesting
├── Community (20%)     : 2.09B — 36mo vesting
├── Treasury (10%)      : 1.05B — 6mo cliff, 24mo vesting
└── Liquidity (10%)     : 1.05B — Immediate

Staking Tiers:
├── FREE    : 0 TRI   (1.0x rewards, 10 req/min)
├── STAKER  : 100 TRI (1.5x rewards, 60 req/min)
├── POWER   : 1K TRI  (2.0x rewards, 300 req/min)
└── WHALE   : 10K TRI (3.0x rewards, unlimited)
```

---

## Competitive Analysis

### Market Overview (2024-2025)

| Metric | Value |
|--------|-------|
| Market Cap | $19.2B (+270% YoY) |
| Active Projects | 423 |
| Devices | 41.8M |
| Monthly Revenue | $150M |

### Feature Gaps

| Feature | Trinity | Filecoin | Render | Akash |
|---------|---------|----------|--------|-------|
| ZK Proofs | ❌ | ✅ | ❌ | ❌ |
| Mobile | ❌ | ❌ | ❌ | ❌ |
| Enterprise SLAs | ❌ | ✅ | ✅ | ✅ |
| Autonomous | ❌ | ✅ | ✅ | ❌ |

### Trinity Advantages

1. **Ternary PoUW** — Lightweight verification via VSA
2. **φ-Based Health** — `phi^2 + 1/phi^2 = 3` target
3. **SEVO Integration** — Evolutionary parameter optimization
4. **Zig Native** — Zero dependencies, memory-safe

---

## Academic Literature

### Key Papers

1. **Lin et al. (2024)** — "DePIN: Challenges and Opportunities" — 5-layer architecture
2. **Protocol Labs (2017)** — "Proof of Replication" — PoRep/PoSt foundation
3. **Alshater (2023)** — "DePIN Tokenomics" — Economic models
4. **Dehkordi (2025)** — "Sybil Detection in ML" — ML-based Sybil resistance

### Research Gaps for Trinity

| Area | Status | Needed |
|------|--------|--------|
| Formal verification | ❌ | Z3 proofs for critical paths |
| Sybil resistance | ⚠️ | PoS + reputation hybrid |
| Economic analysis | ❌ | Griefing attack modeling |
| Game theory | ❌ | Nash equilibrium simulation |

---

## Implementation Roadmap

### Phase 1 (NOW) — Queen Unification

```
✅ Queen PFC (5 cells)
✅ Brainstem refactor (3 cells)
✅ Reticular (3 cells)
⏳ DO THIS FIRST — R30 needs Queen
```

### Phase 2 (AFTER) — DePIN Integration

#### Week 1-2: PNS + Spinal Refactor
- Rename `network.zig` → `depin_spinal.zig`
- Create `depin_pns.zig` (sensory discovery)
- Add Thalamus Relay 14

#### Week 3-4: Amygdala (Threat Detection)
- Create `depin_amygdala.zig`
- Z-score anomaly detection
- EWMA trend analysis
- Alert system

#### Week 5-6: Striatum (SEVO Integration)
- Create `depin_striatum.zig`
- Parameter mutation
- Fitness evaluation
- Reward learning

#### Week 7-8: Autonomic Controller
- Create `depin_autonomic.zig`
- Self-healing loop
- Auto-scaling
- Rollback logic

#### Week 9-10: Endocrine Refactor
- Rename `firebird/depin.zig` → `depin_endocrine.zig`
- Dynamic reward rates
- Hormonal modulation

### Phase 3 (LATER) — Advanced

- ZK proofs for PoUW
- On-chain governance DAO
- Cross-chain bridging

---

## File Structure

### Refactoring Map

```
OLD                           NEW (Phase 2)
─────────────────────────────────────────────────────
src/depin/network.zig      →   src/depin/depin_spinal.zig
src/firebird/depin.zig     →   src/depin/depin_endocrine.zig
NEW: src/depin/depin_pns.zig
NEW: src/depin/depin_amygdala.zig
NEW: src/depin/depin_striatum.zig
NEW: src/depin/depin_autonomic.zig
```

### Cell Interface

Each file implements `Cell` interface:

```zig
pub const Cell = struct {
    pub fn name() []const u8 { return "StructureName"; }
    pub fn health(allocator: Allocator) !f64 {
        // Returns 0-1 health score
    }
    pub fn status(allocator: Allocator) !CellStatus {
        // Returns detailed status
    }
};
```

### Thalamus Integration

```zig
// src/queen/thalamus.zig — ADD

pub fn getNetworkHealth() !NetworkHealth {
    return NetworkHealth{
        .nodes_online = depin_autonomic.getOnlineCount(),
        .health_score = depin_autonomic.getHealthScore(),
        .avg_latency_ms = depin_spinal.getAvgLatency(),
        .tri_earned_hour = depin_endocrine.getEarnedHour(),
        .anomaly_count = depin_amygdala.getAnomalyCount(),
        .sevo_generation = depin_striatum.getGeneration(),
    };
}

pub fn getTokenomicsState() !TokenState {
    return TokenState{
        .total_staked = depin_endocrine.getTotalStaked(),
        .reward_rate_current = depin_endocrine.getCurrentRate(),
        .tier_distribution = depin_endocrine.getTierDistribution(),
        .slashing_events = depin_endocrine.getSlashingEvents(),
        .revenue_24h = depin_endocrine.getRevenue24h(),
    };
}
```

---

## Quick Reference

### Commands

```bash
# Current (Phase 1)
tri depin status          # Network overview
tri depin nodes           # List all nodes
tri depin fitness         # Aggregate fitness

# Future (Phase 2)
tri cell status amygdala    # Threat level
tri cell status striatum    # SEVO fitness
tri depin auto start        # Autonomic loop
tri depin auto stop         # Shutdown
```

### Ports

| Port | Protocol | Analog |
|------|----------|--------|
| 9333 | UDP | PNS (sensory) |
| 9334 | TCP | Spinal (reflex) |
| 8080 | TCP | API (conscious) |
| 9090 | TCP | Proprioception |

---

**φ² + 1/φ² = 3 = TRINITY**

*Focus on Queen Phase 1 first. This spec will be here when ready.*
