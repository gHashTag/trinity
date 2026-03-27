//! tri/interval — Range operations
//! Auto-generated from specs/tri/tri_interval.tri
//! TTT Dogfood v0.2 Stage 140

const std = @import("std");

/// Numeric interval
pub const Interval = struct {
    start: i64,
    end: i64,
    inclusive: bool = true,

    /// Create interval
    pub fn create(start: i64, end: i64) Interval {
        return .{
            .start = start,
            .end = end,
            .inclusive = true,
        };
    }

    /// Check if value is in interval
    pub fn contains(self: Interval, value: i64) bool {
        if (!self.inclusive) {
            return value > self.start and value < self.end;
        }
        return value >= self.start and value <= self.end;
    }

    /// Check if intervals overlap
    pub fn overlaps(a: Interval, b: Interval) bool {
        if (a.start > b.end or b.start > a.end) return false;
        return true;
    }

    /// Get interval length
    pub fn length(self: Interval) usize {
        return @intCast(@max(0, self.end - self.start) + 1);
    }
};

/// Set of intervals
pub const IntervalSet = struct {
    intervals: std.ArrayList(Interval),

    /// Free resources
    pub fn deinit(self: *IntervalSet, allocator: std.mem.Allocator) void {
        self.intervals.deinit(allocator);
    }

    /// Add interval (simplified)
    pub fn add(self: *IntervalSet, interval: Interval, allocator: std.mem.Allocator) !void {
        try self.intervals.append(allocator, interval);
    }

    /// Check if value is in any interval
    pub fn contains(self: *const IntervalSet, value: i64) bool {
        for (self.intervals.items) |interval| {
            if (interval.contains(value)) return true;
        }
        return false;
    }
};

/// Union of interval sets (unionSets to avoid reserved keyword)
pub fn unionSets(a: IntervalSet, b: IntervalSet, allocator: std.mem.Allocator) !IntervalSet {
    var result = IntervalSet{
        .intervals = std.ArrayList(Interval).initCapacity(allocator, a.intervals.items.len + b.intervals.items.len) catch unreachable,
    };
    errdefer result.intervals.deinit(allocator);

    for (a.intervals.items) |interval| {
        try result.intervals.append(allocator, interval);
    }
    for (b.intervals.items) |interval| {
        try result.intervals.append(allocator, interval);
    }

    return result;
}

test "interval contains" {
    const interval = Interval.create(10, 20);
    try std.testing.expect(interval.contains(15));
    try std.testing.expect(!interval.contains(25));
}

test "interval overlaps" {
    const a = Interval.create(10, 20);
    const b = Interval.create(15, 25);
    try std.testing.expect(a.overlaps(b));

    const c = Interval.create(30, 40);
    try std.testing.expect(!a.overlaps(c));
}

test "interval set contains" {
    var set = IntervalSet{
        .intervals = std.ArrayList(Interval).initCapacity(std.testing.allocator, 2) catch unreachable,
    };
    defer set.deinit(std.testing.allocator);

    try set.add(Interval.create(10, 20), std.testing.allocator);
    try set.add(Interval.create(30, 40), std.testing.allocator);

    try std.testing.expect(set.contains(15));
    try std.testing.expect(set.contains(35));
    try std.testing.expect(!set.contains(25));
}

test "interval union" {
    var set1 = IntervalSet{
        .intervals = std.ArrayList(Interval).initCapacity(std.testing.allocator, 1) catch unreachable,
    };
    defer set1.deinit(std.testing.allocator);
    try set1.add(Interval.create(10, 20), std.testing.allocator);

    var set2 = IntervalSet{
        .intervals = std.ArrayList(Interval).initCapacity(std.testing.allocator, 1) catch unreachable,
    };
    defer set2.deinit(std.testing.allocator);
    try set2.add(Interval.create(30, 40), std.testing.allocator);

    var merged = try unionSets(set1, set2, std.testing.allocator);
    defer merged.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), merged.intervals.items.len);
}
