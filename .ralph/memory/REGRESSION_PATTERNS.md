# Regression Patterns — Trinity

Record of failed approaches, anti-patterns, and their root causes.
Consult this file BEFORE fixing errors or trying unfamiliar approaches.

---

## Entry Format

```markdown
---
date: YYYY-MM-DD
anti-pattern: description
root-cause: analysis
---
### Brief description of failure

- **Anti-pattern:** What was tried that failed
- **Correct approach:** What to do instead
- **Files:** Key files involved
```

---

## How to Use

1. **When encountering an error** — search this file for the error message
2. **Before trying a new approach** — check it's not listed as an anti-pattern
3. **After analyzing a failure** — add entry immediately to prevent recurrence
4. **During code review** — verify no known anti-patterns are reintroduced

---

## Known Anti-Patterns

---
date: 2026-02-17
anti-pattern: Wrong binary path
root-cause: Zig build system separation
---
### Wrong VIBEE compiler binary path
- **Correct approach:** Use `zig build vibee -- gen <spec.vibee>`

---
date: 2026-02-17
anti-pattern: Manual edit of output
root-cause: Generation override
---
### Editing generated files directly
- **Correct approach:** Edit the source spec in `specs/tri/*.vibee`

---
date: 2026-02-17
anti-pattern: Commit to main
root-cause: Branch protection policy
---
### Committing to main during autonomous runs
- **Correct approach:** Always create `ralph/<task-slug>` branch

