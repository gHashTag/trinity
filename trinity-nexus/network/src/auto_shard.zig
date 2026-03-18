// ═══════════════════════════════════════════════════════════════════════════════
// AUTO-SHARD: Memory-aware layer assignment for distributed inference
// ═══════════════════════════════════════════════════════════════════════════════
//
// Queries available system RAM and computes optimal layer splits for N nodes.
// Supports both Q4_K (quantized) and f32 (dequantized) weight formats.
//
// Usage:
//   const info = try auto_shard.getSystemMemory();
//   const plan = auto_shard.planShards(info.available_bytes, ...);
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const builtin = @import("builtin");

/// Per-layer memory cost estimates for common model sizes
pub const MemoryProfile = struct {
    /// Bytes per layer for weight matrices
    bytes_per_layer: u64,
    /// Bytes for embedding table (first node only)
    embedding_bytes: u64,
    /// Bytes for output head (last node only)
    output_bytes: u64,
    /// Bytes for forward buffers (per node, fixed overhead)
    buffer_bytes: u64,
    /// Human-readable model name
    model_name: []const u8,
};

/// Pre-computed profiles for known models
pub const QWEN2_5_7B_Q4K = MemoryProfile{
    .bytes_per_layer = 131 * 1024 * 1024, // ~131MB per layer in Q4_K
    .embedding_bytes = 460 * 1024 * 1024, // embedding table
    .output_bytes = 460 * 1024 * 1024, // output weight
    .buffer_bytes = 50 * 1024 * 1024, // forward buffers + KV cache
    .model_name = "Qwen2.5-7B (Q4_K)",
};

pub const QWEN2_5_7B_F32 = MemoryProfile{
    .bytes_per_layer = 932 * 1024 * 1024, // ~932MB per layer in f32
    .embedding_bytes = 460 * 1024 * 1024,
    .output_bytes = 460 * 1024 * 1024,
    .buffer_bytes = 50 * 1024 * 1024,
    .model_name = "Qwen2.5-7B (f32)",
};

pub const TINYLLAMA_Q4K = MemoryProfile{
    .bytes_per_layer = 24 * 1024 * 1024, // ~24MB per layer in Q4_K
    .embedding_bytes = 128 * 1024 * 1024,
    .output_bytes = 128 * 1024 * 1024,
    .buffer_bytes = 20 * 1024 * 1024,
    .model_name = "TinyLlama-1.1B (Q4_K)",
};

/// Compute a MemoryProfile from model parameters
pub fn profileFromParams(
    hidden_size: u32,
    ffn_dim: u32,
    vocab_size: u32,
    num_kv_heads: u32,
    head_dim: u32,
    quantized: bool,
) MemoryProfile {
    const hs: u64 = hidden_size;
    const ff: u64 = ffn_dim;
    const vs: u64 = vocab_size;
    const kv_dim: u64 = @as(u64, num_kv_heads) * head_dim;

    if (quantized) {
        // Q4_K: ~0.5625 bytes per element (144 bytes per 256 elements)
        const q4k_factor: u64 = 144; // bytes per 256 elements
        const per_256 = 256;
        const wq = (hs * hs * q4k_factor + per_256 - 1) / per_256;
        const wk = (kv_dim * hs * q4k_factor + per_256 - 1) / per_256;
        const wv = (kv_dim * hs * q4k_factor + per_256 - 1) / per_256;
        const wo = (hs * hs * q4k_factor + per_256 - 1) / per_256;
        const w_gate = (ff * hs * q4k_factor + per_256 - 1) / per_256;
        const w_up = (ff * hs * q4k_factor + per_256 - 1) / per_256;
        const w_down = (hs * ff * q4k_factor + per_256 - 1) / per_256;
        const norms = hs * 4 * 2; // 2 norms, f32
        const per_layer = wq + wk + wv + wo + w_gate + w_up + w_down + norms;

        return .{
            .bytes_per_layer = per_layer,
            .embedding_bytes = vs * hs * 4, // f32
            .output_bytes = vs * hs * 4, // f32
            .buffer_bytes = (hs * 4 + ff * 4) * 4, // forward buffers
            .model_name = "auto-detected (Q4_K)",
        };
    } else {
        // f32: 4 bytes per element
        const wq = hs * hs * 4;
        const wk = kv_dim * hs * 4;
        const wv = kv_dim * hs * 4;
        const wo = hs * hs * 4;
        const w_gate = ff * hs * 4;
        const w_up = ff * hs * 4;
        const w_down = hs * ff * 4;
        const norms = hs * 4 * 2;
        const per_layer = wq + wk + wv + wo + w_gate + w_up + w_down + norms;

        return .{
            .bytes_per_layer = per_layer,
            .embedding_bytes = vs * hs * 4,
            .output_bytes = vs * hs * 4,
            .buffer_bytes = (hs * 4 + ff * 4) * 4,
            .model_name = "auto-detected (f32)",
        };
    }
}

