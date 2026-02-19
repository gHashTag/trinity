# Golden Chain v2.1: Public Launch + $TRI Mainnet Faucet + Hybrid Canvas 1.0

**Date:** 2026-02-14
**Version:** 2.1.0
**Status:** Implemented & Tested

---

## Summary

Golden Chain v2.1 launches the **Public Release** layer: **$TRI Mainnet Faucet**, **Hybrid Canvas 1.0** (native + WASM), **Public Sessions**, and **Phase H Verification** (faucet integrity). Widens QuarkType from u5 to **u6** (64 capacity), adds **8 new variants** (40 total), increases quarks from 64 to **72 per query** (+1 per node). Export bumped to **v5 (38-byte header)**. Every chain session is now shareable, faucet-claimable, and browser-renderable.

---

## Key Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Quark records per query | 72 (9+9+9+10+9+8+9+9) | Active |
| QuarkType variants | 40 (37 work + 3 verification), u6 | Active |
| New QuarkTypes | faucet_claim, faucet_distribute, canvas_render, canvas_sync, public_session, viral_share, mainnet_anchor, browser_verify | Active |
| Verification phases | 8 (A-H) | Active |
| Phase H sub-checks | 2 (H1: daily limit, H2: cooldown per claimant) | Active |
| Faucet engine | claimFaucet() with cooldown + daily limit | Active |
| Public canvas | initPublicCanvas() + syncCanvasState() | Active |
| Public sessions | createPublicSession() with TTL + share tracking | Active |
| New ChainMessageTypes | FaucetClaim, PublicLaunch, CanvasSync, FaucetDistribution | Active |
| Export format | QGC1 v5 binary, 38-byte header (+4 for faucet/canvas) | Active |
| New tests added | 15 | All passing |
| Total golden chain tests | ~98 (83 old + 15 new) | All passing |
| Memory per agent | ~25KB | Negligible |

---

## What This Means

### For Users
- **$TRI Faucet**: Claim test $TRI tokens directly from the chain (100 uTRI per claim, 1h cooldown)
- **Public sessions**: Every chain result is shareable via browser-renderable links
- **Canvas 1.0**: Dual-mode rendering (WASM for browser, native for desktop)
- **72 quarks per query**: Maximum audit granularity with faucet and canvas tracking
- **4 new message types**: FAUCET, PUBLIC, CANVAS, FAUCET_D visible in canvas

### For Operators
- **80 immutable records per query** (8 provenance + 72 quarks)
- **8-phase verification** = linear + DAG + phi-hash + cross-chain + phi-quantum + staking + self-repair + faucet
- **Faucet safety**: Daily limit (10,000 uTRI), per-claimant cooldown (1 hour), Phase H verification
- **Public session tracking**: View counts, share counts, TTL management
- **u6 QuarkType**: 40/64 slots used, 24 remaining for future expansion

### For Developers
- `claimFaucet(claimant_hash)` -- claim $TRI if within cooldown and daily limit
- `getFaucetState()` -- returns FaucetState with distribution totals
- `initPublicCanvas()` -- set canvas to public mode, version 1.0
- `syncCanvasState()` -- increment render count, return PublicCanvasState
- `createPublicSession()` -- generate PublicSessionInfo with hash and TTL
- `faucetVerify()` -- Phase H with 2 sub-checks (H1: daily limit, H2: cooldown)
- 8 new QuarkType variants with classifiers: `isFaucetQuark()`, `isCanvasQuark()`, `isPublicQuark()`
- `FaucetConfig`, `FaucetClaimRecord`, `FaucetState`, `PublicCanvasState`, `PublicSessionInfo` structs
- Export v5: 38-byte header, backward compatible with v1/v2/v3/v4

---

## Technical Details

### Architecture

