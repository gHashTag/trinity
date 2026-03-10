# specs/INVENTORY.md

## Spec Audit Results (2026-03-10)

| Category | Count | Description |
|----------|-------|-------------|
| LIVE | 102 | Has matching .zig implementation |
| VALID | 324 | Valid structure, no .zig yet |
| DEAD | 125 | Archived to archive/specs/dead/ |
| META | 76 | Archived to archive/specs/meta/ |
| **TOTAL** | **629** | |

---

## LIVE Specs (102)

| Spec | Implementation | Lines | Module |
|------|----------------|-------|--------|
| `specs/api/unified-v1.tri` | `src/phi_loop/api.zig` | 255 | unified_api |
| `specs/fpga/test_values.tri` | `src/plasma/test_values.zig` | 50 | test_values |
| `specs/needle/ann_benchmark.tri` | `src/needle/ann_benchmark.zig` | 198 | ann_benchmark |
| `specs/needle/ann_brute_simd.tri` | `src/needle/ann_brute_simd.zig` | 135 | ann_brute_simd |
| `specs/needle/ann_ivf_pq.tri` | `src/needle/ann_ivf_pq.zig` | 178 | ann_ivf_pq |
| `specs/needle/ann_lsh_ternary.tri` | `src/needle/ann_lsh_ternary.zig` | 168 | ann_lsh_ternary |
| `specs/needle/core.tri` | `src/vsa/core.zig` | 302 | needle-core |
| `specs/needle/fix_parser_memory_leak.tri` | `src/needle/zig_parser.zig` | 28 | fix_parser_memory_leak |
| `specs/tri/abiogenesis.tri` | `src/origin/abiogenesis.zig` | 170 | abiogenesis |
| `specs/tri/absolute_infinity_v2.tri` | `src/sacred/absolute_infinity.zig` | 227 | absolute_infinity |
| `specs/tri/active_inference.tri` | `src/consciousness/active_inference.zig` | 297 | active_inference |
| `specs/tri/adversarial_consciousness_test.tri` | `src/consciousness/testing/adversarial_test.zig` | 199 | adversarial_consciousness_test |
| `specs/tri/agent_mu_self_evolution.tri` | `src/agent_mu/agent_mu.zig` | 138 | agent_mu_self_evolution |
| `specs/tri/anthropic_client.tri` | `src/phi-engine/core/anthropic_client.zig` | 29 | anthropic_client |
| `specs/tri/arrow_of_time.tri` | `src/time/arrow_of_time.zig` | 133 | arrow_of_time |
| `specs/tri/autonomous_universe.tri` | `src/tri/autonomous_universe.zig` | 159 | autonomous_universe |
| `specs/tri/b2t_llm_assist.tri` | `src/b2t/b2t_llm_assist.zig` | 29 | b2t_llm_assist |
| `specs/tri/b2t_llm_lifter.tri` | `src/b2t/b2t_llm_lifter.zig` | 29 | b2t_llm_lifter |
| `specs/tri/b2t_prompts.tri` | `src/b2t/b2t_prompts.zig` | 29 | b2t_prompts |
| `specs/tri/b2t_rag.tri` | `src/b2t/b2t_rag.zig` | 29 | b2t_rag |
| `specs/tri/baryogenesis.tri` | `src/baryogenesis/sacred_baryon.zig` | 250 | baryogenesis |
| `specs/tri/before_big_bang.tri` | `src/cosmos/before_big_bang.zig` | 388 | before_big_bang |
| `specs/tri/black_hole_information.tri` | `src/gravity/black_hole_information.zig` | 399 | black_hole_information |
| `specs/tri/cache.tri` | `src/vibeec/codegen/patterns/cache.zig` | 29 | cache |
| `specs/tri/chemistry_cli.tri` | `src/tri/sacred/chemistry.zig` | 294 | chemistry_cli |
| `specs/tri/codegen_utils.tri` | `src/vibeec/codegen/utils.zig` | 556 | codegen_utils |
| `specs/tri/commands.tri` | `src/tri/math/commands.zig` | 29 | commands |
| `specs/tri/conscious_active_inference.tri` | `src/consciousness/inference/quantum_active_inference.zig` | 223 | conscious_active_inference |
| `specs/tri/crypto.tri` | `src/trinity_node/crypto.zig` | 29 | crypto |
| `specs/tri/cycle106_orchestrator_v2_final.tri` | `src/tri/orchestrator_v2_full.zig` | 492 | orchestrator_v2 |
| `specs/tri/cycle99_cli_integration.tri` | `src/tri/tri_cli_integration.zig` | 527 | cycle99_cli_integration |
| `specs/tri/discovery.tri` | `src/trinity_node/discovery.zig` | 29 | discovery |
| `specs/tri/dynamic_memory.tri` | `src/tri/dynamic_memory.zig` | 86 | dynamic_memory |
| `specs/tri/eeg_pipeline.tri` | `src/consciousness/integration/eeg_pipeline.zig` | 109 | eeg_pipeline |
| `specs/tri/evolving_dark_energy.tri` | `src/cosmos/evolving_dark_energy.zig` | 331 | evolving_dark_energy |
| `specs/tri/flatness_problem_solution.tri` | `src/cosmos/flatness_problem_solution.zig` | 178 | flatness_problem_solution |
| `specs/tri/forge_bitstream.tri` | `src/forge/bitstream.zig` | 246 | forge_bitstream |
| `specs/tri/full_model.tri` | `src/reality/full_model.zig` | 200 | full_model |
| `specs/tri/gwt_model.tri` | `src/consciousness/gwt_model.zig` | 256 | gwt_model |
| `specs/tri/holy_core_emitter_phase1.tri` | `src/vibeec/codegen/emitter.zig` | 457 | holy_core_emitter_phase1 |
| `specs/tri/holy_core_parser_phase1.tri` | `src/vibeec/parser_utils.zig` | 410 | holy_core_parser_phase1 |
| `specs/tri/holy_core_type_resolver.tri` | `src/vibeec/codegen/type_resolver.zig` | 389 | holy_core_type_resolver |
| `specs/tri/http_client.tri` | `src/phi-engine/core/http_client.zig` | 29 | http_client |
| `specs/tri/igla_emitter_phase2.tri` | `src/vibeec/codegen/emitter.zig` | 282 | igla_emitter_phase2 |
| `specs/tri/igla_parser_phase2.tri` | `src/vibeec/parser_sections.zig` | 136 | igla_parser_phase2 |
| `specs/tri/iit_v4.tri` | `src/consciousness/iit_v4.zig` | 295 | iit_v4 |
| `specs/tri/integration_tests.tri` | `src/consciousness/tests/integration_tests.zig` | 29 | integration_tests |
| `specs/tri/jit_adapter.tri` | `src/vibeec/jit_adapter.zig` | 29 | jit_adapter |
| `specs/tri/learning_loops.tri` | `src/tri/learning_loops.zig` | 111 | learning_loops |
| `specs/tri/lempel_ziv.tri` | `src/consciousness/metrics/lempel_ziv.zig` | 72 | lempel_ziv |
| `specs/tri/logger.tri` | `src/agent_mu/logger.zig` | 29 | logger |
| `specs/tri/magnetic_monopoles.tri` | `src/monopoles/sacred_monopoles.zig` | 246 | magnetic_monopoles |
| `specs/tri/math/math_bench.tri` | `src/bench.zig` | 332 | math_bench |
| `specs/tri/math/math_cli.tri` | `src/tri/math/commands.zig` | 446 | math_cli |
| `specs/tri/math/math_compute.tri` | `src/tri/math/compute.zig` | 314 | math_compute |
| `specs/tri/math/math_constants.tri` | `src/constants.zig` | 246 | math_constants |
| `specs/tri/math/math_eval.tri` | `src/tri/math/eval.zig` | 290 | math_eval |
| `specs/tri/math/math_format.tri` | `src/tri/math/format.zig` | 283 | math_format |
| `specs/tri/math/math_identities.tri` | `src/tri/math/identities.zig` | 321 | math_identities |
| `specs/tri/measurement_problem.tri` | `src/quantum/measurement_problem.zig` | 249 | measurement_problem |
| `specs/tri/multilingual_codegen.tri` | `src/vibeec/multilingual_engine.zig` | 165 | multilingual_codegen |
| `specs/tri/network.tri` | `src/depin/network.zig` | 29 | network |
| `specs/tri/neural_gamma.tri` | `src/consciousness/neural_gamma.zig` | 161 | neural_gamma |
| `specs/tri/omega_phase.tri` | `src/needle/omega.zig` | 285 | omega_phase |
| `specs/tri/openai_client.tri` | `src/phi-engine/core/openai_client.zig` | 29 | openai_client |
| `specs/tri/oracle_watchdog.tri` | `tools/mcp/trinity_mcp/oracle_watchdog.zig` | 125 | oracle_watchdog |
| `specs/tri/origin_of_life.tri` | `src/biology/origin_of_life.zig` | 132 | origin_of_life_solution |
| `specs/tri/phenomenal_binding.tri` | `src/consciousness/binding/phenomenal_binder.zig` | 233 | phenomenal_binding |
| `specs/tri/quantum/e8_root_system.tri` | `src/quantum/e8_root_system.zig` | 75 | e8_root_system |
| `specs/tri/quantum/qml_interface.tri` | `src/vibeec/codegen/patterns/ml.zig` | 142 | quantum_ml |
| `specs/tri/quantum/qrl_agent.tri` | `src/vibeec/codegen/patterns/rl.zig` | 160 | quantum_rl |
| `specs/tri/quantum/qutrit_optimizer.tri` | `src/quantum/qutrit_optimizer.zig` | 140 | qutrit_optimizer |
| `specs/tri/quantum/tensor_networks.tri` | `src/quantum/tensor_networks.zig` | 156 | tensor_networks |
| `specs/tri/quantum_biology.tri` | `src/consciousness/quantum_biology.zig` | 147 | quantum_biology |
| `specs/tri/quantum_brain_network.tri` | `src/consciousness/network/qbrain_protocol.zig` | 209 | quantum_brain_network |
| `specs/tri/quantum_decoherence_protection.tri` | `src/consciousness/quantum/decoherence_shield.zig` | 215 | quantum_decoherence_protection |
| `specs/tri/qutrit_consciousness.tri` | `src/consciousness/qutrit_consciousness.zig` | 262 | qutrit_consciousness |
| `specs/tri/rewards.tri` | `src/economy/rewards.zig` | 29 | rewards |
| `specs/tri/sacred_cosmology.tri` | `src/cosmos/sacred_cosmology.zig` | 189 | sacred_cosmology |
| `specs/tri/sacred_dark_matter.tri` | `src/dark_matter/sacred_dark_matter.zig` | 283 | sacred_dark_matter |
| `specs/tri/self_improving_formula_discovery.tri` | `src/tri/self_improving_formula_discovery.zig` | 164 | self_improving_formula_discovery |
| `specs/tri/shard_manager.tri` | `src/trinity_node/shard_manager.zig` | 29 | shard_manager |
| `specs/tri/superconductivity.tri` | `src/superconductivity/room_temperature_superconductivity.zig` | 248 | room_temperature_superconductivity |
| `specs/tri/swarm.tri` | `src/needle/swarm.zig` | 29 | swarm |
| `specs/tri/telegram.tri` | `tools/mcp/trinity_mcp/agent/telegram.zig` | 29 | telegram |
| `specs/tri/templates.tri` | `src/vibeec/codegen/patterns/templates.zig` | 29 | templates |
| `specs/tri/temporal_constants.tri` | `src/time/temporal_constants.zig` | 135 | temporal_constants |
| `specs/tri/temporal_engine.tri` | `src/sacred/temporal_engine.zig` | 164 | temporal_engine |
| `specs/tri/testing/repl_tests.tri` | `src/tri/testing/repl_tests.zig` | 237 | repl_tests |
| `specs/tri/tqnn_benchmark.tri` | `src/models/tqnn/tqnn_bench.zig` | 127 | tqnn_benchmark |
| `specs/tri/tqnn_inference_10k.tri` | `src/models/tqnn/tqnn_inference.zig` | 172 | tqnn_inference_10k |
| `specs/tri/tqnn_quantum_primitives.tri` | `src/quantum/qutrit.zig` | 211 | tqnn_quantum_primitives |
| `specs/tri/treesitter/hnsw_core.tri` | `src/needle/hnsw.zig` | 351 | hnsw_core |
| `specs/tri/tri_search_commands.tri` | `src/tri/tri_search.zig` | 71 | tri_search_commands |
| `specs/tri/trinity_ai_core.tri` | `src/consciousness/core/trinity_ai_core.zig` | 29 | trinity_ai_core |
| `specs/tri/tvc_science.tri` | `src/phi-engine/core/tvc/tvc_science.zig` | 29 | tvc_science |
| `specs/tri/tvc_service/tvc_http_api.tri` | `src/vibeec/http_server.zig` | 145 | tvc_http_api |
| `specs/tri/tvc_service/tvc_rewards.tri` | `src/economy/rewards.zig` | 95 | tvc_rewards |
| `specs/tri/unified_framework.tri` | `src/blind_spot/unified_framework.zig` | 125 | unified_framework |
| `specs/tri/vacuum_catastrophe_solution.tri` | `src/cosmos/vacuum_catastrophe_solution.zig` | 136 | vacuum_catastrophe_solution |
| `specs/tri/vm_sacred_opcodes.tri` | `src/vm.zig` | 73 | vm_sacred_opcodes |
| `specs/tri/vsa_mind.tri` | `src/consciousness/vsa_mind.zig` | 145 | vsa_mind |

