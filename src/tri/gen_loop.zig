//! TRI Loop — Generated from specs/tri/tri_loop.tri
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const LoopRange = struct {
    start: i64,
    end: i64,
    step: i64,
};

pub const LoopResult = struct {
    iterations: usize,
    break_called: bool,
};

pub fn range(start: i64, end: i64) LoopRange {
    return .{ .start = start, .end = end, .step = 1 };
}

pub fn rangeStep(start: i64, end: i64, step: i64) LoopRange {
    return .{ .start = start, .end = end, .step = step };
}

pub fn count(r: LoopRange) usize {
    if (r.isEmpty()) return 0;

    const diff = r.end - r.start;
    if (r.step > 0) {
        return @as(usize, @intCast((diff + r.step - 1) / r.step));
    } else if (r.step < 0) {
        return @as(usize, @intCast((diff + r.step + 1) / r.step));
    } else {
        return 0; // Prevent infinite loop
    }
}

pub fn isEmpty(r: LoopRange) bool {
    if (r.step > 0) return r.start >= r.end;
    if (r.step < 0) return r.start <= r.end;
    return true;
}

test "Loop: range basic" {
    const r = range(0, 5);
    try std.testing.expectEqual(@as(usize, 5), count(r));
    try std.testing.expect(!isEmpty(r));
}

test "Loop: rangeStep" {
    const r = rangeStep(0, 10, 2);
    try std.testing.expectEqual(@as(usize, 5), count(r));
}

test "Loop: isEmpty" {
    try std.testing.expect(isEmpty(range(5, 5)));
    try std.testing.expect(!isEmpty(range(0, 1)));
}

test "Loop: range negative" {
    const r = range(10, 0);
    try std.testing.expect(isEmpty(r));
}