```
Query Input
    |
    v
[GOAL_PARSE] --> Provenance #0 + Quarks Q0-Q8 (9)
    |             (input_capture, goal_classify, oracle_cross_check, phi_verify, collapse_state, self_repair, faucet_claim, hash_verify, gluon_verify)
    v
[DECOMPOSE]  --> Provenance #1 + Quarks Q9-Q17 (9)
    |             (task_decompose, dependency_check, oracle_cross_check, phi_verify, collapse_state, evolution_checkpoint, public_session, hash_verify, gluon_verify)
    v
[SCHEDULE]   --> Provenance #2 + Quarks Q18-Q26 (9)
    |             (schedule_plan, energy_accounting, dag_checkpoint, compress_quark, immortal_persist, self_repair, canvas_sync, hash_verify, gluon_verify)
    v
[EXECUTE]    --> Provenance #3 + Quarks Q27-Q36 (10)
    |             (route_decision, api_call, tvc_cross_check, vsa_bind, oracle_cross_check, phi_verify, share_link, mainnet_anchor, hash_verify, gluon_verify)
    v
[MONITOR]    --> Provenance #4 + Quarks Q37-Q45 (9)
    |             (quality_gate, tvc_cross_check, fake_injection_detect, phi_verify, public_view, self_repair, browser_verify, hash_verify, gluon_verify)
    v
[ADAPT]      --> Provenance #5 + Quarks Q46-Q53 (8)
    |             (adapt_decision, fake_injection_detect, dag_checkpoint, phi_visual, evolution_checkpoint, viral_share, hash_verify, gluon_verify)
    v
[SYNTHESIZE] --> Provenance #6 + Quarks Q54-Q62 (9)
    |             (merge_result, format_output, oracle_cross_check, reward_mint, staking_lock, immortal_persist, faucet_distribute, hash_verify, gluon_verify)
    v
[DELIVER]    --> Provenance #7 + Quarks Q63-Q71 (9)
    |             (chain_integrity, format_output, energy_accounting, reward_mint, staking_yield, self_repair, canvas_render, hash_verify, gluon_verify)
    |             + verifyProvenanceChain() -> TRUTH verdict
    |             + verifyQuarkChain() -> Phase A+B+C+D+E+F+G+H -> QUARK TRUTH verdict
    |             + selfRepairChain() -> SelfRepairEvent
    |             + getChainHealth() -> ChainHealthCheck
    |             + persistState() -> ImmortalPersist
    |             + evolveChain() -> EvolutionStep
    |             + claimFaucet() -> FaucetClaim
    |             + initPublicCanvas() -> PublicLaunch
    |             + syncCanvasState() -> CanvasSync
    |             + getFaucetState() -> FaucetDistribution
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
| H | Faucet integrity | H1: all claims within daily limit, H2: no duplicate claimant within cooldown |

### Faucet Engine

```
claimFaucet(claimant_hash):
  if !faucet_config.enabled -> return 0
  if now - last_claim < cooldown -> return 0  (per-claimant)
  if daily_distributed >= daily_limit -> return 0
  record FaucetClaimRecord
  update totals
  return claim_amount_utri (100)

Constants:
  FAUCET_CLAIM_AMOUNT_UTRI = 100
  FAUCET_COOLDOWN_US = 3,600,000,000 (1 hour)
  FAUCET_DAILY_LIMIT_UTRI = 10,000
  MAX_FAUCET_CLAIMS = 64
```

### Export Format v5 (QGC1)

```
[Header: 38 bytes]  (was 34 in v4)
  magic: 'Q','G','C','1'     (4 bytes)
  version: u16 = 5            (2 bytes)
  provenance_count: u8         (1 byte)
  quark_count: u8              (1 byte)
  chain_verified: u8           (1 byte)
  quark_chain_verified: u8     (1 byte)
  total_reward_utri: u64       (8 bytes)
  staking_total_utri: u64      (8 bytes)
  repair_count: u8             (1 byte)
  evolution_count: u8          (1 byte)
  current_generation: u16      (2 bytes)
  persist_count: u32           (4 bytes)
  faucet_claims_count: u16     (2 bytes, NEW in v5)
  canvas_render_count: u16     (2 bytes, NEW in v5)

[Provenance Records: 158 bytes each]
[Quark Records: 131 bytes each]

Total: ~11.8KB for 8 provenance + 72 quarks
Backward compatible: v1 (10-byte), v2 (18-byte), v3 (26-byte), v4 (34-byte)
```

### Files Modified

| File | Changes |
|------|---------|
| `specs/tri/hdc_golden_chain_v2_1_public.vibee` | Created -- specification (source of truth) |
| `src/vibeec/golden_chain.zig` | QuarkType u5->u6 (+8 variants = 40), +v2.1 constants, +v2.1 types (FaucetConfig, FaucetClaimRecord, FaucetState, PublicCanvasState, PublicSessionInfo), +4 ChainMessageType, +Phase H, +faucet/canvas/public methods, updated 8 emitXxxQuarks (64->72), +export v5 (38-byte), +15 tests |
| `src/wasm_stubs/golden_chain_stub.zig` | QuarkType u5->u6 (+8 variants), +v2.1 types, +4 ChainMessageType, +8 agent fields, +6 stub methods, export v5 |
| `src/vsa/photon_trinity_canvas.zig` | +4 ChatMsgType (faucet_claim, public_launch, canvas_sync, faucet_distribution) + colors + labels + mapping |

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
v2.0 Immortal Self-Verifying Agent (64 quarks, FULL u5)  -- DONE
  |
  v
v2.1 Public Launch + $TRI Faucet + Canvas 1.0 (72 quarks, u6)  <-- YOU ARE HERE
  |
  v
v2.2+ Future: Distributed consensus, cross-node faucet, on-chain evolution
```

---

## Conclusion

Golden Chain v2.1 transforms the chain into a **Public-First Platform**. The 72-quark chain with 40 QuarkTypes (u6) provides 80 immutable records per query. The $TRI mainnet faucet enables permissionless token claims with Phase H verification ensuring integrity. Hybrid Canvas 1.0 renders chain state in both browser (WASM) and desktop (native) modes. Public sessions with TTL and share tracking make every chain result browser-renderable and shareable. Export format v5 (38-byte header) preserves backward compatibility with v1-v4. All golden chain tests pass, WASM stub synchronized, canvas updated with 4 new message types. The QuarkType enum now uses u6 with 40/64 slots occupied, leaving 24 for future expansion.
