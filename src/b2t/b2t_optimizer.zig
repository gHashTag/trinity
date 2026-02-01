// B2T Optimizer - Binary-to-Ternary Optimization Pass
// Converts binary arithmetic to native ternary operations
// V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const b2t_lifter = @import("b2t_lifter.zig");

pub const OptLevel = enum {
    O0, // No optimization
    O1, // Convert arithmetic to ternary
    O2, // + Constant folding
};

pub const OptStats = struct {
    binary_ops: u32,
    ternary_ops: u32,
    constants_folded: u32,

    pub fn init() OptStats {
        return OptStats{
            .binary_ops = 0,
            .ternary_ops = 0,
            .constants_folded = 0,
        };
    }
};

pub const Optimizer = struct {
    allocator: std.mem.Allocator,
    level: OptLevel,
    stats: OptStats,

    pub fn init(allocator: std.mem.Allocator, level: OptLevel) Optimizer {
        return Optimizer{
            .allocator = allocator,
            .level = level,
            .stats = OptStats.init(),
        };
    }

    /// Optimize a TVC module in-place
    pub fn optimize(self: *Optimizer, module: *b2t_lifter.TVCModule) void {
        if (self.level == .O0) return;

        for (module.functions.items) |*func| {
            self.optimizeFunction(func);
        }
    }

    fn optimizeFunction(self: *Optimizer, func: *b2t_lifter.TVCFunction) void {
        for (func.blocks.items) |*block| {
            self.optimizeBlock(block);
        }
    }

    fn optimizeBlock(self: *Optimizer, block: *b2t_lifter.TVCBlock) void {
        for (block.instructions.items) |*inst| {
            self.optimizeInstruction(inst);
        }
    }

    fn optimizeInstruction(self: *Optimizer, inst: *b2t_lifter.TVCInstruction) void {
        // O1: Convert binary arithmetic to ternary
        switch (inst.opcode) {
            .t_add => {
                inst.opcode = .t_tadd;
                self.stats.binary_ops += 1;
                self.stats.ternary_ops += 1;
            },
            .t_sub => {
                inst.opcode = .t_tsub;
                self.stats.binary_ops += 1;
                self.stats.ternary_ops += 1;
            },
            .t_mul => {
                inst.opcode = .t_tmul;
                self.stats.binary_ops += 1;
                self.stats.ternary_ops += 1;
            },
            .t_div => {
                inst.opcode = .t_tdiv;
                self.stats.binary_ops += 1;
                self.stats.ternary_ops += 1;
            },
            .t_cmp => {
                inst.opcode = .t_tcmp;
                self.stats.binary_ops += 1;
                self.stats.ternary_ops += 1;
            },
            else => {},
        }
    }

    pub fn getStats(self: *const Optimizer) OptStats {
        return self.stats;
    }
};

// Tests
fn createTestModule(allocator: std.mem.Allocator, opcodes: []const b2t_lifter.TVCOpcode) !b2t_lifter.TVCModule {
    var module = b2t_lifter.TVCModule.init(allocator);
    errdefer module.deinit();

    var func = b2t_lifter.TVCFunction.init(allocator, 0);
    errdefer func.deinit();

    var block = b2t_lifter.TVCBlock.init(allocator, 0);
    errdefer block.deinit();

    for (opcodes, 0..) |opcode, i| {
        try block.instructions.append(b2t_lifter.TVCInstruction{
            .opcode = opcode,
            .dest = @intCast(i),
            .operands = .{ 1, 2, 0, 0 },
            .operand_count = 2,
            .source_address = 0,
        });
    }

    try func.blocks.append(block);
    try module.functions.append(func);

    return module;
}

test "optimizer O0 no changes" {
    var module = try createTestModule(std.testing.allocator, &[_]b2t_lifter.TVCOpcode{.t_add});
    defer module.deinit();

    var opt = Optimizer.init(std.testing.allocator, .O0);
    opt.optimize(&module);

    // Should remain t_add
    try std.testing.expectEqual(b2t_lifter.TVCOpcode.t_add, module.functions.items[0].blocks.items[0].instructions.items[0].opcode);
}

test "optimizer O1 converts arithmetic" {
    var module = try createTestModule(std.testing.allocator, &[_]b2t_lifter.TVCOpcode{ .t_add, .t_mul });
    defer module.deinit();

    var opt = Optimizer.init(std.testing.allocator, .O1);
    opt.optimize(&module);

    // Should be converted to ternary
    try std.testing.expectEqual(b2t_lifter.TVCOpcode.t_tadd, module.functions.items[0].blocks.items[0].instructions.items[0].opcode);
    try std.testing.expectEqual(b2t_lifter.TVCOpcode.t_tmul, module.functions.items[0].blocks.items[0].instructions.items[1].opcode);

    const stats = opt.getStats();
    try std.testing.expectEqual(@as(u32, 2), stats.binary_ops);
    try std.testing.expectEqual(@as(u32, 2), stats.ternary_ops);
}

test "optimizer converts comparison" {
    var module = try createTestModule(std.testing.allocator, &[_]b2t_lifter.TVCOpcode{.t_cmp});
    defer module.deinit();

    var opt = Optimizer.init(std.testing.allocator, .O1);
    opt.optimize(&module);

    // Should be converted to t_tcmp
    try std.testing.expectEqual(b2t_lifter.TVCOpcode.t_tcmp, module.functions.items[0].blocks.items[0].instructions.items[0].opcode);
}

test "optimizer converts all arithmetic ops" {
    var module = try createTestModule(std.testing.allocator, &[_]b2t_lifter.TVCOpcode{ .t_add, .t_sub, .t_mul, .t_div });
    defer module.deinit();

    var opt = Optimizer.init(std.testing.allocator, .O1);
    opt.optimize(&module);

    const insts = module.functions.items[0].blocks.items[0].instructions.items;
    try std.testing.expectEqual(b2t_lifter.TVCOpcode.t_tadd, insts[0].opcode);
    try std.testing.expectEqual(b2t_lifter.TVCOpcode.t_tsub, insts[1].opcode);
    try std.testing.expectEqual(b2t_lifter.TVCOpcode.t_tmul, insts[2].opcode);
    try std.testing.expectEqual(b2t_lifter.TVCOpcode.t_tdiv, insts[3].opcode);
}