---

## VALID Specs (324) — no .zig yet

### Substantial (158)

| Spec | Lines | Module |
|------|-------|--------|
| `specs/tri/swarm_coordinator.tri` | 1973 | swarm_coordinator |
| `specs/tri/swarm_agents.tri` | 1042 | swarm_agents |
| `specs/integrations/trinity-mcp.tri` | 873 | trinity-mcp |
| `specs/tri/dashboard_agent.tri` | 656 | dashboard_agent |
| `specs/tri/codegen_engine_final_upgrade.tri` | 490 | codegen_engine_final_upgrade |
| `specs/tri/trinity_fpga_core.tri` | 483 | trinity_fpga_core |
| `specs/tri/autonomous_lifecycle.tri` | 478 | tri_autonomous_lifecycle |
| `specs/tri/batch_synthesis.tri` | 461 | batch_synthesis |
| `specs/tri/coordinator_test.tri` | 459 | coordinator_test |
| `specs/tri/stress_test.tri` | 422 | stress_test |
| `specs/tri/governance_agent.tri` | 416 | governance_agent |
| `specs/integrations/tier3-vsa.tri` | 378 | tier3-vsa |
| `specs/tri/batch_large_workloads.tri` | 350 | batch_large_workloads |
| `specs/integrations/tier5-omega.tri` | 341 | tier5-omega |
| `specs/integrations/tier2-graph.tri` | 330 | tier2-graph |
| `specs/integrations/tier4-safe-cross.tri` | 330 | tier4-safe-cross |
| `specs/tri/tri_cli_full_update.tri` | 327 | tri_cli_full_update |
| `specs/tri/regression_test.tri` | 325 | regression_test |
| `specs/cli/real-registration-v3.tri` | 322 | real_registration_v3 |
| `specs/benchmarks/global-mesh-bench.tri` | 317 | global_mesh_bench |
| `specs/tri/smoke_test.tri` | 313 | smoke_test |
| `specs/tri/codegen_engine_formal_spec.tri` | 309 | codegen_engine_formal_spec |
| `specs/tri/jit_compiler_v7.tri` | 306 | jit_compiler_v7 |
| `specs/tri/forge_integration.tri` | 297 | forge_integration |
| `specs/tri/codegen_engine_full_upgrade.tri` | 288 | codegen_engine_full_upgrade |
| `specs/tri/real_jit_x86_64.tri` | 281 | real_jit_x86_64 |
| `specs/tri/igla_parser_types.tri` | 279 | igla_parser_types |
| `specs/tri/simd_batch_final.tri` | 279 | simd_batch_final |
| `specs/cli/dashboard-command-v1.tri` | 271 | omega-dashboard-v1 |
| `specs/tri/state/hardening_v2.tri` | 267 | state_hardening_v2 |
| `specs/tri/forge_routing.tri` | 261 | forge_routing |
| `specs/tri/agent_mu_self_improvement_loop.tri` | 257 | agent_mu_self_improvement_loop |
| `specs/tri/codegen_full_automation.tri` | 253 | codegen_full_automation |
| `specs/tri/forge_database.tri` | 250 | forge_database |
| `specs/tri/forge_synthesis.tri` | 250 | forge_synthesis |
| `specs/tri/agent_mu_self_evolution_guard.tri` | 249 | agent_mu_self_evolution_guard |
| `specs/tri/telegram_pulse_client.tri` | 245 | telegram_pulse_client |
| `specs/tri/ralph_self_evolution_loop.tri` | 240 | ralph_self_evolution_loop |
| `specs/tri/codegen/behavior_emitter.tri` | 237 | behavior_emitter |
| `specs/tri/testing/test_generator.tri` | 236 | tri_test_generator |
| `specs/tri/codegen/type_emitter.tri` | 229 | type_emitter |
| `specs/integrations/needle-mcp.tri` | 227 | needle-mcp-integration |
| `specs/tri/codegen/core_emitter.tri` | 227 | core_emitter |
| `specs/tri/trinity_v2_top_final.tri` | 227 | trinity_v2_top_final |
| `specs/tri/metrics_collector.tri` | 225 | metrics_collector |
| `specs/tri/swarm_orchestrator.tri` | 223 | swarm_orchestrator |
| `specs/tri/benchmarks_603x_final.tri` | 220 | benchmarks_603x_final |
| `specs/tri/codegen_math_safety.tri` | 220 | codegen_math_safety |
| `specs/tri/trinity_v2_final_top.tri` | 220 | trinity_v2_final_top |
| `specs/cli/mesh-v3.tri` | 216 | mesh-command-v3 |
| `specs/tri/uart_command_decoder.tri` | 216 | uart_command_decoder |
| `specs/tri/forge_placement.tri` | 213 | forge_placement |
| `specs/tri/bytecode_serialization_final.tri` | 212 | bytecode_serialization_final |
| `specs/needle/autonomous_refactor_engine.tri` | 211 | needle-autonomous-refactor-engine |
| `specs/tri/multi-cluster-corrected.tri` | 208 | multi-cluster-corrected |
| `specs/tri/trinity_v2_top.tri` | 208 | trinity_v2_top |
| `specs/tri/tri_marketplace.tri` | 203 | tri_marketplace |
| `specs/mcp/omega-tools-v1.tri` | 199 | mcp_omega_tools |
| `specs/tri/codegen_engine_upgrade.tri` | 198 | codegen_engine_upgrade |
| `specs/tri/cycle50/full_regen_test.tri` | 198 | full_regen_test |
| `specs/tri/ga_e2e_chat.tri` | 197 | ga_e2e_chat |
| `specs/depin/multi-cluster-live-v2.tri` | 195 | multi_cluster_live_v2 |
| `specs/tri/tri_devutil_commands.tri` | 193 | tri_devutil_commands |
| `specs/mcp/wallet-tools-v1.tri` | 191 | mcp_wallet_tools |
| `specs/tri/math_identities.tri` | 191 | math_identities |
| `specs/cli/mesh-command-v1.tri` | 189 | mesh_command |
| `specs/uart/vsa_uart_operations.tri` | 188 | vsa_uart_operations |
| `specs/tri/ralph_pulse_integration.tri` | 187 | ralph_pulse_integration |
| `specs/tri/swarm_github.tri` | 187 | swarm_github |
| `specs/cli/reputation-command-v1.tri` | 185 | reputation_command |
| `specs/tri/cycle50/emitter_upgrade.tri` | 182 | emitter_upgrade |
| `specs/mcp/mesh-tools-v1.tri` | 180 | mcp_mesh_tools |
| `specs/cli/hardware-v3.tri` | 178 | hardware-command-v3 |
| `specs/cli/hardware-command-v1.tri` | 177 | hardware_command |
| `specs/cli/wallet-claim-v1.tri` | 176 | wallet-claim-v1 |
| `specs/cli/wallet-command-v1.tri` | 172 | wallet_command |
| `specs/tri/trinity_demo_test_v2.tri` | 172 | trinity_demo_test_v2 |
| `specs/tri/vm_bytecode_v7.tri` | 168 | vm_bytecode_v7 |
| `specs/cli/hardware-command-v4.tri` | 167 | hardware-command-v4 |
| `specs/vibee/self-mod-v1.tri` | 167 | vibee-self-mod-v1 |
| `specs/tri/agent_mu_auto_fixer.tri` | 165 | agent_mu_auto_fixer |
| `specs/tri/ga_contracts.tri` | 163 | ga_contracts |
| `specs/tri/contract_test.tri` | 162 | contract_test |
| `specs/tri/bootstrap/emitter_full.tri` | 158 | emitter_full |
| `specs/tri/zig_ffi_trinity_v2.tri` | 158 | zig_ffi_trinity_v2 |
| `specs/needle/pattern_language.tri` | 157 | needle-pattern-language |
| `specs/tri/benchmarks_v7.tri` | 157 | benchmarks_v7 |
| `specs/tri/bytecode_serialization_v7.tri` | 153 | bytecode_serialization_v7 |
| `specs/tri/fpga_mvp.tri` | 152 | fpga_mvp |
| `specs/tri/uart_full_protocol_v2.tri` | 146 | uart_full_protocol_v2 |
| `specs/needle/tier3-vsa-embeddings.tri` | 144 | needle-tier3-vsa-embeddings |
| `specs/cli/real-registration-v4.tri` | 138 | real-registration-v4 |
| `specs/tri/telegram_command_router.tri` | 134 | telegram_command_router |
| `specs/tri/tvc_service/tvc_mesh.tri` | 133 | tvc_mesh |
| `specs/tri/tvc_service/tvc_staking.tri` | 126 | tvc_staking |
| `specs/cli/wallet-v3.tri` | 124 | wallet-command-v3 |
| `specs/tri/agent_mu_zig15_demo.tri` | 123 | agent_mu_zig15_demo |
| `specs/cli/golden-chain-fix-v1.tri` | 120 | golden_chain_fix |
| `specs/tri/vm_integration_v7.tri` | 120 | vm_integration_v7 |
| `specs/cli/reputation-command-v4.tri` | 116 | reputation-command-v4 |
| `specs/cli/reputation-v3.tri` | 115 | reputation-command-v3 |
| `specs/tri/tri_defi.tri` | 115 | tri_defi |
| `specs/koschei/vsa_fpga_week3.tri` | 114 | Multi-operation pipeline: bind + bundle + similarity на FPGA |
| `specs/cli/depn-commands-enum-v1.tri` | 113 | depn_commands_enum |
| `specs/koschei/vsa_fpga_week2.tri` | 113 | 256-dim VSA bind + pipelining + Zig FFI |
| `specs/cli/wallet-command-v4.tri` | 112 | wallet-command-v4 |
| `specs/tri/fibonacci_lucas.tri` | 111 | fibonacci_lucas |
| `specs/fpga/test_multi_led.tri` | 109 | test_multi_led |
| `specs/tri/tvc_service/tvc_service_integration.tri` | 108 | tvc_service_integration |
| `specs/tri/ga_batch.tri` | 107 | ga_batch |
| `specs/fpga/test_debouncer.tri` | 106 | test_debouncer |
| `specs/tri/swarm_circuit_breaker.tri` | 106 | swarm_circuit_breaker |
| `specs/tri/trinity_v2_synthesis.tri` | 105 | trinity_v2_synthesis |
| `specs/fpga/fsm_simple.tri` | 104 | fsm_simple |
| `specs/tri/trinity_v2_constraints.tri` | 104 | trinity_v2_constraints |
| `specs/tri/multilingual_gen_fluent.tri` | 102 | multilingual_gen_fluent |
| `specs/fpga/test_shift_register.tri` | 101 | test_shift_register |
| `specs/tri/tri_igla_commands.tri` | 98 | tri_igla_commands |
| `specs/tri/codebase_context.tri` | 96 | codebase_context |
| `specs/needle/vsa_performance_hnsw.tri` | 95 | needle-vsa-performance-hnsw |
| `specs/tri/treesitter_improvements.tri` | 94 | treesitter_improvements |
| `specs/tri/hslm_autograd.tri` | 93 | hslm_autograd |
| `specs/fpga/test_counter.tri` | 92 | test_counter |
| `specs/tri/telegram_command_receiver.tri` | 92 | telegram_command_receiver |
| `specs/needle/grammar_full.tri` | 91 | needle-grammar-full |
| `specs/tri/telegram_pulse_emitter.tri` | 91 | telegram_pulse_emitter |
| `specs/fpga/counter.tri` | 89 | counter |
| `specs/tri/full_autonomous.tri` | 89 | full_autonomous |
| `specs/tri/tri_bot.tri` | 89 | tri_bot |
| `specs/tri/phi_engine.tri` | 87 | phi_engine |
| `specs/tri/tri_test_commands.tri` | 87 | tri_test_commands |
| `specs/tri/ralph_queue_monitor.tri` | 84 | ralph_queue_monitor |
| `specs/tri/bootstrap/tests_gen_full.tri` | 83 | tests_gen_full |
| `specs/tri/hslm_trainer.tri` | 83 | hslm_trainer |
| `specs/tri/tri_plan_commands.tri` | 83 | tri_plan_commands |
| `specs/uart/uart_mode_controller.tri` | 83 | uart_mode_controller |
| `specs/tri/ga_smoke.tri` | 82 | ga_smoke |
| `specs/tri/tri_analyzer_commands.tri` | 82 | tri_analyzer_commands |
| `specs/tri/igla_parser_phase3.tri` | 81 | igla_parser_phase3 |
| `specs/tri/phi_utils_multi.tri` | 81 | phi_utils |
| `specs/tri/treesitter_analyzer_checks.tri` | 80 | treesitter_analyzer_checks |
| `specs/fpga/test_pwm.tri` | 78 | test_pwm |
| `specs/needle/ann_verdict.tri` | 78 | ann_verdict |
| `specs/depin/real-network-v1.tri` | 74 | real_network_v1 |
| `specs/needle/ann_integration.tri` | 69 | ann_integration |
| `specs/tri/codegen/function_emitter.tri` | 67 | function_emitter |
| `specs/tri/tri_deps_commands.tri` | 67 | tri_deps_commands |
| `specs/tri/codegen/test_emitter.tri` | 65 | test_emitter |
| `specs/tri/hslm_bench.tri` | 63 | hslm_bench |
| `specs/fpga/test_blink.tri` | 62 | test_blink |
| `specs/tri/hslm_dataset.tri` | 59 | hslm_dataset |
| `specs/fpga/blink.tri` | 57 | blink |
| `specs/tri/codegen/pattern_emitter.tri` | 56 | pattern_emitter |
| `specs/needle/tier4.2-ivf-incremental-build.tri` | 54 | IVF Incremental Build + Persistent Cache |
| `specs/tri/codegen/memory_emitter.tri` | 53 | memory_emitter |
| `specs/tri/bootstrap/impl_block_demo.tri` | 39 | impl_block_demo |
| `specs/tri/build_authentication_system.tri` | 38 | build_authentication_system |
| `specs/needle/tier1-treesitter.tri` | 36 | tier1-treesitter |