---
date: 2026-02-17
anti-pattern: Return typed value from !void function
root-cause: Codegen signature mismatch with implementation blocks
---
### Implementation blocks returning typed values from !void functions
- **Anti-pattern:** Writing `return InputLanguage.english;` in a `.vibee` implementation block. The codegen emits all behavior functions as `pub fn name() !void`, so returning an enum/struct value causes a Zig compile error.
- **Correct approach:** Implementation blocks in `.vibee` specs must only `return;` or use `try`/error flow. To "return" values, use output parameters or debug print stubs. The codegen signature should be updated in the future to support return types.
- **Files:** `specs/tri/multilingual_codegen.vibee`, `src/vibeec/multilingual_engine.zig`
---
date: 2026-03-07T15:01:45+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/beal_simd.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/beal_simd.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/beal_simd.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:18:35+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/hdc_igla_hybrid_v2_1.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/hdc_igla_hybrid_v2_1.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/hdc_igla_hybrid_v2_1.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:18:40+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/full_engine_stress_test.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/full_engine_stress_test.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/full_engine_stress_test.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:19:00+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/100_repl_test_coverage_for_all_195_tri_cli_commands.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/100_repl_test_coverage_for_all_195_tri_cli_commands.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/100_repl_test_coverage_for_all_195_tri_cli_commands.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:19:32+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/autonomous_agent.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/autonomous_agent.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/autonomous_agent.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:19:34+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/babi_pathfinding.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/babi_pathfinding.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/babi_pathfinding.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:19:35+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/absolute_infinity_v2.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/absolute_infinity_v2.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/absolute_infinity_v2.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:19:37+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/babi_qa_benchmark.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/babi_qa_benchmark.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/babi_qa_benchmark.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:19:48+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/beal_simd.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/beal_simd.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/beal_simd.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:19:56+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/adversarial_consciousness_test.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/adversarial_consciousness_test.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/adversarial_consciousness_test.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:20:09+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/bipolar_vsa.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/bipolar_vsa.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/bipolar_vsa.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:20:10+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/bitnet_loader.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/bitnet_loader.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/bitnet_loader.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:20:11+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/bitnet_tensor.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/bitnet_tensor.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/bitnet_tensor.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:20:12+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/branch_kinship.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/branch_kinship.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/branch_kinship.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:20:35+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/cli_binary_integration.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/cli_binary_integration.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/cli_binary_integration.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:20:35+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/cli_query_dispatch.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/cli_query_dispatch.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/cli_query_dispatch.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:20:36+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/clutrr_depth_scaling.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/clutrr_depth_scaling.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/clutrr_depth_scaling.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:20:37+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/clutrr_kinship_benchmark.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/clutrr_kinship_benchmark.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/clutrr_kinship_benchmark.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:20:43+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/code_execution_system.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/code_execution_system.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/code_execution_system.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:21:05+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/combined_spatial_kg.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/combined_spatial_kg.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/combined_spatial_kg.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:21:21+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/autonomous_universe.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/autonomous_universe.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/autonomous_universe.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:21:23+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/peer_ranking.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/peer_ranking.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/peer_ranking.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:21:26+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/auto_healing.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/auto_healing.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/auto_healing.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:21:28+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/self_scale_agents.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/self_scale_agents.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/self_scale_agents.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:21:31+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/compositional_query_dispatch.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/compositional_query_dispatch.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/compositional_query_dispatch.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:21:33+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/confidence_gated_chains.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/confidence_gated_chains.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/confidence_gated_chains.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:22:07+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/clusters.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/clusters.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/clusters.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:22:07+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/effects.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/effects.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/effects.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:22:10+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/panel.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/panel.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/panel.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:22:11+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/panel_system.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/panel_system.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/panel_system.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:22:20+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/wave_scrollview.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/wave_scrollview.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/wave_scrollview.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:22:20+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/before_big_bang.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/before_big_bang.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/before_big_bang.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:22:32+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/black_hole_information.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/black_hole_information.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/black_hole_information.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:22:58+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/e2e_mixed_pipeline.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/e2e_mixed_pipeline.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/e2e_mixed_pipeline.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:23:18+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/clinical_validation.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/clinical_validation.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/clinical_validation.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:23:18+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/event_sourcing_cqrs.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/event_sourcing_cqrs.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/event_sourcing_cqrs.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:23:19+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/codebase_context.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/codebase_context.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/codebase_context.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:23:23+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/expanded_babi_benchmark.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/expanded_babi_benchmark.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/expanded_babi_benchmark.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:23:33+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/conscious_active_inference.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/conscious_active_inference.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/conscious_active_inference.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:23:38+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/consciousness_cluster.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/consciousness_cluster.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/consciousness_cluster.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:23:39+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/file_io_system.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/file_io_system.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/file_io_system.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:23:49+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/coptic_gematria.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/coptic_gematria.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/coptic_gematria.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:24:10+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/cycle100_self_funding.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/cycle100_self_funding.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/cycle100_self_funding.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:24:11+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/cycle101_orchestrator_v2.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/cycle101_orchestrator_v2.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/cycle101_orchestrator_v2.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:24:12+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/cycle102_orchestrator_v2_complete.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/cycle102_orchestrator_v2_complete.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/cycle102_orchestrator_v2_complete.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:24:13+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/cycle103_full_integration.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/cycle103_full_integration.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/cycle103_full_integration.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:24:25+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/fluent_chat_complete.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/fluent_chat_complete.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/fluent_chat_complete.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:24:29+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/cycle105_orchestrator_full_integration.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/cycle105_orchestrator_full_integration.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/cycle105_orchestrator_full_integration.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:24:30+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/cycle106_orchestrator_v2_final.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/cycle106_orchestrator_v2_final.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/cycle106_orchestrator_v2_final.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:24:46+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/cycle113_global_adoption.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/cycle113_global_adoption.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/cycle113_global_adoption.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:25:11+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/cycle_96_self_evolving_sacred_intelligence.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/cycle_96_self_evolving_sacred_intelligence.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/cycle_96_self_evolving_sacred_intelligence.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:25:12+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/cycle_97_full_autonomous_sacred_evolution.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/cycle_97_full_autonomous_sacred_evolution.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/cycle_97_full_autonomous_sacred_evolution.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:25:15+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/full_engine_stress_test.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/full_engine_stress_test.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/full_engine_stress_test.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:25:40+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/graceful_degradation.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/graceful_degradation.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/graceful_degradation.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:26:22+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/evolving_dark_energy.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/evolving_dark_energy.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/evolving_dark_energy.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:28:50+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/higher_order_consciousness.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/higher_order_consciousness.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/higher_order_consciousness.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:30:04+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/hdc_igla_hybrid_v2_1.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/hdc_igla_hybrid_v2_1.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/hdc_igla_hybrid_v2_1.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:31:38+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/hdc_rl_agent.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/hdc_rl_agent.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/hdc_rl_agent.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:31:48+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/hdc_stream_classifier.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/hdc_stream_classifier.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/hdc_stream_classifier.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:31:50+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/measurement_problem.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/measurement_problem.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/measurement_problem.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:32:59+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/heap_massive_kg.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/heap_massive_kg.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/heap_massive_kg.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:33:13+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/hybrid_bipolar_ternary.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/hybrid_bipolar_ternary.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/hybrid_bipolar_ternary.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:33:14+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/hybrid_chain_capacity.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/hybrid_chain_capacity.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/hybrid_chain_capacity.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:33:20+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/hybrid_noise_comparison.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/hybrid_noise_comparison.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/hybrid_noise_comparison.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:33:48+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/omega_phase.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/omega_phase.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/omega_phase.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:07+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_arbitrary_beam_search.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_arbitrary_beam_search.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_arbitrary_beam_search.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:08+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_arbitrary_graph_cycles.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_arbitrary_graph_cycles.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_arbitrary_graph_cycles.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:09+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_associative_memory.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_associative_memory.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_associative_memory.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:09+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_beam_search.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_beam_search.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_beam_search.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:10+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_dijkstra_priority.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_dijkstra_priority.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_dijkstra_priority.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:11+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_hybrid_benchmark.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_hybrid_benchmark.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_hybrid_benchmark.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:11+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_indexed_planning.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_indexed_planning.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_indexed_planning.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:12+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_indexed_vs_flat_benchmark.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_indexed_vs_flat_benchmark.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_indexed_vs_flat_benchmark.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:17+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_intermediate_indexing.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_intermediate_indexing.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_intermediate_indexing.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:18+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_massive_1000.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_massive_1000.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_massive_1000.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:19+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_massive_multihop.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_massive_multihop.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_massive_multihop.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:19+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_massive_noise_benchmark.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_massive_noise_benchmark.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_massive_noise_benchmark.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:20+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_massive_weighted.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_massive_weighted.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_massive_weighted.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:21+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_multihop_discovery.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_multihop_discovery.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_multihop_discovery.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:21+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_multiple_paths.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_multiple_paths.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_multiple_paths.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:22+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_path_discovery.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_path_discovery.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_path_discovery.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:28+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_planning_prototype.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_planning_prototype.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_planning_prototype.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:28+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_priority_multihop.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_priority_multihop.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_priority_multihop.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:33+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_scale_benchmark.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_scale_benchmark.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_scale_benchmark.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:34+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_scaled_superposition.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_scaled_superposition.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_scaled_superposition.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:35+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_stress_test.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_stress_test.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_stress_test.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:35+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_superposition_subgraph.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_superposition_subgraph.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_superposition_subgraph.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:40+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_weight_noise_benchmark.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_weight_noise_benchmark.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_weight_noise_benchmark.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:41+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/kg_weighted_edges.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/kg_weighted_edges.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/kg_weighted_edges.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:56+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/large_codebook_scaling.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/large_codebook_scaling.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/large_codebook_scaling.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:34:57+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/phenomenal_binding.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/phenomenal_binding.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/phenomenal_binding.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:35:50+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/massive_batch_integration.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/massive_batch_integration.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/massive_batch_integration.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:35:50+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/massive_unified_kg.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/massive_unified_kg.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/massive_unified_kg.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:36:00+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/quantum_brain_network.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/quantum_brain_network.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/quantum_brain_network.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:36:04+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/quantum_decoherence_protection.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/quantum_decoherence_protection.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/quantum_decoherence_protection.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:36:19+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/ralph_pulse_integration.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/ralph_pulse_integration.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/ralph_pulse_integration.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:36:34+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/ml_model.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/ml_model.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/ml_model.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:36:56+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/multi_hop_chain_fluency.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/multi_hop_chain_fluency.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/multi_hop_chain_fluency.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:36:57+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/multi_hop_cli_pipeline.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/multi_hop_cli_pipeline.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/multi_hop_cli_pipeline.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:37:10+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/multi_query_batch.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/multi_query_batch.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/multi_query_batch.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:37:30+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/named_entity_registry.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/named_entity_registry.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/named_entity_registry.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:37:36+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/neuro_symbolic_comparison.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/neuro_symbolic_comparison.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/neuro_symbolic_comparison.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:38:21+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/observability_tracing.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/observability_tracing.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/observability_tracing.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:38:21+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/open_query_kg.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/open_query_kg.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/open_query_kg.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:38:58+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/phi_loop.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/phi_loop.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/phi_loop.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:39:02+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/plugin_extension.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/plugin_extension.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/plugin_extension.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:39:20+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/swarm_coordinator.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/swarm_coordinator.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/swarm_coordinator.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:39:36+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/ralph_agent.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/ralph_agent.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/ralph_agent.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:39:37+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/telegram_command_router.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/telegram_command_router.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/telegram_command_router.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:39:37+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/ralph_canvas_monitor.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/ralph_canvas_monitor.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/ralph_canvas_monitor.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:39:42+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/telegram_pulse_emitter.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/telegram_pulse_emitter.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/telegram_pulse_emitter.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:39:58+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/repl_interactive_system.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/repl_interactive_system.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/repl_interactive_system.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:40:17+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/robustness_distractor.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/robustness_distractor.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/robustness_distractor.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:40:38+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/treesitter_improvements.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/treesitter_improvements.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/treesitter_improvements.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:41:09+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/sota_noise_comparison.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/sota_noise_comparison.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/sota_noise_comparison.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:42:13+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/streaming_multimodal.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/streaming_multimodal.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/streaming_multimodal.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:42:26+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/swarm_watch.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/swarm_watch.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/swarm_watch.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:42:57+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/temporal_workflow.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/temporal_workflow.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/temporal_workflow.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:45:04+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/unified_multi_domain_fusion.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/unified_multi_domain_fusion.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/unified_multi_domain_fusion.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:45:05+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/unified_multimodal_agent.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/unified_multimodal_agent.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/unified_multimodal_agent.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:45:14+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/version_control_system.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/version_control_system.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/version_control_system.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:45:33+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/vsa_imported_system.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/vsa_imported_system.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/vsa_imported_system.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:45:54+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/vsa_real_system.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/vsa_real_system.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/vsa_real_system.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:46:13+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/vsa_swarm_production_32.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/vsa_swarm_production_32.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/vsa_swarm_production_32.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:46:20+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/webarena_agent.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/webarena_agent.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/webarena_agent.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes
---
date: 2026-03-08T12:46:25+00:00
anti-pattern: Zig syntax error error
root-cause: Auto-fix not yet implemented for this error type
---
### formatting check failed (run 'zig fmt generated/webarena_browser.zig' to fix)

