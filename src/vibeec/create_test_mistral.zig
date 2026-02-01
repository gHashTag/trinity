// CREATE TEST MISTRAL MODEL
// Создание тестовой модели со структурой Mistral для проверки пайплайна
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const output_path = "src/vibeec/test_mistral_mini.safetensors";

    // Mini Mistral config (scaled down for testing)
    const vocab_size: usize = 256;
    const hidden_size: usize = 64;
    const intermediate_size: usize = 128;
    const num_layers: usize = 2;
    const num_heads: usize = 4;
    const num_kv_heads: usize = 2;
    const head_dim = hidden_size / num_heads;

    std.debug.print("Creating test Mistral model...\n", .{});
    std.debug.print("  vocab_size: {d}\n", .{vocab_size});
    std.debug.print("  hidden_size: {d}\n", .{hidden_size});
    std.debug.print("  intermediate_size: {d}\n", .{intermediate_size});
    std.debug.print("  num_layers: {d}\n", .{num_layers});

    // Build JSON header
    var header = std.ArrayList(u8).init(allocator);
    defer header.deinit();

    try header.appendSlice("{");

    var offset: usize = 0;
    var first = true;

    // Helper to add tensor
    const addTensor = struct {
        fn add(h: *std.ArrayList(u8), name: []const u8, shape: []const usize, off: *usize, is_first: *bool) !void {
            if (!is_first.*) {
                try h.appendSlice(",");
            }
            is_first.* = false;

            var size: usize = 4; // f32
            for (shape) |dim| {
                size *= dim;
            }

            try h.writer().print("\"{s}\":{{\"dtype\":\"F32\",\"shape\":[", .{name});
            for (shape, 0..) |dim, i| {
                if (i > 0) try h.appendSlice(",");
                try h.writer().print("{d}", .{dim});
            }
            try h.writer().print("],\"data_offsets\":[{d},{d}]}}", .{ off.*, off.* + size });
            off.* += size;
        }
    }.add;

    // Embedding
    try addTensor(&header, "model.embed_tokens.weight", &[_]usize{ vocab_size, hidden_size }, &offset, &first);

    // Layers
    for (0..num_layers) |layer| {
        var name_buf: [128]u8 = undefined;

        // Attention
        const q_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.self_attn.q_proj.weight", .{layer});
        try addTensor(&header, q_name, &[_]usize{ hidden_size, hidden_size }, &offset, &first);

        const k_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.self_attn.k_proj.weight", .{layer});
        try addTensor(&header, k_name, &[_]usize{ num_kv_heads * head_dim, hidden_size }, &offset, &first);

        const v_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.self_attn.v_proj.weight", .{layer});
        try addTensor(&header, v_name, &[_]usize{ num_kv_heads * head_dim, hidden_size }, &offset, &first);

        const o_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.self_attn.o_proj.weight", .{layer});
        try addTensor(&header, o_name, &[_]usize{ hidden_size, hidden_size }, &offset, &first);

        // MLP
        const gate_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.mlp.gate_proj.weight", .{layer});
        try addTensor(&header, gate_name, &[_]usize{ intermediate_size, hidden_size }, &offset, &first);

        const up_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.mlp.up_proj.weight", .{layer});
        try addTensor(&header, up_name, &[_]usize{ intermediate_size, hidden_size }, &offset, &first);

        const down_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.mlp.down_proj.weight", .{layer});
        try addTensor(&header, down_name, &[_]usize{ hidden_size, intermediate_size }, &offset, &first);
    }

    // LM head
    try addTensor(&header, "lm_head.weight", &[_]usize{ vocab_size, hidden_size }, &offset, &first);

    try header.appendSlice("}");

    // Write file
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();

    // Header size (8 bytes, little-endian)
    var header_size_bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &header_size_bytes, header.items.len, .little);
    try file.writeAll(&header_size_bytes);

    // Header
    try file.writeAll(header.items);

    // Data (random f32)
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();

    const data = try allocator.alloc(u8, offset);
    defer allocator.free(data);

    var i: usize = 0;
    while (i < offset) : (i += 4) {
        const val = random.float(f32) * 2.0 - 1.0;
        const bytes: [4]u8 = @bitCast(val);
        @memcpy(data[i..][0..4], &bytes);
    }

    try file.writeAll(data);

    const total_params = offset / 4;
    std.debug.print("\n✅ Created {s}\n", .{output_path});
    std.debug.print("   Total parameters: {d}\n", .{total_params});
    std.debug.print("   File size: {d} bytes\n", .{8 + header.items.len + offset});
}