/// System memory information
pub const SystemMemory = struct {
    total_bytes: u64,
    available_bytes: u64,
};

/// Query available system RAM.
/// On macOS: uses sysctl hw.memsize + vm.page_pageable_internal_count
/// On Linux: reads /proc/meminfo
pub fn getSystemMemory() !SystemMemory {
    if (builtin.os.tag == .macos) {
        return getSystemMemoryMacOS();
    } else if (builtin.os.tag == .linux) {
        return getSystemMemoryLinux();
    } else {
        // Fallback: assume 8GB total, 6GB available
        return SystemMemory{ .total_bytes = 8 * 1024 * 1024 * 1024, .available_bytes = 6 * 1024 * 1024 * 1024 };
    }
}

fn getSystemMemoryMacOS() !SystemMemory {
    // hw.memsize via sysctl
    var memsize: u64 = 0;
    var size: usize = @sizeOf(u64);
    const mib_memsize = [2]c_int{ 6, 24 }; // CTL_HW=6, HW_MEMSIZE=24
    const rc = std.c.sysctl(
        @ptrCast(&mib_memsize),
        2,
        @ptrCast(&memsize),
        &size,
        null,
        0,
    );
    if (rc != 0) return error.SysctlFailed;

    // Conservative: assume 70% of total is available for inference
    // (macOS keeps a significant portion for unified memory / GPU / system)
    const available = memsize * 70 / 100;

    return SystemMemory{
        .total_bytes = memsize,
        .available_bytes = available,
    };
}

fn getSystemMemoryLinux() !SystemMemory {
    // Read /proc/meminfo
    const file = std.fs.openFileAbsolute("/proc/meminfo", .{}) catch {
        // Fallback
        return SystemMemory{ .total_bytes = 8 * 1024 * 1024 * 1024, .available_bytes = 6 * 1024 * 1024 * 1024 };
    };
    defer file.close();

    var buf: [4096]u8 = undefined;
    const n = file.read(&buf) catch return SystemMemory{
        .total_bytes = 8 * 1024 * 1024 * 1024,
        .available_bytes = 6 * 1024 * 1024 * 1024,
    };
    const content = buf[0..n];

    var total_kb: u64 = 0;
    var available_kb: u64 = 0;

    var lines = std.mem.splitSequence(u8, content, "\n");
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "MemTotal:")) {
            total_kb = parseMemInfoValue(line);
        } else if (std.mem.startsWith(u8, line, "MemAvailable:")) {
            available_kb = parseMemInfoValue(line);
        }
    }

    if (total_kb == 0) {
        return SystemMemory{ .total_bytes = 8 * 1024 * 1024 * 1024, .available_bytes = 6 * 1024 * 1024 * 1024 };
    }

    return SystemMemory{
        .total_bytes = total_kb * 1024,
        .available_bytes = if (available_kb > 0) available_kb * 1024 else total_kb * 1024 * 70 / 100,
    };
}

