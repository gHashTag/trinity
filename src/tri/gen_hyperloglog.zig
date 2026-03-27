//! tri/hyperloglog — Cardinality estimation
//! TTT Dogfood v0.2 Stage 212

const std = @import("std");

pub const HyperLogLog = struct {
    registers: []u8,
    p: u6,
    allocator: std.mem.Allocator,

    const ALPHA: f64 = 0.7213;

    pub fn init(allocator: std.mem.Allocator, p: u6) !HyperLogLog {
        const m = @as(usize, 1) << p;
        const registers = try allocator.alloc(u8, m);
        @memset(registers, 0);

        return .{
            .registers = registers,
            .p = p,
            .allocator = allocator,
        };
    }

    fn hash64(x: u64) u64 {
        var h = x;
        h ^= h >> 33;
        h *%= 0xff51afd7ed558ccd;
        h ^= h >> 33;
        h *%= 0xc4ceb9fe1a85ec53;
        h ^= h >> 33;
        return h;
    }

    pub fn add(hll: *HyperLogLog, value: []const u8) void {
        const x = hash64(std.hash.Wyhash.hash(0, value));
        const index = x >> (64 - hll.p);

        const rho = @as(u8, @intCast(@clz(x << hll.p)));
        const reg = @max(hll.registers[index], rho);
        hll.registers[index] = reg;
    }

    pub fn count(hll: *const HyperLogLog) f64 {
        const m = @as(f64, @floatFromInt(@as(usize, 1) << hll.p));
        var sum: f64 = 0;
        for (hll.registers) |r| {
            sum += @as(f64, @floatFromInt(r));
        }

        const raw_estimate = ALPHA * m * m / sum;
        return raw_estimate;
    }

    pub fn deinit(hll: *HyperLogLog) void {
        hll.allocator.free(hll.registers);
    }
};

test "hyperloglog add count" {
    var hll = try HyperLogLog.init(std.testing.allocator, 4);
    defer hll.deinit();

    hll.add("a");
    hll.add("b");
    hll.add("c");

    const count = hll.count();
    try std.testing.expect(count > 0);
}
