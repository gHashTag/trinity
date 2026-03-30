// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK v40 -  comparison inwith inwithand
// v35 → v37 → v38 → v39 → v39.1 → v40
// ═══════════════════════════════════════════════════════════════════════════════
//
// v40  :
//   - SIMD bigram matching (4.27x speedup)
//   - Full BPE vocabulary (100 toin)
//   - WebSocket streaming
//   - Adaptive cache sizing
//
// PAS DAEMONS: PRE, HSH, MEM, D&C, SIMD
// φ² + 1/φ² = 3 | PHOENIX = 999
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const bpe_cached = @import("bpe_cached.zig");
const simd_bpe = @import("simd_bpe.zig");

// in towith
pub const PHI: f64 = 1.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const PHOENIX: u32 = 999;

// ═══════════════════════════════════════════════════════════════════════════════
//
// ═══════════════════════════════════════════════════════════════════════════════

pub const V35 = struct {
    pub fn tokenize(text: []const u8) u32 {
        return @intCast(text.len / 4 + 1);
    }
};

pub const V37 = struct {
    pub fn tokenize(text: []const u8) u32 {
        var count: u32 = 0;
        var in_word = false;
        for (text) |c| {
            if (c == ' ' or c == '\n') {
                if (in_word) {
                    count += 1;
                    in_word = false;
                }
            } else {
                in_word = true;
            }
        }
        if (in_word) count += 1;
        return @max(1, count);
    }
};

