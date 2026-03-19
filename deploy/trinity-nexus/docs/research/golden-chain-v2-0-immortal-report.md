# Golden Chain v2.0: Immortal Self-Verifying Agent

**Date:** 2026-02-14
**Version:** 2.0.0
**Status:** Implemented & Tested

---

## Summary

Golden Chain v2.0 adds **Self-Repair Engine**, **Immortal Persistence**, **Evolution Loop**, **Phase G Verification**, and **3 new QuarkTypes** (filling u5 to 32/32). Quarks increase from 56 to **64 per query** (+8 total, +1 per node on average). Verification gains Phase G (self-repair integrity). Combined: 8 provenance + 64 quarks = **72 immutable records per query**. Export bumped to **v4 (34-byte header)**.

---

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Quark records per query | 64 (8+8+8+9+8+7+8+8) | Active |
| QuarkType variants | 32 (29 work + 3 verification) = FULL u5 | Active |
| New QuarkTypes | self_repair, immortal_persist, evolution_checkpoint | Active |
| Verification phases | 7 (A-G) | Active |
| Phase G sub-checks | 2 (G1: repaired quarks valid, G2: tvc_corpus_hash consistent) | Active |
| Self-repair engine | selfRepairChain() with 4 repair types | Active |
| Immortal persistence | persistState() + restoreState() with SHA256 fingerprint | Active |
| Evolution loop | evolveChain() with generation tracking + fitness scoring | Active |
| New ChainMessageTypes | SelfRepairEvent, ImmortalPersist, EvolutionStep, ChainHealthCheck | Active |
| Export format | QGC1 v4 binary, 34-byte header (+8 for repair/evolution/persist) | Active |
| New tests added | 17 | All passing |
| Total golden chain tests | 83 (66 old + 17 new) | All passing |
| Memory per agent | ~23KB | Negligible |

---

## What This Means

### For Users
- **Self-healing chain**: Broken quarks detected and repaired automatically
- **Immortal sessions**: Chain state persists across restarts via SHA256 fingerprint
- **Evolution tracking**: Each query generation improves fitness, adaptation visible in UI
- **64 quarks per query**: Maximum audit granularity with self-repair and evolution tracking
- **4 new message types**: REPAIR, PERSIST, EVOLVE, HEALTH visible in canvas

### For Operators
- **72 immutable records per query** = maximum audit granularity
- **7-phase verification** = linear + DAG + phi-hash + cross-chain + phi-quantum + staking + self-repair
- **Self-repair**: Automatic detection and fix of hash mismatches, low confidence, broken entanglement
- **Chain health reports**: Total/healthy/repaired/broken counts with health_score
- **Full u5 QuarkType**: All 32 slots used, no further QuarkType capacity without enum widening

### For Developers
- `selfRepairChain()` -- scan + repair first broken quark, returns RepairRecord
- `getChainHealth()` -- returns ChainHealthReport with health_score
- `persistState()` -- compute SHA256 fingerprint of all quark+provenance hashes
- `restoreState(buf)` -- deserialize chain, increment restore_count
- `evolveChain()` -- record EvolutionRecord with generation, fitness, repairs
- `selfRepairVerify()` -- Phase G with 2 sub-checks
- 3 new QuarkType variants with classifiers: `isSelfRepairQuark()`, `isImmortalQuark()`, `isEvolutionQuark()`
- `SelfRepairState` enum: healthy, degraded, repairing, repaired
- `SelfRepairType` enum: hash_recompute, confidence_restore, entangle_fix, chain_rebuild
- `RepairRecord`, `EvolutionConfig`, `EvolutionRecord`, `ImmortalState`, `ChainHealthReport` structs
- Export v4: 34-byte header, backward compatible with v1/v2/v3

---

## Technical Details

### Architecture

```
Query Input
    |
    v
[GOAL_PARSE] --> Provenance #0 + Quarks Q0-Q7 (8)
    |             (input_capture, goal_classify, oracle_cross_check, phi_verify, collapse_state, self_repair, hash_verify, gluon_verify)
    v
[DECOMPOSE]  --> Provenance #1 + Quarks Q8-Q15 (8)
    |             (task_decompose, dependency_check, oracle_cross_check, phi_verify, collapse_state, evolution_checkpoint, hash_verify, gluon_verify)
    v
[SCHEDULE]   --> Provenance #2 + Quarks Q16-Q23 (8)
    |             (schedule_plan, energy_accounting, dag_checkpoint, compress_quark, immortal_persist, self_repair, hash_verify, gluon_verify)
    v
[EXECUTE]    --> Provenance #3 + Quarks Q24-Q32 (9)
    |             (route_decision, api_call, tvc_cross_check, vsa_bind, oracle_cross_check, phi_verify, share_link, hash_verify, gluon_verify)
    v
[MONITOR]    --> Provenance #4 + Quarks Q33-Q40 (8)
    |             (quality_gate, tvc_cross_check, fake_injection_detect, phi_verify, public_view, self_repair, hash_verify, gluon_verify)
    v
[ADAPT]      --> Provenance #5 + Quarks Q41-Q47 (7)
    |             (adapt_decision, fake_injection_detect, dag_checkpoint, phi_visual, evolution_checkpoint, hash_verify, gluon_verify)
    v
[SYNTHESIZE] --> Provenance #6 + Quarks Q48-Q55 (8)
    |             (merge_result, format_output, oracle_cross_check, reward_mint, staking_lock, immortal_persist, hash_verify, gluon_verify)
    v
[DELIVER]    --> Provenance #7 + Quarks Q56-Q63 (8)
    |             (chain_integrity, format_output, energy_accounting, reward_mint, staking_yield, self_repair, hash_verify, gluon_verify)
    |             + verifyProvenanceChain() -> TRUTH verdict
    |             + verifyQuarkChain() -> Phase A+B+C+D+E+F+G -> QUARK TRUTH verdict
    |             + selfRepairChain() -> SelfRepairEvent message
    |             + getChainHealth() -> ChainHealthCheck message
    |             + persistState() -> ImmortalPersist message
    |             + evolveChain() -> EvolutionStep message
    v
Response Output
```

