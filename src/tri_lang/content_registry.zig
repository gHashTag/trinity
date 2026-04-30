const std = @import("std");
const ContentHash = @import("content_hash.zig").ContentHash;

pub const FunctionLocation = struct {
    file_path: []const u8,
    line: u32,
    hash: ContentHash,
};

pub const Registry = struct {
    entries: std.StringHashMap(FunctionLocation),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{
            .entries = std.StringHashMap(FunctionLocation).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Registry) void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.entries.deinit();
    }

    pub fn register(self: *Registry, hash_hex: []const u8, location: FunctionLocation) !void {
        const key = try self.allocator.dupe(u8, hash_hex);
        const existing = self.entries.fetchPut(key, location) catch |err| {
            self.allocator.free(key);
            return err;
        };
        if (existing) |old| {
            self.allocator.free(old.key);
        }
    }

    pub fn lookup(self: *Registry, hash_hex: []const u8) ?FunctionLocation {
        return self.entries.get(hash_hex);
    }

    pub fn hasHash(self: *Registry, hash_hex: []const u8) bool {
        return self.entries.contains(hash_hex);
    }

    pub fn count(self: *Registry) usize {
        return self.entries.count();
    }

    pub fn deduplicate(self: *Registry) usize {
        var dedup = Registry.init(self.allocator);
        defer dedup.deinit();

        var iter = self.entries.iterator();
        var removed: usize = 0;
        while (iter.next()) |entry| {
            if (dedup.hasHash(entry.key_ptr.*)) {
                removed += 1;
            } else {
                dedup.register(entry.key_ptr.*, entry.value_ptr.*) catch {};
            }
        }
        return removed;
    }
};

test "register and lookup" {
    const allocator = std.testing.allocator;
    var reg = Registry.init(allocator);
    defer reg.deinit();

    const hash = "aa" ** 32;
    const loc = FunctionLocation{
        .file_path = "test.tri",
        .line = 42,
        .hash = [_]u8{0xAA} ** 32,
    };

    try reg.register(hash, loc);
    try std.testing.expectEqual(@as(usize, 1), reg.count());

    const found = reg.lookup(hash);
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("test.tri", found.?.file_path);
    try std.testing.expectEqual(@as(u32, 42), found.?.line);
}

test "duplicate registration updates" {
    const allocator = std.testing.allocator;
    var reg = Registry.init(allocator);
    defer reg.deinit();

    const hash = "bb" ** 32;
    try reg.register(hash, .{ .file_path = "a.tri", .line = 1, .hash = [_]u8{0} ** 32 });
    try reg.register(hash, .{ .file_path = "b.tri", .line = 2, .hash = [_]u8{0} ** 32 });

    try std.testing.expectEqual(@as(usize, 1), reg.count());
    try std.testing.expectEqualStrings("b.tri", reg.lookup(hash).?.file_path);
}

test "lookup missing returns null" {
    const allocator = std.testing.allocator;
    var reg = Registry.init(allocator);
    defer reg.deinit();

    try std.testing.expect(reg.lookup("nonexistent") == null);
}
