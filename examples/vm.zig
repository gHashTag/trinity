// Trinity - VM Example
const std = @import("std");
const trinity = @import("trinity");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    std.debug.print("\n=== Trinity VM Example ===\n\n", .{});

    var vm = trinity.VSAVM.init(gpa.allocator());
    defer vm.deinit();

    // Program: bind/unbind roundtrip
    const program = [_]trinity.VSAInstruction{
        .{ .opcode = .v_random, .dst = 0, .imm = 111 },
        .{ .opcode = .v_random, .dst = 1, .imm = 222 },
        .{ .opcode = .v_bind, .dst = 2, .src1 = 0, .src2 = 1 },
        .{ .opcode = .v_unbind, .dst = 3, .src1 = 2, .src2 = 1 },
        .{ .opcode = .v_cosine, .src1 = 0, .src2 = 3 },
        .{ .opcode = .halt },
    };

    try vm.loadProgram(&program);
    try vm.run();

    std.debug.print("Program:\n", .{});
    std.debug.print("  v0 = random(111)\n", .{});
    std.debug.print("  v1 = random(222)\n", .{});
    std.debug.print("  v2 = bind(v0, v1)\n", .{});
    std.debug.print("  v3 = unbind(v2, v1)\n", .{});
    std.debug.print("  f0 = cosine(v0, v3)\n\n", .{});
    std.debug.print("Result: f0 = {d:.4} (expected ~1.0)\n", .{vm.registers.f0});
    std.debug.print("Cycles: {}\n\n", .{vm.cycle_count});
}
