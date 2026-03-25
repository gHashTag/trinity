// E-zone: Linear Types Verifier
// Ensures linear values are consumed exactly once
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Linear type tracking state
pub const LinearState = enum {
    /// Not yet used
    Unused,
    /// Used exactly once (valid)
    Consumed,
    /// Used multiple times (error)
    Overused,
};

/// Linear type error
pub const LinearError = error{
    LinearValueConsumedTwice,
    LinearValueNeverConsumed,
    LinearValueDropped,
};

/// Track linear value usage across a function
pub const LinearTracker = struct {
    allocator: std.mem.Allocator,
    values: std.StringHashMap(LinearState),

    pub fn init(allocator: std.mem.Allocator) LinearTracker {
        return .{
            .allocator = allocator,
            .values = std.StringHashMap(LinearState).init(allocator),
        };
    }

    pub fn deinit(self: *LinearTracker) void {
        self.values.deinit();
    }

    /// Mark a linear value as consumed
    pub fn consume(self: *LinearTracker, name: []const u8) !void {
        const entry = try self.values.getOrPut(name);
        if (entry.found_existing) {
            if (entry.value_ptr.* == .Consumed) {
                return error.LinearValueConsumedTwice;
            }
        }
        entry.value_ptr.* = .Consumed;
    }

    /// Check if all linear values were consumed
    pub fn validateAllConsumed(self: *const LinearTracker) !void {
        var iter = self.values.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.* == .Unused) {
                return error.LinearValueNeverConsumed;
            }
        }
    }
};

// Tests
test "linear tracker consume" {
    const tracker = LinearTracker.init(std.testing.allocator);
    defer tracker.deinit();

    try tracker.consume("buffer1");
    try tracker.consume("buffer2");
    try std.testing.expectError(error.LinearValueConsumedTwice, tracker.consume("buffer1"));
}

test "linear tracker validate all consumed" {
    const tracker = LinearTracker.init(std.testing.allocator);
    defer tracker.deinit();

    try tracker.consume("buffer1");
    try tracker.consume("buffer2");
    try tracker.validateAllConsumed();
}

test "linear tracker uncomsumed error" {
    const tracker = LinearTracker.init(std.testing.allocator);
    defer tracker.deinit();

    try tracker.consume("buffer1");
    // buffer2 never consumed
    try std.testing.expectError(error.LinearValueNeverConsumed, tracker.validateAllConsumed());
}
