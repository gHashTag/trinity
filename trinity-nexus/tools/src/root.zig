// TRINITY NEXUS — Tools Module (trinity-tools)
// NEXUS-007: CLI, REPL, DevTools, benchmarks, build helpers, utilities,
// Maxwell agent, Phi-engine.
// Source: src/vibeec/ (57 files), src/maxwell/ (7), src/phi-engine/ (5),
//         benchmarks/ (7). Total: 73 files, 26629 lines.

// --- Maxwell Agent (self-contained) ---
pub const maxwell = @import("maxwell/maxwell.zig");
pub const maxwell_agent_loop = @import("maxwell/agent_loop.zig");
pub const maxwell_code_analyzer = @import("maxwell/code_analyzer.zig");
pub const maxwell_codebase = @import("maxwell/codebase.zig");
pub const maxwell_llm_client = @import("maxwell/llm_client.zig");
pub const maxwell_memory_store = @import("maxwell/memory_store.zig");
pub const maxwell_spec_generator = @import("maxwell/spec_generator.zig");

// --- Phi-Engine (self-contained) ---
pub const akashic_records = @import("phi/akashic_records_manual.zig");
pub const ouroboros = @import("phi/ouroboros.zig");
pub const ouroboros_v2 = @import("phi/ouroboros_v2.zig");
pub const quantum_coder = @import("phi/quantum_coder_agent_with_akashic.zig");
pub const uroboros_final = @import("phi/uroboros_final.zig");

// --- Utilities (mostly self-contained) ---
pub const json_parser = @import("util/json_parser.zig");
pub const ffi = @import("util/ffi.zig");
pub const package_manager = @import("util/package_manager.zig");
pub const http_client = @import("util/http_client.zig");
pub const websocket = @import("util/websocket.zig");
pub const streaming_sse = @import("util/streaming_sse.zig");
pub const circuit_breaker = @import("util/circuit_breaker.zig");
pub const autoscaling = @import("util/autoscaling.zig");
pub const parallel_downloader = @import("util/parallel_downloader.zig");

// --- Gen/Build Helpers (partially self-contained) ---
pub const spec_generator = @import("gen/spec_generator.zig");
pub const batch_gen = @import("gen/batch_gen.zig");
pub const spec_loader = @import("gen/spec_loader.zig");

// --- DevTools (partially self-contained) ---
pub const debugger = @import("devtools/debugger.zig");
pub const profiler = @import("devtools/profiler.zig");
pub const lsp = @import("devtools/lsp.zig");
pub const lsp_server = @import("devtools/lsp_server.zig");
pub const error_reporter = @import("devtools/error_reporter.zig");
pub const antipattern_detector = @import("devtools/antipattern_detector.zig");
pub const validate_cmd = @import("devtools/validate_cmd.zig");
pub const trinity_format = @import("devtools/trinity_format.zig");
pub const trinity_validator = @import("devtools/trinity_validator.zig");
pub const validation_engine = @import("devtools/validation_engine.zig");

// --- CLI/REPL ---
pub const tri_cmd = @import("cli/tri_cmd.zig");

// --- Benchmarks (self-contained subset) ---
pub const bench_compression = @import("bench/suite/bench_compression.zig");
pub const ai_models_comparison = @import("bench/suite/ai_models_comparison.zig");
pub const continuous_bench = @import("bench/suite/continuous_bench.zig");
pub const run_benchmarks = @import("bench/suite/run_benchmarks.zig");
pub const vibee_vs_zig = @import("bench/suite/vibee_vs_zig.zig");
pub const benchmark_trinity = @import("bench/benchmark_trinity.zig");
pub const full_benchmark = @import("bench/full_benchmark.zig");
pub const production_benchmark = @import("bench/production_benchmark.zig");
pub const full_matrix_benchmark = @import("bench/full_matrix_benchmark.zig");

// --- Deferred (external deps -> NEXUS-008 workspace wiring) ---
// cli/cli.zig — imports error_reporter (devtools), gguf_to_tri
// cli/cli_main.zig — imports coptic_*, bytecode_*, vm_runtime, jit_*
// cli/repl.zig — imports error_reporter
// cli/repl_main.zig — imports coptic_repl
// cli/evolved_cli.zig — imports trinity_mentor
// cli/tested_cli.zig — imports updated_codex, adaptive_cache
// cli/trinity_cli.zig — imports trinity_swe_agent
// cli/competitive_repl.zig — imports moe_router, enhanced_moe, agent_tools, dao_integration
// devtools/profile_detailed.zig — imports simd_matmul, gguf_inference
// devtools/profile_inference.zig — imports gguf_model
// devtools/validator_engine.zig — imports bogatyrs_common, bogatyrs_registry
// devtools/validator_main.zig — imports validate_cmd (sibling, ok)
// devtools/validator_main_simple.zig — imports validate_cmd (sibling, ok)
// devtools/trinity_format.zig — imports prometheus_seed
// gen/vibee_gen.zig — imports vibee_parser, zig_codegen, verilog_codegen, lang_generators
// gen/gen_cmd_minimal.zig — imports vibee_parser
// gen/gen_cmd_simple.zig — imports vibee_parser, zig_codegen
// util/http_server.zig — imports gguf_model, gguf_tokenizer, gguf_inference
// util/load_test.zig — imports autoscaling (sibling, ok)
// bench/*.zig — various external imports (simd, jit, tokenizer, vsa module)
// bench/suite/bench_math.zig — imports vsa, bundle_opt modules
// bench/suite/bench_core.zig — imports ../src/trinity.zig, ../src/vsa.zig

// --- Test block (self-contained modules only) ---
test {
    // Maxwell (fully self-contained)
    _ = maxwell;
    _ = maxwell_agent_loop;
    _ = maxwell_code_analyzer;
    _ = maxwell_codebase;
    _ = maxwell_llm_client;
    _ = maxwell_memory_store;
    _ = maxwell_spec_generator;

    // Phi-Engine (fully self-contained)
    _ = akashic_records;
    _ = ouroboros;
    _ = ouroboros_v2;
    _ = quantum_coder;
    _ = uroboros_final;

    // Utilities (self-contained subset)
    _ = json_parser;
    _ = ffi;
    _ = package_manager;
    _ = http_client;
    _ = websocket;
    _ = streaming_sse;
    _ = circuit_breaker;
    _ = autoscaling;
    _ = parallel_downloader;

    // Gen (self-contained subset)
    _ = spec_generator;
    _ = batch_gen;
    _ = spec_loader;

    // DevTools (self-contained subset)
    _ = debugger;
    _ = profiler;
    _ = lsp;
    _ = lsp_server;
    _ = error_reporter;
    _ = antipattern_detector;
    _ = validate_cmd;
    _ = trinity_validator;
    _ = validation_engine;

    // CLI (self-contained subset)
    _ = tri_cmd;

    // Benchmarks (self-contained subset)
    _ = bench_compression;
    _ = ai_models_comparison;
    _ = continuous_bench;
    _ = run_benchmarks;
    _ = vibee_vs_zig;
    _ = benchmark_trinity;
    _ = full_benchmark;
    _ = production_benchmark;
    _ = full_matrix_benchmark;
}

test "tools module identity" {
    const name = "trinity-tools";
    const version = "0.7.0";
    try @import("std").testing.expect(name.len > 0);
    try @import("std").testing.expect(version.len > 0);
}

test "maxwell available" {
    const M = @TypeOf(maxwell);
    try @import("std").testing.expect(@sizeOf(M) >= 0);
}
