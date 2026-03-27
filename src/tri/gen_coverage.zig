//! tri/coverage — Code coverage tracking
//! TTT Dogfood v0.2 Stage 305

const std = @import("std");

pub const Coverage = struct {
    covered: std.ArrayList(bool),
    total: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, total: usize) !Coverage {
        var covered = try std.ArrayList(bool).initCapacity(allocator, total);
        for (0..total) |_| {
            try covered.append(allocator, false);
        }
        return .{
            .covered = covered,
            .total = total,
            .allocator = allocator,
        };
    }

    pub fn mark(cov: *Coverage, line: usize) void {
        if (line < cov.total) {
            cov.covered.items[line] = true;
        }
    }

    pub fn percentage(cov: *const Coverage) f64 {
        var hit: usize = 0;
        for (cov.covered.items) |c| {
            if (c) hit += 1;
        }
        return @as(f64, @floatFromInt(hit)) / @as(f64, @floatFromInt(cov.total));
    }

    pub fn deinit(cov: *Coverage) void {
        cov.covered.deinit(cov.allocator);
    }
};

test "coverage" {
    var cov = try Coverage.init(std.testing.allocator, 10);
    defer cov.deinit();
    cov.mark(5);
    try std.testing.expect(cov.percentage() > 0);
}
