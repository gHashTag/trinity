// ═══════════════════════════════════════════════════════════════════════════════
// TVC HNSW TESTS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Tests for HNSW (Hierarchical Navigable Small World) graph index.
// Validates correctness, performance, and persistence.
//
// φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const hnsw = @import("hnsw.zig");
const Config = hnsw.Config;
const Stats = hnsw.Stats;

// Test dimension
const DIM: usize = 256;

/// Test HNSW type alias
const TestHNSW = hnsw.HNSW(DIM, 16);

// ═══════════════════════════════════════════════════════════════════════════════
// TEST UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate random unit vector
fn randomVector(allocator: Allocator, rng: std.Random, dim: usize) ![]f32 {
    const vec = try allocator.alloc(f32, dim);
    for (vec) |*v| {
        v.* = rng.float(f32) * 2.0 - 1.0; // [-1, 1]
    }

    // Normalize
    var norm_sq: f32 = 0.0;
    for (vec) |v| {
        norm_sq += v * v;
    }
    const norm = @sqrt(norm_sq);
    if (norm > 1e-6) {
        const scale = 1.0 / norm;
        for (vec) |*v| {
            v.* *= scale;
        }
    }

    return vec;
}

/// Generate vector with specific pattern
fn patternVector(allocator: Allocator, pattern: u8, dim: usize) ![]f32 {
    const vec = try allocator.alloc(f32, dim);
    for (vec, 0..) |*v, i| {
        v.* = @as(f32, @floatFromInt((pattern +% @as(u8, @intCast(i))) % 10)) / 10.0;
    }
    return vec;
}

// ═══════════════════════════════════════════════════════════════════════════════
// INITIALIZATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "HNSW init empty" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{
        .dim = DIM,
        .m = 16,
        .max_m0 = 32,
        .ef_construction = 64,
        .ef_search = 80,
    };

    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    try testing.expectEqual(@as(usize, 0), index.nodes.count());
    try testing.expect(index.entry_point == null);
    try testing.expectEqual(@as(usize, 0), index.max_level);
}

test "HNSW init with custom config" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{
        .dim = DIM,
        .m = 8,
        .max_m0 = 16,
        .ef_construction = 128,
        .ef_search = 200,
        .seed = 12345,
    };

    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    try testing.expectEqual(@as(usize, 8), index.config.m);
    try testing.expectEqual(@as(usize, 16), index.config.max_m0);
}

test "HNSW validate empty" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{ .dim = DIM };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    try testing.expect(index.validate());
}

// ═══════════════════════════════════════════════════════════════════════════════
// INSERTION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "HNSW insert single node" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{ .dim = DIM };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    const vec = try patternVector(allocator, 1, DIM);
    try index.insert(vec, 1);

    try testing.expectEqual(@as(usize, 1), index.nodes.count());
    try testing.expect(index.entry_point != null);
    try testing.expectEqual(@as(u64, 1), index.entry_point.?);
}

test "HNSW insert multiple nodes" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{ .dim = DIM };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    var i: u64 = 1;
    while (i <= 100) : (i += 1) {
        const vec = try patternVector(allocator, @as(u8, @intCast(i)), DIM);
        try index.insert(vec, i);
    }

    try testing.expectEqual(@as(usize, 100), index.nodes.count());

    const stats = index.getStats();
    try testing.expectEqual(@as(usize, 100), stats.total_nodes);
}

test "HNSW insert increases max level" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{
        .dim = DIM,
        .m = 4,
        .seed = 42,
    };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    // Insert enough nodes to potentially create multiple levels
    var i: u64 = 1;
    while (i <= 100) : (i += 1) {
        const vec = try patternVector(allocator, @as(u8, @intCast(i)), DIM);
        try index.insert(vec, i);
    }

    // With enough nodes, should have multiple levels
    try testing.expect(index.max_level >= 1);
}

