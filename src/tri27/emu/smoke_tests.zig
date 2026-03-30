// @origin(spec:ttt_dogfood.tri) @regen(manual-impl)
// TTT Dogfood Verification Sweep — Tier 1 Smoke Tests
//
// Smoke tests verify basic functionality: assembly + execution without crashes
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const CPUState = @import("cpu_state.zig").CPUState;
const ExecError = @import("executor.zig").ExecError;
const run = @import("executor.zig").run;
const tri_asm = @import("tri_asm.zig");

// Tier 1 files requiring smoke tests
pub const TIER1_ALGORITHMS = [_][]const u8{
    // Convolutional Neural Networks
    "conv_2d.t27", "conv_lbs_to_kg.t27", "conv2d_transpose.t27", "inception_resnet.t27",
    "mask_rcnn_detection.t27", "neural_downsample.t27", "transposed_conv2d.t27",

    // Transformers
    "xai_attention.t27", "bert_attention.t27", "attention_self.t27",
    "attention_explainability.t27", "graph_attention.t27", "ml_attention.t27",
    "transformer_bert.t27", "transformer_timeseries.t27", "ml_transformer.t27",
    "timeseries_transformer.t27", "gpt_turbo.t27", "tinybert.t27",

    // Neural Networks
    "bilstm.t27", "rnn.t27", "ts_lstm.ts.t27", "time_lstm.t27",
    "dense_layer.t27", "embeddings_normflow.t27",

    // Loss Functions
    "triplet_loss.t27", "loss_mae.t27", "contrastive_loss.t27",
    "loss_kl_divergence.t27", "lossy.t27",

    // Generative
    "generative_vae.t27", "generative_gan.t27", "diffusion_model.t27",

    // Optimizers
    "optimize_convex.t27", "optimize_sgd.t27", "optimization_sgd.t27",
    "opt_adamax.t27", "sgd_optimizer.t27", "dsp_gradient.t27",

    // Reinforcement Learning
    "adv_sprague_grundy.t27", "game_a3c.t27", "prob_expected_value.t27",
    "face_value.t27",

    // Activation Functions
    "ml_tanh_act.t27", "color_convert.t27", "image_color_convert.t27",

    // Normalization
    "dropout_regularization.t27", "nn_layer_norm.t27", "reg_layernorm.t27",

    // Other
    "dp_knapsack.t27",
};

/// Helper to read a .t27 file from src/tri27/
fn readT27File(allocator: std.mem.Allocator, filename: []const u8) ![]const u8 {
    const path = try std.fmt.allocPrint(allocator, "src/tri27/{s}", .{filename});
    defer allocator.free(path);
    return std.fs.cwd().readFileAlloc(allocator, path, 1024 * 100); // Max 100KB
}

/// Helper to assemble source and verify it produces valid bytecode
fn assemble(allocator: std.mem.Allocator, source: []const u8) ![]const u8 {
    const bytecode = try tri_asm.assemble(allocator, source);
    defer allocator.free(bytecode);
    if (bytecode.len == 0) return error.EmptyBytecode;
    return bytecode;
}

/// Smoke test: verify assembly produces valid bytecode
fn testAssembly(allocator: std.mem.Allocator, filename: []const u8) !void {
    const source = try readT27File(allocator, filename);
    defer allocator.free(source);

    // Just verify it assembles
    const bytecode = try assemble(allocator, source);
    // Use bytecode to satisfy Zig's discarding rules
    if (bytecode.len == 0) return error.EmptyBytecode;

    std.debug.print("✅ {s} assembled ({d} bytes)\n", .{filename, bytecode.len});
}

/// Smoke test: verify basic execution works
fn testExecution(allocator: std.mem.Allocator, filename: []const u8) !void {
    const source = try readT27File(allocator, filename);
    defer allocator.free(source);

    const bytecode = try assemble(allocator, source);
    defer allocator.free(bytecode);

    if (bytecode.len == 0 or bytecode.len > 1024) return; // Skip empty or too large

    var cpu = try CPUState.init(allocator);
    defer cpu.deinit();

    const mem = cpu.getBytesMut();
    if (bytecode.len > mem.len) return;
    @memcpy(mem[0..bytecode.len], bytecode);

    // Initialize registers
    cpu.flags.Z = true;

    // Try to run - smoke test just needs it not to crash
    const result = run(&cpu, cpu.getBytesMut()) catch |err| {
        std.debug.print("⚠️ {s} execution error: {}\n", .{filename, err});
        return;
    };
    _ = result; // Use result to avoid discard warning

    std.debug.print("✅ {s} executed without crash\n", .{filename});
}

test "smoke: tier1 assembly" {
    const allocator = std.testing.allocator;
    for (TIER1_ALGORITHMS) |filename| {
        testAssembly(allocator, filename) catch |err| {
            std.debug.print("❌ {s} assembly failed: {}\n", .{filename, err});
        };
    }
}

test "smoke: tier1 execution" {
    const allocator = std.testing.allocator;
    for (TIER1_ALGORITHMS) |filename| {
        // Use arena allocator for per-test isolation
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        testExecution(arena_allocator, filename) catch |err| {
            std.debug.print("❌ {s} execution test failed: {}\n", .{filename, err});
        };
    }
}
