# Golden Chain v5.1

## Module
tri.golden_chain

## Description
28-link pipeline orchestration with brain zone mapping. Implemented as subcommand of tri.

## Subcommand
`tri chain run|status|resume`

## Neuro-Mapped Links (28)
Link 1: analyze_request → WERNICKE (brain)
Link 2: check_blacklist → AMYGDALA (brain)
Link 3: find_similar → HIPPOCAMPUS (brain)
Link 4: create_spec → BROCA (brain)
Link 5: validate_spec → DLPFC (brain)
Link 6-12: codegen/verify → CEREBELLUM (brain)
Link 13: quality_review → DLPFC (brain)
Link 14: security_audit → HABENULA (brain)
Link 15-16: performance/docs → DLPFC (brain)
Link 17: api_compat → THALAMUS (brain)
Link 18: approve_merge → OFC (brain) ← P1: toxic verdict
Link 19-20: e2e/integration → STRIATUM (brain)
Link 21: stress_test → COERULEUS (brain)
Link 22: fuzz_test → STRIATUM (brain)
Link 23: benchmark → NIGRA (brain)
Link 24: verdict_toxic → OFC (brain) ← P1: toxic verdict
Link 25: git_commit → CEREBELLUM (brain)
Link 26: github_comment → FORNIX (brain)
Link 27: experience_save → HIPPOCAMPUS (brain)
Link 28: phoenix_lineage → RAPHE (brain)

## Functions
### init() !GoldenChain
Initialize chain with defaults.

### run(chain, task) !Result
Execute all 28 links with brain zone calls.

### resume(chain, id) !Result
Load checkpoint, continue.

### saveCheckpoint(chain) !void
Persist state to .trinity/storm/checkpoints/

## Dependencies
- std
- tri.brain.* (brain zone modules imported)