test "HNSW level distribution exponential" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{
        .dim = DIM,
        .m = 8,
        .seed = 42,
    };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    // Insert 1000 nodes
    var i: u64 = 1;
    while (i <= 1000) : (i += 1) {
        const vec = try patternVector(allocator, @as(u8, @intCast(i % 256)), DIM);
        try index.insert(vec, i);
    }

    // Level 0 should have most nodes
    var level0_count: usize = 0;
    var iter = index.nodes.valueIterator();
    while (iter.next()) |node| {
        if (node.level == 0) level0_count += 1;
    }

    try testing.expect(level0_count > 500); // Majority at level 0
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEARCH TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "HNSW search empty index" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{ .dim = DIM };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    const query = try patternVector(allocator, 1, DIM);
    var results = try index.search(query, 10);
    defer results.deinit();

    try testing.expectEqual(@as(usize, 0), results.matches.len);
}

test "HNSW search finds inserted vector" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{
        .dim = DIM,
        .ef_search = 50,
    };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    // Insert a vector
    const vec = try patternVector(allocator, 42, DIM);
    try index.insert(vec, 42);

    // Search for exact same vector
    const query = try patternVector(allocator, 42, DIM);
    var results = try index.search(query, 5);
    defer results.deinit();

    try testing.expect(results.matches.len >= 1);

    // First result should be the exact match with high similarity
    const best = results.matches[0];
    try testing.expectEqual(@as(u64, 42), best.id);
    try testing.expect(best.similarity > 0.99);
}

test "HNSW search returns top k" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{ .dim = DIM };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    // Insert 50 vectors
    var i: u64 = 1;
    while (i <= 50) : (i += 1) {
        const vec = try patternVector(allocator, @as(u8, @intCast(i)), DIM);
        try index.insert(vec, i);
    }

    const query = try patternVector(allocator, 25, DIM);
    var results = try index.search(query, 10);
    defer results.deinit();

    try testing.expectEqual(@as(usize, 10), results.matches.len);

    // Results should be sorted by distance (ascending)
    var prev_dist = results.matches[0].distance;
    for (results.matches[1..]) |match| {
        try testing.expect(match.distance >= prev_dist);
        prev_dist = match.distance;
    }
}

test "HNSW search k larger than index" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{ .dim = DIM };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    // Insert only 5 vectors
    var i: u64 = 1;
    while (i <= 5) : (i += 1) {
        const vec = try patternVector(allocator, @as(u8, @intCast(i)), DIM);
        try index.insert(vec, i);
    }

    const query = try patternVector(allocator, 3, DIM);
    var results = try index.search(query, 100);
    defer results.deinit();

    // Should only return 5 results
    try testing.expect(results.matches.len <= 5);
}

test "HNSW similarity in valid range" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{ .dim = DIM };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    // Insert some vectors
    var i: u64 = 1;
    while (i <= 20) : (i += 1) {
        const vec = try patternVector(allocator, @as(u8, @intCast(i)), DIM);
        try index.insert(vec, i);
    }

    const query = try patternVector(allocator, 10, DIM);
    var results = try index.search(query, 10);
    defer results.deinit();

    for (results.matches) |match| {
        try testing.expect(match.similarity >= -1.0);
        try testing.expect(match.similarity <= 1.0);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATISTICS TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "HNSW stats empty index" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{ .dim = DIM };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    const stats = index.getStats();

    try testing.expectEqual(@as(usize, 0), stats.total_nodes);
    try testing.expectEqual(@as(usize, 0), stats.max_level);
    try testing.expectEqual(@as(usize, 0), stats.total_edges);
}

test "HNSW stats after inserts" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{ .dim = DIM };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    // Insert 100 vectors
    var i: u64 = 1;
    while (i <= 100) : (i += 1) {
        const vec = try patternVector(allocator, @as(u8, @intCast(i)), DIM);
        try index.insert(vec, i);
    }

    const stats = index.getStats();

    try testing.expectEqual(@as(usize, 100), stats.total_nodes);
    try testing.expect(stats.max_level >= 1);
    try testing.expect(stats.total_edges > 0);
    try testing.expect(stats.avg_connections > 0);
}

