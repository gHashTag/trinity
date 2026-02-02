// Create minimal .tri test model for validation
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL

const std = @import("std");
const tri = @import("tri_inference.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Minimal model config
    const vocab_size: u32 = 32;
    const hidden_size: u32 = 64;
    const intermediate_size: u32 = 128;
    const num_layers: u32 = 2;
    const num_heads: u32 = 4;
    const num_kv_heads: u32 = 4;
    const head_dim: u32 = hidden_size / num_heads; // 16
    const context_length: u32 = 64;

    // Calculate sizes
    const emb_size = vocab_size * hidden_size;
    const norm_size = hidden_size;
    const output_ternary_size = (vocab_size * hidden_size + 3) / 4;

    // Per layer ternary sizes
    const attn_ternary_size = (hidden_size * num_heads * head_dim + 3) / 4;
    const kv_ternary_size = (hidden_size * num_kv_heads * head_dim + 3) / 4;
    const ffn_ternary_size = (hidden_size * intermediate_size + 3) / 4;
    const ffn_down_ternary_size = (intermediate_size * hidden_size + 3) / 4;

    const total_ternary = output_ternary_size + num_layers * (attn_ternary_size + kv_ternary_size * 2 + attn_ternary_size + ffn_ternary_size * 2 + ffn_down_ternary_size);
    _ = allocator;

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           CREATING MINIMAL .TRI TEST MODEL                   ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Config:\n", .{});
    std.debug.print("  vocab_size:        {d}\n", .{vocab_size});
    std.debug.print("  hidden_size:       {d}\n", .{hidden_size});
    std.debug.print("  intermediate_size: {d}\n", .{intermediate_size});
    std.debug.print("  num_layers:        {d}\n", .{num_layers});
    std.debug.print("  num_heads:         {d}\n", .{num_heads});
    std.debug.print("  num_kv_heads:      {d}\n", .{num_kv_heads});
    std.debug.print("  head_dim:          {d}\n", .{head_dim});
    std.debug.print("  context_length:    {d}\n", .{context_length});
    std.debug.print("\n", .{});

    // Create header
    const header = tri.TriHeader{
        .magic = tri.TRI_MAGIC,
        .version = 1,
        .model_type = 1,
        .vocab_size = vocab_size,
        .hidden_size = hidden_size,
        .intermediate_size = intermediate_size,
        .num_layers = num_layers,
        .num_heads = num_heads,
        .num_kv_heads = num_kv_heads,
        .head_dim = head_dim,
        .context_length = context_length,
        .rope_theta = 10000.0,
        .rms_norm_eps = 1e-5,
        .total_params = emb_size + norm_size + total_ternary,
        .ternary_size = total_ternary,
        .embedding_offset = @sizeOf(tri.TriHeader),
        .output_norm_offset = @sizeOf(tri.TriHeader) + emb_size * @sizeOf(f32),
        .output_weight_offset = @sizeOf(tri.TriHeader) + emb_size * @sizeOf(f32) + norm_size * @sizeOf(f32),
        .layers_offset = @sizeOf(tri.TriHeader) + emb_size * @sizeOf(f32) + norm_size * @sizeOf(f32) + @sizeOf(f32) + output_ternary_size,
    };

    // Create file
    const file = try std.fs.cwd().createFile("test_minimal.tri", .{});
    defer file.close();
    const writer = file.writer();

    // Write header
    try writer.writeAll(std.mem.asBytes(&header));

    // Write embeddings (random f32)
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();

    for (0..emb_size) |_| {
        const val = random.float(f32) * 2.0 - 1.0;
        try writer.writeAll(std.mem.asBytes(&val));
    }

    // Write output norm (ones)
    for (0..norm_size) |_| {
        const val: f32 = 1.0;
        try writer.writeAll(std.mem.asBytes(&val));
    }

    // Write output scale
    const output_scale: f32 = 1.0;
    try writer.writeAll(std.mem.asBytes(&output_scale));

    // Write output ternary weights (random trits)
    for (0..output_ternary_size) |_| {
        const byte: u8 = random.int(u8);
        try writer.writeByte(byte);
    }

    // Write layers
    for (0..num_layers) |_| {
        // attn_norm (f32)
        for (0..norm_size) |_| {
            const val: f32 = 1.0;
            try writer.writeAll(std.mem.asBytes(&val));
        }

        // ffn_norm (f32)
        for (0..norm_size) |_| {
            const val: f32 = 1.0;
            try writer.writeAll(std.mem.asBytes(&val));
        }

        // wq scale + ternary
        const scale: f32 = 1.0;
        try writer.writeAll(std.mem.asBytes(&scale));
        for (0..attn_ternary_size) |_| {
            try writer.writeByte(random.int(u8));
        }

        // wk scale + ternary
        try writer.writeAll(std.mem.asBytes(&scale));
        for (0..kv_ternary_size) |_| {
            try writer.writeByte(random.int(u8));
        }

        // wv scale + ternary
        try writer.writeAll(std.mem.asBytes(&scale));
        for (0..kv_ternary_size) |_| {
            try writer.writeByte(random.int(u8));
        }

        // wo scale + ternary
        try writer.writeAll(std.mem.asBytes(&scale));
        for (0..attn_ternary_size) |_| {
            try writer.writeByte(random.int(u8));
        }

        // w_gate scale + ternary
        try writer.writeAll(std.mem.asBytes(&scale));
        for (0..ffn_ternary_size) |_| {
            try writer.writeByte(random.int(u8));
        }

        // w_up scale + ternary
        try writer.writeAll(std.mem.asBytes(&scale));
        for (0..ffn_ternary_size) |_| {
            try writer.writeByte(random.int(u8));
        }

        // w_down scale + ternary
        try writer.writeAll(std.mem.asBytes(&scale));
        for (0..ffn_down_ternary_size) |_| {
            try writer.writeByte(random.int(u8));
        }
    }

    const file_size = try file.getPos();
    std.debug.print("Created test_minimal.tri ({d} bytes)\n", .{file_size});
    std.debug.print("\nKOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n", .{});
}