### Verification Phases

| Phase | Check | Description |
|-------|-------|-------------|
| A | Linear chain | Genesis zero-hash, recompute all hashes, verify chain links |
| B | DAG integrity | Entanglement bounds, backward refs only, gluon_verify has refs |
| C | Phi-hash balance | XOR all hashes, mod-3 residue classes >= 2 of 3 present |
| D | Cross-chain | Node ordering non-decreasing, every provenance node has quarks |
| E | Phi-quantum | E1: phi-residue, E2: Lucas modular, E3: golden angle |
| F | Staking integrity | F1: share link fingerprint valid, F2: staking balance consistent |
| G | Self-repair integrity | G1: repaired quarks valid, G2: tvc_corpus_hash consistent |

### Self-Repair Engine

```
selfRepairChain():
  for each quark in chain:
    recompute expected hash
    if hash != expected:
      repair_state = .repairing
      fix hash, restore confidence to threshold
      record RepairRecord
      repair_state = .repaired
      return RepairRecord
  return null (chain healthy)

Repair types:
  hash_recompute    -- re-link prev_hash and recompute current_hash
  confidence_restore -- restore confidence to SELF_REPAIR_CONFIDENCE_THRESHOLD
  entangle_fix      -- reset broken entanglement references
  chain_rebuild     -- full chain rebuild from point
```

### Export Format v4 (QGC1)

```
[Header: 34 bytes]  (was 26 in v3)
  magic: 'Q','G','C','1'     (4 bytes)
  version: u16 = 4            (2 bytes)
  provenance_count: u8         (1 byte)
  quark_count: u8              (1 byte)
  chain_verified: u8           (1 byte)
  quark_chain_verified: u8     (1 byte)
  total_reward_utri: u64       (8 bytes)
  staking_total_utri: u64      (8 bytes)
  repair_count: u8             (1 byte, NEW in v4)
  evolution_count: u8          (1 byte, NEW in v4)
  current_generation: u16      (2 bytes, NEW in v4)
  persist_count: u32           (4 bytes, NEW in v4)

[Provenance Records: 158 bytes each]
[Quark Records: 131 bytes each]

Total: ~10.5KB for 8 provenance + 64 quarks
Backward compatible: v1 (10-byte), v2 (18-byte), v3 (26-byte)
```

### Files Modified

| File | Changes |
|------|---------|
| `specs/tri/hdc_golden_chain_v2_0_immortal.vibee` | Created -- specification (source of truth) |
| `src/vibeec/golden_chain.zig` | +3 QuarkType variants (32 total, FULL u5), +v2.0 constants, +v2.0 types (SelfRepairState, RepairRecord, ImmortalState, EvolutionConfig, EvolutionRecord, ChainHealthReport), +4 ChainMessageType, +Phase G, +self-repair/persist/evolve methods, updated 6 emitXxxQuarks (56->64), +export v4 (34-byte), +17 tests |
| `src/wasm_stubs/golden_chain_stub.zig` | +3 QuarkType variants, +v2.0 types, +4 ChainMessageType, +7 agent fields, +6 stub methods, export v4 |
| `src/vsa/photon_trinity_canvas.zig` | +4 ChatMsgType (self_repair_event, immortal_persist, evolution_step, chain_health_check) + colors + labels |

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
v1.4 Phi-Engine Quantum + Live DAG + $TRI Rewards (48 quarks)  -- DONE
  |
  v
v1.5 Collapsible Views + Share Links + $TRI Staking (56 quarks)  -- DONE
  |
  v
v2.0 Immortal Self-Verifying Agent (64 quarks, FULL u5)  <-- YOU ARE HERE
  |
  v
v2.1+ Future: Distributed consensus, cross-node repair, on-chain evolution
```

---

## Conclusion

Golden Chain v2.0 transforms the agent into an **Immortal Self-Verifying Agent**. The 64-quark chain with 32 QuarkTypes (FULL u5) provides 72 immutable records per query. The self-repair engine automatically detects and fixes broken quarks. Immortal persistence via SHA256 fingerprint enables state recovery across restarts. The evolution loop tracks generation fitness and adaptation. Phase G (self-repair integrity) adds 2 verification sub-checks for a total of 7 verification phases. Export format v4 (34-byte header) preserves backward compatibility with v1/v2/v3. All 83 golden chain tests pass, WASM stub synchronized, canvas updated with 4 new message types. The QuarkType enum is now at full u5 capacity (32/32 variants).
