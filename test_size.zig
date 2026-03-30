const std = @import("std");
const staking = @import("./src/firebird/staking.zig");

pub fn main() !void {
    std.debug.print("StakePosition size: {d}\n", .{@sizeOf(staking.StakePosition)});
    std.debug.print("StakingManager size: {d}\n", .{@sizeOf(staking.StakingManager)});
}
