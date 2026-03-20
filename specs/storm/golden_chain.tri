# Golden Chain v5.1 — Neuro-Anatomical Pipeline

## Module
storm.golden_chain

## Description
28-link pipeline orchestration with brain zone mapping. Each link maps to a neuroanatomical structure (TNA 2017).

## Dependencies
- std
- storm.brain_zones.* (OFC, HABENULA, AMYGDALA, etc.)
- storm.experience_engine (MNL pattern)
- storm.phoenix_bridge (Self-healing)

## Structs
### Role
enum { planner, coder, reviewer, tester, integrator }

### BrainZone
enum {
    // Prosencephalon
    cortex, dlpfc, ofc, acc, broca, wernicke, insula,
    // Limbic
    hippocampus, amygdala, accumbens, fornix,
    // Basal Ganglia
    striatum, pallidus, nigra,
    // Diencephalon
    thalamus, hypothalamus, habenula,
    // Mesencephalon
    colliculus_s, colliculus_i, ruber, pag, vta,
    // Rhombencephalon
    cerebellum, vermis, pons, medulla, coeruleus, raphe,
}

### Link
- id: u8
- name: []const u8
- role: Role
- brain_zone: BrainZone
- timeout_ms: u64 = 300_000
- checkpoint: bool = true

### State
- current_link: u8
- completed_links: BitSet(28)
- checkpoint_id: ?[]const u8
- phoenix_regenerated: bool

### GoldenChain
- allocator: Allocator
- links: [28]Link = CHAIN_LINKS
- checkpoint_dir: []const u8
- current_state: State

### Result
- success: bool
- final_link: u8
- error: ?[]const u8
- checkpoint_id: ?[]const u8

## Constants
### CHAIN_LINKS
[28]Link with full neuro-mapping:
- Link 1: analyze_request → WERNICKE
- Link 2: check_experience_blacklist → AMYGDALA (MNL)
- Link 3: find_similar_tasks → HIPPOCAMPUS
- Link 4: create_tri_spec → BROCA
- Link 5: validate_spec_schema → DLPFC
- Link 6: vibee_codegen → CEREBELLUM
- Link 7-9: verify/syntax/build → CEREBELLUM
- Link 10-11: unit_tests/vsa_verify → STRIATUM
- Link 12: tri_spec_zig_sync → ACC (conflict monitor)
- Link 13: code_review_quality → DLPFC
- Link 14: security_audit → HABENULA (P1: anti-corruption)
- Link 15-16: performance/docs → DLPFC
- Link 17: api_compatibility → THALAMUS
- Link 18: approve_for_merge → OFC (P1: toxic verdict)
- Link 19-20: e2e/integration → STRIATUM
- Link 21: stress_test → COERULEUS
- Link 22: fuzz_test → STRIATUM
- Link 23: benchmark_baseline → NIGRA
- Link 24: verdict_toxic → OFC (P1: toxic verdict)
- Link 25: git_commit → CEREBELLUM
- Link 26: github_issue_comment → FORNIX
- Link 27: experience_save → HIPPOCAMPUS
- Link 28: phoenix_lineage_update → RAPHE

## Functions
### init(allocator) !GoldenChain
Initialize chain with default checkpoint_dir.

### run(chain, task) !Result
Execute all 28 links. Call brain zones at mapped links.
- Link 2: amygdala.isBlacklisted()
- Link 14: habenula.unfairDetect()
- Link 18: ofc.verdict()
- Link 24: ofc.verdict()
- Link 27: hippocampus.saveEpisode()

### resume(chain, checkpoint_id) !Result
Load checkpoint, continue from current_link.

### saveCheckpoint(chain) !void
Serialize State to checkpoint_dir/{timestamp}.json

### loadCheckpoint(chain, id) !State
Deserialize State from checkpoint file.

### validateHandoff(from_role, to_role, artifact) !bool
Check artifact completeness before role transition.