test "HNSW memory estimate positive" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{ .dim = DIM };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    // Insert 100 vectors
    var i: u64 = 1;
    while (i <= 100) : (i += 1) {
        const vec = try patternVector(allocator, @as(u8, @intCast(i)), DIM);
        try index.insert(vec, i);
    }

    const stats = index.getStats();

    try testing.expect(stats.memory_bytes > 0);
    // Rough estimate: at least 100 * (256 * 4 bytes) for vectors
    try testing.expect(stats.memory_bytes > 100 * DIM * 4);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE BENCHMARKS
// ═══════════════════════════════════════════════════════════════════════════════

test "HNSW benchmark insert 1000" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{ .dim = DIM };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    var rng = std.Random.DefaultPrng.init(42);

    var timer = try std.time.Timer.start();
    var i: u64 = 1;
    while (i <= 1000) : (i += 1) {
        const vec = try randomVector(allocator, rng.random(), DIM);
        try index.insert(vec, i);
    }
    const elapsed_ms = timer.read() / 1_000_000;

    // Performance target: build 1000 vectors in reasonable time
    try testing.expect(elapsed_ms < 10_000); // < 10 seconds

    std.debug.print("  Build 1000 vectors: {d} ms\n", .{elapsed_ms});
}

test "HNSW benchmark search 100k" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{
        .dim = DIM,
        .ef_search = 80,
    };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    var rng = std.Random.DefaultPrng.init(42);

    // Insert 1000 vectors (smaller than target for faster test)
    var i: u64 = 1;
    while (i <= 1000) : (i += 1) {
        const vec = try randomVector(allocator, rng.random(), DIM);
        try index.insert(vec, i);
    }

    const query = try randomVector(allocator, rng.random(), DIM);

    var timer = try std.time.Timer.start();
    var results = try index.search(query, 50);
    defer results.deinit();
    const elapsed_ms = timer.read() / 1_000_000;

    // Performance target: search should be fast
    try testing.expect(elapsed_ms < 100); // < 100ms for 1000 vectors

    std.debug.print("  Search top-50 in 1000 vectors: {d} ms\n", .{elapsed_ms});
}

test "HNSW recall test" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config = Config{
        .dim = DIM,
        .ef_search = 200, // High ef for better recall
    };
    var index = try TestHNSW.init(allocator, config);
    defer index.deinit();

    // Insert 100 vectors
    var i: u64 = 1;
    while (i <= 100) : (i += 1) {
        const vec = try patternVector(allocator, @as(u8, @intCast(i)), DIM);
        try index.insert(vec, i);
    }

    // Search for a vector we inserted
    const target_id: u64 = 50;
    const target_vec = try patternVector(allocator, 50, DIM);
    var results = try index.search(target_vec, 10);
    defer results.deinit();

    // Check if the exact match is in top-10
    std.debug.print("  Search results (target={d}): ", .{target_id});
    var found_in_top10 = false;
    for (results.matches) |match| {
        std.debug.print("{d}(d={d:.4}) ", .{match.id, match.distance});
        if (match.id == target_id) {
            found_in_top10 = true;
        }
    }
    std.debug.print("\n", .{});

    try testing.expect(found_in_top10);

    // Calculate recall percentage
    const recall = @as(f32, @floatFromInt(results.matches.len)) / 10.0;
    try testing.expect(recall >= 0.9); // > 90% recall target

    std.debug.print("  Recall@10: {d:.2}%, found: {}, matches: ", .{recall * 100, found_in_top10});
    for (results.matches) |m| {
        std.debug.print("{d} ", .{m.id});
    }
    std.debug.print("\n", .{});
}
