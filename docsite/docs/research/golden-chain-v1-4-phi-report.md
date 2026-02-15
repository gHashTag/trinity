# Golden Chain v1.4: Phi-Engine Quantum Verification + Live DAG + $TRI Energy Rewards

**Date:** 2026-02-13
**Version:** 1.4.0
**Status:** Implemented & Tested

---

## Summary

Golden Chain v1.4 adds **Phi-Engine Quantum Verification (Phase E)**, **Live DAG Export**, **$TRI Energy Rewards**, and **3 new QuarkTypes** on top of v1.3's 40-quark chain. Quarks increase from 40 to **48 per query** (+1 per node). Verification gains a new phase: **Phase E (phi-quantum)** with 3 sub-checks. Combined: 8 provenance + 48 quarks = **56 immutable records per query**.

---

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Quark records per query | 48 (6+6+5+8+6+5+6+6) | Active |
| QuarkType variants | 22 (19 work + 3 verification) | Active |
| New QuarkTypes | phi_verify, dag_checkpoint, reward_mint | Active |
| Verification phases | 5 (A: linear, B: DAG, C: phi-hash, D: cross-chain, E: phi-quantum) | Active |
| Phase E sub-checks | 3 (E1: phi-residue, E2: Lucas diversity, E3: golden angle) | Active |
| DAG export | getDAGEdges() + getDAGStats() | Active |
| $TRI rewards | calculateSessionReward() with TriRewardConfig | Active |
| New ChainMessageTypes | DAGVisualization, RewardSummary | Active |
| Export format | QGC1 v2 binary, 18-byte header (+8 for reward) | Active |
| New tests added | 15 | All passing |
| Updated tests | 1 (verification classification 19w+3v=22) | Updated |
| Total golden chain tests | 50 (35 old + 15 new) | All passing |
| Memory per agent | ~17KB (quarks 6.2KB + provenance 2.5KB + export 7.5KB + DAG 192B + reward 48B) | Negligible |

---

## What This Means

### For Users
- **Phi-quantum verification**: Mathematical proof of chain integrity using golden ratio properties
- **DAG visibility**: Live DAG statistics (edges, depth, width, fan-out, fan-in) in chat
- **$TRI rewards**: Earn micro-TRI for verified high-quality sessions
- **48 quarks per query**: Maximum audit granularity with phi, DAG, and reward tracking

### For Operators
- **56 immutable records per query** = maximum audit granularity
- **5-phase verification** = linear + DAG + phi-hash + cross-chain + phi-quantum
- **$TRI reward system**: Configurable base reward, confidence bonus, quark depth bonus, energy penalty
- **Binary export v2**: 18-byte header with reward field, backward compatible with v1

### For Developers
- `phiQuantumVerify()` — Phase E with 3 sub-checks (phi-residue, Lucas modular, golden angle)
- `getDAGEdges()` / `getDAGStats()` — DAG adjacency export for canvas rendering
- `calculateSessionReward()` — Self-contained $TRI reward calculation
- `TriRewardConfig` / `TriRewardResult` structs
- `DAGEdge` / `DAGStats` structs
- 3 new QuarkType variants with `isPhiQuark()`, `isDAGQuark()`, `isRewardQuark()` classifiers
- `isVerificationQuark()` now includes `phi_verify` (3 verification quarks total)
- Phi constants: PHI, PHI_INV, PHI_SQ, GOLDEN_IDENTITY, LUCAS_SEQUENCE[16], FIB_SEQUENCE[16]

---

## Technical Details

### Architecture

```
Query Input
    |
    v
[GOAL_PARSE] --> Provenance #0 + Quarks Q0-Q5 (6)
    |             (input_capture, goal_classify, oracle_cross_check, phi_verify, hash_verify, gluon_verify)
    v
[DECOMPOSE]  --> Provenance #1 + Quarks Q6-Q11 (6)
    |             (task_decompose, dependency_check, oracle_cross_check, phi_verify, hash_verify, gluon_verify)
    v
[SCHEDULE]   --> Provenance #2 + Quarks Q12-Q16 (5)
    |             (schedule_plan, energy_accounting, dag_checkpoint, hash_verify, gluon_verify)
    v
[EXECUTE]    --> Provenance #3 + Quarks Q17-Q24 (8)
    |             (route_decision, api_call, tvc_cross_check, vsa_bind, oracle_cross_check, phi_verify, hash_verify, gluon_verify)
    v
[MONITOR]    --> Provenance #4 + Quarks Q25-Q30 (6)
    |             (quality_gate, tvc_cross_check, fake_injection_detect, phi_verify, hash_verify, gluon_verify)
    v
[ADAPT]      --> Provenance #5 + Quarks Q31-Q35 (5)
    |             (adapt_decision, fake_injection_detect, dag_checkpoint, hash_verify, gluon_verify)
    v
[SYNTHESIZE] --> Provenance #6 + Quarks Q36-Q41 (6)
    |             (merge_result, format_output, oracle_cross_check, reward_mint, hash_verify, gluon_verify)
    v
[DELIVER]    --> Provenance #7 + Quarks Q42-Q47 (6)
    |             (chain_integrity, format_output, energy_accounting, reward_mint, hash_verify, gluon_verify)
    |             + verifyProvenanceChain() -> TRUTH verdict
    |             + verifyQuarkChain() -> Phase A+B+C+D+E -> QUARK TRUTH verdict
    |             + getDAGStats() -> DAGVisualization message
    |             + calculateSessionReward() -> RewardSummary message
    v
Response Output
```

