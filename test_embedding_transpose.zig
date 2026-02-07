// Verify embedding transpose issue
const std = @import("std");
const model_mod = @import("src/vibeec/gguf_model.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== EMBEDDING TRANSPOSE CHECK ===\n\n", .{});

    var model = model_mod.FullModel.init(allocator, "models/bitnet-2b-fixed.gguf") catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return;
    };
    defer model.deinit();
    try model.loadWeights();

    const hidden_size = model.config.hidden_size; // 2560
    const vocab_size = model.config.vocab_size;    // 128256
    const token: u32 = 9906;

    std.debug.print("hidden_size: {}, vocab_size: {}\n", .{ hidden_size, vocab_size });
    std.debug.print("token: {}\n\n", .{token});

    // Current lookup (WRONG - assumes vocab x hidden):
    const wrong_start = @as(usize, token) * hidden_size;
    std.debug.print("WRONG lookup (token * hidden_size = {} * {} = {}):\n", .{ token, hidden_size, wrong_start });
    std.debug.print("  First 5 values: ", .{});
    for (0..5) |i| {
        std.debug.print("{d:.4} ", .{model.token_embedding[wrong_start + i]});
    }
    std.debug.print("\n\n", .{});

    // Correct lookup (hidden x vocab layout - gather across rows):
    std.debug.print("CORRECT lookup (gather from each hidden row at col={}):\n", .{token});
    std.debug.print("  First 5 values: ", .{});
    for (0..5) |h| {
        // In [hidden_size][vocab_size] layout:
        // embedding[h][token] = embedding[h * vocab_size + token]
        const idx = h * vocab_size + token;
        std.debug.print("{d:.4} ", .{model.token_embedding[idx]});
    }
    std.debug.print("\n\n", .{});

    // Show non-zero count in correct positions
    var nonzero_correct: usize = 0;
    for (0..hidden_size) |h| {
        const idx = h * vocab_size + token;
        if (@abs(model.token_embedding[idx]) > 1e-6) nonzero_correct += 1;
    }
    std.debug.print("Non-zero in CORRECT positions: {} / {}\n", .{ nonzero_correct, hidden_size });

    // Show non-zero count in wrong positions
    var nonzero_wrong: usize = 0;
    for (0..hidden_size) |i| {
        if (@abs(model.token_embedding[wrong_start + i]) > 1e-6) nonzero_wrong += 1;
    }
    std.debug.print("Non-zero in WRONG positions: {} / {}\n", .{ nonzero_wrong, hidden_size });

    std.debug.print("\n=== CHECK COMPLETE ===\n\n", .{});
}
