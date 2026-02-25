# Golden Chain v1.3: VSA-Semantic Quark Query + On-Chain Export

**Date:** 2026-02-13
**Version:** 1.3.0
**Status:** Implemented & Tested

---

## Summary

Golden Chain v1.3 adds **VSA-Semantic Quark Query**, **On-Chain Binary Export**, **Verbosity Control**, and **3 new adversarial/accounting QuarkTypes** on top of v1.2's 32-quark gluon DAG chain. Quarks increase from 32 to **40 per query** (+1 per node). Verification gains two new phases: **phi-hash balance check** (Phase C) and **cross-chain verification** (Phase D). Combined: 8 provenance + 40 quarks = **48 immutable records per query**.

---

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Quark records per query | 40 (5+5+4+7+5+4+5+5) | Active |
| QuarkType variants | 19 (17 work + 2 verification) | Active |
| New QuarkTypes | fake_injection_detect, oracle_cross_check, energy_accounting | Active |
| Gluon entanglement refs | 0-2 per quark (DAG) | Active |
| Verification phases | 4 (A: linear, B: DAG, C: phi-hash, D: cross-chain) | Active |
| QuarkVerbosity modes | 3 (full, summary, silent) | Active |
| QuarkSearchQuery filters | 7 (type, node, conf min/max, verification_only, work_only, min_entangle) | Active |
| Export format | QGC1 binary, ~6.5KB per chain | Active |
| New tests added | 12 | All passing |
| Total golden chain tests | 35 (23 old + 12 new) | All passing |
| Chat lines per query (full) | ~55 (was ~47) | Expected |
| Chat lines per query (summary) | ~18 | Expected |
| Memory per agent | ~15KB (quarks 9.4KB + provenance 2.5KB + export 6.5KB stack) | Negligible |

---

## What This Means

### For Users
- **Verbosity control**: Choose `full` (every quark line), `summary` (one line per node), or `silent` (no quark output)
- **Quark search**: Filter quarks by type, node, confidence range, verification/work only, entanglement count
- **Adversarial detection**: Fake injection detection and oracle cross-checks built into pipeline
- **Energy accounting**: Compute cost tracking at sub-step level

### For Operators
- **48 immutable records per query** = maximum audit granularity
- **Binary export** (`QGC1` format) enables on-chain shard storage via Trinity Storage v2.1
- **4-phase verification** = linear chain + DAG + phi-hash + cross-chain
- **Backward compatible**: v1.1 provenance + v1.2 quark chain fully intact

### For Developers
- `QuarkSearchQuery` struct with 7 filter fields + `searchQuarks()` method
- `serializeQuarkChain()` / `deserializeQuarkChain()` for binary roundtrip
- `QuarkVerbosity` enum gating message emission (records always stored)
- `phiHashCheck()` — XOR quark hashes, check mod-3 residue class distribution
- `crossChainVerify()` — verify quark node ordering matches provenance chain
- 3 new QuarkType variants with `isAdversarialQuark()` and `isAccountingQuark()` classifiers

---

## Technical Details

### Architecture

```
Query Input
    |
    v
[GOAL_PARSE] --> Provenance #0 + Quarks Q0-Q4 (5)
    |             (input_capture, goal_classify, oracle_cross_check, hash_verify, gluon_verify)
    v
[DECOMPOSE]  --> Provenance #1 + Quarks Q5-Q9 (5)
    |             (task_decompose, dependency_check, oracle_cross_check, hash_verify, gluon_verify)
    v
[SCHEDULE]   --> Provenance #2 + Quarks Q10-Q13 (4)
    |             (schedule_plan, energy_accounting, hash_verify, gluon_verify)
    v
[EXECUTE]    --> Provenance #3 + Quarks Q14-Q20 (7)
    |             (route_decision, api_call, tvc_cross_check, vsa_bind, oracle_cross_check, hash_verify, gluon_verify)
    v
[MONITOR]    --> Provenance #4 + Quarks Q21-Q25 (5)
    |             (quality_gate, tvc_cross_check, fake_injection_detect, hash_verify, gluon_verify)
    v
[ADAPT]      --> Provenance #5 + Quarks Q26-Q29 (4)
    |             (adapt_decision, fake_injection_detect, hash_verify, gluon_verify)
    v
[SYNTHESIZE] --> Provenance #6 + Quarks Q30-Q34 (5)
    |             (merge_result, format_output, oracle_cross_check, hash_verify, gluon_verify)
    v
[DELIVER]    --> Provenance #7 + Quarks Q35-Q39 (5)
    |             (chain_integrity, format_output, energy_accounting, hash_verify, gluon_verify)
    |             + verifyProvenanceChain() -> TRUTH verdict
    |             + verifyQuarkChain() -> Phase A+B+C+D -> QUARK TRUTH verdict
    v
Response Output
```

