//! tri/golden_master — Golden master testing
//! TTT Dogfood v0.2 Stage 309

const std = @import("std");

pub const GoldenMaster = struct {
    golden_output: []const u8,

    pub fn init(golden_output: []const u8) GoldenMaster {
        return .{ .golden_output = golden_output };
    }

    pub fn compare(gm: *const GoldenMaster, actual: []const u8) bool {
        return std.mem.eql(u8, gm.golden_output, actual);
    }
};

test "golden master" {
    var master = GoldenMaster.init("expected");
    try std.testing.expect(master.compare("expected"));
}
