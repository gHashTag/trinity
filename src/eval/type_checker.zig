// E-zone: Type Checker for Tri Language
// Verifies type correctness, validates Result types, checks linear usage
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const temple = @import("temple");

// ═════════════════════════════════════════════════════════════════════════════
// TYPE CHECKING — Validates type correctness for Tri programs
// ═════════════════════════════════════════════════════════════════════════════

/// Type check error
pub const TypeError = error{
    Mismatch,
    Undefined,
    NotCallable,
    LinearUsedTwice,
    LinearNotConsumed,
    InvalidEffect,
};

/// Type checker state
pub const TypeChecker = struct {
    allocator: std.mem.Allocator,
    errors: std.ArrayList(Error),

    const Error = struct {
        kind: TypeError,
        message: []const u8,
        line: u32,
        column: u32,
    };

    pub fn init(allocator: std.mem.Allocator) TypeChecker {
        return .{
            .allocator = allocator,
            .errors = std.ArrayList(Error).init(allocator),
        };
    }

    pub fn deinit(self: *TypeChecker) void {
        self.errors.deinit();
    }

    /// Check if there are any errors
    pub fn hasErrors(self: *const TypeChecker) bool {
        return self.errors.items.len > 0;
    }

    /// Add a type error
    pub fn addError(self: *TypeChecker, kind: TypeError, message: []const u8, line: u32, column: u32) !void {
        try self.errors.append(.{
            .kind = kind,
            .message = message,
            .line = line,
            .column = column,
        });
    }

    /// Reset errors for reuse
    pub fn reset(self: *TypeChecker) void {
        self.errors.clearRetainingCapacity();
    }
};

// Tests
test "type checker init" {
    var checker = TypeChecker.init(std.testing.allocator);
    defer checker.deinit();

    try std.testing.expect(!checker.hasErrors());
}

test "type checker add error" {
    var checker = TypeChecker.init(std.testing.allocator);
    defer checker.deinit();

    try checker.addError(.Mismatch, "type mismatch", 10, 5);
    try std.testing.expect(checker.hasErrors());
}

test "type checker reset" {
    var checker = TypeChecker.init(std.testing.allocator);
    defer checker.deinit();

    try checker.addError(.Mismatch, "error", 1, 1);
    try std.testing.expect(checker.hasErrors());

    checker.reset();
    try std.testing.expect(!checker.hasErrors());
}