### Auto-generated stubs (166)

| Spec | Module |
|------|--------|
| `specs/tri/3d_generation_v13590.tri` | 3d_generation_v13590 |
| `specs/tri/achievement_system.tri` | achievement_system |
| `specs/tri/admin_api.tri` | admin_api |
| `specs/tri/admin_commands.tri` | admin_commands |
| `specs/tri/ai_queue.tri` | ai_queue |
| `specs/tri/ai_router.tri` | ai_router |
| `specs/tri/analytics.tri` | analytics |
| `specs/tri/api_auth.tri` | api_auth |
| `specs/tri/api_gateway.tri` | api_gateway |
| `specs/tri/app_context.tri` | app_context |
| `specs/tri/audio_group.tri` | audio_group |
| `specs/tri/audit_log.tri` | audit_log |
| `specs/tri/auth_middleware.tri` | auth_middleware |
| `specs/tri/avatar_brain.tri` | avatar_brain |
| `specs/tri/avatar_generator.tri` | avatar_generator |
| `specs/tri/avatar_group.tri` | avatar_group |
| `specs/tri/avatar_orchestrator.tri` | avatar_orchestrator |
| `specs/tri/avatar_session.tri` | avatar_session |
| `specs/tri/background_removal.tri` | background_removal |
| `specs/tri/balance_middleware.tri` | balance_middleware |
| `specs/tri/bitnet_inference.tri` | bitnet_inference |
| `specs/tri/bitnet_mac.tri` | bitnet_mac |
| `specs/tri/bot.tri` | bot |
| `specs/tri/bot_core.tri` | bot_core |
| `specs/tri/bot_main.tri` | bot_main |
| `specs/tri/broadcast.tri` | broadcast |
| `specs/tri/callback_handler.tri` | callback_handler |
| `specs/tri/campaign_manager.tri` | campaign_manager |
| `specs/tri/chat_with_avatar.tri` | chat_with_avatar |
| `specs/tri/command_handler.tri` | command_handler |
| `specs/tri/cost_calculator.tri` | cost_calculator |
| `specs/tri/cryptobot_client.tri` | cryptobot_client |
| `specs/tri/database.tri` | database |
| `specs/tri/date_utils.tri` | date_utils |
| `specs/tri/dht.tri` | dht |
| `specs/tri/digital_avatar_wizard.tri` | digital_avatar_wizard |
| `specs/tri/dual_channel_dma.tri` | dual_channel_dma |
| `specs/tri/e2e_flows.tri` | e2e_flows |
| `specs/tri/e2e_test_suite.tri` | e2e_test_suite |
| `specs/tri/elevenlabs_client.tri` | elevenlabs_client |
| `specs/tri/erasure.tri` | erasure |
| `specs/tri/error_handler.tri` | error_handler |
| `specs/tri/event_bus.tri` | event_bus |
| `specs/tri/face_swap.tri` | face_swap |
| `specs/tri/fast_image_edit.tri` | fast_image_edit |
| `specs/tri/fast_image_gen.tri` | fast_image_gen |
| `specs/tri/fast_tts.tri` | fast_tts |
| `specs/tri/feedback_messages.tri` | feedback_messages |
| `specs/tri/final_verification_test.tri` | final_verification_test |
| `specs/tri/flyio_deploy_test.tri` | flyio_deploy_test |
| `specs/tri/formatters.tri` | formatters |
| `specs/tri/full_v40_test.tri` | full_v40_test |
| `specs/tri/generation_pipeline.tri` | generation_pipeline |
| `specs/tri/generation_repository.tri` | generation_repository |
| `specs/tri/gguf_parser.tri` | gguf_parser |
| `specs/tri/golden_chain_v40.tri` | GOLDEN_CHAIN_v40 |
| `specs/tri/health_check.tri` | health_check |
| `specs/tri/help.tri` | help |
| `specs/tri/i18n.tri` | i18n |
| `specs/tri/image_to_prompt.tri` | image_to_prompt |
| `specs/tri/image_to_video.tri` | image_to_video |
| `specs/tri/image_to_video_wizard.tri` | image_to_video_wizard |
| `specs/tri/improved_main_menu.tri` | improved_main_menu |
| `specs/tri/invoice.tri` | invoice |
| `specs/tri/job_queue.tri` | job_queue |
| `specs/tri/keyboard_patterns.tri` | keyboard_patterns |
| `specs/tri/language.tri` | language |
| `specs/tri/lifecycle_manager.tri` | lifecycle_manager |
| `specs/tri/linear_scan_allocator.tri` | linear_scan_allocator |
| `specs/tri/lip_sync.tri` | lip_sync |
| `specs/tri/logging_middleware.tri` | logging_middleware |
| `specs/tri/main_menu.tri` | main_menu |
| `specs/tri/media_handler.tri` | media_handler |
| `specs/tri/media_processor.tri` | media_processor |
| `specs/tri/menu_e2e_tests.tri` | menu_e2e_tests |
| `specs/tri/message_handler.tri` | message_handler |
| `specs/tri/middleware.tri` | middleware |
| `specs/tri/middleware_chain.tri` | middleware_chain |
| `specs/tri/mocks.tri` | mocks |
| `specs/tri/model_registry.tri` | model_registry |
| `specs/tri/model_repository.tri` | model_repository |
| `specs/tri/model_training.tri` | model_training |
| `specs/tri/moderation.tri` | moderation |
| `specs/tri/modes.tri` | modes |
| `specs/tri/netpipeline.tri` | netpipeline |
| `specs/tri/neuro_photo.tri` | neuro_photo |
| `specs/tri/neuro_photo_wizard.tri` | neuro_photo_wizard |
| `specs/tri/notification_service.tri` | notification_service |
| `specs/tri/nsfw_detection.tri` | nsfw_detection |
| `specs/tri/onboarding_flow.tri` | onboarding_flow |
| `specs/tri/openai_api.tri` | openai_api |
| `specs/tri/paid_services.tri` | paid_services |
| `specs/tri/payment_group.tri` | payment_group |
| `specs/tri/payment_handler.tri` | payment_handler |
| `specs/tri/payment_processor.tri` | payment_processor |
| `specs/tri/payment_repository.tri` | payment_repository |
| `specs/tri/payment_router.tri` | payment_router |
| `specs/tri/payment_system.tri` | payment_system |
| `specs/tri/performance_monitor.tri` | performance_monitor |
| `specs/tri/photo_group.tri` | photo_group |
| `specs/tri/photo_handler.tri` | photo_handler |
| `specs/tri/pipeline.tri` | pipeline |
| `specs/tri/polling_loop.tri` | polling_loop |
| `specs/tri/pos.tri` | pos |
| `specs/tri/postgres_client.tri` | postgres_client |
| `specs/tri/pricing_system.tri` | pricing_system |
| `specs/tri/prompt_engineering.tri` | prompt_engineering |
| `specs/tri/rate_limit_middleware.tri` | rate_limit_middleware |
| `specs/tri/rate_limiter.tri` | rate_limiter |
| `specs/tri/redis_client.tri` | redis_client |
| `specs/tri/referral_system.tri` | referral_system |
| `specs/tri/replicate_api.tri` | replicate_api |
| `specs/tri/replicate_client.tri` | replicate_client |
| `specs/tri/reply_keyboard.tri` | reply_keyboard |
| `specs/tri/repositories.tri` | repositories |
| `specs/tri/revenue_analytics.tri` | revenue_analytics |
| `specs/tri/s3_client.tri` | s3_client |
| `specs/tri/scene_base.tri` | scene_base |
| `specs/tri/scene_manager.tri` | scene_manager |
| `specs/tri/scheduler.tri` | scheduler |
| `specs/tri/service_registry.tri` | service_registry |
| `specs/tri/session.tri` | session |
| `specs/tri/simd_cluster.tri` | simd_cluster |
| `specs/tri/sketch_to_image.tri` | sketch_to_image |
| `specs/tri/stars_wallet.tri` | stars_wallet |
| `specs/tri/state_manager.tri` | state_manager |
| `specs/tri/stripe_client.tri` | stripe_client |
| `specs/tri/subscription.tri` | subscription |
| `specs/tri/supabase_client.tri` | supabase_client |
| `specs/tri/supabase_schema.tri` | supabase_schema |
| `specs/tri/supabase_storage.tri` | supabase_storage |
| `specs/tri/system_config.tri` | system_config |
| `specs/tri/telegram_client.tri` | telegram_client |
| `specs/tri/telegram_stars.tri` | telegram_stars |
| `specs/tri/test_fixtures.tri` | test_fixtures |
| `specs/tri/text_message_handler.tri` | text_message_handler |
| `specs/tri/text_to_speech.tri` | text_to_speech |
| `specs/tri/text_to_video.tri` | text_to_video |
| `specs/tri/text_to_video_wizard.tri` | text_to_video_wizard |
| `specs/tri/tools_group.tri` | tools_group |
| `specs/tri/transformer_forward.tri` | transformer_forward |
| `specs/tri/trinity_menu_system.tri` | trinity_menu_system |
| `specs/tri/trit_alu.tri` | trit_alu |
| `specs/tri/unified_navigation.tri` | unified_navigation |
| `specs/tri/update_processor.tri` | update_processor |
| `specs/tri/usage_limits.tri` | usage_limits |
| `specs/tri/user.tri` | user |
| `specs/tri/user_management.tri` | user_management |
| `specs/tri/user_repository.tri` | user_repository |
| `specs/tri/user_state.tri` | user_state |
| `specs/tri/ux_design_system.tri` | ux_design_system |
| `specs/tri/validators.tri` | validators |
| `specs/tri/verify_v40.tri` | verify_v40 |
| `specs/tri/video_group.tri` | video_group |
| `specs/tri/video_transcription.tri` | video_transcription |
| `specs/tri/video_upscaler.tri` | video_upscaler |
| `specs/tri/voice_avatar.tri` | voice_avatar |
| `specs/tri/vsa_bundle_opt.tri` | vsa_bundle_opt |
| `specs/tri/vsa_large_scale_analogies.tri` | vsa_large_scale_analogies |
| `specs/tri/vsa_math_proofs.tri` | vsa_math_proofs |
| `specs/tri/webhook_handler.tri` | webhook_handler |
| `specs/tri/webhook_manager.tri` | webhook_manager |
| `specs/tri/weight_cache.tri` | weight_cache |
| `specs/tri/wizard_ux.tri` | wizard_ux |
| `specs/tri/worker.tri` | worker |
| `specs/tri/zhar_ptitsa_webarena.tri` | zhar_ptitsa_webarena |

---

## Archived Specs

| Directory | Count | Content |
|-----------|-------|---------|
| `archive/specs/dead/cycle_plans/` | 34 | Never-implemented cycle plans (cycle95-113) |
| `archive/specs/dead/fantasy/` | 69 | Theoretical/fantasy specs (consciousness, quantum gravity, etc.) |
| `archive/specs/dead/broken/` | 22 | Invalid structure or stub-only specs |
| `archive/specs/meta/roadmap/` | ~10 | Phase plans, omega release |
| `archive/specs/meta/bootstrap/` | ~7 | Bootstrap/migration scripts |
| `archive/specs/meta/tooling/` | ~40 | Build tools, validators, week plans |
| `archive/specs/meta/investor/` | 4 | Investor deck versions |
| `archive/specs/meta/release/` | ~5 | Release announcements |
| `archive/specs/meta/infra/` | 2 | Build purge, transcendence |
