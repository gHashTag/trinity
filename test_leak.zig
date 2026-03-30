const std = @import("std");
const staking = @import("firebird_staking");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var manager = staking.StakingManager.init(allocator);
    
    var address: [20]u8 = undefined;
    @memset(&address, 0);
    address[0] = 0x12;
    
    const stake_id = try manager.createStake(address, 100 * std.math.pow(u128, 10, 18), .one_month);
    std.debug.print("stake_id: {s}\n", .{stake_id});
    std.debug.print("StakePosition size: {d}\n", .{@sizeOf(staking.StakePosition)});
    
    manager.deinit();
}