### QuarkType v1.3 (19 variants)

| # | Type | Category | Description |
|---|------|----------|-------------|
| 0-13 | (v1.2 work types) | Work | Unchanged from v1.2 |
| 14 | hash_verify | Verification | SHA256 hash verification |
| 15 | gluon_verify | Verification | Gluon entanglement verification |
| 16 | fake_injection_detect | Work (Adversarial) | Detect injection/hallucination |
| 17 | oracle_cross_check | Work (Adversarial) | Cross-check against known-good |
| 18 | energy_accounting | Work (Accounting) | Track compute cost |

### Verification Phases

| Phase | Check | Description |
|-------|-------|-------------|
| A | Linear chain | Genesis zero-hash, recompute all hashes, verify chain links |
| B | DAG integrity | Entanglement bounds, backward refs only, gluon_verify has refs |
| C | Phi-hash balance | XOR all hashes, mod-3 residue classes >= 2 of 3 present |
| D | Cross-chain | Node ordering non-decreasing, every provenance node has quarks |

### Export Format (QGC1)

```
[Header: 10 bytes]
  magic: 'Q','G','C','1'     (4 bytes)
  version: u16 = 1            (2 bytes)
  provenance_count: u8         (1 byte)
  quark_count: u8              (1 byte)
  chain_verified: u8           (1 byte)
  quark_chain_verified: u8     (1 byte)

[Provenance Records: 158 bytes each]
  step_index + node + digest[64] + digest_len + conf + tvc + verdict
  + timestamp + latency + source + prev_hash[32] + current_hash[32]

[Quark Records: 131 bytes each]
  quark_index + type + node + digest[48] + digest_len + conf
  + timestamp + prev_hash[32] + current_hash[32] + ent_indices[2] + ent_count

Total: ~6.5KB for 8 provenance + 40 quarks
```

### Files Modified

| File | Changes |
|------|------------|
| `specs/tri/hdc_golden_chain_v1_3_vsa_onchain.vibee` | Created -- specification (source of truth) |
| `src/vibeec/golden_chain.zig` | +3 QuarkType variants, +QuarkVerbosity, +QuarkSearchQuery, +export constants, +searchQuarks(), +serialize/deserialize, +phiHashCheck(), +crossChainVerify(), +emitNodeQuarkSummary(), updated 8 emitXxxQuarks() (32->40), +12 tests |
| `src/wasm_stubs/golden_chain_stub.zig` | +3 QuarkType variants, +QuarkVerbosity, +QuarkSearchQuery, +export constants, +quark_verbosity field, +stub methods |
| `src/vsa/photon_trinity_canvas.zig` | NO CHANGE (already handles QuarkStep/GluonEntangle) |

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
v1.3 VSA Query + On-Chain Export (40 quarks, search, serialize)  <-- YOU ARE HERE
  |
  v
v2.0 Phi-Engine Integration (quantum-inspired truth computation)
  |
  v
v3.0 Immortal Self-Verifying Agent
```

---

## Conclusion

Golden Chain v1.3 transforms the quark chain from a passive audit trail into a queryable, exportable, verbosity-controlled provenance system. The 40-quark chain with 3 new adversarial/accounting types provides 48 immutable records per query. QuarkSearchQuery enables structured filtering across the chain. Binary export (QGC1 format, ~6.5KB) enables on-chain shard storage. Phi-hash and cross-chain verification phases add mathematical and structural integrity checks. All 35 golden chain tests pass, WASM stub synchronized. v1.1 provenance + v1.2 quark chain remain fully backward compatible.
