// Check output weight dimensions
const std = @import("std");
const gguf = @import("src/vibeec/gguf_reader.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== OUTPUT WEIGHT DIMENSION CHECK ===\n\n", .{});

    var reader = try gguf.GGUFReader.init(allocator, "models/bitnet-2b-fixed.gguf");
    defer reader.deinit();

    // Check key tensors
    const tensors = [_][]const u8{
        "token_embd.weight",
        "output.weight",
        "blk.0.attn_q.weight",
        "blk.0.ffn_gate.weight",
    };

    for (tensors) |name| {
        if (reader.getTensor(name)) |info| {
            std.debug.print("{s}:\n", .{name});
            std.debug.print("  type:     {} ({})\n", .{ info.tensor_type, @intFromEnum(info.tensor_type) });
            std.debug.print("  n_dims:   {}\n", .{info.n_dims});
            std.debug.print("  dims:     ", .{});
            for (0..info.n_dims) |i| {
                std.debug.print("{} ", .{info.dims[i]});
            }
            std.debug.print("\n", .{});
            std.debug.print("  elements: {}\n\n", .{info.numElements()});
        } else {
            std.debug.print("{s}: NOT FOUND\n\n", .{name});
        }
    }

    std.debug.print("Expected dimensions:\n", .{});
    std.debug.print("  vocab_size:      128256\n", .{});
    std.debug.print("  hidden_size:     2560\n", .{});
    std.debug.print("  num_heads:       20\n", .{});
    std.debug.print("  head_dim:        32 (fixed)\n", .{});
    std.debug.print("  intermediate:    1728 (ffn_gate_dim, fixed)\n\n", .{});

    std.debug.print("Matrix dimension conventions:\n", .{});
    std.debug.print("  GGUF stores row-major: [rows][cols]\n", .{});
    std.debug.print("  matVec computes: output = mat @ vec\n", .{});
    std.debug.print("  For y = W @ x:  W should be [output_dim][input_dim]\n\n", .{});
}
