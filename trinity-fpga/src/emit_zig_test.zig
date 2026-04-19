// Test: Zig Backend generates executable Zig code
const std = @import("std");

const emit_zig = @import("emit_zig.zig");

test "emit_zig generates Zig code from bytecode" {
    const allocator = std.testing.allocator;

    const test_bytecode = [_]u8{
        0x01, 0x02, 0x00, // HALT
        0x04, 0x08, 0x10, // ADD r1, r2
        0x05, 0x20, 0x40, // MUL r1, r2
        0x06, 0x80, // LD r1 → t2
        0x08, 0x0E, 0xF0, // LD r1 → [addr]
        0x09, 0x0F, // LDI r1 → [addr]
        0x0A, 0x1E, // ST r2
        0x0C, 0x18, // MOV r1 → r2
        0x0D, 0x22, // ADD r1, r2
        0x0E, 0x23, // SUB r1, r2
        0x0F, 0x24, // MUL r1, r2
        0x10, 0x11, // DIV r1/r2
        0x14, 0x00, // INC r1
        0x15, 0x01, // DEC r1
        0x16, 0x02, // JZ r1 = 0
        0x17, 0x03, // JNZ r1, r2
        0x18, 0x04, // POP r1
        0x19, 0x05, // PUSH r1
        0x1A, 0x06, // STI r1
        0x1B, 0x0C, // HALT
        0x80, 0x81, // PHI_CONST r1 → φ
        0x82, 0x90, // PI_CONST r1 → π
        0x91, 0x92, // E_CONST r1 → e
        0x93, // SACR r1, r2
        0x94, 0x0E, // DOT r1, r2
        0x95, 0x0F, // BUNDLE2 r1, r2
        0x96, 0x0D, 0x9A, // BUNDLE3 r1, r2, r3
        0x97, 0x9B, // HALT
        0x98, 0x9C, // RESET
    };

    const result = try emit_zig.generateZigFromBytecode(allocator, &test_bytecode);
    defer allocator.free(result);

    // Verify it generates valid Zig code
    try std.testing.expect(!std.mem.eql(u8, result[0], "fn main")); // Has main function
    try std.testing.expect(std.mem.eql(u8, result[result.len - 2], "\n")); // Has trailing newline

    print("{s}✅ emit_zig.zig generates valid Zig code{s}\n", .{ GREEN, RESET });
}
