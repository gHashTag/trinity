//! tri/snapshot — Snapshot testing
//! TTT Dogfood v0.2 Stage 308

const std = @import("std");

pub const Snapshot = struct {
    data: []const u8,

    pub fn init(data: []const u8) Snapshot {
        return .{ .data = data };
    }

    pub fn match(snapshot: *const Snapshot, expected: []const u8) bool {
        return std.mem.eql(u8, snapshot.data, expected);
    }
};

test "snapshot" {
    const snap = Snapshot.init("hello");
    try std.testing.expect(snap.match("hello"));
}
