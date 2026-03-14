// @origin(spec:bpe_train.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — BPE Tokenizer Trainer
// Learns 469 byte-pair merge rules from corpus data
// Outputs: src/hslm/bpe_merges.zig (comptime arrays, zero runtime I/O)
//
// Usage: zig build bpe-train -- --data data/tinystories/real_tinystories.txt --output src/hslm/bpe_merges.zig

const std = @import("std");

const MERGE_COUNT: usize = 469;
const MAX_CORPUS_BYTES: usize = 50 * 1024 * 1024; // 50MB
const MERGE_OFFSET: u16 = 260; // Byte offset (4) + byte count (256)

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var data_path: []const u8 = "data/tinystories/real_tinystories.txt";
    var output_path: []const u8 = "src/hslm/bpe_merges.zig";

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--data") and i + 1 < args.len) {
            i += 1;
            data_path = args[i];
        } else if (std.mem.eql(u8, args[i], "--output") and i + 1 < args.len) {
            i += 1;
            output_path = args[i];
        }
    }

    std.debug.print("BPE Trainer: reading corpus from {s}\n", .{data_path});

    // Read corpus (first MAX_CORPUS_BYTES)
    const file = try std.fs.cwd().openFile(data_path, .{});
    defer file.close();

    const stat = try file.stat();
    const read_size = @min(stat.size, MAX_CORPUS_BYTES);
    const corpus = try allocator.alloc(u8, read_size);
    defer allocator.free(corpus);

    const reader = file.deprecatedReader();
    const bytes_read = try reader.readAll(corpus);
    const corpus_data = corpus[0..bytes_read];

    std.debug.print("BPE Trainer: loaded {d} bytes\n", .{bytes_read});

    // Convert corpus to token sequence (each byte → u16 token)
    var tokens = try std.ArrayList(u16).initCapacity(allocator, bytes_read);
    defer tokens.deinit(allocator);
    for (corpus_data) |byte| {
        try tokens.append(allocator, @as(u16, byte) + 4); // BYTE_OFFSET = 4
    }

    // Storage for merge rules: merge_rules[i] = {left_token, right_token}
    var merge_rules: [MERGE_COUNT][2]u16 = undefined;

    // Storage for token byte sequences (for decode)
    // Each merged token maps to a variable-length byte sequence
    var token_bytes = std.AutoArrayHashMap(u16, []u8).init(allocator);
    defer {
        var it = token_bytes.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.value_ptr.*);
        }
        token_bytes.deinit();
    }

    // Initialize byte tokens → single byte
    for (0..256) |b| {
        const slice = try allocator.alloc(u8, 1);
        slice[0] = @intCast(b);
        try token_bytes.put(@as(u16, @intCast(b)) + 4, slice);
    }

    // BPE training loop
    std.debug.print("BPE Trainer: learning {d} merge rules...\n", .{MERGE_COUNT});

    for (0..MERGE_COUNT) |merge_idx| {
        // Count adjacent pairs
        var pair_counts = std.AutoHashMap(u32, u64).init(allocator);
        defer pair_counts.deinit();

        const seq = tokens.items;
        if (seq.len < 2) break;

        for (0..seq.len - 1) |j| {
            const key = pairKey(seq[j], seq[j + 1]);
            const entry = try pair_counts.getOrPut(key);
            if (!entry.found_existing) {
                entry.value_ptr.* = 0;
            }
            entry.value_ptr.* += 1;
        }

        // Find most frequent pair
        var best_key: u32 = 0;
        var best_count: u64 = 0;
        var pit = pair_counts.iterator();
        while (pit.next()) |entry| {
            if (entry.value_ptr.* > best_count) {
                best_count = entry.value_ptr.*;
                best_key = entry.key_ptr.*;
            }
        }

        if (best_count < 2) break;

        const left: u16 = @intCast(best_key >> 16);
        const right: u16 = @intCast(best_key & 0xFFFF);
        const new_token: u16 = MERGE_OFFSET + @as(u16, @intCast(merge_idx));

        merge_rules[merge_idx] = .{ left, right };

        // Build byte sequence for new token
        const left_bytes = token_bytes.get(left).?;
        const right_bytes = token_bytes.get(right).?;
        const merged_bytes = try allocator.alloc(u8, left_bytes.len + right_bytes.len);
        @memcpy(merged_bytes[0..left_bytes.len], left_bytes);
        @memcpy(merged_bytes[left_bytes.len..], right_bytes);
        try token_bytes.put(new_token, merged_bytes);

        // Apply merge to token sequence in-place
        var read_pos: usize = 0;
        var write_pos: usize = 0;
        while (read_pos < tokens.items.len) {
            if (read_pos + 1 < tokens.items.len and
                tokens.items[read_pos] == left and
                tokens.items[read_pos + 1] == right)
            {
                tokens.items[write_pos] = new_token;
                write_pos += 1;
                read_pos += 2;
            } else {
                tokens.items[write_pos] = tokens.items[read_pos];
                write_pos += 1;
                read_pos += 1;
            }
        }
        tokens.shrinkRetainingCapacity(write_pos);

        if ((merge_idx + 1) % 50 == 0 or merge_idx < 10) {
            const bytes_repr = token_bytes.get(new_token).?;
            std.debug.print("  merge {d}/{d}: ", .{ merge_idx + 1, MERGE_COUNT });
            printRepr(bytes_repr);
            std.debug.print(" (count={d}, seq_len={d})\n", .{ best_count, tokens.items.len });
        }
    }

    // Write output Zig source file
    std.debug.print("BPE Trainer: writing {s}\n", .{output_path});

    const out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();

    const writer = out_file.deprecatedWriter();

    try writer.writeAll(
        \\// HSLM — BPE Merge Rules (auto-generated)
        \\// Do NOT edit manually. Regenerate with: zig build bpe-train
        \\//
        \\// 469 merge rules learned from corpus data
        \\
        \\
    );

    // Write merge rules
    try writer.writeAll("pub const merge_rules: [469][2]u16 = .{\n");
    for (0..MERGE_COUNT) |mi| {
        try writer.print("    .{{ {d}, {d} }},\n", .{ merge_rules[mi][0], merge_rules[mi][1] });
    }
    try writer.writeAll("};\n\n");

    // Write token byte sequences for decode
    // Each merge token (260..728) maps to a byte sequence
    try writer.writeAll("/// Byte sequences for each merge token (index 0 = token 260)\n");
    try writer.writeAll("pub const merge_byte_lengths: [469]u8 = .{\n");
    for (0..MERGE_COUNT) |mi| {
        const tok: u16 = MERGE_OFFSET + @as(u16, @intCast(mi));
        const bytes = token_bytes.get(tok).?;
        if (mi % 20 == 0 and mi > 0) try writer.writeAll("\n");
        try writer.print("    {d},", .{bytes.len});
    }
    try writer.writeAll("\n};\n\n");

    // Write flattened byte data
    try writer.writeAll("/// Flattened byte data for all merge tokens\n");
    try writer.writeAll("pub const merge_byte_data: [");
    var total_bytes: usize = 0;
    for (0..MERGE_COUNT) |mi| {
        const tok: u16 = MERGE_OFFSET + @as(u16, @intCast(mi));
        total_bytes += token_bytes.get(tok).?.len;
    }
    try writer.print("{d}", .{total_bytes});
    try writer.writeAll("]u8 = .{\n");
    for (0..MERGE_COUNT) |mi| {
        const tok: u16 = MERGE_OFFSET + @as(u16, @intCast(mi));
        const bytes = token_bytes.get(tok).?;
        try writer.writeAll("    ");
        for (bytes) |b| {
            try writer.print("{d}, ", .{b});
        }
        try writer.writeAll("\n");
    }
    try writer.writeAll("};\n");

    std.debug.print("BPE Trainer: done! {d} merge rules written.\n", .{MERGE_COUNT});
    std.debug.print("Compression: {d} bytes → {d} tokens ({d:.2} tokens/byte)\n", .{
        bytes_read,
        tokens.items.len,
        @as(f64, @floatFromInt(tokens.items.len)) / @as(f64, @floatFromInt(bytes_read)),
    });
}

fn pairKey(a: u16, b: u16) u32 {
    return (@as(u32, a) << 16) | @as(u32, b);
}

fn printRepr(bytes: []const u8) void {
    std.debug.print("\"", .{});
    for (bytes) |b| {
        if (b >= 32 and b < 127) {
            std.debug.print("{c}", .{b});
        } else {
            std.debug.print("\\x{x:0>2}", .{b});
        }
    }
    std.debug.print("\"", .{});
}
