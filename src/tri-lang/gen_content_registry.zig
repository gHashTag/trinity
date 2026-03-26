// ═══════════════════════════════════════════════════════════════════════════
// Content Registry (GENERATED from .tri spec)
// TTT Dogfood v0.1: Self-hosted codegen
// DO NOT EDIT — Generated from specs/tri-lang/content_registry.tri
//
// TRI-LANG-6: Content-Addressed Functions
//
// Implements:
// - ContentRegistry: map content hashes to function locations
// - FunctionLocation: module, name, line, file_path
// - DuplicateInfo: duplicate detection results
// - JSON persistence: loadFromFile, saveToFile
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const ContentHash = @import("content_hash.zig").ContentHash;

// Zig 0.15: ArrayListManaged helper
const ArrayListManaged = std.array_list.AlignedManaged;

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTION LOCATION
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Location of a function definition
pub const FunctionLocation = struct {
    /// Module name (e.g., "tri.lang.array")
    module: []const u8,
    /// Original function name (for display)
    name: []const u8,
    /// Definition line number
    line: usize,
    /// File path (for error messages)
    file_path: []const u8,

    /// Duplicate location for allocator management
    pub fn clone(self: *const FunctionLocation, allocator: Allocator) !FunctionLocation {
        return .{
            .module = try allocator.dupe(u8, self.module),
            .name = try allocator.dupe(u8, self.name),
            .line = self.line,
            .file_path = try allocator.dupe(u8, self.file_path),
        };
    }

    /// Free resources
    pub fn deinit(self: *const FunctionLocation, allocator: Allocator) void {
        allocator.free(self.module);
        allocator.free(self.name);
        allocator.free(self.file_path);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DUPLICATE INFO
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Information about duplicate functions
pub const DuplicateInfo = struct {
    /// Content hash that identifies the duplicate
    hash: ContentHash,
    /// All locations where this function appears
    locations: []const FunctionLocation,

    /// Free resources
    pub fn deinit(self: *const DuplicateInfo, allocator: Allocator) void {
        for (self.locations) |*loc| {
            loc.deinit(allocator);
        }
        allocator.free(self.locations);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTRY ENTRY
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Single registry entry
const RegistryEntry = struct {
    hash: [32]u8,
    location: FunctionLocation,
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONTENT REGISTRY
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Content registry - maps content hashes to function locations
pub const ContentRegistry = struct {
    allocator: Allocator,
    /// Map from hash bytes to locations
    entries: std.HashMap([32]u8, []const FunctionLocation, Context, 80),

    const Context = struct {
        pub fn hash(self: Context, key: [32]u8) u64 {
            _ = self;
            // Use first 8 bytes for hash (little-endian)
            return std.mem.readInt(u64, key[0..8], .little);
        }

        pub fn eql(self: Context, a: [32]u8, b: [32]u8) bool {
            _ = self;
            return std.mem.eql(u8, &a, &b);
        }
    };

    /// Initialize empty registry
    pub fn init(allocator: Allocator) !ContentRegistry {
        return .{
            .allocator = allocator,
            .entries = std.HashMap([32]u8, []const FunctionLocation, Context, 80).init(allocator),
        };
    }

    /// Free all resources
    pub fn deinit(self: *ContentRegistry) void {
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
    pub fn register(self: *ContentRegistry, hash: ContentHash, loc: FunctionLocation) !void {
        const gop = try self.entries.getOrPut(hash.bytes);

        if (!gop.found_existing) {
            // First entry with this hash
            const loc_copy = try loc.clone(self.allocator);
            gop.value_ptr.* = try self.allocator.dupe(FunctionLocation, &.{loc_copy});
        } else {
            // Append to existing locations
            const loc_copy = try loc.clone(self.allocator);
            const old_locs = gop.value_ptr.*;
            // Use dup + free instead of realloc (Zig 0.15 compatibility)
            const new_locs = try self.allocator.alloc(FunctionLocation, old_locs.len + 1);
            @memcpy(new_locs[0..old_locs.len], old_locs);
            new_locs[old_locs.len] = loc_copy;
            self.allocator.free(old_locs);
            gop.value_ptr.* = new_locs;
        }
    }

    /// Register a function by raw hash bytes
    pub fn registerBytes(self: *ContentRegistry, hash_bytes: [32]u8, loc: FunctionLocation) !void {
        const gop = try self.entries.getOrPut(hash_bytes);

        if (!gop.found_existing) {
            const loc_copy = try loc.clone(self.allocator);
            gop.value_ptr.* = try self.allocator.dupe(FunctionLocation, &.{loc_copy});
        } else {
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
    pub fn lookup(self: *const ContentRegistry, hash: ContentHash) ?[]const FunctionLocation {
        return self.entries.get(hash.bytes);
    }

    /// Look up by raw hash bytes
    pub fn lookupBytes(self: *const ContentRegistry, hash_bytes: [32]u8) ?[]const FunctionLocation {
        return self.entries.get(hash_bytes);
    }

    /// Check if a function with this hash exists
    pub fn contains(self: *const ContentRegistry, hash: ContentHash) bool {
        return self.entries.contains(hash.bytes);
    }

    /// Get total number of registered functions
    pub fn size(self: *const ContentRegistry) usize {
        return self.entries.count();
    }

    /// Get total number of functions (including duplicates)
    pub fn totalFunctions(self: *const ContentRegistry) usize {
        var count: usize = 0;
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            count += entry.value_ptr.*.len;
        }
        return count;
    }

    /// Detect all duplicate functions
    /// Returns list of duplicates (functions appearing >1 time)
    pub fn detectDuplicates(self: *const ContentRegistry) ![]const DuplicateInfo {
        var dup_list = ArrayListManaged(DuplicateInfo, null).init(self.allocator);

        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.*.len > 1) {
                var hash: ContentHash = undefined;
                @memcpy(&hash.bytes, &entry.key_ptr.*);

                // Clone locations
                const locs = try self.allocator.dupe(FunctionLocation, entry.value_ptr.*);
                for (locs, entry.value_ptr.*) |*dst, *src| {
                    dst.* = try src.clone(self.allocator);
                }

                try dup_list.append(.{
                    .hash = hash,
                    .locations = locs,
                });
            }
        }

        return dup_list.toOwnedSlice();
    }

    /// Get statistics about the registry
    pub const Stats = struct {
        unique_hashes: usize,
        total_functions: usize,
        duplicate_count: usize,
        duplicate_functions: usize,
    };

    pub fn stats(self: *const ContentRegistry) Stats {
        var unique: usize = 0;
        var total: usize = 0;
        var dup_hashes: usize = 0;
        var dup_funcs: usize = 0;

        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            unique += 1;
            const count = entry.value_ptr.*.len;
            total += count;
            if (count > 1) {
                dup_hashes += 1;
                dup_funcs += count;
            }
        }

        return .{
            .unique_hashes = unique,
            .total_functions = total,
            .duplicate_count = dup_hashes,
            .duplicate_functions = dup_funcs,
        };
    }

    /// Clear all entries
    pub fn clear(self: *ContentRegistry) void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.*) |*loc| {
                loc.deinit(self.allocator);
            }
            self.allocator.free(entry.value_ptr.*);
        }
        self.entries.clearAndFree();
    }

    /// Merge another registry into this one
    pub fn merge(self: *ContentRegistry, other: *const ContentRegistry) !void {
        var iter = other.entries.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.*) |loc| {
                try self.registerBytes(entry.key_ptr.*, loc);
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PERSISTENCE
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Default registry file path
pub const DEFAULT_REGISTRY_PATH = ".trinity/content_registry.json";

/// Load registry from JSON file
pub fn loadFromFile(allocator: Allocator, path: []const u8) !ContentRegistry {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024); // 1MB max
    defer allocator.free(content);

    return parseFromJson(allocator, content);
}

/// Save registry to JSON file
pub fn saveToFile(self: *const ContentRegistry, path: []const u8) !void {
    const json_str = try toJson(self.allocator, self);
    defer self.allocator.free(json_str);

    const dir = std.fs.path.dirname(path) orelse ".";
    try std.fs.cwd().makePath(dir);

    const file = try std.fs.cwd().createFile(path, .{ .mode = 0o644 });
    defer file.close();

    try file.writeAll(json_str);
}

/// Parse registry from JSON string
pub fn parseFromJson(allocator: Allocator, json_str: []const u8) !ContentRegistry {
    const parsed = try std.json.parseFromSlice(
        struct {
            entries: []struct {
                hash: []const u8,
                locations: []struct {
                    module: []const u8,
                    name: []const u8,
                    line: usize,
                    file_path: []const u8,
                },
            },
        },
        allocator,
        json_str,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    var registry = try ContentRegistry.init(allocator);

    for (parsed.value.entries) |entry| {
        var hash_bytes: [32]u8 = undefined;

        // Decode hex hash
        if (entry.hash.len >= 64) {
            for (0..32) |i| {
                const byte_str = entry.hash[i * 2 .. i * 2 + 2];
                hash_bytes[i] = std.fmt.parseInt(u8, byte_str, 16) catch |err| {
                    std.debug.panic("invalid hash byte {s}: {}", .{ byte_str, err });
                };
            }

            for (entry.locations) |loc| {
                const function_loc = FunctionLocation{
                    .module = try allocator.dupe(u8, loc.module),
                    .name = try allocator.dupe(u8, loc.name),
                    .line = loc.line,
                    .file_path = try allocator.dupe(u8, loc.file_path),
                };
                try registry.registerBytes(hash_bytes, function_loc);
            }
        }
    }

    return registry;
}

/// Serialize registry to JSON string
pub fn toJson(allocator: Allocator, self: *const ContentRegistry) ![]const u8 {
    const JsonLocation = struct {
        module: []const u8,
        name: []const u8,
        line: usize,
        file_path: []const u8,
    };

    const JsonEntry = struct {
        hash: []const u8,
        locations: []const JsonLocation,
    };

    var entries = ArrayListManaged(JsonEntry, null).init(allocator);

    var iter = self.entries.iterator();
    while (iter.next()) |entry| {
        // Encode hash as hex
        var hash_str: [64]u8 = undefined;
        for (0..32) |i| {
            _ = std.fmt.bufPrint(
                hash_str[i * 2 .. i * 2 + 2],
                "{x:0>2}",
                .{entry.key_ptr.*[i]},
            ) catch unreachable;
        }

        // Convert locations
        var locs = ArrayListManaged(JsonLocation, null).init(allocator);

        for (entry.value_ptr.*) |loc| {
            try locs.append(.{
                .module = loc.module,
                .name = loc.name,
                .line = loc.line,
                .file_path = loc.file_path,
            });
        }

        try entries.append(.{
            .hash = &hash_str,
            .locations = try locs.toOwnedSlice(),
        });
    }

    const result = try std.json.Stringify.valueAlloc(allocator, .{
        .version = "1.0",
        .entries = entries.items,
    }, .{ .whitespace = .indent_2 });

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════

test "ContentRegistry init and deinit" {
    const a = std.testing.allocator;
    var registry = try ContentRegistry.init(a);
    defer registry.deinit();

    try std.testing.expectEqual(@as(usize, 0), registry.size());
}

test "ContentRegistry register and lookup" {
    const a = std.testing.allocator;
    var registry = try ContentRegistry.init(a);
    defer registry.deinit();

    var hash: ContentHash = undefined;
    hash.bytes[0] = 0x01;

    const loc = FunctionLocation{
        .module = "test.module",
        .name = "test_func",
        .line = 10,
        .file_path = "test.tri",
    };

    try registry.register(hash, loc);

    const result = registry.lookup(hash);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(usize, 1), result.?.len);
    try std.testing.expectEqualStrings("test.module", result.?[0].module);
}

test "ContentRegistry detectDuplicates" {
    const a = std.testing.allocator;
    var registry = try ContentRegistry.init(a);
    defer registry.deinit();

    var hash: ContentHash = undefined;
    hash.bytes[0] = 0x01;

    const loc1 = FunctionLocation{
        .module = "module1",
        .name = "func1",
        .line = 10,
        .file_path = "file1.tri",
    };

    const loc2 = FunctionLocation{
        .module = "module2",
        .name = "func2",
        .line = 20,
        .file_path = "file2.tri",
    };

    try registry.register(hash, loc1);
    try registry.register(hash, loc2);

    const dups = try registry.detectDuplicates();
    defer {
        for (dups) |*d| d.deinit(a);
        a.free(dups);
    }

    try std.testing.expectEqual(@as(usize, 1), dups.len);
    try std.testing.expectEqual(@as(usize, 2), dups[0].locations.len);
}

test "ContentRegistry stats" {
    const a = std.testing.allocator;
    var registry = try ContentRegistry.init(a);
    defer registry.deinit();

    var hash1: ContentHash = undefined;
    hash1.bytes[0] = 0x01;

    var hash2: ContentHash = undefined;
    hash2.bytes[0] = 0x02;

    const loc1 = FunctionLocation{
        .module = "module1",
        .name = "func1",
        .line = 10,
        .file_path = "file1.tri",
    };

    const loc2 = FunctionLocation{
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
    try std.testing.expectEqual(@as(usize, 1), stats.duplicate_count);
    try std.testing.expectEqual(@as(usize, 2), stats.duplicate_functions);
}

test "ContentRegistry toJson and parseFromJson" {
    const a = std.testing.allocator;
    var registry = try ContentRegistry.init(a);
    defer registry.deinit();

    var hash: ContentHash = undefined;
    hash.bytes[0] = 0xAA;
    hash.bytes[1] = 0xBB;

    const loc = FunctionLocation{
        .module = "test.module",
        .name = "test_func",
        .line = 42,
        .file_path = "test/file.tri",
    };

    try registry.register(hash, loc);

    const json = try toJson(a, &registry);
    defer a.free(json);

    var parsed = try parseFromJson(a, json);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 1), parsed.size());

    const result = parsed.lookup(hash);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(usize, 1), result.?.len);
    try std.testing.expectEqualStrings("test.module", result.?[0].module);
    try std.testing.expectEqual(@as(usize, 42), result.?[0].line);
}

test "FunctionLocation clone" {
    const a = std.testing.allocator;

    const loc = FunctionLocation{
        .module = "test.module",
        .name = "test_func",
        .line = 42,
        .file_path = "test/file.tri",
    };

    var cloned = try loc.clone(a);
    defer cloned.deinit(a);

    try std.testing.expectEqualStrings("test.module", cloned.module);
    try std.testing.expectEqualStrings("test_func", cloned.name);
    try std.testing.expectEqual(@as(usize, 42), cloned.line);
    try std.testing.expectEqualStrings("test/file.tri", cloned.file_path);
}

test "ContentRegistry merge" {
    const a = std.testing.allocator;
    var registry1 = try ContentRegistry.init(a);
    defer registry1.deinit();

    var registry2 = try ContentRegistry.init(a);
    defer registry2.deinit();

    var hash1: ContentHash = undefined;
    hash1.bytes[0] = 0x01;

    var hash2: ContentHash = undefined;
    hash2.bytes[0] = 0x02;

    const loc1 = FunctionLocation{
        .module = "module1",
        .name = "func1",
        .line = 10,
        .file_path = "file1.tri",
    };

    const loc2 = FunctionLocation{
        .module = "module2",
        .name = "func2",
        .line = 20,
        .file_path = "file2.tri",
    };

    try registry1.register(hash1, loc1);
    try registry2.register(hash2, loc2);

    try registry1.merge(&registry2);

    try std.testing.expectEqual(@as(usize, 2), registry1.size());
    try std.testing.expect(registry1.contains(hash1));
    try std.testing.expect(registry1.contains(hash2));
}

test "ContentRegistry totalFunctions" {
    const a = std.testing.allocator;
    var registry = try ContentRegistry.init(a);
    defer registry.deinit();

    var hash: ContentHash = undefined;
    hash.bytes[0] = 0x01;

    const loc1 = FunctionLocation{
        .module = "module1",
        .name = "func1",
        .line = 10,
        .file_path = "file1.tri",
    };

    const loc2 = FunctionLocation{
        .module = "module2",
        .name = "func2",
        .line = 20,
        .file_path = "file2.tri",
    };

    const loc3 = FunctionLocation{
        .module = "module3",
        .name = "func3",
        .line = 30,
        .file_path = "file3.tri",
    };

    try registry.register(hash, loc1);
    try registry.register(hash, loc2);
    try registry.register(hash, loc3);

    try std.testing.expectEqual(@as(usize, 1), registry.size());
    try std.testing.expectEqual(@as(usize, 3), registry.totalFunctions());
}
