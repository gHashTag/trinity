# Golden Chain v1.5: Collapsible Quark Views + Public Shareable Links + Real $TRI Staking

**Date:** 2026-02-14
**Version:** 1.5.0
**Status:** Implemented & Tested

---

## Summary

Golden Chain v1.5 adds **Collapsible Quark Views**, **Public Shareable Provenance Links**, **Real $TRI Staking**, and **7 new QuarkTypes** on top of v1.4's 48-quark chain. Quarks increase from 48 to **56 per query** (+1 per node). Verification gains Phase F (staking integrity). Combined: 8 provenance + 56 quarks = **64 immutable records per query**.

---

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Quark records per query | 56 (7+7+6+9+7+6+7+7) | Active |
| QuarkType variants | 29 (26 work + 3 verification) | Active |
| New QuarkTypes | collapse_state, share_link, staking_lock, staking_yield, public_view, compress_quark, phi_visual | Active |
| Verification phases | 6 (A-F) | Active |
| Phase F sub-checks | 2 (F1: share link fingerprint, F2: staking balance) | Active |
| Collapsible views | QuarkViewState (expanded/collapsed/hidden) per node | Active |
| Shareable links | generateShareLink() + verifyShareLink() | Active |
| $TRI staking | stakeReward() + unstakeReward() with lock durations | Active |
| New ChainMessageTypes | CollapseToggle, ShareLinkGenerated, StakingEvent | Active |
| Export format | QGC1 v3 binary, 26-byte header (+8 for staking) | Active |
| New tests added | 16 | All passing |
| Total golden chain tests | 66 (50 old + 16 new) | All passing |
| Memory per agent | ~21KB | Negligible |

---

## What This Means

### For Users
- **Collapsible quark views**: Click to expand/collapse quark details per pipeline node
- **Shareable provenance links**: Get a `tri://chain/<hash>` URL proving chain integrity
- **$TRI staking**: Lock earned $TRI with yield (0.1%/day default), auto-restake option
- **56 quarks per query**: Maximum audit granularity with collapse, share, and staking tracking

### For Operators
- **64 immutable records per query** = maximum audit granularity
- **6-phase verification** = linear + DAG + phi-hash + cross-chain + phi-quantum + staking integrity
- **Public share links**: Verifiable chain proofs for external audits
- **Staking system**: Configurable lock duration, yield rate, max stakes, auto-restake

### For Developers
- `collapseNodeQuarks()` / `expandNodeQuarks()` / `getCollapsedSummary()` -- view state management
- `generateShareLink()` / `verifyShareLink()` -- SHA256-based proof URLs
- `stakeReward()` / `unstakeReward()` -- staking lifecycle with yield
- `stakingVerify()` -- Phase F with 2 sub-checks
- 7 new QuarkType variants with classifiers: `isCollapseQuark()`, `isShareQuark()`, `isStakingQuark()`, `isCompressQuark()`, `isVisualizationQuark()`
- `QuarkViewState` enum(u2): expanded, collapsed, hidden
- `ShareableLink`, `StakingConfig`, `StakingRecord`, `StakingResult` structs
- Export v3: 26-byte header, backward compatible with v1/v2

---

## Technical Details

### Architecture

