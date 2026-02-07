// Check embedding size and bounds
const std = @import("std");
const model_mod = @import("src/vibeec/gguf_model.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== EMBEDDING SIZE CHECK ===\n\n", .{});

    var model = model_mod.FullModel.init(allocator, "models/bitnet-2b-fixed.gguf") catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return;
    };
    defer model.deinit();
    try model.loadWeights();

    const hidden_size = model.config.hidden_size;
    const vocab_size = model.config.vocab_size;

    std.debug.print("Config:\n", .{});
    std.debug.print("  vocab_size:           {}\n", .{vocab_size});
    std.debug.print("  hidden_size:          {}\n", .{hidden_size});
    std.debug.print("  expected_emb_len:     {} (vocab * hidden)\n", .{vocab_size * hidden_size});
    std.debug.print("  actual_emb_len:       {}\n", .{model.token_embedding.len});

    const token: u32 = 9906;
    const emb_start = @as(usize, token) * hidden_size;
    const emb_end = emb_start + hidden_size;

    std.debug.print("\nToken {} lookup:\n", .{token});
    std.debug.print("  emb_start:            {}\n", .{emb_start});
    std.debug.print("  emb_end:              {}\n", .{emb_end});
    std.debug.print("  array_len:            {}\n", .{model.token_embedding.len});

    if (emb_end <= model.token_embedding.len) {
        std.debug.print("  status:               IN BOUNDS\n", .{});

        // Check first few values at that position
        std.debug.print("\n  First 10 values at position:\n", .{});
        for (0..10) |i| {
            std.debug.print("    [{d}] = {d:.6}\n", .{ i, model.token_embedding[emb_start + i] });
        }
    } else {
        std.debug.print("  status:               OUT OF BOUNDS!\n", .{});
        std.debug.print("  missing:              {} elements\n", .{emb_end - model.token_embedding.len});
    }

    // Also check BOS token (128000)
    const bos_token: u32 = 128000;
    const bos_start = @as(usize, bos_token) * hidden_size;
    const bos_end = bos_start + hidden_size;

    std.debug.print("\nBOS token {} lookup:\n", .{bos_token});
    std.debug.print("  bos_start:            {}\n", .{bos_start});
    std.debug.print("  bos_end:              {}\n", .{bos_end});
    if (bos_end <= model.token_embedding.len) {
        std.debug.print("  status:               IN BOUNDS\n", .{});
    } else {
        std.debug.print("  status:               OUT OF BOUNDS!\n", .{});
    }

    std.debug.print("\n=== CHECK COMPLETE ===\n\n", .{});
}
