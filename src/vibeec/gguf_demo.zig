// GGUF DEMO - Load and inspect GGUF model
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const gguf = @import("gguf_reader.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const path = if (args.len > 1) args[1] else "models/qwen2.5-coder-1.5b-q4_k_m.gguf";

    std.debug.print("\n", .{});
    std.debug.print("GGUF READER DEMO\n", .{});
    std.debug.print("phi^2 + 1/phi^2 = 3 = TRINITY\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Loading: {s}\n", .{path});

    var reader = gguf.GGUFReader.init(allocator, path) catch |err| {
        std.debug.print("Error opening file: {}\n", .{err});
        return;
    };
    defer reader.deinit();

    reader.printInfo();

    // Print some metadata
    std.debug.print("\n", .{});
    std.debug.print("MODEL METADATA\n", .{});

    const arch = reader.getMetadataString("general.architecture") orelse "unknown";
    std.debug.print("  Architecture:     {s}\n", .{arch});

    // Try architecture-specific keys
    var key_buf: [64]u8 = undefined;

    const ctx_key = std.fmt.bufPrint(&key_buf, "{s}.context_length", .{arch}) catch "llama.context_length";
    if (reader.getMetadataU64(ctx_key)) |ctx| {
        std.debug.print("  Context length:   {d}\n", .{ctx});
    }

    const emb_key = std.fmt.bufPrint(&key_buf, "{s}.embedding_length", .{arch}) catch "llama.embedding_length";
    if (reader.getMetadataU64(emb_key)) |emb| {
        std.debug.print("  Embedding size:   {d}\n", .{emb});
    }

    const blk_key = std.fmt.bufPrint(&key_buf, "{s}.block_count", .{arch}) catch "llama.block_count";
    if (reader.getMetadataU64(blk_key)) |blk| {
        std.debug.print("  Num layers:       {d}\n", .{blk});
    }

    const head_key = std.fmt.bufPrint(&key_buf, "{s}.attention.head_count", .{arch}) catch "llama.attention.head_count";
    if (reader.getMetadataU64(head_key)) |heads| {
        std.debug.print("  Attention heads:  {d}\n", .{heads});
    }

    const kv_key = std.fmt.bufPrint(&key_buf, "{s}.attention.head_count_kv", .{arch}) catch "llama.attention.head_count_kv";
    if (reader.getMetadataU64(kv_key)) |kv| {
        std.debug.print("  KV heads:         {d}\n", .{kv});
    }

    // Print tensor info
    std.debug.print("\n", .{});
    std.debug.print("TENSORS ({d} total)\n", .{reader.tensors.items.len});

    var total_params: u64 = 0;
    var total_size: u64 = 0;

    for (reader.tensors.items, 0..) |t, i| {
        if (i < 10 or i >= reader.tensors.items.len - 3) {
            std.debug.print("  [{d:>3}] {s:<40} ", .{ i, t.name[0..@min(t.name.len, 40)] });
            std.debug.print("type={s:<6} ", .{@tagName(t.tensor_type)[0..@min(@tagName(t.tensor_type).len, 6)]});
            std.debug.print("dims=[", .{});
            var j: usize = 0;
            while (j < t.n_dims) : (j += 1) {
                if (j > 0) std.debug.print(",", .{});
                std.debug.print("{d}", .{t.dims[j]});
            }
            std.debug.print("]\n", .{});
        } else if (i == 10) {
            std.debug.print("  ... ({d} more tensors) ...\n", .{reader.tensors.items.len - 13});
        }
        total_params += t.numElements();
        total_size += t.dataSize();
    }

    std.debug.print("\n", .{});
    std.debug.print("SUMMARY\n", .{});
    std.debug.print("  Total parameters: {d:.2}B\n", .{@as(f64, @floatFromInt(total_params)) / 1e9});
    std.debug.print("  Model size:       {d:.2} GB\n", .{@as(f64, @floatFromInt(total_size)) / 1e9});
    std.debug.print("  Data offset:      {d}\n", .{reader.data_offset});

    std.debug.print("\n", .{});
    std.debug.print("KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n", .{});
}

test "load_gguf" {
    // Just verify compilation
}