```
Query Input
    |
    v
[GOAL_PARSE] --> Provenance #0 + Quarks Q0-Q6 (7)
    |             (input_capture, goal_classify, oracle_cross_check, phi_verify, collapse_state, hash_verify, gluon_verify)
    v
[DECOMPOSE]  --> Provenance #1 + Quarks Q7-Q13 (7)
    |             (task_decompose, dependency_check, oracle_cross_check, phi_verify, collapse_state, hash_verify, gluon_verify)
    v
[SCHEDULE]   --> Provenance #2 + Quarks Q14-Q19 (6)
    |             (schedule_plan, energy_accounting, dag_checkpoint, compress_quark, hash_verify, gluon_verify)
    v
[EXECUTE]    --> Provenance #3 + Quarks Q20-Q28 (9)
    |             (route_decision, api_call, tvc_cross_check, vsa_bind, oracle_cross_check, phi_verify, share_link, hash_verify, gluon_verify)
    v
[MONITOR]    --> Provenance #4 + Quarks Q29-Q35 (7)
    |             (quality_gate, tvc_cross_check, fake_injection_detect, phi_verify, public_view, hash_verify, gluon_verify)
    v
[ADAPT]      --> Provenance #5 + Quarks Q36-Q41 (6)
    |             (adapt_decision, fake_injection_detect, dag_checkpoint, phi_visual, hash_verify, gluon_verify)
    v
[SYNTHESIZE] --> Provenance #6 + Quarks Q42-Q48 (7)
    |             (merge_result, format_output, oracle_cross_check, reward_mint, staking_lock, hash_verify, gluon_verify)
    v
[DELIVER]    --> Provenance #7 + Quarks Q49-Q55 (7)
    |             (chain_integrity, format_output, energy_accounting, reward_mint, staking_yield, hash_verify, gluon_verify)
    |             + verifyProvenanceChain() -> TRUTH verdict
    |             + verifyQuarkChain() -> Phase A+B+C+D+E+F -> QUARK TRUTH verdict
    |             + generateShareLink() -> ShareLinkGenerated message
    |             + auto-stake if enabled -> StakingEvent message
    |             + collapse state -> CollapseToggle message
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

### $TRI Staking Formula

```
stake(amount):
  if amount < min_stake_utri (100): reject
  if active_stakes >= max_active_stakes (8): reject
  lock_end = now + lock_duration_us (1 day)
  staking_total += amount

unstake(index):
  if now < lock_end: reject (locked)
  yield = amount * yield_rate_per_day * days_elapsed
  staking_total -= amount
  return {staked, yield, remaining}
```

### Export Format v3 (QGC1)

```
[Header: 26 bytes]  (was 18 in v2)
  magic: 'Q','G','C','1'     (4 bytes)
  version: u16 = 3            (2 bytes)
  provenance_count: u8         (1 byte)
  quark_count: u8              (1 byte)
  chain_verified: u8           (1 byte)
  quark_chain_verified: u8     (1 byte)
  total_reward_utri: u64       (8 bytes)
  staking_total_utri: u64      (8 bytes, NEW in v3)

[Provenance Records: 158 bytes each]
[Quark Records: 131 bytes each]

Total: ~9.5KB for 8 provenance + 56 quarks
Backward compatible: v1 (10-byte header), v2 (18-byte header)
```

### Files Modified

| File | Changes |
|------|---------|
| `specs/tri/hdc_golden_chain_v1_5.vibee` | Created -- specification (source of truth) |
| `src/vibeec/golden_chain.zig` | +7 QuarkType variants, +v1.5 constants, +v1.5 types, +3 ChainMessageType, +Phase F, +collapse/share/staking methods, updated 8 emitXxxQuarks (48->56), +export v3, +16 tests |
| `src/wasm_stubs/golden_chain_stub.zig` | +7 QuarkType variants, +v1.5 types, +3 ChainMessageType, +6 agent fields, +7 stub methods |
| `src/vsa/photon_trinity_canvas.zig` | +3 ChatMsgType (collapse_toggle, share_link_generated, staking_event) + colors + labels |

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
v1.5 Collapsible Views + Share Links + $TRI Staking (56 quarks)  <-- YOU ARE HERE
  |
  v
v2.0 Immortal Self-Verifying Agent
```

---

## Conclusion

Golden Chain v1.5 transforms the quark chain into a collapsible, shareable, stakeable provenance system. The 56-quark chain with 29 QuarkTypes provides 64 immutable records per query. Phase F (staking integrity) adds 2 verification sub-checks. Collapsible views enable UI-friendly quark display. Shareable `tri://chain/<hash>` links provide external proof of chain integrity. The $TRI staking system with configurable yield incentivizes long-term verified sessions. Export format v3 (26-byte header) preserves backward compatibility with v1/v2. All 66 golden chain tests pass, WASM stub synchronized, canvas updated. v1.1-v1.4 features remain fully backward compatible.
