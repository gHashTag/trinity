// ═══════════════════════════════════════════════════════════════════
// CONTENT_REGISTRY_V2 (GENERATED)
// ═══════════════════════════════════════════════════════════════════
// Improved Content Registry
// Generated from: specs/tri-lang/content_registry_v2.tri
// TTT Dogfood v0.1 — DO NOT EDIT DIRECTLY
// Source of truth: .tri spec (edit spec, regenerate)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ContentHash = @import("content_hash.zig").ContentHash;

// ═══════════════════════════════════════════════════════════════════════════════
// IMPROVED HASH MAP CONTEXT
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Improved Context for HashMap - uses full 32-byte hash
/// Instead of only first 8 bytes as in the original
pub const ImprovedHashMapContext = struct {
    pub fn hash(self: ImprovedHashMapContext, key: [32]u8) u64 {
        _ = self;
        // Wyhash - modern non-cryptographic hash function with excellent avalanche
        // Much better than FNV-1a for HashMap usage
        return std.hash.Wyhash.hash(0, &key);
    }

    pub fn eql(self: ImprovedHashMapContext, a: [32]u8, b: [32]u8) bool {
        _ = self;
        return std.mem.eql(u8, &a, &b);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// IMPROVED CONTENT REGISTRY
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Improved registry with better hash function
pub const ContentRegistryV2 = struct {
    allocator: Allocator,
    /// Map from hash bytes to locations (uses improved context)
    entries: std.HashMap([32]u8, []const FunctionLocation, ImprovedHashMapContext, 80),

    pub const FunctionLocation = @import("content_registry.zig").FunctionLocation;

    /// Initialize empty registry
    pub fn init(allocator: Allocator) !ContentRegistryV2 {
        var registry = ContentRegistryV2{
            .allocator = allocator,
            .entries = std.HashMap([32]u8, []const FunctionLocation, ImprovedHashMapContext, 80).init(allocator),
        };
        // Pre-allocate memory for expected number of functions
        try registry.entries.ensureTotalCapacity(1024);
        return registry;
    }

    /// Free all resources
    pub fn deinit(self: *ContentRegistryV2) void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.*) |*loc| {
                loc.deinit(self.allocator);
            }
            self.allocator.free(entry.value_ptr.*);
        }
        self.entries.deinit();
    }

    /// Register a function with its content hash
    pub fn register(self: *ContentRegistryV2, hash: ContentHash, loc: FunctionLocation) !void {
        const gop = try self.entries.getOrPut(hash.bytes);

        if (!gop.found_existing) {
            // First entry with this hash
            const loc_copy = try loc.clone(self.allocator);
            gop.value_ptr.* = try self.allocator.dupe(FunctionLocation, &.{loc_copy});
        } else {
            // Append to existing locations
            const loc_copy = try loc.clone(self.allocator);
            const old_locs = gop.value_ptr.*;
            const new_locs = try self.allocator.alloc(FunctionLocation, old_locs.len + 1);
            @memcpy(new_locs[0..old_locs.len], old_locs);
            new_locs[old_locs.len] = loc_copy;
            self.allocator.free(old_locs);
            gop.value_ptr.* = new_locs;
        }
    }

    /// Look up function locations by content hash
    pub fn lookup(self: *const ContentRegistryV2, hash: ContentHash) ?[]const FunctionLocation {
        return self.entries.get(hash.bytes);
    }

    /// Get statistics
    pub const Stats = struct {
        unique_hashes: usize,
        total_functions: usize,
    };

    pub fn stats(self: *const ContentRegistryV2) Stats {
        var unique: usize = 0;
        var total: usize = 0;

        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            unique += 1;
            total += entry.value_ptr.*.len;
        }

        return .{
            .unique_hashes = unique,
            .total_functions = total,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HASH QUALITY TEST
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Check hash function quality (avalanche effect)
pub fn testHashQuality() !void {
    const context = ImprovedHashMapContext{};

    // Test 1: Different keys → different hashes
    const k1: [32]u8 = .{0} ** 32;
    const k2: [32]u8 = .{1} ** 32;

    const h1 = context.hash(k1);
    const h2 = context.hash(k2);

    std.debug.print("Test 1: Different keys → different hashes: {any}\n", .{h1 != h2});

    // Test 2: Avalanche effect (1 bit change → ~50% bits change)
    var k3: [32]u8 = .{0} ** 32;
    k3[0] = 0xFF;
    const h3 = context.hash(k3);

    // Count differences
    var diff_bits: u32 = 0;
    const h1_arr = @as([8]u8, @bitCast(h1));
    const h3_arr = @as([8]u8, @bitCast(h3));
    for (h1_arr, h3_arr) |b1, b2| {
        if (b1 != b2) diff_bits += 1;
    }

    std.debug.print("Test 2: Avalanche effect: {}/32 bits changed ({d}%)\n", .{ diff_bits, @as(f32, @floatFromInt(diff_bits)) * 100.0 / 32.0 });

    // Good hash function should change ~50% bits
    if (diff_bits >= 12) {
        std.debug.print("✅ Hash quality: GOOD\n", .{});
    } else {
        std.debug.print("❌ Hash quality: POOR (< 12 bits changed)\n", .{});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════

test "ContentRegistryV2 init and basic usage" {
    const a = std.testing.allocator;
    var registry = try ContentRegistryV2.init(a);
    defer registry.deinit();

    var hash: ContentHash = undefined;
    hash.bytes[0] = 0x01;

    const loc = ContentRegistryV2.FunctionLocation{
        .module = "test.module",
        .name = "test_func",
        .line = 10,
        .file_path = "test.tri",
    };

    try registry.register(hash, loc);

    const result = registry.lookup(hash);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(usize, 1), result.?.len);
}

test "ImprovedHashMapContext - avalanche effect" {
    const context = ImprovedHashMapContext{};

    const k1: [32]u8 = .{0} ** 32;
    var k2: [32]u8 = .{0} ** 32;
    k2[0] = 0xFF; // Change 8 bits in first byte

    const h1 = context.hash(k1);
    const h2 = context.hash(k2);

    // Count differing bits (not bytes!)
    var diff_bits: u32 = 0;
    const h1_arr = @as([8]u8, @bitCast(h1));
    const h2_arr = @as([8]u8, @bitCast(h2));
    for (h1_arr, h2_arr) |b1, b2| {
        // XOR to find different bits, then count bits set
        const x = b1 ^ b2;
        // Brian Kernighan's algorithm to count set bits
        var v = x;
        while (v != 0) {
            v &= v - 1;
            diff_bits += 1;
        }
    }

    // Good hash function should change ~50% bits (32 out of 64) when input changes
    // Accept >= 20 bits (31.25%) as acceptable avalanche effect
    try std.testing.expect(diff_bits >= 20);
}

test "ImprovedHashMapContext - distribution" {
    const context = ImprovedHashMapContext{};

    // Generate 100 random hashes and check distribution
    var seen = std.AutoHashMap(u64, void).init(std.testing.allocator);
    defer seen.deinit();

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        var key: [32]u8 = undefined;
        key[0] = @intCast(i & 0xFF);
        key[1] = @intCast((i >> 8) & 0xFF);

        const h = context.hash(key);
        try seen.put(h, {});
    }

    // Все хеши должны быть разными (с высокой вероятностью)
    try std.testing.expect(seen.count() == 1000);
}

test "ContentRegistryV2 stats" {
    const a = std.testing.allocator;
    var registry = try ContentRegistryV2.init(a);
    defer registry.deinit();

    var hash1: ContentHash = undefined;
    hash1.bytes[0] = 0x01;

    var hash2: ContentHash = undefined;
    hash2.bytes[0] = 0x02;

    const loc1 = ContentRegistryV2.FunctionLocation{
        .module = "module1",
        .name = "func1",
        .line = 10,
        .file_path = "file1.tri",
    };

    const loc2 = ContentRegistryV2.FunctionLocation{
        .module = "module2",
        .name = "func2",
        .line = 20,
        .file_path = "file2.tri",
    };

    try registry.register(hash1, loc1);
    try registry.register(hash2, loc2);
    try registry.register(hash1, loc2); // Duplicate of hash1

    const stats = registry.stats();
    try std.testing.expectEqual(@as(usize, 2), stats.unique_hashes);
    try std.testing.expectEqual(@as(usize, 3), stats.total_functions);
}