/// Parse "MemTotal:    12345678 kB" → 12345678
fn parseMemInfoValue(line: []const u8) u64 {
    // Find first digit
    var start: usize = 0;
    for (line, 0..) |c, i| {
        if (c >= '0' and c <= '9') {
            start = i;
            break;
        }
    }
    // Find end of digits
    var end: usize = start;
    while (end < line.len and line[end] >= '0' and line[end] <= '9') {
        end += 1;
    }
    if (start == end) return 0;
    return std.fmt.parseInt(u64, line[start..end], 10) catch 0;
}

/// Shard assignment for one node
pub const ShardAssignment = struct {
    node_idx: u32,
    start_layer: u32,
    end_layer: u32, // exclusive
    layer_count: u32,
    estimated_memory_mb: u64,
    is_first: bool,
    is_last: bool,
};

/// Plan result
pub const ShardPlan = struct {
    assignments: [MAX_NODES]ShardAssignment,
    num_nodes: u32,
    total_layers: u32,
    profile: MemoryProfile,
};

const MAX_NODES = 8;

/// Compute optimal layer assignment for N nodes given their available RAM.
/// `node_ram` is an array of available bytes per node.
/// Nodes are ordered: node 0 = coordinator (first), node N-1 = worker (last).
/// Layers are assigned proportional to available RAM.
pub fn planShards(
    node_ram: []const u64,
    total_layers: u32,
    profile: MemoryProfile,
    model_path: []const u8,
) ShardPlan {
    const num_nodes: u32 = @intCast(node_ram.len);
    var plan = ShardPlan{
        .assignments = undefined,
        .num_nodes = num_nodes,
        .total_layers = total_layers,
        .profile = profile,
    };

    // Compute effective RAM per node (subtract fixed overhead)
    var effective_ram: [MAX_NODES]u64 = undefined;
    var total_effective: u64 = 0;
    for (0..num_nodes) |i| {
        var overhead: u64 = profile.buffer_bytes;
        if (i == 0) overhead += profile.embedding_bytes; // first node holds embedding
        if (i == num_nodes - 1) overhead += profile.output_bytes; // last node holds output
        effective_ram[i] = if (node_ram[i] > overhead) node_ram[i] - overhead else 0;
        total_effective += effective_ram[i];
    }

    // Assign layers proportional to effective RAM
    var assigned: u32 = 0;
    var current_start: u32 = 0;
    for (0..num_nodes) |i| {
        const is_last_node = (i == num_nodes - 1);
        const layers: u32 = if (is_last_node)
            total_layers - assigned
        else blk: {
            if (total_effective == 0) break :blk total_layers / num_nodes;
            const frac = @as(f64, @floatFromInt(effective_ram[i])) / @as(f64, @floatFromInt(total_effective));
            const raw = frac * @as(f64, @floatFromInt(total_layers));
            const rounded = @as(u32, @intFromFloat(@round(raw)));
            break :blk @min(rounded, total_layers - assigned);
        };

        const overhead_mb = blk: {
            var oh: u64 = profile.buffer_bytes;
            if (i == 0) oh += profile.embedding_bytes;
            if (is_last_node) oh += profile.output_bytes;
            break :blk oh / (1024 * 1024);
        };

        plan.assignments[i] = ShardAssignment{
            .node_idx = @intCast(i),
            .start_layer = current_start,
            .end_layer = current_start + layers,
            .layer_count = layers,
            .estimated_memory_mb = @as(u64, layers) * profile.bytes_per_layer / (1024 * 1024) + overhead_mb,
            .is_first = (i == 0),
            .is_last = is_last_node,
        };

        _ = model_path;
        current_start += layers;
        assigned += layers;
    }

    return plan;
}

