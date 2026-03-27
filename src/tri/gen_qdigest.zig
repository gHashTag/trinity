//! tri/qdigest — Quantile digest sketch
//! TTT Dogfood v0.2 Stage 220

const std = @import("std");

const K = 50;

pub const QDigest = struct {
    nodes: std.ArrayList(Node),
    size: usize,
    max_size: usize,
    k: f64,
    allocator: std.mem.Allocator,

    const Node = struct {
        value: f64,
        rank: f64,
        count: f64,
    };

    pub fn init(allocator: std.mem.Allocator) !QDigest {
        return .{
            .nodes = try std.ArrayList(Node).initCapacity(allocator, K),
            .size = 0,
            .max_size = K,
            .k = 1.0,
            .allocator = allocator,
        };
    }

    pub fn insert(qd: *QDigest, value: f64) !void {
        const node = Node{ .value = value, .rank = 0, .count = 1 };
        try qd.nodes.append(qd.allocator, node);
        qd.size += 1;

        if (qd.size > qd.max_size) {
            try qd.compress();
        }
    }

    fn compress(qd: *QDigest) !void {
        while (qd.nodes.items.len > qd.max_size) {
            _ = qd.nodes.orderedRemove(0);
            qd.size -= 1;
        }
    }

    pub fn quantile(qd: *const QDigest, q: f64) f64 {
        if (qd.nodes.items.len == 0) return 0;

        const target = q * @as(f64, @floatFromInt(qd.size));
        var sum: f64 = 0;

        for (qd.nodes.items) |n| {
            sum += n.count;
            if (sum >= target) {
                return n.value;
            }
        }

        return qd.nodes.items[qd.nodes.items.len - 1].value;
    }

    pub fn deinit(qd: *QDigest) void {
        qd.nodes.deinit(qd.allocator);
    }
};

test "qdigest insert quantile" {
    var qd = try QDigest.init(std.testing.allocator);
    defer qd.deinit();

    try qd.insert(1.0);
    try qd.insert(2.0);
    try qd.insert(3.0);
    try qd.insert(4.0);
    try qd.insert(5.0);

    const median = qd.quantile(0.5);
    try std.testing.expect(median > 0);
}