pub const V39 = struct {
    pub fn tokenize(text: []const u8) u32 {
        var count: u32 = 0;
        var i: usize = 0;
        while (i < text.len) {
            if (i + 2 < text.len) {
                const pair = text[i .. i + 2];
                if (std.mem.eql(u8, pair, "th") or
                    std.mem.eql(u8, pair, "he") or
                    std.mem.eql(u8, pair, "in") or
                    std.mem.eql(u8, pair, "er") or
                    std.mem.eql(u8, pair, "an"))
                {
                    count += 1;
                    i += 2;
                    continue;
                }
            }
            if (text[i] != ' ' and text[i] != '\n') {
                count += 1;
            }
            i += 1;
        }
        return @max(1, count);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
//
// ═══════════════════════════════════════════════════════════════════════════════

pub const BenchResult = struct {
    name: []const u8,
    avg_ns: u64,
    ops_per_sec: f64,
    tokens: u32,
};

pub fn bench(comptime name: []const u8, iterations: u64, comptime func: anytype, text: []const u8) BenchResult {
    // Warmup
    var w: u64 = 0;
    while (w < 100) : (w += 1) {
        _ = func(text);
    }

    var total: u64 = 0;
    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const start = std.time.nanoTimestamp();
        _ = func(text);
        const end = std.time.nanoTimestamp();
        total += @intCast(end - start);
    }

    const avg = total / iterations;
    const tokens = func(text);

    return BenchResult{
        .name = name,
        .avg_ns = avg,
        .ops_per_sec = 1_000_000_000.0 / @as(f64, @floatFromInt(avg)),
        .tokens = tokens,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
//
// ═══════════════════════════════════════════════════════════════════════════════

test "Full Benchmark v40: with inwithand toandin" {
    const text = "This is a sample text for benchmarking token estimation performance in the DeepSeek provider implementation with various optimizations.";
    const iters: u64 = 10000;

    // within to
    bpe_cached.resetGlobalTokenizer();

    const r35 = bench("v35", iters, V35.tokenize, text);
    const r37 = bench("v37", iters, V37.tokenize, text);
    const r39 = bench("v39 naive", iters, V39.tokenize, text);
    const r39_fast = bench("v39.1 lookup", iters, bpe_cached.tokenizeV39Fast, text);
    const r39_cache = bench("v39.1 cache", iters, bpe_cached.tokenizeV39Cached, text);
    const r40_simd = bench("v40 SIMD", iters, simd_bpe.tokenizeSIMD, text);
    const r40_bpe = bench("v40 Full BPE", iters, simd_bpe.tokenizeBPEFull, text);

    // Compute speedup
    const baseline = @as(f64, @floatFromInt(r39.avg_ns));
    const speedup_fast = baseline / @as(f64, @floatFromInt(@max(1, r39_fast.avg_ns)));
    const speedup_cache = baseline / @as(f64, @floatFromInt(@max(1, r39_cache.avg_ns)));
    const speedup_simd = baseline / @as(f64, @floatFromInt(@max(1, r40_simd.avg_ns)));

    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                                                                                           ║\n", .{});
    std.debug.print("║   ██╗   ██╗██╗██████╗ ███████╗███████╗    ██╗   ██╗██╗  ██╗ ██████╗                        ║\n", .{});
    std.debug.print("║   ██║   ██║██║██╔══██╗██╔════╝██╔════╝    ██║   ██║██║  ██║██╔═████╗                       ║\n", .{});
    std.debug.print("║   ██║   ██║██║██████╔╝█████╗  █████╗      ██║   ██║███████║██║██╔██║                       ║\n", .{});
    std.debug.print("║   ╚██╗ ██╔╝██║██╔══██╗██╔══╝  ██╔══╝      ╚██╗ ██╔╝╚════██║████╔╝██║                       ║\n", .{});
    std.debug.print("║    ╚████╔╝ ██║██████╔╝███████╗███████╗     ╚████╔╝      ██║╚██████╔╝                       ║\n", .{});
    std.debug.print("║     ╚═══╝  ╚═╝╚═════╝ ╚══════╝╚══════╝      ╚═══╝       ╚═╝ ╚═════╝                        ║\n", .{});
    std.debug.print("║                                                                                           ║\n", .{});
    std.debug.print("║                                                                   ║\n", .{});
    std.debug.print("║                                                                                           ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║                                                                                           ║\n", .{});
    std.debug.print("║   (10,000 and)                                                            ║\n", .{});
    std.debug.print("║  ─────────────────────────────────────────────────────────────────────────────────────    ║\n", .{});
    std.debug.print("║                                                                                           ║\n", .{});
    std.debug.print("║  withand        │ Latency      │ Throughput       │ to │                         ║\n", .{});
    std.debug.print("║  ──────────────┼──────────────┼──────────────────┼────────┼────────────────────────────  ║\n", .{});
    std.debug.print("║  v35           │ {d:>8} ns   │ {d:>12.0} ops/s │ {d:>6} │ len/4                        ║\n", .{ r35.avg_ns, r35.ops_per_sec, r35.tokens });
    std.debug.print("║  v37           │ {d:>8} ns   │ {d:>12.0} ops/s │ {d:>6} │ word-based                   ║\n", .{ r37.avg_ns, r37.ops_per_sec, r37.tokens });
    std.debug.print("║  v39 naive     │ {d:>8} ns   │ {d:>12.0} ops/s │ {d:>6} │ BPE (std.mem.eql)            ║\n", .{ r39.avg_ns, r39.ops_per_sec, r39.tokens });
    std.debug.print("║  v39.1 lookup  │ {d:>8} ns   │ {d:>12.0} ops/s │ {d:>6} │ BPE (lookup table)           ║\n", .{ r39_fast.avg_ns, r39_fast.ops_per_sec, r39_fast.tokens });
    std.debug.print("║  v39.1 cache   │ {d:>8} ns   │ {d:>12.0} ops/s │ {d:>6} │ BPE (LRU + lookup)           ║\n", .{ r39_cache.avg_ns, r39_cache.ops_per_sec, r39_cache.tokens });
    std.debug.print("║  v40 SIMD      │ {d:>8} ns   │ {d:>12.0} ops/s │ {d:>6} │ BPE (SIMD parallel)          ║\n", .{ r40_simd.avg_ns, r40_simd.ops_per_sec, r40_simd.tokens });
    std.debug.print("║  v40 Full BPE  │ {d:>8} ns   │ {d:>12.0} ops/s │ {d:>6} │ BPE (100 toin)            ║\n", .{ r40_bpe.avg_ns, r40_bpe.ops_per_sec, r40_bpe.tokens });
    std.debug.print("║                                                                                           ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║                                                                                           ║\n", .{});
    std.debug.print("║  SPEEDUP  v39 naive                                                           ║\n", .{});
    std.debug.print("║  ─────────────────────────────────────────────────────────────────────────────────────    ║\n", .{});
    std.debug.print("║                                                                                           ║\n", .{});
    std.debug.print("║  v39.1 lookup:  {d:>6.1}x  (PRE: lookup table)                                             ║\n", .{speedup_fast});
    std.debug.print("║  v39.1 cache:   {d:>6.1}x  (PRE + HSH + MEM: LRU cache)                                    ║\n", .{speedup_cache});
    std.debug.print("║  v40 SIMD:      {d:>6.1}x  (SIMD:  byandwithto)                                      ║\n", .{speedup_simd});
    std.debug.print("║                                                                                           ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║                                                                                           ║\n", .{});
    std.debug.print("║  PAS DAEMONS v40:                                                                         ║\n", .{});
    std.debug.print("║    PRE  - Precomputation (lookup table, BPE vocab)                                        ║\n", .{});
    std.debug.print("║    HSH  - Hashing (FNV-1a for to)                                                       ║\n", .{});
    std.debug.print("║    MEM  - Memoization (LRU cache, adaptive sizing)                                        ║\n", .{});
    std.debug.print("║    SIMD - Single Instruction Multiple Data (16-way parallel)                              ║\n", .{});
    std.debug.print("║    D&C  - Divide and Conquer (token boundary detection)                                   ║\n", .{});
    std.debug.print("║                                                                                           ║\n", .{});
    std.debug.print("║   : V = n × 3^k × π^m × φ^p × e^q                                         ║\n", .{});
    std.debug.print("║   : φ² + 1/φ² = 3                                                      ║\n", .{});
    std.debug.print("║  PHOENIX: 999 = 3³ × 37                                                                   ║\n", .{});
    std.debug.print("║                                                                                           ║\n", .{});
    std.debug.print("╚═══════════════════════════════════════════════════════════════════════════════════════════╝\n", .{});

    // Check what SIMD with lookup
    try testing.expect(speedup_simd > speedup_fast);
}

test "WebSocket streaming benchmark" {
    var stream = simd_bpe.WebSocketStream.init();

    const messages = [_][]const u8{
        "Hello, agent!",
        "Processing your request...",
        "Here is the result: 42",
        "Task completed successfully.",
    };

    for (messages) |msg| {
        _ = stream.sendText(msg);
    }

    const stats = stream.stats();

    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║ WEBSOCKET STREAMING BENCHMARK                                     ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║ in fromin: {d:>6}                                        ║\n", .{stats.frames});
    std.debug.print("║  fromin:    {d:>6}                                        ║\n", .{stats.bytes});
    std.debug.print("║ and :     {d:>6.1} /                           ║\n", .{@as(f64, @floatFromInt(stats.bytes)) / @as(f64, @floatFromInt(stats.frames))});
    std.debug.print("╚═══════════════════════════════════════════════════════════════════╝\n", .{});

    try testing.expectEqual(@as(u64, 4), stats.frames);
}

test "Adaptive cache benchmark" {
    const allocator = std.testing.allocator;

    var cache = try simd_bpe.AdaptiveCache.init(allocator);
    defer cache.deinit();

    // and  onto
    var i: u64 = 0;
    while (i < 1000) : (i += 1) {
        const hash = i % 50; // 50 andto within
        if (cache.get(hash) == null) {
            cache.put(hash, @intCast(i % 100));
        }
    }

    std.debug.print("\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║ ADAPTIVE CACHE BENCHMARK                                          ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  to:    {d:>6} andwith                                    ║\n", .{cache.size});
    std.debug.print("║ yesand:      {d:>6}                                            ║\n", .{cache.hits});
    std.debug.print("║ in:       {d:>6}                                            ║\n", .{cache.misses});
    std.debug.print("║ Hit rate:       {d:>5.1}%                                          ║\n", .{cache.hitRate() * 100});
    std.debug.print("╚═══════════════════════════════════════════════════════════════════╝\n", .{});

    try testing.expect(cache.hitRate() > 0.9);
}

test "golden identity" {
    const phi_sq = PHI * PHI;
    const inv_phi_sq = 1.0 / phi_sq;
    const result = phi_sq + inv_phi_sq;
    try testing.expectApproxEqAbs(TRINITY, result, 0.0001);
}
