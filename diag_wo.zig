// Diagnostic: Investigate Wo (attention output projection) and norm weights
const std = @import("std");
const model_mod = @import("src/vibeec/gguf_model.zig");
const gguf = @import("src/vibeec/gguf_reader.zig");

fn printStats(name: []const u8, data: []const f32) void {
    var sum: f64 = 0;
    var sum_sq: f64 = 0;
    var min: f32 = data[0];
    var max: f32 = data[0];

    for (data) |v| {
        sum += v;
        sum_sq += @as(f64, v) * @as(f64, v);
        if (v < min) min = v;
        if (v > max) max = v;
    }

    const n: f64 = @floatFromInt(data.len);
    const mean = sum / n;
    const l2 = @sqrt(sum_sq);

    std.debug.print("{s}: mean={d:.6}, min={d:.4}, max={d:.4}, L2={d:.2}\n", .{
        name, mean, min, max, l2
    });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";

    std.debug.print("=== Wo AND NORM WEIGHTS ANALYSIS ===\n\n", .{});

    var model = try model_mod.FullModel.init(allocator, path);
    defer model.deinit();
    try model.loadWeights();

    const hidden_size = model.config.hidden_size;
    const num_heads = model.config.num_heads;
    const head_dim = model.config.head_dim;

    std.debug.print("Config: hidden_size={d}, num_heads={d}, head_dim={d}\n", .{
        hidden_size, num_heads, head_dim
    });
    std.debug.print("Wo expected dims: [{d}, {d}] (out=hidden, in=heads*head_dim)\n\n", .{
        hidden_size, num_heads * head_dim
    });

    // Check norm weights for layers 0, 1, 2
    std.debug.print("=== ATTENTION NORM WEIGHTS ===\n", .{});
    for (0..3) |layer_idx| {
        var buf: [64]u8 = undefined;
        const name = std.fmt.bufPrint(&buf, "Layer {d} attn_norm", .{layer_idx}) catch "layer";
        printStats(name, model.layers[layer_idx].attn_norm);
    }

    std.debug.print("\n=== FFN NORM WEIGHTS ===\n", .{});
    for (0..3) |layer_idx| {
        var buf: [64]u8 = undefined;
        const name = std.fmt.bufPrint(&buf, "Layer {d} ffn_norm", .{layer_idx}) catch "layer";
        printStats(name, model.layers[layer_idx].ffn_norm);
    }

    std.debug.print("\n=== OUTPUT NORM WEIGHT ===\n", .{});
    printStats("output_norm", model.output_norm);

    // Check Wo weights for layers 0, 1, 2
    std.debug.print("\n=== Wo WEIGHTS (attn_output.weight) ===\n", .{});
    for (0..3) |layer_idx| {
        const wo = model.layers[layer_idx].wo;
        var buf: [64]u8 = undefined;
        const name = std.fmt.bufPrint(&buf, "Layer {d} Wo", .{layer_idx}) catch "layer";
        printStats(name, wo);

        // Check a few rows of Wo to see their norms
        std.debug.print("  Row norms (first 5 output neurons):\n", .{});
        for (0..5) |row| {
            const row_start = row * (num_heads * head_dim);
            const row_data = wo[row_start..][0..(num_heads * head_dim)];
            var row_sq: f64 = 0;
            for (row_data) |v| row_sq += @as(f64, v) * @as(f64, v);
            std.debug.print("    Row {d}: L2={d:.4}\n", .{ row, @sqrt(row_sq) });
        }
    }

    // Also check Wq, Wk, Wv for comparison
    std.debug.print("\n=== Q/K/V WEIGHT MATRICES (Layer 2) ===\n", .{});
    const layer2 = model.layers[2];
    printStats("Layer 2 Wq", layer2.wq);
    printStats("Layer 2 Wk", layer2.wk);
    printStats("Layer 2 Wv", layer2.wv);

    // Now check the GGUF tensor info directly for dimensions
    std.debug.print("\n=== GGUF TENSOR DIMENSIONS ===\n", .{});
    var reader = try gguf.GGUFReader.init(allocator, path);
    defer reader.deinit();

    const tensors_to_check = [_][]const u8{
        "blk.2.attn_output.weight",
        "blk.2.attn_q.weight",
        "blk.2.attn_k.weight",
        "blk.2.attn_v.weight",
        "blk.2.attn_norm.weight",
    };

    for (tensors_to_check) |name| {
        if (reader.getTensor(name)) |info| {
            std.debug.print("{s}: dims=[", .{name});
            for (info.dims[0..info.n_dims], 0..) |dim, i| {
                if (i > 0) std.debug.print(", ", .{});
                std.debug.print("{d}", .{dim});
            }
            std.debug.print("], type={}\n", .{info.tensor_type});
        }
    }

    std.debug.print("\n=== DIAGNOSTIC COMPLETE ===\n", .{});
}