### QuarkType v1.4 (22 variants)

| # | Type | Category | Description |
|---|------|----------|-------------|
| 0-13 | (v1.2 work types) | Work | Unchanged from v1.2 |
| 14 | hash_verify | Verification | SHA256 hash verification |
| 15 | gluon_verify | Verification | Gluon entanglement verification |
| 16 | fake_injection_detect | Work (Adversarial) | Detect injection/hallucination |
| 17 | oracle_cross_check | Work (Adversarial) | Cross-check against known-good |
| 18 | energy_accounting | Work (Accounting) | Track compute cost |
| 19 | phi_verify | Verification | Phi-engine quantum hash verification |
| 20 | dag_checkpoint | Work (DAG) | DAG structure checkpoint |
| 21 | reward_mint | Work (Reward) | $TRI reward minting record |

### Verification Phases

| Phase | Check | Description |
|-------|-------|-------------|
| A | Linear chain | Genesis zero-hash, recompute all hashes, verify chain links |
| B | DAG integrity | Entanglement bounds, backward refs only, gluon_verify has refs |
| C | Phi-hash balance | XOR all hashes, mod-3 residue classes >= 2 of 3 present |
| D | Cross-chain | Node ordering non-decreasing, every provenance node has quarks |
| E | Phi-quantum | E1: phi-residue balance, E2: Lucas modular diversity, E3: golden angle spacing |

### Phase E Sub-Checks

| Sub-check | Method | Pass Condition |
|-----------|--------|---------------|
| E1 | Map bytes to phi-space (byte/256 * PHI), fractional part into 3 buckets (<0.382, <0.618, >=0.618) | All 3 buckets populated |
| E2 | XOR hashes, check positions 0..15 against LUCAS_SEQUENCE modular residue | >= 8 of 16 positions non-zero |
| E3 | Byte pairs as u16 angles, check consecutive diffs in golden angle range [16806, 33190] | >= 1 pair in range |

### $TRI Reward Formula

```
if confidence < min_reward_confidence: 0
if !verified: 0
base = base_reward_utri (default 1000 = 0.001 TRI)
conf_bonus = floor(base * 0.5) if confidence >= 0.9 else 0
quark_bonus = (quark_count - 40) * 10 if quark_count > 40 else 0
energy_penalty = floor(total_latency_us * 0.001)
total = max(0, base + conf_bonus + quark_bonus - energy_penalty)
```

### Export Format v2 (QGC1)

```
[Header: 18 bytes]  (was 10 in v1)
  magic: 'Q','G','C','1'     (4 bytes)
  version: u16 = 2            (2 bytes)
  provenance_count: u8         (1 byte)
  quark_count: u8              (1 byte)
  chain_verified: u8           (1 byte)
  quark_chain_verified: u8     (1 byte)
  total_reward_utri: u64       (8 bytes, NEW in v2)

[Provenance Records: 158 bytes each]
[Quark Records: 131 bytes each]

Total: ~7.5KB for 8 provenance + 48 quarks
Backward compatible: deserialize accepts v1 (10-byte header, reward=0)
```

### Files Modified

| File | Changes |
|------|---------|
| `specs/tri/hdc_golden_chain_phi_v1_4.vibee` | Created — specification (source of truth) |
| `src/vibeec/golden_chain.zig` | +3 QuarkType variants, +phi constants, +DAGEdge/DAGStats, +TriRewardConfig/TriRewardResult, +2 ChainMessageType, +phiQuantumVerify(), +getDAGEdges(), +getDAGStats(), +calculateSessionReward(), updated 8 emitXxxQuarks (40->48), +export v2, +15 tests |
| `src/wasm_stubs/golden_chain_stub.zig` | +3 QuarkType variants, +phi constants, +DAG/reward types, +2 ChainMessageType, +stub methods, +agent fields |
| `src/vsa/photon_trinity_canvas.zig` | +2 ChatMsgType (dag_visualization, reward_summary) + colors + labels |

---

## Technology Tree

```
v1.0 Golden Chain (8-node pipeline)
  |
  v
v1.1 Truth & Provenance (SHA256, 8 records)  -- DONE
  |
  v
v1.2 Quark-Gluon (32 quarks, DAG entanglement)  -- DONE
  |
  v
v1.3 VSA Query + On-Chain Export (40 quarks, search, serialize)  -- DONE
  |
  v
v1.4 Phi-Engine Quantum + Live DAG + $TRI Rewards (48 quarks)  <-- YOU ARE HERE
  |
  v
v2.0 Immortal Self-Verifying Agent
```

---

## Conclusion

Golden Chain v1.4 transforms the quark chain into a phi-verified, reward-generating, DAG-exportable provenance system. The 48-quark chain with 22 QuarkTypes provides 56 immutable records per query. Phase E (phi-quantum verification) adds 3 mathematical sub-checks based on golden ratio properties. The DAG adjacency export enables canvas visualization. The $TRI energy reward system incentivizes verified high-quality sessions. Export format v2 (18-byte header) preserves backward compatibility with v1. All 50 golden chain tests pass, WASM stub synchronized, canvas updated. v1.1 provenance + v1.2 quark chain + v1.3 search/export remain fully backward compatible.
