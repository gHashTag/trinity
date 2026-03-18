# Golden Chain v1.2: Quark-Gluon Ultra-Granular Provenance

**Date:** 2026-02-13
**Version:** 1.2.0
**Status:** Implemented & Tested

---

## Summary

Golden Chain v1.2 adds a **Quark-Gluon Ultra-Granular Provenance** layer on top of v1.1's 8-record SHA256 hash chain. Every pipeline node now emits 3-6 quark sub-step records, totaling **32 quarks per query**. Gluon entanglement creates a DAG overlay on the linear quark chain, making the topology tamper-evident. Combined: 8 provenance + 32 quarks = **40 immutable records per query**.

---

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Quark records per query | 32 (4+4+3+6+4+3+4+4) | Active |
| QuarkType variants | 16 (14 work + 2 verification) | Active |
| Gluon entanglement refs | 0-2 per quark (DAG) | Active |
| Quark hash chain | SHA256, independent from v1.1 | Active |
| MAX_QUARK_RECORDS | 48 | Configured |
| MAX_ENTANGLE_REFS | 2 | Configured |
| QUARK_CONTENT_DIGEST_LEN | 48 bytes | Configured |
| New ChatMsgTypes | 2 (QuarkStep, GluonEntangle) | Active |
| New tests added | 8 | All passing |
| Total golden chain tests | 23 (15 old + 8 new) | All passing |
| Chat lines per query | ~47 (was ~18) | Expected |
| Memory per agent | ~10KB (quarks 7.2KB + provenance 2.5KB) | Negligible |

---

## What This Means

### For Users
- Every AI response now shows an ultra-granular provenance trail with 32 quark sub-steps
- Each quark displays: `Q[hash_prefix] NODE.QUARK_TYPE | conf% | ent:N`
- Gluon entanglement messages show DAG cross-references between quarks
- Both provenance chain (8/8) and quark chain (32/32) integrity verified at DELIVER

### For Operators
- 40 immutable records per query = unparalleled audit granularity
- DAG topology included in SHA256 hashes = tamper-evident entanglement
- Linear chain + DAG cross-links = dual integrity verification
- Backward-compatible: v1.1 provenance chain remains intact

### For Developers
- `QuarkType` enum (u5, 16 variants) with `getLabel()`, `isVerificationQuark()`, `isWorkQuark()`
- `QuarkRecord` struct with `computeQuarkHash()` and `formatQuarkLine()`
- `recordQuark()` method with optional entanglement references
- `verifyQuarkChain()` with Phase A (linear) + Phase B (DAG) validation
- 8 `emitXxxQuarks()` methods, one per pipeline node

---

## Technical Details

### Architecture

```
Query Input
    |
    v
[GOAL_PARSE] --> Provenance #0 + Quarks Q0-Q3
    |             (input_capture, goal_classify, hash_verify, gluon_verify)
    v
[DECOMPOSE]  --> Provenance #1 + Quarks Q4-Q7
    |             (task_decompose, dependency_check, hash_verify, gluon_verify)
    v
[SCHEDULE]   --> Provenance #2 + Quarks Q8-Q10
    |             (schedule_plan, hash_verify, gluon_verify)
    v
[EXECUTE]    --> Provenance #3 + Quarks Q11-Q16
    |             (route_decision, api_call, tvc_cross_check, vsa_bind, hash_verify, gluon_verify)
    v
[MONITOR]    --> Provenance #4 + Quarks Q17-Q20
    |             (quality_gate, tvc_cross_check, hash_verify, gluon_verify)
    v
[ADAPT]      --> Provenance #5 + Quarks Q21-Q23
    |             (adapt_decision, hash_verify, gluon_verify)
    v
[SYNTHESIZE] --> Provenance #6 + Quarks Q24-Q27
    |             (merge_result, format_output, hash_verify, gluon_verify)
    v
[DELIVER]    --> Provenance #7 + Quarks Q28-Q31
    |             (chain_integrity, format_output, hash_verify, gluon_verify)
    |             + verifyProvenanceChain() -> TRUTH verdict
    |             + verifyQuarkChain() -> QUARK TRUTH verdict
    v
Response Output
```

### QuarkType (16 variants)

| # | Type | Category | Description |
|---|------|----------|-------------|
| 0 | input_capture | Work | Capture raw user input |
| 1 | goal_classify | Work | Classify intent type |
| 2 | task_decompose | Work | Break into subtasks |
| 3 | dependency_check | Work | Check subtask dependencies |
| 4 | schedule_plan | Work | Plan execution order |
| 5 | route_decision | Work | Choose execution backend |
| 6 | api_call | Work | Invoke LLM/tool |
| 7 | tvc_cross_check | Work | TVC corpus verification |
| 8 | vsa_bind | Work | VSA bind operation |
| 9 | quality_gate | Work | Quality threshold check |
| 10 | adapt_decision | Work | Adaptation decision |
| 11 | merge_result | Work | Merge subtask outputs |
| 12 | format_output | Work | Format final response |
| 13 | chain_integrity | Work | Full chain integrity check |
| 14 | hash_verify | Verification | SHA256 hash verification |
| 15 | gluon_verify | Verification | Gluon entanglement verification |

