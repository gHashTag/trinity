// Diagnostic: Verify Q4_K dequantization against expected values
const std = @import("std");
const gguf = @import("src/vibeec/gguf_reader.zig");
const inference = @import("src/vibeec/gguf_inference.zig");

fn printStats(name: []const u8, data: []const f32) void {
    var min: f32 = data[0];
    var max: f32 = data[0];
    var sum: f64 = 0;
    var sum_sq: f64 = 0;

    for (data) |v| {
        if (v < min) min = v;
        if (v > max) max = v;
        sum += v;
        sum_sq += @as(f64, v) * @as(f64, v);
    }

    const n: f64 = @floatFromInt(data.len);
    const mean = sum / n;
    const variance = (sum_sq / n) - (mean * mean);
    const std_dev = @sqrt(@abs(variance));

    std.debug.print("{s}:\n", .{name});
    std.debug.print("  len={d}, min={d:.4}, max={d:.4}, mean={d:.6}, std={d:.4}\n", .{
        data.len, min, max, mean, std_dev
    });
    std.debug.print("  first 10: ", .{});
    for (data[0..@min(10, data.len)]) |v| {
        std.debug.print("{d:.4} ", .{v});
    }
    std.debug.print("\n\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const path = "models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf";

    std.debug.print("=== Q4_K DEQUANTIZATION VERIFICATION ===\n\n", .{});

    var reader = try gguf.GGUFReader.init(allocator, path);
    defer reader.deinit();

    // Load and dequantize specific tensors
    const tensors_to_check = [_][]const u8{
        "token_embd.weight",
        "blk.0.attn_q.weight",
        "blk.0.attn_k.weight",
        "blk.0.ffn_gate.weight",
    };

    for (tensors_to_check) |name| {
        if (reader.getTensor(name)) |info| {
            std.debug.print("Loading {s} (type: {}, elements: {d})...\n", .{
                name, info.tensor_type, info.numElements()
            });

            const raw_data = try reader.readTensorData(info);
            defer allocator.free(raw_data);

            const dequantized = try inference.dequantizeTensor(
                allocator, raw_data, info.tensor_type, info.numElements()
            );
            defer allocator.free(dequantized);

            printStats(name, dequantized);

            // For embedding, check specific token embeddings
            if (std.mem.eql(u8, name, "token_embd.weight")) {
                const hidden_size: usize = 2048;
                std.debug.print("  Checking specific token embeddings:\n", .{});

                // Token 1 (BOS)
                const bos_emb = dequantized[1 * hidden_size ..][0..hidden_size];
                var bos_sum: f64 = 0;
                for (bos_emb) |v| bos_sum += v;
                std.debug.print("    Token 1 (BOS) mean: {d:.6}\n", .{bos_sum / @as(f64, @floatFromInt(hidden_size))});

                // Token 450 ("The")
                const the_emb = dequantized[450 * hidden_size ..][0..hidden_size];
                var the_sum: f64 = 0;
                for (the_emb) |v| the_sum += v;
                std.debug.print("    Token 450 ('The') mean: {d:.6}\n", .{the_sum / @as(f64, @floatFromInt(hidden_size))});

                // Check if embeddings are distinct
                var diff: f64 = 0;
                for (0..hidden_size) |i| {
                    const d = bos_emb[i] - the_emb[i];
                    diff += d * d;
                }
                std.debug.print("    L2 distance between BOS and 'The': {d:.4}\n\n", .{@sqrt(diff)});
            }
        } else {
            std.debug.print("{s}: NOT FOUND\n\n", .{name});
        }
    }

    // Now let's verify the Q4_K formula by manually dequantizing a single block
    std.debug.print("=== MANUAL Q4_K BLOCK VERIFICATION ===\n\n", .{});

    if (reader.getTensor("blk.0.attn_q.weight")) |info| {
        const raw = try reader.readTensorData(info);
        defer allocator.free(raw);

        // Q4_K block structure:
        // d (f16, 2 bytes) + dmin (f16, 2 bytes) + scales[12] + qs[128]
        // Total: 144 bytes per 256 elements

        std.debug.print("First Q4_K block raw bytes:\n", .{});
        std.debug.print("  d (f16):    0x{x:0>2}{x:0>2}\n", .{ raw[1], raw[0] });
        std.debug.print("  dmin (f16): 0x{x:0>2}{x:0>2}\n", .{ raw[3], raw[2] });
        std.debug.print("  scales[0..4]: {x:0>2} {x:0>2} {x:0>2} {x:0>2}\n", .{ raw[4], raw[5], raw[6], raw[7] });
        std.debug.print("  qs[0..8]: {x:0>2} {x:0>2} {x:0>2} {x:0>2} {x:0>2} {x:0>2} {x:0>2} {x:0>2}\n", .{
            raw[16], raw[17], raw[18], raw[19], raw[20], raw[21], raw[22], raw[23]
        });

        // Dequantize first block
        const d_bits = @as(u16, raw[0]) | (@as(u16, raw[1]) << 8);
        const dmin_bits = @as(u16, raw[2]) | (@as(u16, raw[3]) << 8);
        const d = gguf.f16ToF32(d_bits);
        const min = gguf.f16ToF32(dmin_bits);

        std.debug.print("\n  d = {d:.6}, dmin = {d:.6}\n", .{ d, min });

        // First sub-block scale and min
        const sc0 = raw[4] & 63;
        const m0 = raw[8] & 63;
        const d1 = d * @as(f32, @floatFromInt(sc0));
        const m1 = min * @as(f32, @floatFromInt(m0));
        std.debug.print("  Sub-block 0: scale={d}, min_scale={d}, d1={d:.6}, m1={d:.6}\n", .{ sc0, m0, d1, m1 });

        // First few dequantized values
        std.debug.print("  First 8 dequantized values:\n    ", .{});
        for (0..8) |i| {
            const q = raw[16 + i] & 0x0F;
            const val = d1 * @as(f32, @floatFromInt(q)) - m1;
            std.debug.print("{d:.4} ", .{val});
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("\n=== DIAGNOSTIC COMPLETE ===\n", .{});
}