/// Print a shard plan summary
pub fn printPlan(plan: ShardPlan) void {
    std.debug.print("\n\x1b[38;2;255;215;0m╔══════════════════════════════════════════════════════════╗\x1b[0m\n", .{});
    std.debug.print("\x1b[38;2;255;215;0m║         AUTO-SHARD PLAN                                  ║\x1b[0m\n", .{});
    std.debug.print("\x1b[38;2;255;215;0m╠══════════════════════════════════════════════════════════╣\x1b[0m\n", .{});
    std.debug.print("║  Model: {s}\n", .{plan.profile.model_name});
    std.debug.print("║  Total layers: {d} | Nodes: {d}\n", .{ plan.total_layers, plan.num_nodes });
    std.debug.print("║\n", .{});

    for (0..plan.num_nodes) |i| {
        const a = plan.assignments[i];
        const role: []const u8 = if (a.is_first) "coordinator" else if (a.is_last) "worker" else "relay";
        std.debug.print("║  Node {d} ({s}): layers {d}-{d} ({d} layers, ~{d}MB)\n", .{
            a.node_idx, role, a.start_layer, a.end_layer -| 1, a.layer_count, a.estimated_memory_mb,
        });
    }

    std.debug.print("\x1b[38;2;255;215;0m╚══════════════════════════════════════════════════════════╝\x1b[0m\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "auto_shard_2_nodes_equal" {
    const ram = [_]u64{ 8 * 1024 * 1024 * 1024, 8 * 1024 * 1024 * 1024 };
    const plan = planShards(&ram, 28, QWEN2_5_7B_Q4K, "test.gguf");

    try std.testing.expectEqual(plan.num_nodes, 2);
    try std.testing.expectEqual(plan.assignments[0].start_layer, 0);
    // With equal RAM, should split roughly 14+14 (embedding/output overhead causes slight asymmetry)
    try std.testing.expect(plan.assignments[0].layer_count >= 12);
    try std.testing.expect(plan.assignments[0].layer_count <= 16);
    try std.testing.expectEqual(plan.assignments[0].layer_count + plan.assignments[1].layer_count, 28);
    try std.testing.expect(plan.assignments[0].is_first);
    try std.testing.expect(plan.assignments[1].is_last);
}

test "auto_shard_2_nodes_asymmetric" {
    // Mac 16GB + VPS 8GB
    const ram = [_]u64{ 16 * 1024 * 1024 * 1024, 8 * 1024 * 1024 * 1024 };
    const plan = planShards(&ram, 28, QWEN2_5_7B_Q4K, "test.gguf");

    try std.testing.expectEqual(plan.num_nodes, 2);
    // Mac has more RAM — should get more layers
    try std.testing.expect(plan.assignments[0].layer_count > plan.assignments[1].layer_count);
    try std.testing.expectEqual(plan.assignments[0].layer_count + plan.assignments[1].layer_count, 28);
}

test "auto_shard_3_nodes" {
    const ram = [_]u64{ 16 * 1024 * 1024 * 1024, 16 * 1024 * 1024 * 1024, 8 * 1024 * 1024 * 1024 };
    const plan = planShards(&ram, 28, QWEN2_5_7B_Q4K, "test.gguf");

    try std.testing.expectEqual(plan.num_nodes, 3);
    try std.testing.expect(plan.assignments[0].is_first);
    try std.testing.expect(!plan.assignments[1].is_first);
    try std.testing.expect(!plan.assignments[1].is_last);
    try std.testing.expect(plan.assignments[2].is_last);
    try std.testing.expectEqual(
        plan.assignments[0].layer_count + plan.assignments[1].layer_count + plan.assignments[2].layer_count,
        28,
    );
}

test "system_memory_query" {
    const mem = try getSystemMemory();
    // Should return something reasonable (at least 1GB)
    try std.testing.expect(mem.total_bytes > 1024 * 1024 * 1024);
    try std.testing.expect(mem.available_bytes > 0);
    try std.testing.expect(mem.available_bytes <= mem.total_bytes);
}
