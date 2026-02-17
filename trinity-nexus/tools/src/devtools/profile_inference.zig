// Profile inference to find bottlenecks
const std = @import("std");
const model_mod = @import("gguf_model.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("           INFERENCE PROFILER\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const path = if (args.len > 1) args[1] else "models/tinyllama-1.1b-q8_0.gguf";

    // Load model
    std.debug.print("\nLoading model: {s}\n", .{path});
    var model = try model_mod.FullModel.init(allocator, path);
    defer model.deinit();

    std.debug.print("Loading weights...\n", .{});
    try model.loadWeights();
    std.debug.print("Model ready!\n\n", .{});

    // Profile forward pass
    const num_tokens = 10;
    var total_time: u64 = 0;

    std.debug.print("Profiling {d} forward passes...\n", .{num_tokens});

    for (0..num_tokens) |pos| {
        var timer = try std.time.Timer.start();
        
        const logits = try model.forward(1, pos); // token 1
        allocator.free(logits);
        
        const elapsed = timer.read();
        total_time += elapsed;
        
        std.debug.print("  Token {d}: {d:.1} ms\n", .{pos, @as(f64, @floatFromInt(elapsed)) / 1e6});
    }

    const avg_ms = @as(f64, @floatFromInt(total_time)) / @as(f64, @floatFromInt(num_tokens)) / 1e6;
    const tok_per_sec = 1000.0 / avg_ms;

    std.debug.print("\n", .{});
    std.debug.print("RESULTS:\n", .{});
    std.debug.print("  Total time: {d:.1} ms\n", .{@as(f64, @floatFromInt(total_time)) / 1e6});
    std.debug.print("  Avg per token: {d:.1} ms\n", .{avg_ms});
    std.debug.print("  Throughput: {d:.2} tok/s\n", .{tok_per_sec});
    std.debug.print("\n", .{});

    // Breakdown estimate
    const config = model.config;
    std.debug.print("ESTIMATED BREAKDOWN (per token):\n", .{});
    
    const qkv_ops = config.hidden_size * config.hidden_size + 
                    2 * config.hidden_size * config.num_kv_heads * config.head_dim;
    const attn_ops = config.num_heads * config.head_dim * config.hidden_size;
    const ffn_ops = 3 * config.hidden_size * config.intermediate_size;
    const output_ops = config.vocab_size * config.hidden_size;
    
    const total_ops_per_layer = qkv_ops + attn_ops + ffn_ops;
    const total_ops = total_ops_per_layer * config.num_layers + output_ops;
    
    std.debug.print("  Layers: {d}\n", .{config.num_layers});
    std.debug.print("  Ops per layer: {d:.1}M\n", .{@as(f64, @floatFromInt(total_ops_per_layer)) / 1e6});
    std.debug.print("  Output proj: {d:.1}M\n", .{@as(f64, @floatFromInt(output_ops)) / 1e6});
    std.debug.print("  Total ops: {d:.1}M\n", .{@as(f64, @floatFromInt(total_ops)) / 1e6});
    
    const gflops = @as(f64, @floatFromInt(total_ops)) * 2.0 / (avg_ms / 1000.0) / 1e9;
    std.debug.print("  Achieved: {d:.2} GFLOPS\n", .{gflops});
}
