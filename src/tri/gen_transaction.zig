//! tri/transaction — Transaction log
//! TTT Dogfood v0.2 Stage 294

const std = @import("std");

pub const Operation = enum { insert, update, delete };

pub const Transaction = struct {
    operations: std.ArrayList(struct {
        op: Operation,
        key: []const u8,
        value: []const u8,
    }),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Transaction {
        return .{
            .operations = std.ArrayList(struct {
                op: Operation,
                key: []const u8,
                value: []const u8,
            }).init(allocator),
        };
    }

    pub fn add(tx: *Transaction, op: Operation, key: []const u8, value: []const u8) !void {
        const key_copy = try tx.allocator.dupe(u8, key);
        const value_copy = try tx.allocator.dupe(u8, value);
        try tx.operations.append(.{ .op = op, .key = key_copy, .value = value_copy });
    }

    pub fn commit(tx: *Transaction) !void {
        _ = tx;
    }

    pub fn rollback(tx: *Transaction) void {
        _ = tx;
    }

    pub fn deinit(tx: *Transaction) void {
        for (tx.operations.items) |op| {
            tx.allocator.free(op.key);
            tx.allocator.free(op.value);
        }
        tx.operations.deinit();
    }
};

test "transaction" {
    var tx = Transaction.init(std.testing.allocator);
    defer tx.deinit();
    try tx.add(.insert, "k", "v");
}