### Quark Hash Construction

```
SHA256(
    prev_quark_hash[32]
    ++ quark_type_label
    ++ node_label
    ++ content_digest[0..digest_len]
    ++ confidence_bytes[4]
    ++ timestamp_bytes[8]
    ++ entangled_indices[0..entangle_count]
)
```

Entanglement indices are included in the hash, making the DAG topology tamper-evident.

### Gluon Entanglement Pattern

- **Genesis (Q0)**: entangle_count=0 (no predecessors)
- **First quark of each node**: entangles with last quark of previous node
- **hash_verify**: entangles with work quarks of same node + hash_verify of previous node
- **gluon_verify**: entangles with own hash_verify + hash_verify of related node
- **Skip-links**: SCHEDULE->GOAL_PARSE, SYNTHESIZE->EXECUTE, DELIVER->EXECUTE

### Verification (verifyQuarkChain)

**Phase A — Linear Chain:**
1. Genesis record has all-zero prev_quark_hash
2. For each quark: recompute hash and verify it matches stored hash
3. For each quark[i>0]: verify prev_quark_hash == quarks[i-1].current_quark_hash

**Phase B — DAG Integrity:**
1. entangle_count in [0, MAX_ENTANGLE_REFS]
2. All entangled_indices point backward (< current index)
3. Genesis quark has entangle_count == 0
4. gluon_verify quarks (except genesis) must have entangle_count > 0

### Chat Visualization

```
[YOU] Build a web server in Zig

[* GOAL_PARSE] Goal: CodeGen detected
[# HASH] [a3f2b1c9] GOAL_PARSE | VERIFIED | 95% | tvc:0.00
[~ QUARK] Q[e2f1a3b4] GOAL_PARSE.INPUT_CAP | 95% | ent:0
[~ QUARK] Q[7c8d9e0f] GOAL_PARSE.GOAL_CLASS | 95% | ent:1
[~ QUARK] Q[1a2b3c4d] GOAL_PARSE.HASH_VER | 95% | ent:2
[~ GLUON] GLUON: Q3<->Q2

[* EXECUTE] pub fn main() !void { ... }
[# HASH] [d9a2c4f1] EXECUTE | VERIFIED | 92% | tvc:0.78
[~ QUARK] Q[5e6f7a8b] EXECUTE.ROUTE_DEC | 92% | ent:2
[~ QUARK] Q[9c0d1e2f] EXECUTE.API_CALL | 92% | ent:1
[~ QUARK] Q[3a4b5c6d] EXECUTE.TVC_XCHK | 92% | ent:2
[~ QUARK] Q[7e8f9a0b] EXECUTE.VSA_BIND | 92% | ent:1
[~ QUARK] Q[1c2d3e4f] EXECUTE.HASH_VER | 92% | ent:2
[~ GLUON] GLUON: Q16<->Q15,Q9

[* DELIVER] Chain complete | Total: 92% | 1350us
[# HASH] [f4e2a7b9] DELIVER | VERIFIED | 92% | tvc:0.00
[~ QUARK] Q[5a6b7c8d] DELIVER.CHAIN_INT | 92% | ent:2
[~ QUARK] Q[9e0f1a2b] DELIVER.FMT_OUT | 92% | ent:1
[~ QUARK] Q[3c4d5e6f] DELIVER.HASH_VER | 92% | ent:2
[~ GLUON] GLUON: Q31<->Q30,Q15
[V TRUTH] Chain integrity: VERIFIED (8/8 hashes valid)
[V TRUTH] Quark chain: VERIFIED (32/32 quarks, DAG intact)
```

### Files Modified

| File | Changes |
|------|---------|
| `specs/tri/hdc_golden_chain_quark_gluon_v1_2.vibee` | Created -- specification (source of truth) |
| `src/vibeec/golden_chain.zig` | +QuarkType(16), +QuarkRecord, +recordQuark(), +verifyQuarkChain(), +8 emitXxxQuarks(), +8 tests |
| `src/vsa/photon_trinity_canvas.zig` | +2 ChatMsgType (quark_step, gluon_entangle), +colors, +labels |
| `src/wasm_stubs/golden_chain_stub.zig` | +QuarkType stub, +QuarkRecord stub, +constants, +agent fields |

---

## Technology Tree

```
v1.0 Golden Chain (8-node pipeline)
  |
  v
v1.1 Truth & Provenance (SHA256, 8 records)  -- DONE
  |
  v
v1.2 Quark-Gluon (32 quarks, DAG entanglement)  <-- YOU ARE HERE
  |
  v
v2.0 Phi-Engine Integration (quantum-inspired truth computation)
  |
  v
v3.0 Immortal Self-Verifying Agent
```

---

## Conclusion

Golden Chain v1.2 establishes ultra-granular provenance for every AI pipeline sub-step. The 32-quark chain with gluon entanglement creates a DAG overlay on the linear hash chain, providing 40 immutable records per query. Entanglement indices are included in SHA256 hashes, making the DAG topology tamper-evident. All 23 golden chain tests pass, compilation succeeds for both native and WASM targets. v1.1 provenance chain remains fully intact (backward compatible).