- **Anti-pattern:** Zig syntax error error
- **Symptom:** formatting check failed (run 'zig fmt generated/webarena_browser.zig' to fix)
- **Correct approach:** TBD
- **Files:** generated/webarena_browser.zig:1:1
- **Attempted fixes:**
  Auto-fix attempted

- **Manual review required:** Yes

---
date: 2026-03-09
anti-pattern: Non-power-of-2 BRAM memory depth
root-cause: Yosys BRAM cascade address decode broken for non-power-of-2
---
### BRAM array with non-power-of-2 depth fails on hardware

- **Anti-pattern:** `reg [1:0] mem [0:177146]` — passes simulation, fails on hardware (reads as 0)
- **Correct approach:** `localparam MEM_DEPTH = 1 << ADDR_WIDTH; reg [1:0] mem [0:MEM_DEPTH-1]`
- **Files:** fpga/openxc7-synth/ternary_matvec_bram.v

---
date: 2026-03-09
anti-pattern: Using % modulo in synthesizable Verilog
root-cause: Yosys generates combinational divider — timing failure risk at 50 MHz
---
### Using % operator for modular arithmetic on FPGA

- **Anti-pattern:** `(idx % 3 == 0) ? ...` — full combinational divider
- **Correct approach:** `reg [1:0] j_mod3; j_mod3 <= (j_mod3 == 2'd2) ? 2'd0 : j_mod3 + 1;`
- **Files:** fpga/openxc7-synth/ternary_matvec_243x729_top.v

---
date: 2026-03-10
anti-pattern: Using Verilog division operator in synthesizable code
root-cause: Combinational divider exceeds timing budget and produces wrong signs for signed operands
---
### Verilog `/` division operator fails on FPGA

- **Anti-pattern:** `result = value / divisor;` — Yosys generates full combinational divider that (a) can't meet 50 MHz timing for wide operands, (b) produces wrong results when sign bit is set
- **Correct approach:** Use shift-based normalization: `find_msb(mean_abs)` priority encoder + barrel shift. For RMS norm: `shift_amt = msb_pos - FRAC_BITS; output = abs_val >> shift_amt;` with explicit sign restoration
- **Files:** fpga/openxc7-synth/ternary_rmsnorm.v
